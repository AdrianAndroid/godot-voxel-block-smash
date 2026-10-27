# godot-voxel-block-smash

Godot 4.7 3D 体素打砖块游戏：拖动旋转一只 4105 块的体素青蛙，炮台队列自动连发同色弹珠，把模型一块块真实消除直至全清。玩法对标小程序游戏《这关消一消》。

**仅个人学习项目，不对外发布、不分发。**

当前状态：**已完成并验收**（2026-10-27，git `c54e51e`）。核心玩法、性能、测试、macOS 打包全链路通过真实 .app 回放验收——连续 13 局完整通关（169.4~190.9 秒/局，4105/4105 块全部真实消除，零取消、守恒审计全绿）。

## 玩法规则

- 上方是一只纯色体素拼成的立体青蛙模型（4105 块），拖拽模型区域可自由旋转（双轴 yaw/pitch，pitch ±60°）；模型同时绕中心 +Y 轴以 8°/s 俯视逆时针自动旋转，拖动时暂停、松手后从当前姿态 0.2s 渐入续转，不跳角、不补转。
- 中部是 5 个发射槽（全部解锁）。从下方 3×3 炮台池把炮台安放入槽；入槽有 0.28s 上位飞行（LOADING，到位才开火），之后自动连发直至弹尽。
- 弹尽炮台进入 DRAINING（等在途子弹结算完）→ RETIRING（0.20s 收缩淡出）→ 槽位释放、队列补位。取回功能保留用于测试；零弹取回 = 直接退场、不回队列。
- 弹珠只能击碎**同色**方块，异色反弹；出界消失并清零连击。一发一块，目标预订制（多炮并发不抢同一块）。
- 方块全清（渲染实例归零 + 守恒审计通过）→ 通关；无法继续消除 → 失败。
- 底部四种消耗道具：speed_x2 / designated_target / shuffle（add_slot 因 5 槽全解锁已从默认库存移除）。
- 正常完整一局有效时间 ≤300s（验收目标 210~240s，实测已达 169~191s）。

## 操作（macOS，鼠标即点按）

| 操作 | 行为 |
|---|---|
| 拖动模型区 | 旋转模型（四象限直观方向，不倒立不侧翻） |
| 点按炮台池 → 点按槽位 | 安放炮台（或先点池内炮再点空槽） |
| 点按槽内炮台 | 取回（测试用） |
| 道具按钮 | 使用消耗道具 |
| 暂停按钮 | 继续 / 重开 / 返回关卡列表 |

窗口固定 540×1200 竖屏（1080×2400 画布 keep 缩放）。

## 环境

- 引擎：Godot **4.7.2 stable**（渲染器 `gl_compatibility`，兼容老集显）
- 开发/验收机：Mac mini i7-8700B / UHD 630 / macOS 15.7.9
- 体素编辑器：Goxel 0.15.1（产出 .vox → 转 JSON，见 `tools/voxel_export/`）

## 快速开始

```bash
# 打开工程（编辑器）
godot --editor --path /Users/zhaojian/code/godot-voxel-block-smash

# 直接运行（540×1200 窗口）
godot --path /Users/zhaojian/code/godot-voxel-block-smash
```

主场景：`scenes/main/main.tscn`。关卡：`assets/levels/level_01.json`（模型 `assets/models/json/frog_02.json`，4105 块，queue_seed=4）。

## 构建与运行（macOS .app）

```bash
# 导出（需要已安装 4.7.2 导出模板）
godot --headless --path . --export-release "macOS"

# 运行
open builds/macos/VoxelBlockSmash.app

# 全自动通关回放（真实 .app 内驱动，输出验收报告 JSON）
builds/macos/VoxelBlockSmash.app/Contents/MacOS/godot-voxel-block-smash \
  -- --replay=res://assets/levels/s03-solution.json \
     --replay-report=/tmp/replay_report.json --replay-max-sec=360
# 退出码 0 = 通关(WON)
```

导出预设：`export_presets.cfg` 含 **macOS**（已验收）、**Android**（APK 已出过包）、**iOS**（适配准备完成：导出预设/安全区内移/触摸双触发修复，待模板与真机）。

## 测试体系

三层验证，全部 headless 可跑，测试绝不触碰真实存档（隔离目录 `user://test_saves/`）：

```bash
# 单元 + 集成 + 持久化共 21 个套件（当前全绿）
godot --headless --path . -s tests/unit/test_voxel.gd        # 单套件示例
godot --headless --path . -s tests/integration/test_play.gd  # 全流程通关夹具
```

| 层 | 内容 | 位置 |
|---|---|---|
| 单元测试 | 体素/事件总线/输入/旋转/票据/队列/HUD/选靶扫描等 10 套件 | `tests/unit/` |
| 集成测试 | 弹道（旋转中命中）、多球并发、自动旋转、上位/退场、指定目标、完整通关等 10 套件 | `tests/integration/` |
| 持久化 | 存档往返/隔离 | `tests/persistence/` |
| 真机验收 | 回放驱动真实 .app：13 连 WON、性能采样、30 轮生命周期 | `tools/replay_runner`（`scripts/app/replay_runner.gd`）+ `tools/lifecycle_check.gd` |

