# iOS 适配方案（zhaojian/forios）

> 基线：分支 `zhaojian/forios`，commit `eab2e64`，Godot 4.7.2 stable，GL Compatibility。
> 本阶段范围：源码检查、平台适配、构建准备。**不启动 iOS 模拟器、不做长时间运行/性能测试。**
> 执行状态与证据见 `reports/ios/adaptation-status.md`。

## 1. 目标与边界

- 首要目标：iPhone 竖屏（设计视口 1080×2400，stretch `canvas_items`/`keep`）。
- 公共玩法优化以 Mac 端后续明确提交为同步来源；本方案不重写旋转/射击/选靶/炮台/存档系统。
- 不新增广告、内购、账号、联网、统计 SDK；不虚构 Team ID/证书/描述文件。
- 发现的公共逻辑缺陷：记录 + 仅做 iOS 适配所必需的最小修复，单独列出供同步（见 §6）。

## 2. 工具链（本机实测，只读核查）

| 项 | 值 | 来源 |
|---|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf（`/usr/local/bin/godot`，与 project.godot 一致） | `godot --version` |
| Xcode | 26.3 (17C529) | `xcodebuild -version` |
| iOS SDK | 26.2 | `xcrun --sdk iphoneos --show-sdk-version` |
| 导出模板 | **缺 iOS 模板**（4.7.2.stable 目录仅 android/macos） | 目录清单 |
| 签名身份 | `Apple Development: Jian Zhao (93J95FB35Y)` 在钥匙串 | `security find-identity` |
| iOS 模拟器运行时 | iOS 17.2 / iOS 26.2（本阶段不启动） | `xcrun simctl list runtimes` |

渲染兼容性：工程全局 `gl_compatibility`（含 `.mobile`）。iOS 上 GL Compatibility 经 ANGLE(Metal→GLES) 路径运行，最低部署目标 Godot 默认 15.0（已核实 4.7.2-stable 导出插件源码 `get_minimum_deployment_target()=15.0`）。本阶段**不切换渲染后端**；iOS 实机渲染表现列入真机清单。

## 3. 导出配置（export_presets.cfg 新增 preset.2 "iOS"）

- `platform="iOS"`，`architectures/arm64=true`（4.7.2 iOS 唯一支持架构）。
- Bundle ID `com.learning.godotvoxelblocksmash`（沿用 Android/macOS 现有值）。
- 版本：`short_version="0.3.2"`、`version="5"`（与 Android `version/code=5` 对齐）。
- `targeted_device_family=0`（iPhone；iPad 兼容模式可运行，不做专项布局）。
- `min_ios_version="15.0"`（Godot 4.7.2 默认最低目标）。
- `export_project_only=true`：本阶段只产出 Xcode 工程，不在导出流程内签名打包。
- 图标：`icons/icon_1024x1024` → `res://assets/textures/app_icon_1024.png`（由 432 源图一次性放大，App Store 1024 槽位强制不透明由导出器自动填底色；各尺寸槽留空自动从 1024 缩放——已核实导出器回退链源码）。
- 权限/能力：全部关闭（无网络、无通知、无 GameCenter、无相机/麦克风/相册用途说明）——游戏无相关功能。
- `exclude_filter="tests/*,tools/*,docs/*,reports/*,builds/*,*.vox,assets/vox_source/*,assets/source/*"`：排除非运行资源与历史产物。
- 签名四字段（team_id/identity/profile uuid/specifier）**留空**，不虚构；真机签名步骤见 §7。
- 方向：沿用 project.godot `window/handheld/orientation=1`（竖屏）。iOS 默认 `hide_home_indicator=true`、`suppress_ui_gesture=true`（拖动密集游戏友好，实测默认确认）。

## 4. 屏幕与交互适配

### 4.1 布局

HUD 已是比例锚点分区（信息 0~10% / 模型 10~56% / 炮位 57~65% / 队列 66~91% / 道具 92~100%），非固定分辨率。本次补齐：

- **安全区**：`HudPresenter._apply_safe_area()`（仅 `OS.has_feature("ios")` 生效）——`DisplayServer.get_display_safe_area()` 屏幕像素经 `canvas_transform` 逆变换到画布坐标，顶栏 `offset_top += 上内边距`、道具行 `offset_bottom -= 下内边距`；`size_changed` 时重算。桌面/无刘海设备安全区=全屏、内边距为 0，行为不变。
- **触控尺寸**：暂停/守恒按钮 120×60 → **124×124** 逻辑像素（iPhone 15 Pro 档 keep 缩放 ≈44×44pt；SE 档等比略小，任务允许"约 44pt 参考"）。其余按钮（道具 190、取回/合成 150、关卡 400×120、结算 480×120）均达标。
- 上位动画坐标、炮口位置、指定目标点选全部走"屏幕坐标↔相机射线"运行时换算（`FireGeometry`/`muzzle_screen_center`/`unproject_position`），布局变化后自动正确——无硬编码坐标。

### 4.2 输入互斥与触摸

- **已实证缺陷（headless 探针）**：默认 `emulate_mouse_from_touch=true` 下，一次触摸同时派发 MouseButton/Motion 与 ScreenTouch/Drag → 旋转量×2、点按双触发（一指点两炮）。修复：`main._ready` 中 `if OS.has_feature("ios"): Input.emulate_mouse_from_touch = false`（运行时开关，其他平台零影响；工程所有处理器原生支持触摸）。
- 互斥体系（现有，保留）：`InputMutex` 指针归属唯一；`ColumnClip.mouse_filter=STOP` 消费拖拽（队列>旋转优先级）；12px 阈值区分点按/滚动/拖动；多指只认首指；`main._input` 释放兜底防卡死。
- 触摸取消/多指/失焦/切后台：`NOTIFICATION_APPLICATION_PAUSED` → `router.cancel_all()` + 冻结调度 + 落盘；`WM_WINDOW_FOCUS_OUT` 清理悬挂手势；`_unhandled_input` 在 `_input_enabled=false`/遮罩可见时不生效。多指第二指被路由为 `ignored`。
- **NOT_RUN（留真机）**：触摸手感、阈值体感、边缘手势冲突、自动旋转接续手感。

