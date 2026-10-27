# iOS 适配状态报告（实时进度）

> 任务分支 `zhaojian/forios`，基线 commit `eab2e64`（工作区干净）。
> 本文件随每个步骤实时追加，作为防中断的进度锚点。最终报告见文末汇总。
> 状态标记：DONE / NOT_RUN / BLOCKED / WIP。

## 进度日志

### 2026-10-27 步骤记录

1. **DONE 基线核实（git）**：分支 `zhaojian/forios`，HEAD `eab2e64`，工作区干净，无未提交修改。其他分支：`main`、`zhaojian/forandroid`（本会话不操作）。
2. **DONE 项目配置核实**：`project.godot` 为 Godot **4.7.2 stable (ed1daf0bf)**，渲染后端 **GL Compatibility**（`gl_compatibility`，桌面与 mobile 均同），无原生插件/GDExtension。视口 1080×2400，窗口覆盖 540×1200，`orientation=1`（竖屏），stretch=`canvas_items`/`keep`。
3. **DONE 工具链核查（只读）**：
   - Godot：`/usr/local/bin/godot` = 4.7.2.stable.official.ed1daf0bf，与工程匹配。
   - Xcode 26.3 (17C529)，`xcode-select -p` = `/Applications/Xcode.app/Contents/Developer`，iOS SDK **26.2**。
   - 签名身份：`Apple Development: Jian Zhao (93J95FB35Y)`（本机钥匙串已存在，未验证其 provisioning 覆盖范围）。
   - iOS 模拟器运行时：iOS 17.2、iOS 26.2（本阶段按要求**不启动**）。
4. **BLOCKED iOS 导出模板缺失**：`~/Library/Application Support/Godot/export_templates/4.7.2.stable/` 仅有 `android_debug.apk`、`android_release.apk`、`macos.zip`、`version.txt`，**无 iOS 模板**（`ios.zip`）。阻塞“导出 Xcode 工程”步骤。按任务约束不自动下载大型运行时；需用户通过 Godot 编辑器 "Manage Export Templates" 安装 4.7.2.stable 模板，或手动放入官方 `Godot_v4.7.2-stable_export_templates.tpz` 中的 `ios.zip`。
5. **DONE 导出配置核实**：`export_presets.cfg` 现有 Android（preset.0，`com.learning.godotvoxelblocksmash`）与 macOS（preset.1）两个预设，**无 iOS 预设**。Bundle ID 沿用 `com.learning.godotvoxelblocksmash`。
6. **DONE 源码结构清点**：43 个 .gd 脚本（app/data/diagnostics/gameplay/input/level/presentation/projectile/voxel），主场景 `scenes/main/main.tscn`（Node3D + Camera3D + DirectionalLight3D + WorldEnvironment）。
7. **DONE 平台 API 面扫描**：`main.gd` 已处理 `NOTIFICATION_APPLICATION_PAUSED/RESUMED`（退后台冻结调度+落盘）、`NOTIFICATION_WM_CLOSE_REQUEST`、`NOTIFICATION_WM_WINDOW_FOCUS_OUT`；存档走 `user://saves`；诊断写 `user://event_log.jsonl`、`user://perf_log.jsonl`；回放报告写 `user://replay_report.json`。未发现桌面绝对路径或外部命令依赖。
8. **WIP 输入双触发风险**：`main.gd`/`hud_presenter.gd`/`cannon_view.gd` 同时处理 `InputEventScreenTouch` 与 `InputEventMouseButton/Motion`。Godot 默认 `emulate_mouse_from_touch=true`，iOS 上单次触摸会同时产生两类事件 → 旋转量翻倍、`handle_press` 重复进入。需要 iOS 侧关闭鼠标模拟（最小修复，见后）。
9. **DONE 核心脚本精读**（main/game_controller/level_repository/hud_presenter/level_list_presenter/cannon_view/level_session + 子代理覆盖其余 30+ 文件）：
   - 存档链路完整：原子写（tmp→校验→rename）、v2 快照、RNG 十进制字符串、坏档备份重开、退后台落盘。user:// 沙盒路径，iOS 兼容。
   - HUD 为比例锚点布局（信息0~10%/模型10~56%/炮位57~65%/队列66~91%/道具92~100%），**未处理安全区**：顶栏 offset_top=12、道具行贴底 100%，iPhone 刘海/灵动岛/Home 条会遮挡。
   - 暂停按钮 120×60 逻辑像素（keep 缩放下 ≈43×21pt），高度低于 44pt 参考值；道具/关卡按钮达标。
   - replay_runner 仅 CLI `--replay=` 触发，iOS 包内空转无害；game_state.gd 为无引用死代码（不动）。
   - 诊断：event_recorder 默认开、每事件 flush 写 user://event_log.jsonl；perf_monitor 默认开、每 5s 写 perf_log.jsonl。发布构建无关闭开关 → 需加门禁（任务§7 要求）。
   - 性能护栏已存在：MultiMesh 单实例渲染+尾交换删除、选靶 3ms 时间片+负缓存、在途弹 30 全局/6 单炮、DDA 4096 守卫。hit_effects 每次消除新建粒子/光圈节点（长线局 8000+ 节点），记入观察项，本阶段不改。
