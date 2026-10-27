# 第 6 章：一次发射为什么需要事务和票据

[← 上一页：第 5 章：主场景不是全部节点的静态清单](05-main-scene.md) · [总目录](README.md) · [下一页：第 7 章：模型转动时，子弹为什么还能命中 →](07-local-ballistics.md)

## 本章目标

读懂一次列首点击怎样变成槽内炮台，再怎样产生一颗真正参与碰撞的球。你将掌握队列、槽位和票据的职责，完成一次显式调用发射入口的实验。当前正式玩法是上位后自动射击，本章不会给游戏增加手动开火按钮；“手动”指测试脚本主动调用公开控制器接口。

## 概念讲解：一个炮台只能有一个归属

炮台 ID 对应颜色、剩余弹药、来源列、状态和在途数量。五列队列保存 ID 序列，五个槽位保存 ID 或空标记。炮台详细信息只保存在 turrets 字典，不应在队列和槽位各复制一份可变弹药。否则队列显示 80、槽位显示 79 时，你无法确定哪份是权威状态。

[scripts/gameplay/cannon_queue_service.gd:27](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/gameplay/cannon_queue_service.gd.txt:27)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/gameplay/cannon_queue_service.gd#L27) · [仓库内快照](source-baseline/scripts/gameplay/cannon_queue_service.gd.txt)） 将每色总弹药拆成多门炮，再由 generate 分配进五列。拆分不能丢余数；一色 85 块不能只生成一门 80 发炮而忽略 5 发。炮台“常规范围 30～80”与尾炮余量规则要一起理解。使用固定种子有利于复现布局，但随机守恒不自动证明关卡一定可解，后面还需要解路径和真实回放验证。

槽位保持固定位置，[scripts/gameplay/slot_service.gd:26](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/gameplay/slot_service.gd.txt:26)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/gameplay/slot_service.gd#L26) · [仓库内快照](source-baseline/scripts/gameplay/slot_service.gd.txt)） 寻找最左空槽。中间炮台耗尽，不应该把右侧炮台整体左移，因为炮口对应的射线和玩家视觉记忆都会改变。队列补位是列内前移，槽位释放是原位置变空，两者不是同一种数组操作。

票据（Ticket）记录一次发射的生命周期：哪门炮、哪个目标、哪种颜色、哪颗球、属于哪一代会话、当前是否结算。只有目标指针不够，因为两门炮可能同时看见同一块；第一门发射之后，该目标必须暂时对其他炮不可用。[scripts/gameplay/shot_ledger.gd:17](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/gameplay/shot_ledger.gd.txt:17)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/gameplay/shot_ledger.gd#L17) · [仓库内快照](source-baseline/scripts/gameplay/shot_ledger.gd.txt)） 用 reservations 建立目标到 shot_id 的唯一预订。

## 动手步骤：沿一笔事务走完整链路

先读 [scripts/app/game_controller.gd:204](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:204)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L204) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)）。它检查关卡仍运行、列号有效、列首存在、槽位有空，然后先占槽再出列。这里的“原子”主要表示一次同步操作内成功一起改变、失败不改变，并非数据库事务或多线程锁。当前实现依赖出列前已经验证列首，后续若引入异步流程，需要重新审视这种假设。

成功上位后进入 LOADING，不立即注册射击；第 10 章详述动画阶段。READY 后调度器调用 try_auto_fire。它依次检查槽位、弹药、单炮并发上限、全局球数、炮口解析和目标。找到合法瞄点后进入 [scripts/app/game_controller.gd:430](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:430)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L430) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)）：预订目标，创建球，成功后才扣弹，再发布发射反馈。若方向非法或球创建失败，取消预订，不扣玩家弹药。

命中也分两层。物理层报告“球与某块接触”，控制器验证票据和颜色后调用 destroy，成功才结算命中。视觉上球碰到东西不是消除许可；逻辑上找到目标也不是命中证明。这个边界防止选靶代码提前删除方块，用好看的弹道动画掩盖实际没有碰撞的事实。

取消路径通过 [scripts/app/game_controller.gd:624](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:624)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L624) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)） 处理。只有 `settle_cancel` 返回 changed 才返还一次弹药。同一球既产生命中结束又触发清理消息时，第二次不能再加弹。这个幂等条件比“我认为这个事件只会来一次”可靠得多，也容易用小测试主动复现。

下面是可保存到练习副本 `manual_shot.gd` 的教学实验。它选择一列炮台，把自动调度关闭，再主动调用控制器，直到一笔真实命中完成。它不是生产代码替代品，也不修改方块计数。原点构造参考 [tests/integration/test_loading_retire.gd:32](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/tests/integration/test_loading_retire.gd.txt:32)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/tests/integration/test_loading_retire.gd#L32) · [仓库内快照](source-baseline/tests/integration/test_loading_retire.gd.txt)）。

