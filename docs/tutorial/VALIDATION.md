# 教程文档校验记录

日期：2026-10-27。校验对象是本次生成的教程，不是新一轮游戏验收。

## 内容和篇幅

- README 总目录 + 13章完整正文；每章均有目标、概念、动手、踩坑、验证、小结及导航。
- 去掉代码围栏后，仅统计中文汉字：**30332字**（不含目录、附录、源码快照、代码和英文）。
- 每章2000～4000汉字，全系列达到3～5万字要求。

| 章节 | 正文汉字数 |
|---|---:|
| 01-godot-basics.md | 2624 |
| 02-project-and-rules.md | 2388 |
| 03-data-model.md | 2245 |
| 04-voxel-rendering.md | 2199 |
| 05-main-scene.md | 2267 |
| 06-gameplay-transactions.md | 2066 |
| 07-local-ballistics.md | 2344 |
| 08-target-selection.md | 2447 |
| 09-input-and-rotation.md | 2294 |
| 10-loading-and-retiring.md | 2305 |
| 11-performance-engineering.md | 2643 |
| 12-testing-and-evidence.md | 2148 |
| 13-build-and-delivery.md | 2362 |

## 本次实际执行的检查

- 63处源码引用全部解析并核实，33份源文件快照与固定提交逐字一致。
- Markdown本地链接存在性检查通过，章节结构检查通过。
- 23个Bash命令块通过bash -n语法检查；其中8段内嵌Python通过AST语法解析。
- 固定提交中发现21个测试入口，与历史报告的套件数量一致。
- 离线读取固定提交中的13份回放JSON：全部WON、真实存活与渲染残留为0、守恒通过、每局成功发射和命中均为4105、取消为0。
- 历史有效局时最小169.4秒，最大190.9秒，平均174.6154秒；四舍五入为174.6秒。
- 未执行教程中的游戏运行、Godot测试、导出、录像或性能采样；GDScript教学片段未做引擎运行验证。语法检查不等于端到端命令执行通过。

## 10处引用抽查

所有行号对应003648e3ac102692c9722b441ba2f801c2f6ac1d，点击正文链接打开只读文本快照。当前工作区在写作期间由其他开发进程继续提交，因此特意不把可变工作区行号作为基线证据。

| 原文件:行 | 对应源码内容 |
|---|---|
| scripts/app/main.gd:30 | `func _ready() -> void:` |
| scripts/data/voxel_loader.gd:11 | `static func load_from_json(path: String, enforce_range: bool = true) -> Dictionary:` |
| tests/unit/test_voxel.gd:9 | `func _initialize() -> void:` |
| scripts/app/main.gd:124 | `func _cleanup_session(save: bool) -> void:` |
| scripts/app/game_controller.gd:430 | `func _fire_at(slot_index: int, tid: int, t: Dictionary, origin: Dictionary, target: Dictionary) -> Dictionary:` |
| scripts/projectile/projectile_system.gd:40 | `func spawn_local(local_pos: Vector3, local_dir: Vector3, speed_grid_per_sec: float,` |
| scripts/gameplay/target_selector.gd:43 | `var scan_budget_us := 3000  # 单次 find_target 时间片预算（测试可注入小值验证断点续扫）` |
| scripts/app/main.gd:248 | `func _apply_rotation(rot_px: Vector2) -> void:` |
| scripts/presentation/hud_presenter.gd:699 | `func _on_column_pressed(c: int) -> void:` |
| scripts/presentation/hud_presenter.gd:588 | `func _process(_delta: float) -> void:` |

## 已纠正的提示词前提

五槽而非三槽；一个渲染节点但4105个方块实例；默认100与关卡120格/秒分开；单次3ms与每步6ms预算分开；不存在tests/run_tests.gd；朴素逐节点性能对照无原始实测，列为建议实验；p95保留3/35超标窗口；逻辑胜利计时不等于最终动画完成计时。

## 尚需读者实际执行

- GDScript最小示例及各章命令在自己的独立练习副本运行。
- 逐节点与MultiMesh性能A/B实验。
- 拖动手感、上位/退场关键时序和真机平台验证。
- 新构建的完整通关、画面截图、性能与生命周期采样。

这里不把缺少的实验数据编造成教程案例，也不将历史数据改名为本次结果。只读源码快照位于docs/tutorial/source-baseline，以.txt保存，不参与游戏编译或运行。