**守恒审计**：每局校验 V+D=V₀（消除数+剩余数=初始数）、fires==hits、0 取消、renderer_instances==0——用机器证明"没有穿透、没有改数字、没有伪造命中"。

## 性能验收数据（Mac mini i7-8700B / UHD 630）

| 指标 | 验收线 | 实测 |
|---|---|---|
| 通关时长 | ≤300s（目标 210~240s） | **13 连 WON，169.4~190.9s，均值 174.6s** |
| FPS | ≥30 | min 42 / avg 81.6 |
| 帧 p95 | ≤50ms | 35 采样中 32 达标（3 个开局建模/首扫单帧尖峰） |
| 内存 RSS | ≤512MB，60s 增长≤10% | 338→339MB / 190s，增长≈0 |
| 命中质量 | 无穿透/无浪费 | fire_attempt 17195 → hit 4105，0 取消 |

完整证据：`reports/desktop/ux/ux-acceptance.md`（UX01~UX14 矩阵）、`reports/desktop/fm/fm-matrix.md`（FM01~FM20）。

## 架构速览

```
scenes/main/main.tscn        主场景（Main:Node3D + Camera3D + WorldEnvironment + HUD 层）
scripts/
├─ app/          协调层：main（输入路由/旋转）、game_controller（唯一玩法状态机）、
│                game_state、event_bus（按 event_id 去重）、replay_runner（回放驱动）
├─ voxel/        体素核心：model_node（set_orientation 唯一姿态写入口 + transform_version）、
│                state/index/renderer（实例化渲染，4105 块压到个位数渲染实例）、spatial_index
├─ projectile/   弹道：projectile_system（局部空间步进+回收）、ball_physics（连续扫掠）、
│                collision_solver
├─ gameplay/     玩法：target_selector（暴露面多点选靶/6ms 步预算分片/负缓存 gen+tver+TTL）、
│                shot_ledger（目标预订票据）、auto_fire_scheduler、cannon_queue_service、
│                slot/merge/prop/outcome、fire_stats、fire_geometry
├─ presentation/ 表现：hud_presenter（事件驱动按帧合并刷新）、marble/cannon_view、
│                hit_effects、audio、level_list
├─ level/        关卡：catalog/repository（可注入存档目录）/session（RNG 字符串往返）
├─ data/         数据：voxel_loader/data、level_loader、game_rules（全部可调参数集中一处）
├─ input/        gesture_router（只报原始位移）、input_mutex
└─ diagnostics/  perf_monitor/perf_probe（发布构建自动关闭）、event_recorder
```

关键设计决策（详见 `docs/architecture.md` 与各任务文档）：

- **弹道局部空间锁定**：弹球记录格空间 `local_pos/local_dir`，模型旋转不影弹道；事件派发时才用当前矩阵转世界。这是"旋转中子弹仍命中"的根本解法。
- **控制器唯一持有姿态**：yaw/pitch 单源（B=Rx(pitch)×Ry(yaw)），手势层只报位移，杜绝多写入口导致的跳角/侧翻。
- **选靶可审计**：等待原因全部计数可查（waiting_target / no_reachable_target / revalidate_failed），绝不穿透异色块或改数字伪造命中。
- **配表驱动**：ball_speed=100 格/s、auto_fire_interval=0.10s、max_in_flight=6、auto_rot=8°/s 等集中在 `game_rules.gd` / 关卡 JSON。

## 文档导航

| 文件 | 作用 |
|---|---|
| `docs/game-design.md` | GDD：权威规则与测试用例 |
| `docs/architecture.md` | 目录树、模块契约、事件清单、GDScript 规范 |
| `docs/dev-step-log.md` | 追加式开发日志（最新状态以末尾为准） |
| `docs/tasks/` | 各轮任务单（CQ 队列重做 / FM 快速连发 / 交互打磨 / iOS 适配） |
| `docs/prompts/` | 任务提示词存档 |
| `reports/desktop/ux/` | 交互打磨验收（13 连 WON 回放报告、性能、关键帧） |
| `reports/desktop/fm/` | FM 验收矩阵与基线 |
| `reports/ios/adaptation-status.md` | iOS 适配状态 |

## 开发方法说明

本项目由 Claude Code 按任务单驱动开发：每轮任务先出实施计划 → 分阶段执行 → headless 测试 → 真实 .app 回放验收 → 量化报告。验收红线：不缩小模型、不无限弹、不异色弹、不计时删块、不超时清场、不改计数、不强制胜利；未执行的检查一律标注 NOT_RUN，不用旧报告冒充本轮结果。
