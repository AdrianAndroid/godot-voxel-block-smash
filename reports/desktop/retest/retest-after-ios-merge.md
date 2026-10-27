# iOS/Android 合入后 macOS 玩法回归验收（2026-10-27）

范围：确认 `2e4f6d6`（iOS 适配准备）+ `c54e51e`（合并）合入后 macOS 玩法无回归。
构建：`builds/macos/VoxelBlockSmash.app` 全新导出（HEAD `c54e51e`），可执行 SHA256
`b60ed174618ab6c3ca4d318e0a4b8dc2f2c4c1716ae65062a433771beab6431f`。
设备：Mac mini i7-8700B / UHD 630 / macOS 15.7.9，窗口 540×1200。

## 合入改动审查（git diff 003648e..c54e51e）

| 文件 | 改动 | 桌面影响评估 |
|---|---|---|
| main.gd | iOS 下关闭 emulate_mouse_from_touch | `OS.has_feature("ios")` 门控，桌面不受影响 |
| hud_presenter.gd | 安全区内移（iOS 门控）；暂停/守恒按钮 120×60→124×124 | 桌面仅按钮变大，布局有余量 |
| event_recorder.gd / perf_monitor.gd | enabled 默认改为 `OS.is_debug_build()` | 发布构建不再写 event/perf 日志（性能更好；验收采样需 debug 构建或外部手段） |
| export_presets.cfg | 新增 iOS 预设 + 1024 图标 | 不影响 macOS 预设 |

结论：无针对桌面玩法逻辑的改动；风险点为 HUD 按钮尺寸与诊断门禁，均已覆盖验证。

## 执行结果（全部本轮实际执行）

| 项 | 结果 | 证据 |
|---|---|---|
| headless 21 套件 | **21/21 PASS**（exit=0） | 逐套件 TEST_PASS |
| .app 完整回放 ×3 | **3/3 WON** | replay_retest4/5/6.json |
| 画面抽帧 | 模型渲染/队列/道具/暂停按钮/连击显示全部正常 | /tmp 抽帧（r4_t30 等，未入库） |

### 回放数据

| 局 | 有效时长 | alive | renderer | 守恒 | fires==hits | cancel | revalidate_failed | op_mismatches |
|---|---|---|---|---|---|---|---|---|
| 4 | 168.7s | 0 | 0 | ok | 4105==4105 | 0 | 12 | 0 |
| 5 | 193.1s | 0 | 0 | ok | 4105==4105 | 0 | — | 0 |
| 6 | 183.9s | 0 | 0 | ok | 4105==4105 | 0 | — | 0 |

三局 exit=0 WON，全部 ≤300s（168.7~193.1s），与合入前基线（169.4~190.9s）一致，**玩法无回归**。

## 本轮踩坑（供后续）

1. **回放解文件必须用绝对路径**：`--replay=res://...` 或相对路径在导出 .app 中读不到
   （PCK 内无 s03-solution.json；相对路径 cwd 不定），arm 失败后 app 落到正常模式——
   若存在旧存档还会自动续玩，造成"看似在跑实则无驱动"的假对局（retest1 即此情况，
   18 分钟仅消 324 块后停滞）。验收前必须先确认日志无 `[replay] 无法读取解文件`。
2. 验收前 `pkill -f VoxelBlockSmash.app` 清旧实例（本轮发现一个 48 分钟旧实例）。

## NOT_RUN

- 发布后性能采样（perf_monitor 发布构建已默认关闭；本轮未做 debug 构建采样，
  历史性能结论见 ux-acceptance.md，不受本次合入影响——改动均非热路径）。
- 人工手感复验（iOS 合入不改变桌面输入路径）。
