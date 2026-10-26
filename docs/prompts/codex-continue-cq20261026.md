# Codex CLI 接续任务提示词（CQ-20261026 / S06 起）

> 用法：在仓库根目录启动 codex CLI，把本文件全文贴给它（或让它先读这个文件）。
> 本提示词由 Claude 在 2026-10-26 交接时生成；Claude 已完成 S00~S05，你（Codex）从 S06 剩余项继续。

---

你是 Codex，接续完成 Godot 体素消除游戏的「炮台队列重做」任务。项目目录：
`/Users/zhaojian/code/godot-voxel-block-smash`（macOS，zsh）。

## 一、先读这些（按顺序，30 分钟内读完再动手）

1. `docs/tasks/cannon-queue-redesign.md` —— 本轮权威任务文档（S00~S11 步骤、§2 规则、§3 数据契约、CQ-T01~T16 验收用例）。它与旧文档冲突时以它为准。
2. `docs/dev-step-log.md` 末尾 5 条 —— S01~S05 完成记录 + **S06 条目里的「剩余 7 项工作清单」**（这是你最直接的施工单）。
3. `reports/android/cq/cq-acceptance.md` —— 验收表，当前 T01~T09 桌面 PASS、T10~T16 NOT_RUN。
4. `scripts/app/game_controller.gd`、`scripts/gameplay/` 下新服务（cannon_queue_service / slot_service / shot_ledger / target_selector / fire_geometry）、`scripts/presentation/hud_presenter.gd` —— 新契约的实际代码。
5. `docs/game-design.md` 与 `docs/architecture.md` 末尾的 CQ-20261026 增量声明。

## 二、当前状态（已完成，不要重做）

- S00~S05 完成。五列守恒队列、一键上位、固定五槽、目标化自动发射（同色可达才发射、一发一块、取消/超时返还、逐色 Q+S+F=V 守恒）、v2 存档、五列 HUD 均已实现。
- `assets/levels/level_01.json` 已含 `queue_seed: 4`（离线验证器 VERIFY_PASS，4260 动作解）与 `merge_max: 160`。
- **13 个 headless 测试套件全部 PASS**（清单见下）；主场景 headless 冒烟无 SCRIPT ERROR。
- S06 只做完了素材：`tools/cannon_gen.py` 已生成 `assets/cannons/{cannon_base,cannon_body,cannon_barrel,cannon_flash}.png`（CC0 自制分层图，炮管枢轴=图内 (128,150)，炮口距枢轴 124px）。**尚无代码引用这些图**。
- 工作区有未提交改动，属正常；**不要 git reset/revert/clean，不要删除你看不懂的文件**。

## 三、你的工作范围（从 S06 剩余项开始，按 S06→S07→S08→S09→S10→S11 顺序）

S06 剩余 7 项（详见 dev-step-log 的 S06 条目，概括）：
1. 新建 `scripts/presentation/cannon_view.gd`：三层 TextureRect（base/body/barrel 同矩形 KEEP_ASPECT_CENTERED 对齐）+ 弹药数字 Label（白字深色粗描边，支持 1~160）+ pressed 信号；状态视觉：queued/front/back-disabled/waiting/recoil/draining/locked/empty；`recoil()` 后坐 tween + 炮口闪光；`muzzle_screen_center()` = 枢轴屏点 + 瞄准方向 × (124/256 × 实际渲染边长)。
2. `hud_presenter.gd`：五槽位与五列列首换成 CannonView（锁槽/空槽/结算中/待取回状态映射）。
3. 炮管瞄准：每帧对有炮槽位计算朝向（有 PENDING 票据 → 目标体素屏幕投影；否则模型中心投影），turret_fire 时后坐+闪光（只在成功发射后）。
4. 发射起点来自可见炮口：`fire_geometry.gd` 泛化为任意屏幕点求原点；`main.gd _resolve_fire_origin` 改用 HUD 炮口屏点（默认朝上偏移 ≈0.025h）。**改完必须重跑 `tools/cq_verify.gd` 复核 seed=4 仍可解**（失败则另找种子、改 level_01.json、并在日志说明）。
5. `hit_effects.gd` 碎片尺寸 bug：现 BoxMesh 0.08 × scale 0.05~0.12 相乘后远小于体素；改为碎片边长 0.08~0.18 体素（如 mesh 0.13 × scale 0.62~1.38）；加同色光圈；预算 ≤512、寿命 ≤0.8s 保持。
6. 弹珠：同色亮球 + 高光（emission），每次删除只播一次效果。
7. 素材清单写入 `docs/asset-manifest.md`（作者=本项目程序化生成、方法=PIL 矢量绘制、源文件=tools/cannon_gen.py、日期）。

