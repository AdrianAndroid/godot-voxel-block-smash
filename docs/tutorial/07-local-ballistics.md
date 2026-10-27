# 第 7 章：模型转动时，子弹为什么还能命中

[← 上一页：第 6 章：一次发射为什么需要事务和票据](06-gameplay-transactions.md) · [总目录](README.md) · [下一页：第 8 章：选靶不是找颜色，而是证明路径可达 →](08-target-selection.md)

## 本章目标

讲清屏幕、世界、模型局部与格空间之间的关系，并能解释本项目选择格空间弹道的产品含义。掌握连续扫掠与两阶段碰撞查询，知道为什么碰撞事实与实际消除要分层。完成之后，你应能从一段命中日志判断位置到底属于哪个空间，而不是靠不断调偏移量碰运气。

## 概念讲解：先确定这个游戏想模拟什么

常见弹道做法是出膛时计算一次世界方向，然后每步 `world_pos += velocity * dt`。若目标静止，这很合理。玩家在球飞行中旋转青蛙，目标的世界位置变了，旧直线自然可能错过。对于真实射击模拟，这未必是 bug；对于本项目“旋转查看模型，不应让已经锁定的消除失效”的体验要求，它就不合适。

可选方案包括追踪当前目标世界位置、让子弹随模型父节点转动、锁定模型格空间轨迹。追踪弹会改变方向，需处理转弯速率与路径遮挡；仅设置父节点会把可视对象转走，却未必让物理使用同一变换。项目选择最后一种：位置、方向和速度都在固定格空间中推进，模型转动只改变世界投影。它表达的是一种玩法约定，不是现实惯性力学。

记当前格到世界变换为 T，格空间点 g 的世界位置为 `T*g`；世界点反算格位置为 `T.affine_inverse()*w`。点的变换包含平移，方向只通过 Basis 变换，不应把模型中心平移加进速度。单位方向需要归一化，速度另存为格/秒。这几个细节比记住函数名更重要，因为错用点和向量可能在模型原点附近看似正常，换位置后才出现斜飞。

[scripts/voxel/voxel_model_node.gd:35](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/voxel/voxel_model_node.gd.txt:35)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/voxel/voxel_model_node.gd#L35) · [仓库内快照](source-baseline/scripts/voxel/voxel_model_node.gd.txt)） 提供当前变换。这里仍要记住第 4 章的适用条件：当前模型 voxel_size=1，渲染与碰撞存在半格约定差异，不能声称这个函数已经支持任意缩放的严格统一。教程的数学意图与实际实现边界需要同时呈现。

## 动手步骤：沿一颗球追踪坐标

从 [scripts/gameplay/fire_geometry.gd:30](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/gameplay/fire_geometry.gd.txt:30)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/gameplay/fire_geometry.gd#L30) · [仓库内快照](source-baseline/scripts/gameplay/fire_geometry.gd.txt)） 开始。屏幕炮口位置通过相机投射形成射线，再结合模型空间边界得到发射原点。这个过程回答“二维炮台画在哪里，三维球从哪里开始”。它不是拿屏幕 `(x,y)` 直接作为世界 `(x,y,0)`；相机位置、视角和模型姿态都参与计算。

控制器收到原点与 aim_grid_point 后，用两者之差算出格空间方向。[scripts/projectile/projectile_system.gd:40](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/projectile/projectile_system.gd.txt:40)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/projectile/projectile_system.gd#L40) · [仓库内快照](source-baseline/scripts/projectile/projectile_system.gd.txt)） 记录 local_pos、local_dir 和 speed。球每步前进多少由速度乘 dt 得到，世界矩阵不参与这一步的位移积分。教学公式如下，省略了碰撞与生命周期，不可直接替换正式实现：

```gdscript
# 教学简化版：位置和速度始终以格为单位。
var p0: Vector3 = ball.local_pos
var p1: Vector3 = p0 + ball.local_dir * ball.speed * dt
# 碰撞应查询整条 p0→p1，不能直接把 p1 当成已到达的位置。
var display_world: Vector3 = current_world_from_grid * p1
```

假设球和目标的格空间位置分别为 g_ball 和 g_target，它们的相对关系不因外层旋转而改变。T 每步变化，世界轨迹可能是弯曲的，但格空间中的扫掠仍沿同一方向。玩家看到模型与球共同改变投影，因此旋转不再破坏已经锁定的几何关系。不要把这种视觉描述成“自动吸附目标”：球仍要碰撞，目标若失效仍需正确取消。

为什么要连续检测？速度 120 格/秒、60Hz 时，一步可走 2 格；如果只测试终点是否位于方块内，就可能从方块前直接跳到后面。扫掠（Sweep）测试整条线段是否首次进入碰撞区域。帧率下降时单步更长，问题更明显，所以提高球速必须与连续碰撞一起考虑。

碰撞分两层。空间索引以 DDA 遍历线段经过的格子并加入半径相关邻居，得到候选 ID；窄相求解器再计算每个候选盒的进入时间，选最早者。[scripts/voxel/voxel_spatial_index.gd:58](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/voxel/voxel_spatial_index.gd.txt:58)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/voxel/voxel_spatial_index.gd#L58) · [仓库内快照](source-baseline/scripts/voxel/voxel_spatial_index.gd.txt)） 与 [scripts/projectile/collision_solver.gd:8](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/projectile/collision_solver.gd.txt:8)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/projectile/collision_solver.gd#L8) · [仓库内快照](source-baseline/scripts/projectile/collision_solver.gd.txt)） 分别负责这两件事。只要候选集合漏了一块，窄相再精确也无能为力；候选多一点影响速度，候选少了影响正确性。