10. **CONFIRMED 触摸双触发（实证）**：headless 实验（/tmp/ios-adapt/test_touch_emulation.gd，godot 4.7.2 默认设置）证明一次触摸在 `_unhandled_input` 同时产生 mousebtn+touch 按下、mousemotion+screendrag 拖动（鼠标事件先到）。后果：旋转量×2、CannonView/ColumnClip 一次点按 emit 两次 → 一指点两炮/双倍滚动。属 iOS 必修项。
11. **DONE iOS 导出插件参数核实**（godotengine/godot@4.7.2-stable 源码）：arm64 唯一默认架构；最低部署目标默认 15.0；图标链 icon_1024x1024 → 缺省回退 application/config/icon 自动缩放；app_store_1024 强制不透明（自动填底色）；export_path 的 basename 决定 `<name>.xcodeproj` 与产物目录；导出前校验仅强制模板存在，team id 不阻塞工程导出。
12. **DONE 系统设置默认值实测**（headless dump）：emulate_mouse_from_touch=true、emulate_touch_from_mouse=false、hide_home_indicator=true、suppress_ui_gesture=true、allow_high_refresh_rate=true、audio session_category=0（Ambient，遵循静音开关）。音频中断/静音实际行为 → 真机 NOT_RUN。
13. **DONE 实施修改**（6 个文件，见下文清单）。
14. **DONE 轻量测试**：`.godot` 导入缓存重建（80 项无错误）→ 19/19 套件 TEST_PASS（10 unit + 8 integration + 1 persistence）；`tools/lifecycle_check.gd` 30 轮存档/恢复 PASS。
15. **DONE 导出尝试（有界，5.7s）**：`godot --headless --export-release "iOS"` → 预设解析正确，**唯一错误是缺 ios.zip 模板**（无 bundle id/图标/签名配置报错）。`--export-pack "iOS"` PCK 探针：脚本(.gdc)/场景/音频/图标/全部 JSON 关卡与模型打入；tests/tools/docs/reports/builds/*.vox 全部排除。排除过滤器对嵌套目录递归生效。
16. **DONE 大小写核对**：67 个 res:// 引用逐一与实际文件名比对，0 问题（唯一"缺失"是 test_persistence 故意不存在的路径穿越夹具）。
17. （进行中）最终报告落盘 + dev-step-log 交接条目。

---

# 最终报告（2026-10-27）

## 1. 当前源码基线与功能核实

- 分支 `zhaojian/forios` @ `eab2e64`，开始适配前工作区干净；Godot **4.7.2 stable (ed1daf0bf)**；渲染 **GL Compatibility**（desktop/mobile 同）；**无原生插件/GDExtension**。
- 当前玩法功能（源码为准）：五列守恒队列一键上位、固定五槽、入槽自动连发（0.09~0.10s 间隔）、目标化选靶（同色+可达+未预订，3ms 时间片续扫）、多弹并发（单炮 6/全局 30）、格空间锁定弹道（旋转中命中）、一发一块真实消除、超时/出界/异色取消返还、耗尽等待在途结算后退场、合成/随机排列/速度×2/指定目标四道具、测试取回保留、暂停遮罩/重开/返回列表/全清胜利、五类程序化音效、跟手旋转（±70° 俯仰限制）+ 慢速逆时针自动旋转（按住暂停/松手渐入）、v2 存档（原子写/白名单校验/坏档备份/RNG 状态随档）、有效局时计时（≤300s 目标）。
- 本阶段以 `eab2e64` 源码为准，未假设 Mac 端未提交修改。

## 2. 修改文件及作用（共 6 个，均未提交）

| 文件 | 作用 | 类别 |
|---|---|---|
| `export_presets.cfg` | 新增 `[preset.2] iOS`：arm64、bundle `com.learning.godotvoxelblocksmash`、0.3.2(5)、iPhone 竖屏、min iOS 15.0、export_project_only、图标链、零权限、排除非运行资源；签名字段留空 | 平台适配 |
| `assets/textures/app_icon_1024.png` | 由 432 源图放大生成（sips），供 icon_1024x1024 槽位 | 平台适配 |
| `scripts/app/main.gd` | `_ready` 中 `if OS.has_feature("ios"): Input.emulate_mouse_from_touch = false`（修复实证双触发） | iOS 最小修复 |
| `scripts/presentation/hud_presenter.gd` | `_apply_safe_area()`（仅 iOS：顶栏/道具行按安全区内移，canvas 坐标换算，size_changed 重算）；暂停/守恒按钮 120×60→124×124（≈44pt） | iOS 最小修复 |
| `scripts/diagnostics/event_recorder.gd` | `enabled` 默认 `OS.is_debug_build()` + open() 早退（release 不落盘；debug/编辑器行为不变） | 任务§7 要求 |
| `scripts/diagnostics/perf_monitor.gd` | 同上门禁（release 不建文件不采样） | 任务§7 要求 |
| 文档 | 新增 `docs/tasks/ios-adaptation-plan.md`、本报告 | 交付 |

## 3. 工具链检查结果

- Godot 4.7.2.stable ✓（与工程匹配）；Xcode 26.3 + iOS SDK 26.2 ✓；签名身份 `Apple Development: Jian Zhao (93J95FB35Y)` 存在（描述文件覆盖范围未验证）。
- **缺 iOS 导出模板**：`~/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip` 不存在。按任务约束未自动下载（官方 tpz 约 1GB）。
- 渲染兼容：GL Compatibility 在 iOS 经 ANGLE 路径运行，Godot 4.7.2 最低部署目标 15.0（源码核实）；未切换渲染后端。

## 4. iOS 导出配置及产物路径

- 预设：`export_presets.cfg` `[preset.2] "iOS"`（键名/默认值逐一比对 4.7.2-stable `platform/ios/export/export_plugin.cpp` 与 `editor/export/editor_export_platform_apple_embedded.cpp`）。
- 预期产物（模板安装后）：`/Users/zhaojian/orca/workspaces/godot-voxel-block-smash/forios/builds/ios/VoxelBlockSmash.xcodeproj` + 同目录 `VoxelBlockSmash/`（export_path basename 决定，源码核实）。
- 本阶段实测产物：`/tmp/ios-adapt/ios_probe.pck`（384KB，`--export-pack` 资源包探针，验证包含/排除规则）。

## 5. 导出/编译/签名/安装/运行状态

| 阶段 | 状态 | 证据 |
|---|---|---|
| 导出 Xcode 工程 | **BLOCKED** | 缺 ios.zip 模板；预设其余校验通过（导出器仅报模板缺失一项） |
| 编译 | **BLOCKED** | 依赖上一步 |
| 签名安装 | **BLOCKED** | 依赖工程产物；签名字段按要求留空待用户配置 |
| 运行 | **NOT_RUN** | 本阶段不启动模拟器/真机 |

## 6. 已执行检查与真实结果

- 19/19 headless 测试套件 TEST_PASS（修改后全量重跑）。
- `tools/lifecycle_check.gd`：30 轮存档/恢复 PASS。
- PCK 内容核验：脚本(.gdc)/场景/音频/图标/全部 JSON 关卡与模型打入；tests/tools/docs/reports/builds/*.vox/assets/vox_source/assets/source 全部排除（嵌套递归生效）。
- 67 个 res:// 引用大小写逐一核对：0 问题。
- 触摸双触发实证（headless 注入探针）：默认设置下 mouse+touch 双派发；修复后（iOS 门内关闭模拟）逻辑上等效单通道。
- 系统默认值实测：emulate_mouse_from_touch=true（已针对 iOS 关闭）、hide_home_indicator=true、suppress_ui_gesture=true、audio session_category=0(Ambient)。
- 耗时记录：导入缓存 ~秒级；19 套件串行 ~4 分钟；导出尝试 5.7s。

## 7. NOT_RUN / BLOCKED 清单

- BLOCKED（缺模板）：导出 Xcode 工程、编译、签名、安装、运行。
- NOT_RUN（本阶段约束）：iOS 模拟器一切验证；触摸手感/阈值体感/边缘手势；安全区实机显示效果；音频中断/静音开关实际行为；帧率/p95/内存/发热；三局回放清零与人工试玩。
- NOT_RUN（观察项）：GL Compatibility 在 iOS 的实机渲染正确性（ANGLE 路径）；`OS.get_static_memory_usage()` 在 iOS 的读数有效性（macOS 上已知返回 0）。

## 8. 需要从 Mac 端同步的公共修复/变更

1. `main.gd` iOS 门内 `Input.emulate_mouse_from_touch=false`——**Android 端建议复核同一默认值是否导致双事件**（headless 探针证实默认双派发；若 Android 真机存在双击/倍速旋转即同源）。
2. `hud_presenter.gd` 安全区内移目前仅 iOS 启用；Android 刘海/挖孔可同样受益。
3. 诊断 `enabled` 默认改为 `OS.is_debug_build()`：**release 导出不再写 event_log/perf_log**（FM 验收 run-4 用的是 release 导出，若后续仍需 release 证据需显式开启）。
4. 暂停/守恒按钮尺寸 120×60→124×124（视觉微变）。
5. 观察项（未改）：hit_effects 每消除新建粒子/光圈节点（长线局 8000+ 节点创建）；event_bus._seen_event_ids 单局只增不清（每局新 bus，量级可控）。

## 9. 后续签名、构建与真机测试步骤

见 `docs/tasks/ios-adaptation-plan.md` §7（模板安装→导出→Xcode 签名→部署）与 §8（12 项真机验收清单，含性能口径与局时目标）。

## 结论

按证据只能声明：**iOS 适配准备完成**（源码适配+导出配置+静态验证+轻量测试全绿）。工程导出因缺 ios.zip 模板 BLOCKED；iOS 运行、性能与完整适配均未验收。