```gdscript
extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var repo = preload("res://scripts/level/level_repository.gd")
    repo.set_save_dir("user://test_saves/tutorial_manual_%d" % OS.get_process_id())
    var gc = preload("res://scripts/app/game_controller.gd").new()
    root.add_child(gc)
    gc.set_physics_process(false) # 只让本实验显式步进，避免双重推进。
    var started: Dictionary = gc.start_level("res://assets/levels/level_01.json")
    if not started.ok:
        push_error(str(started))
        quit(1)
        return
    gc.origin_resolver = func(_slot: int) -> Dictionary:
        var sys = gc.ball_physics.system
        var p: Vector3 = sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0)
        return {"ok": true, "origin_grid": p,
                "origin": gc.voxel_model.world_from_grid() * p}
    var col := -1
    for c in 5:
        if not gc.session.queue_columns[c].is_empty():
            col = c
            break
    var placed: Dictionary = gc.place_front(col)
    if not placed.ok:
        push_error(str(placed))
        quit(1)
        return
    # 阻断自动发射回调，让过渡时钟到位后仍不产生球。
    gc.auto_fire.fire_by_slot = func(_s: int) -> Dictionary:
        return {"ok": false, "reason": "no_ammo"}
    var initial: int = gc.voxel_manager.alive_count()
    for i in 600:
        gc.step(1.0 / 60.0)
        if gc.loading_progress(int(placed.turret_id)) < 0.0:
            break
    gc.auto_fire.clear()
    var fired := false
    for i in 3600:
        gc.step(1.0 / 60.0)
        if not fired:
            var result: Dictionary = gc.try_auto_fire(int(placed.slot))
            fired = bool(result.get("ok", false))
        if gc.voxel_manager.alive_count() < initial:
            break
    var removed: int = initial - gc.voxel_manager.alive_count()
    print("fired=", fired, " removed=", removed)
    gc.stop_session()
    gc.free()
    quit(0 if fired and removed == 1 else 1)
```

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s manual_shot.gd
```

本实验有界执行，不承诺每个改过的模型和队列都必定找到目标。如果超时，保留错误并分析选靶等待原因，不直接改成 destroy(0) 让断言通过。当前版本的标准发射覆盖优先由仓库 test_auto_fire 和 test_multi_ball 提供，这段教学脚本是读者需要实际执行验证的独立练习。

再看合成 [scripts/gameplay/merge_service.gd:11](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/gameplay/merge_service.gd.txt:11)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/gameplay/merge_service.gd#L11) · [仓库内快照](source-baseline/scripts/gameplay/merge_service.gd.txt)）：两列列首、同色、不同来源、总量不超过上限，条件不满足就拒绝且不改变双方。合成完成后原炮 ID 的去向必须明确，不能让旧视图稍后继续操作已删除炮台。所谓 UI 模式只是帮助玩家选择，真正限制必须在业务接口里再次验证。

### 延伸练习：把失败也写进事务表

列出预订失败、方向非法、球创建失败、正常命中、超时取消五条路径。前面三条没有成功生成，就不应该减少可用弹药；后面两条已经生成，必须恰好结算一次在途资源。表中每一行都写明目标预订是否仍存在。只测弹量而不测预订，可能漏掉“弹药退回了，但目标永远被占用”的死锁式体验。

再看多球顺序。先发的球不一定先到，因为路径长度不同，速度道具也会改变飞行时间。不能用一个turret.current_shot字段代表全部在途球，更不能认为收到第一条命中就可以删除炮台。票据按shot_id分别结算，炮台只汇总in_flight。这个设计与并发请求的处理相似：完成顺序不能由提交顺序推断。

最后检查道具消费时点。用户激活下一发加速，随后连续几次扫描返回pending，不能消耗道具；只有球成功生成才消费。若目标预订失败就扣次数，玩家会感到按钮随机失效。把“意图已选择”和“效果已落实”分成两个状态，有助于所有存在延迟动作的交互，不只适用于射击。

## 踩坑记录：射速与吞吐不是一个参数

单球闸门会让炮台必须等上一颗命中再发下一颗。即使 interval 很小，平均飞行 0.3 秒仍把它限制在约每秒三发。当前通过单炮最多 6 发、全局最多 30 发实现多球在途。间隔控制发射频率，上限控制资源占用，两者共同作用。只把 ball_speed 提得很高会缩短可见弹道，还可能增加每步扫掠长度，并不是免费提速。

再以等待比例为例：历史报告中 fire_attempt 17195、fire_success 4105，不能解释成打空了一万多发。尝试可能在扫描未完成时返回，并没有扣弹或生成球。实际命中 4105、取消 0 才能说明这轮成功发射的全部球均有效结算。统计名称一定要对应发生阶段，否则优化方向会完全相反。

最后一发发出时 ammo 已归零，但 F（在途）仍大于零。立刻删除炮台会让取消退款无处可还，也让结束动画和弹道失去所属对象。DRAINING 表示不再发新球但等待结算，这个状态不是表现特效，而是正确处理事务未完成的必要条件。

## 验证方法

运行两个标准套件，再检查自身实验：

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/unit/test_shot_ledger.gd
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" -s tests/integration/test_auto_fire.gd
```

用表格记录发射前、生成后、命中后、取消后四个时刻的弹药和在途数。成功生成时 S 减一、F 加一；命中时 F 减一、V 减一；取消时 F 减一、S 加一。状态变化能画清楚，代码里的每次加减才有可靠解释。

本章完成后你应该能明确看到或通过日志确认真实一发消除一块，并能解释两个炮台抢目标为什么只能有一个预订成功。下一章把镜头移到这颗球本身，解决模型旋转时为什么不应该脱靶。

## 小结

发射不是一条动画命令，而是一笔有创建、预订、结算和取消的事务。把这些阶段显式化，既改善多炮正确性，也让性能统计具备含义。

[← 上一页：第 5 章：主场景不是全部节点的静态清单](05-main-scene.md) · [总目录](README.md) · [下一页：第 7 章：模型转动时，子弹为什么还能命中 →](07-local-ballistics.md)