当前求解器将盒子沿三个轴扩张 radius，然后做线段与 AABB 的 slab 相交。这是对球扫掠的保守盒扩张近似，角部并非严格球与盒的圆角闵可夫斯基边界。不要在教学中称它为“精确球体碰撞”。选靶和真实飞行使用同一模型，至少保持了可达性判断与命中的契约一致。若改成精确球盒算法，两边必须一起改并重新验证面角目标。

slab 法可以理解成三个轴分别给出“线段在哪一段参数范围位于盒内”，再取这些区间的交集。某轴方向接近零时，不能直接除以零，而应判断起点是否已在该轴区间内。最终 t 在 0～1 之间表示本步最早接触。多个块同时命中时按稳定 ID 破平局，避免字典遍历顺序影响结果。

物理结束后，[scripts/projectile/ball_physics.gd:34](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/projectile/ball_physics.gd.txt:34)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/projectile/ball_physics.gd#L34) · [仓库内快照](source-baseline/scripts/projectile/ball_physics.gd.txt)） 用本步的 world_from_grid 投影命中点、法线和速度，再发布事件。不能用发射时旧矩阵显示粒子，否则模型已经转动，爆炸却留在旧世界位置。当前法线转换直接用 basis，在纯旋转条件下合适；若引入非均匀缩放，应重新审视逆转置法线变换，而不是沿用后声称仍普遍正确。

### 延伸练习：用两种变换检查不变量

在纸上选择格空间起点(0,0,0)和目标(4,0,0)。模型不转时，世界轨迹沿某个轴；模型整体绕Y旋转90度后，两点一起映射，格空间距离仍是4。再把模型整体平移十个单位，方向不该增加十。这两个简单例子足以检查你是否把点变换误用到方向，以及是否把发射时矩阵缓存成永久有效。

接着考虑模型缩放。如果每格大小变成两倍，而ball_speed仍称为格/秒，世界移动速度也应随之变成两倍；若设计希望世界速度不变，就必须显式转换单位。两种方案都能成立，问题在于接口未说明时不同模块各选一种。本基线只验证单位尺度，所以扩展前应先确定单位契约，再修改矩阵，而不是让测试迎合偶然结果。

最后区分“锁定轨迹”和“锁定命中结果”。前者只确保旋转不改变局部路径，仍可能因其他事件使目标失效；后者则会无论是否碰撞都删目标，是另一种玩法。本项目需要前者。日志里保留目标ID、实际首命中ID和取消原因，能够证明系统没有把两种概念悄悄混合。

## 踩坑记录：漏碰通常发生在层间

历史记录里一个真实错误来自空间索引坐标打包。球从模型边界外出发会经过负格坐标，旧位打包与邻域偏移的组合造成借位或回绕，漏掉坐标 0 附近的候选。修复加入偏置并统一打包入口。这个案例说明“模型坐标非负”不代表“射线经过的所有格子非负”。算法的输入域应包括边界外起点。

另一个回归发生在亚单位线段：本步末端还没进入目标格，但球半径已经接触扩张盒。若候选只看中心经过的格子，就会漏掉真实应该命中的邻格。开发记录 [docs/dev-step-log.md:377](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/docs/dev-step-log.md.txt:377)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/docs/dev-step-log.md#L377) · [仓库内快照](source-baseline/docs/dev-step-log.md.txt)） 保存了对应夹具思路。把这种极小反例固定下来，比只用高速大球测试更能发现边界问题。

球的回收顺序也必须谨慎。若在产生 hit 时立即删掉全部球数据，稍后事件包装拿不到 shot_id；若永远保留 ended 球，长局内存会持续增长。当前先派发结果快照，再回收 ended 对象，并保留有界诊断历史。这是正确性和资源管理共同决定的顺序，不是单纯内存优化。

## 验证方法

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/integration/test_ball.gd
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/integration/test_local_ballistics.gd
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/integration/test_multi_ball.gd
```

阅读测试时为每个 Vector3 加上“格/世界/屏幕”的旁注，检查发射、步进、碰撞和效果转换是否统一。尝试把测试中的姿态换到侧面，确认球不因纯模型旋转而错失预订块；若调整尺度，明确它是新增能力实验，不是已有结论的简单复测。

本章完成后你应该能解释“物理轨迹在格空间直，屏幕上可以弯”并不矛盾，也知道仅画一条射线不能证明球半径通得过去。下一章将用完全相同的几何约定为炮台寻找合法目标。

## 小结

选择坐标系实际上是在选择玩法不变量。当前方案让玩家旋转不改变已锁定弹道，同时保留真实扫掠和结算。把坐标、单位和变换时刻写进接口，能减少大量看似随机的脱靶问题。

[← 上一页：第 6 章：一次发射为什么需要事务和票据](06-gameplay-transactions.md) · [总目录](README.md) · [下一页：第 8 章：选靶不是找颜色，而是证明路径可达 →](08-target-selection.md)