之后按任务文档继续 S07（五列界面/滚动/输入优先级/12px 阈值）、S08（指定目标替代任意指、5 秒无进展提示）、S09（存档 v2 完善：模型哈希/RNG 状态）、S10（性能+新 APK）、S11（真机完整通关验收 + 30 轮生命周期）。

## 四、硬性规则（违反=返工）

1. **实时记录进度**：每完成一个小项（哪怕只是一个文件）就立即追加 `docs/dev-step-log.md`（沿用现有条目格式：任务/前置证据/修改文件/参数决定/命令与退出码/测试/截图日志/守恒统计/未解决问题/下一步），并把 `reports/android/cq/cq-acceptance.md` 对应行改为真实状态（PASS / FAIL / BLOCKED / NOT_RUN + 证据路径）。**这是你与下一棒（Claude）交接的生命线**：随时可能被叫停，叫停时日志必须反映此刻真实状态，且末尾写明「下一个具体动作」。
2. **诚实标记**：没过就是 FAIL/BLOCKED，写明复现方法；禁止伪报 PASS，禁止通过直接删体素、改胜负状态、无限弹药等方式「证明」通关。
3. **每改必测**：桌面逻辑用 headless 回归（命令见下）；触摸/画面/完整通关/后台恢复/性能必须真机。
4. **真机 only**：Pixel 7a（设备号 35181JEHN08868，1080×2400）已开 adb；先用 `adb devices` 核实。**禁止启动/使用模拟器**。真机不可用就继续做无设备部分并在日志标 BLOCKED。
5. 不等待任何审批；遇到真实外部阻塞写明原因跳过该项继续下一项。
6. 不 commit 不 push（用户明确要求时才做；push 用 SSH，`gh` token 无效）。
7. 跨模块通知只能走事件总线白名单；炮台数据唯一容器是 `session.turrets`（队列/槽位只存 turret_id）。

## 五、已踩过的坑（不要再踩）

- **弹球物理在格空间扫掠**：旋转模型世界变换不改变格空间弹道；离线驱动/测试要移动「格空间原点」来模拟真机炮口换向。
- **发射原点必须在出界判定盒内部**（真机契约=相机射线∩边界 AABB 后内移 0.1）；放盒外出生即出界。
- **JSON 存档往返后 Dictionary 键变 String、数字变 float**：`level_session.restore` 已做 int 归一化，新增字段要保持。
- **事件总线按 event_id 去重**：测试里每次 publish 必须给新 id，meta 必须含 event_id/level_id/session_generation。
- headless 下 `--resolution` 无效：SceneTree 脚本用 `root.size = Vector2i(w, h)`。
- 截图坐标：adb screencap 1080×2400，显示缩放 900×2000 时 ×1.2 还原；道具按钮隐藏后 HBox 会重排，点击坐标要用亮度分段检测定位（见 dev-step-log S00 条目）。

## 六、常用命令

```bash
# 桌面回归（每个都要 TEST_PASS）
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . -s tests/unit/test_cannon_queue.gd
$G --headless --path . -s tests/unit/test_gameplay.gd
$G --headless --path . -s tests/unit/test_shot_ledger.gd
$G --headless --path . -s tests/unit/test_presentation.gd
$G --headless --path . -s tests/unit/test_rotation.gd
$G --headless --path . -s tests/unit/test_event_bus.gd
$G --headless --path . -s tests/unit/test_input.gd
$G --headless --path . -s tests/unit/test_voxel.gd
$G --headless --path . -s tests/persistence/test_persistence.gd
$G --headless --path . -s tests/integration/test_auto_fire.gd
$G --headless --path . -s tests/integration/test_play.gd     # 含完整通关，约 3 分钟
$G --headless --path . -s tests/integration/test_ball.gd
$G --headless --path . -s tests/integration/test_import.gd
$G --headless --path . --quit-after 120                       # 主场景冒烟

# 离线可解性验证（改发射几何后必跑）
$G --headless --path . -s tools/cq_verify.gd -- 4 1           # 复核 seed=4
$G --headless --path . -s tools/cq_verify.gd -- 1 100         # 找新种子

# 素材再生成
python3 tools/cannon_gen.py

# 真机
adb devices                                                   # 核实 35181JEHN08868 在线
adb -s 35181JEHN08868 shell dumpsys package org.godotengine.voxelblocksmash | grep version
```

## 七、交接协议（你被叫停或主动收尾时）

1. 跑一遍受影响的测试套件，把结果写进日志。
2. dev-step-log 追加/更新当前步骤条目，验收表同步。
3. 日志最后一行写：「下一个具体动作：<一句话>」。
4. 回复用户：完成了什么、证据在哪、剩什么、下一步是什么。

现在开始：先读第一节的文档，然后从 S06 剩余项第 1 条（cannon_view.gd）动手。
