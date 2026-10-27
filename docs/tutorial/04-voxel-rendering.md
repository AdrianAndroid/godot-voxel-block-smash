# 第 4 章：用一个渲染节点显示 4105 个方块

[上一章](03-data-model.md) · [总目录](README.md) · [下一章](05-main-scene.md)

## 本章目标

在独立场景里显示完整青蛙，理解节点数量、实例数量和绘制成本是不同指标，再通过删除测试理解数据、索引和画面的同步。完成后你应该能解释：为什么只用一个 MultiMeshInstance3D 节点，却必须在开局报告 4105 个可见方块实例。

## 概念讲解：先问每块需要什么能力

最直观的方案是每块建立一个 MeshInstance3D，给它 BoxMesh、材质和坐标。优点是每块在场景树里独立可选，调试很直观；缺点是每块都参与节点管理和变换维护。相同几何被重复提交也可能增加 CPU 与渲染开销。是否在 4105 块时“崩塌”取决于机器、材质、阴影和引擎优化，本仓库没有逐节点版的可核验基准，因此不能编造一组前后 FPS。

这个游戏每个方块没有独立脚本，没有独立动画骨骼，也不依赖逐块物理节点。它们最重要的差别是位置、颜色和是否存活。MultiMesh 把共用几何与逐实例属性分离，恰好适合这种数据形态。节点树变小不意味着几何量消失，而是引擎可以更集中地处理相似对象。官方 [MultiMesh 优化说明](https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html) 介绍了这种批量绘制思路；本章按仓库代码讲具体实现。

当前 renderer 用一个 BoxMesh、一个启用顶点色的 StandardMaterial3D，以及一个 MultiMesh。每个实例写入自己的 Transform3D 和 Color，见 [scripts/voxel/voxel_renderer.gd:16](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/voxel/voxel_renderer.gd.txt:16)。`instance_count` 分配实例容量，`visible_instance_count` 控制连续前缀内显示多少个。删除时不用重新创建全部节点，但需要保持可见数据集中在前缀，这就引出了尾交换算法。

这里应区分至少四个数字：场景节点数、MultiMesh 容量、可见实例数、GPU 绘制调用数。源码里的 `renderer.instance_count()` 返回的是逻辑可见实例数，不是节点数，也不是 profiler 的 draw call 数。把它优化到 1 会只剩一块，甚至直接破坏胜利条件。真正的约束是“可见实例数等于存活数”。

## 动手步骤：独立展示场景

确保上一章复制了展示依赖。给 sandbox 新建 `preview.gd`，填写以下教学简化版。它使用正式 Loader、Manager 和 ModelNode，只简化场景装配。不会启动正式队列、存档和自动射击。

```gdscript
extends Node3D

func _ready() -> void:
    var loader = preload("res://scripts/data/voxel_loader.gd")
    var loaded: Dictionary = loader.load_from_json(
        "res://assets/models/json/frog_02.json")
    if not loaded.ok:
        push_error(loaded.error)
        return
    var manager = preload("res://scripts/voxel/voxel_manager.gd").new()
    var model = preload("res://scripts/voxel/voxel_model_node.gd").new()
    add_child(model)
    model.attach(manager, loaded.data)

    var camera := Camera3D.new()
    camera.position = Vector3(0, 8, 65)
    add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.current = true

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -25, 0)
    add_child(sun)
    print("alive=", manager.alive_count(),
          " visible=", manager.renderer.instance_count())
```

创建 `preview.tscn`，根为 Node3D，挂接该脚本。场景里不要再手工添加第二套模型和相机；脚本已经负责它们。运行当前场景，预期看到模型和 `alive=4105 visible=4105`。若模型太小，只调整这个教学相机的距离；正式工程按包围盒拟合相机，我们在下一章分析。

接着阅读实例材质设置。方块边长为 `voxel_size * 0.97`，格距保持原值，于是出现约 3% 的视觉缝。这个缝是造型表现，不是允许子弹穿过的物理通道。若把碰撞方块也随缝缩小，会让本来相邻的实体边界出现不符合玩法的通路。视觉与碰撞可以有意采用不同几何，但必须说明其契约，不能混成一个“正确大小”。

现在在纸上模拟尾交换。假设可见槽里放着 ID `[10,20,30,40]`，删除 ID20 时，把最后的 ID40 搬到索引1，序列变为 `[10,40,30]`。这一步改变的是渲染槽，不是体素 ID。必须同时更新 `voxel_of[1]=40`、`slot_of[40]=1`，并删除 `slot_of[20]`。位置和颜色也要一起搬，否则会出现模型形状正确、颜色错位的隐蔽问题。