### 4.3 自动旋转/暂停不变量（现有行为，iOS 沿用）

缓慢逆时针自动旋转；按住暂停、松手 0.2s 渐入接续；暂停/后台由 `is_running()` 门冻结，无补转/补发射击（`set_paused` 同时冻结调度与物理，`fire_stats` 有效局时同步停走）。

## 5. 生命周期 / 存档 / 音频

- 存档：`user://saves/level_<id>.json`，tmp 写入→JSON 校验→原子 rename；v2 快照白名单校验（先校验后 mutate）；RNG uint64 十进制字符串往返；坏档/v1 旧档备份 `.v1.bak` 后明确提示重开；**保存前结算/返还全部在途弹**（不丢弹、不占槽）。iOS 沙盒 user:// 兼容。
- 保存时机：返回列表/终局/退后台（PAUSED）/关窗请求。无高频写盘（关键状态变化触发）。
- 音频：5 个程序化 WAV + 8 路 AudioStreamPlayer 池；iOS session_category 保持默认 0=Ambient（遵循静音开关、可与其他 App 混音）。中断/恢复行为 → 真机 NOT_RUN。
- 诊断发布门禁：`event_recorder`/`perf_monitor` 的 `enabled` 默认改为 `OS.is_debug_build()`（编辑器与 debug 导出行为不变；release 构建不再每事件 flush 写盘）。诊断能力保留，可手动置 `enabled=true` 开启。

## 6. 需同步给 Mac/Android 端的公共项

1. `main.gd` iOS 门内关闭触摸→鼠标模拟。**Android 端建议复核**：同一默认值在其真机上是否也产生双事件（headless 探针证实默认设置下 mouse+touch 双派发）。
2. `hud_presenter.gd` `_apply_safe_area()` 目前仅 iOS 启用；Android 刘海/挖孔同样受益，可由 Android 端决定开启。
3. 诊断门禁默认值改动（debug 行为不变，release 关闭）。若 Mac 端用 release 导出做验收，需显式开 `enabled`。
4. 暂停/调试按钮最小尺寸 120×60→124×124（视觉微变）。
5. 观察项（未改）：`hit_effects.gd` 每次消除新建 CPUParticles3D+TorusMesh+材质（光圈不受 512 粒子上限约束）；`event_bus._seen_event_ids` 单局内只增不清（每局新 bus，量级可控）。

## 7. 后续步骤（本阶段之外）

1. 安装 iOS 导出模板（编辑器 Manage Export Templates 或官方 tpz 中 ios.zip → `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`）。
2. `godot --headless --path . --export-release "iOS"` → 产物 `builds/ios/VoxelBlockSmash.xcodeproj`。
3. Xcode 打开工程，Signing 选 Personal Team（本机已有 `Apple Development: Jian Zhao (93J95FB35Y)`；需在 Xcode 登录同名 Apple ID 自动生成开发描述文件）。
4. 真机部署执行验收清单（§8）；模拟器仅补布局/基本功能，不出性能结论。

## 8. iPhone 真机验收清单（NOT_RUN，暂不执行）

> 环境记录：机型/iOS 版本/构建配置（debug/release）/渲染后端。目标：常规游玩 FPS≥30、p95 帧耗时≤50ms；正常通关不依赖测试取回，每局有效游戏时间≤300s（暂停/后台时间单列）。

1. **安装与首启**：开发签名安装成功；首启到关卡列表 <5s；模型/颜色/音效资源完整。
2. **安全区域**：刘海/灵动岛不遮顶栏（关卡、剩余、连击、暂停键）；Home 条不遮道具行；四种长宽比（SE/标准/Pro Max/灵动岛机型）逐一看。
3. **触摸互斥**：拖队列不转模型；拖模型不滚队列；按钮单触发（一指点一炮）；12px 阈值点/滚判别正确；双指不打架（第二指忽略）。
4. **自动旋转**：缓慢逆时针；按住即停；松手从当前姿态 0.2s 渐入接续；无回弹。
5. **上位/退场**：点列首一键上位+补位动画；弹药归零炮台结算后离场；取回（有在途弹先结算）。
6. **多炮射击**：多槽并发自动连发；旋转中命中预订目标（弹道格空间锁定）；一发一块真实消除，剩余数与视觉一致。
7. **道具**：合成（两列同色列首）、随机排列、速度×2、指定目标（选炮→选同色可达块，非法不扣次，取消可退）；测试取回路径可用。
8. **全清结算**：真实清零（Q+S+F=V 守恒，debug 构建"守恒"面板可核）；耗尽等待在途结算后播退场；WON 结算遮罩。
9. **暂停/后台/锁屏/杀进程**：暂停遮罩冻结一切；切后台立即保存且恢复不补帧/不补射；锁屏恢复正常；杀进程后从最近存档恢复（在途弹已返还）；后台恢复不冲掉手动暂停。
10. **音频**：发射/消除/合成/胜负音效齐全；静音开关与音量键行为符合 Ambient 类别预期；来电中断后恢复。
11. **压力**：五炮齐发+持续拖动 5 分钟：无崩溃、内存趋势平稳（记录 Xcode Metrics/Instruments 口径：Memory Gauge 物理占用）、无异常发热降频。
12. **局时回放**：三局正常操作回放清零（有效局时≤300s/局）+ 至少一局人工试玩。
