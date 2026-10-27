# 第 9 章：拖动手感来自状态和坐标的一致

[← 上一页：第 8 章：选靶不是找颜色，而是证明路径可达](08-target-selection.md) · [总目录](README.md) · [下一页：第 10 章：动画不是装饰，而是状态的一部分 →](10-loading-and-retiring.md)

## 本章目标

理解为什么旧旋转“没有明显崩溃，却就是别扭”，以及如何用唯一 yaw/pitch 状态、输入归属和自动旋转渐入改善它。你将学会区分公式可以验证的性质与需要人手体验的质量，避免把几条数学断言写成“手感完美”。

## 概念讲解：手势不是姿态

手指移动是输入意图，模型当前角度是游戏状态，最终矩阵是状态的表现。三者应该沿一个方向转换。若路由器维护一份 pitch、控制器再从当前 Basis 反算另一份 pitch，边界判断和显示就可能不一致。当前 GestureRouter 只返回已归属指针的像素位移，main 把横纵位移乘各自灵敏度，控制器统一累积角度。

旧方案逐次把绕相机轴的旋转乘到已有 Basis 上。三维旋转不可交换，右、下、左、上等幅操作不保证恢复原姿态，可能累积 roll。试图用模型 forward 与 up 的点积反推俯仰，在侧向姿态下又可能无法反映真正上下翻转。问题不是浮点误差足够大，而是保存的状态和想要的交互模型不同。

当前用 yaw（方位）和 pitch（俯仰）两个标量作为唯一状态，每次重建 `B = Rx(pitch) * Ry(yaw)`。没有第三个可自由累积的 roll 变量，因此闭合角度输入不会制造侧倾。这个设计主动减少了自由度，符合看模型的转台式交互，不是通用自由轨迹球算法。如果目标是让用户随意翻到任何角度，必须重新设计交互，而非放开一个上限就算完成。

## 动手步骤：把输入链路拆成四段

第一段是输入归属。[scripts/input/gesture_router.gd:18](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/input/gesture_router.gd.txt:18)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/input/gesture_router.gd#L18) · [仓库内快照](source-baseline/scripts/input/gesture_router.gd.txt)） 在按下时决定该指针属于 UI、模型还是忽略的第二根手指。归属应持续到释放，不能根据当前手指移到哪里每帧改变。否则从队列开始滚动、途中划过模型时，模型会突然转动，玩家感到“控件抢手势”。InputMutex 记录这种所有权，它不是操作系统线程锁。

第二段是原始位移。[scripts/input/gesture_router.gd:32](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/input/gesture_router.gd.txt:32)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/input/gesture_router.gd#L32) · [仓库内快照](source-baseline/scripts/input/gesture_router.gd.txt)） 对非模型指针返回零，对活跃模型指针返回原始 delta。不要在这里再应用角度钳制，因为它没有权威姿态。鼠标与触摸都可映射到相同意图接口，但需要防止触摸模拟鼠标带来双次输入；桌面测得正常不等于手机也正常。

第三段是屏幕尺度换算。[scripts/app/main.gd:248](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/main.gd.txt:248)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/main.gd#L248) · [仓库内快照](source-baseline/scripts/app/main.gd.txt)） 使用横向、纵向不同灵敏度；_frame_model 根据视口初始化，使横扫约对应 180 度，模型区域纵扫约对应 120 度。分轴换算能避免狭长窗口里上下移动与左右移动感觉完全不同。当前初始化路径不等于完整动态窗口适配，未来可变窗口或安全区域变化要同步更新。

第四段是物理步统一应用。[scripts/app/game_controller.gd:726](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:726)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L726) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)） 累积意图，step 先处理旋转，再选靶和推进球，确保同一步都使用同一姿态。若 `_process` 改显示，`_physics_process` 还使用旧几何，玩家看到的位置和选靶位置就不同。transform_version 每步至多递增一次，有助于缓存正确判断几何变化，也减少重复失效。

下面教学公式展示重建姿态与累计角度，完整实现见 [scripts/app/game_controller.gd:765](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:765)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L765) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)）：

```gdscript
# 教学简化版：真实项目还包含输入积累、暂停和自动旋转。
yaw = wrapf(yaw + dyaw, -PI, PI)
pitch = clampf(pitch + dpitch, -deg_to_rad(60.0), deg_to_rad(60.0))
var orientation := Basis(Quaternion(Vector3.RIGHT, pitch)) \
    * Basis(Quaternion(Vector3.UP, yaw))
voxel_model.set_orientation(orientation)
```

为什么是 clamp 新角度，而不是“超界就拒绝本次移动”？假设当前 59 度，输入要再加 5 度。clamp 到 60，合法的一度被保留；整段拒绝会留在 59，给玩家一种靠近边界突然卡住的感觉。反向输入应立即生效，不需要先偿还一堆被积累的越界输入。当前每步合并输入的做法在撞边界时仍可能与事件逐个处理存在差异，所以事件分段不变性应限定在没有触边界的条件下。