实现见 [scripts/voxel/voxel_renderer.gd:49](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/voxel/voxel_renderer.gd.txt:49)。镜像数组保存 CPU 可观察的变换和颜色，方便在 headless 下断言，因为虚拟渲染后端不能当作真正 GPU 缓冲验证工具。镜像不是第二套世界状态；它服务于渲染映射的检查，不能拿它代替存活集合决定业务。

删除应通过 [scripts/voxel/voxel_manager.gd:41](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/voxel/voxel_manager.gd.txt:41) 统一进入。Manager 先确认存活，再同步状态、空间索引和 renderer。调用者只收到明确成功或失败。重复命中同一 ID 时第二次不能再减少数字，这种幂等语义以后会保护多球和事件重复投递场景。不要在 HUD 里直接执行剩余数减一，再希望底层最终跟上。

如果你想做逐节点对比实验，在另一份 preview 脚本中把每个坐标转成 MeshInstance3D，使用同一个共享 BoxMesh、同一材质、同一相机和相同阴影配置。先确认视觉一致，再分别记录创建耗时和稳定运行帧耗时。不要给朴素版每块一个独立材质，而给实例版共用材质，然后把全部差距归因于节点数量；实验改变了多个变量，结论就不干净。

> 📷 截图：preview 中完整青蛙、Remote 树中一个 VoxelMultiMesh 节点，以及输出中的 4105。对照素材可参考 reports/desktop/ux/keyframes/ux13_t000.png，但那是历史完整游戏，不是本章实验截图。

### 延伸练习：用三个删除顺序检查映射

同一个四块夹具，分别删除首槽、中槽和尾槽。删除尾槽时不需要搬运；删除首槽时必须搬最后一块；连续删除刚搬过来的ID时，要使用新的slot_of，不能继续用旧索引。把这三个序列列出来，比随机删除一百次更容易知道失败在哪里。随机压力测试可以补充覆盖，却不应替代能够解释的最小例子。

再问一个问题：为什么不把删掉的实例缩放成零，永久留在原槽？这样实现简单，但可见计数和存活集合不再天然一致，孔洞越来越多，还可能留下碰撞或查询歧义。尾交换让有效数据保持紧凑，代价是维护映射。工程选择通常是在“隐藏复杂度”和“显式维护复杂度”之间取舍；这里把复杂度集中到一个可测试函数，比让每个消费者理解空洞更好。

测量渲染对比时还应控制观察方向。同一个模型正面和侧面的像素覆盖、遮挡和高光不同；将相机距离改变后直接比较FPS，可能是在测填充率而非节点开销。记录窗口尺寸、相机姿态、阴影和材质，才能让另一个人重复你的实验。没有固定这些条件的“优化十倍”很难转化成可复用知识。

## 踩坑记录：半格差异与证据缺口

当前代码有一个值得带着疑问阅读的细节：renderer 把 BoxMesh 中心放到 `grid_to_local(i)`，而碰撞求解把格坐标视为 `[p,p+1]` 盒子的最小角，选靶中心用 `p+0.5`。这表明渲染中心与碰撞中心的约定存在半格差异；`world_from_grid` 本身没有补上半格。当前回放通过不等于这个约定已经严格统一。教程应让读者看到差异，而不是声称三者完全重合。

同样，VoxelData 的 grid_to_local 乘了 voxel_size，而 ModelNode.world_from_grid 当前只加入中心偏移，没有显式乘 voxel_size。正式模型使用 1.0，所以历史结果不覆盖非单位体素。若未来调到 0.5，需要新增尺度测试并统一变换，不能只改模型 JSON。把有效条件写清，比给出泛化程度超过实现的数学公式更可靠。

MultiMesh 也不是万能渲染器。单个巨大批次的剔除粒度、局部更新成本、透明排序等都有代价。本项目模型紧凑、材料简单，当前方案合适；若扩展成开放世界几十万个分散方块，可能需要空间分块。不要在本章提前加入复杂分块系统，先建立数据与画面一致的最小闭环。

## 验证方法

运行 [tests/unit/test_voxel.gd:9](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/tests/unit/test_voxel.gd.txt:9) 对应的套件。它使用四块夹具，验证首次删除成功、重复删除失败、索引剔除、可见数一致、双向映射和位置正确。这比仅运行完整青蛙看“好像少了一块”更敏感。

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" \
  -s tests/unit/test_voxel.gd
```

本章完成后你应该在窗口看到青蛙，在测试输出看到删除与映射断言通过。两种证据各回答一个问题：图像证明实际可见，测试证明数据操作符合约定。没有运行逐节点对照，就把对照栏标为 NOT_RUN，而不是根据理论猜一个 FPS。

## 小结

实例化把重复的图形组织成数据，使渲染更适合这个游戏的规模。真正值得复用的不只是 API，而是稳定 ID、连续可见槽、双向映射和统一删除入口。下一章把展示实验放回完整主场景，理解游戏如何装配这些模块。

[上一章](03-data-model.md) · [下一章](05-main-scene.md)