自动旋转加的是同一个 yaw。速度 8 度/秒意味着稳定转一圈约 45 秒，不是每帧加 8 度。按住模型时 hold 冻结自动角速度；松手后通过 0.2 秒 ease 恢复。渐入恢复的是速度，不是把模型角度拉回某个起始方向。若松手时重置 yaw，数学很干净，体验却会跳转到另一面。

此处存在明确轴约定：外层 Rx 会使内层 yaw 轴随 pitch 倾斜，因此不等于任意俯仰下都绕固定世界 +Y。当前实现优先保持转台手感与俯仰状态。源码旧注释可能仍提世界 +Y，教程必须以实际矩阵解释。逆时针也应说明从俯视观察，屏幕中的轮廓位移会随相机和 pitch 变化，不能简单要求所有顶点永远向左。

> 📷 截图：同一模型 yaw=0、90、180、270 度时向下拖动的连续姿态；建议用独立练习副本录屏，不拿单张静态图证明接续流畅。

### 延伸练习：建立可描述的手感记录

不要只记录“顺滑”“别扭”。可以写成：从正面拖过半屏，模型旋转约90度；侧面向上拖时眼睛向远处倾斜；接近俯仰上限后继续拖动不跳动；松手后前0.2秒速度逐渐恢复。这样的描述把主观感受拆成可观察动作，别人才能复现。必要时同时录手势与画面，避免只有结果姿态却不知道输入方向。

比较两台分辨率不同的设备时，用屏幕宽度比例描述拖动长度，而不是要求相同像素数。触控采样频率和事件合并也可能不同，应在不碰边界时检验累计角度一致，再单独检验边界语义。一个测试若同时改变输入尺度、采样频率和相机姿态，出现差异时很难归因。

还可以记录停止的语义：按下模型立即停止自动转，还是拖动超过阈值才停止？当前设计要求按住暂停，目的在于用户准备观察时模型不继续跑。不要只按代码哪个事件方便就选哪个时机。交互状态应该来自用户动作的意义，然后才映射到press、drag、release和cancel。

## 踩坑记录：暂停与取消的边界

如果手指按下后应用失焦，没有收到正常 release，hold 可能永久保持。必须在取消、返回列表和生命周期清理时释放指针归属与旋转 hold。[scripts/app/main.gd:278](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/main.gd.txt:278)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/main.gd#L278) · [仓库内快照](source-baseline/scripts/app/main.gd.txt)） 和 cleanup 负责对应桥接。只测试“按下→移动→抬起”的理想流程，会错过真实手机上的系统手势中断。

自动旋转与指定目标模式也会争夺控制。如果玩家正在精确点某一块，模型仍持续转动，点到的可能是另一块；当前选择期间暂停自动旋转。这里不是越多自动化越好，而是把不同操作状态的主导权写清楚。暂停游戏时则模拟时钟不推进，不应恢复后根据过去墙钟补转几十度。

测试可以证明四象限下没有倒立、俯仰限制有效、输入闭合后不积累 roll；无法仅凭这些证明“玩家觉得舒服”。历史 UX01、UX04 就明确标为逻辑通过、人工主观手感 NOT_RUN。保留这种区分会让后续用户反馈进入正确流程：若数学断言稳定但觉得慢，调灵敏度；若侧面方向反了，先检查坐标约定。

另一个实践原则是先关掉惯性，再调基础跟手。惯性和阻尼能让操作看起来顺滑，也可能掩盖不稳定的轴和重复输入。当前目标并不要求自由甩动模型，没必要为了“高级感”增加额外状态。所有手感参数都应有明确观察任务，例如短距离微调是否能准确选面、长距离拖动是否需要反复抬手。

## 验证方法

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/unit/test_input.gd
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/unit/test_rotation.gd
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/integration/test_auto_rotation.gd
```

人工练习按四个象限各做一次左右、上下拖动，再连续右下左上二十轮，观察是否出现侧倾。按住不动几秒，自动旋转应停止；松手保持当前视角并逐渐继续。最后暂停再恢复，角度不应补跳。将每个现象对应到一个状态或公式，而不是只写“手感不错”。

本章完成后你应该能看到自动旋转与手动拖动自然交接，并知道哪些结果必须自己上手确认。后续移植手机时复用这些断言，但重新进行触摸输入验收。

## 小结

交互质量来自清楚的状态归属与坐标约定。少一份角度副本、少一个姿态写入口，往往比多加平滑算法更有效。下一章以同样方法处理大炮动画中的业务状态与视觉状态。

[← 上一页：第 8 章：选靶不是找颜色，而是证明路径可达](08-target-selection.md) · [总目录](README.md) · [下一页：第 10 章：动画不是装饰，而是状态的一部分 →](10-loading-and-retiring.md)
