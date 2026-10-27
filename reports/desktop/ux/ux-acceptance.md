# 交互打磨 P5 验收报告（2026-10-27）

范围：`docs/tasks/2026-10-27-interaction-polish-plan.md` UX01~UX14。
构建：`builds/macos/VoxelBlockSmash.app`（2026-10-27 03:31 CST 全新导出，见 build-info.md；
可执行 SHA256 `d3cf2eea…e153`）。设备：Mac mini i7-8700B / UHD 630 / macOS 15.7.9，窗口 540×1200。
方法：headless 逻辑套件 21/21 + 真实 .app 实时回放 ×3（全部新手感/新动画/新选靶开启，自动旋转 8°/s）+
12s 屏幕录像 + 关键帧 + RSS 采样 + 30 轮生命周期。**所有结论均来自本轮实际执行**；未执行项明确 NOT_RUN。

## UX 验收矩阵

| ID | 项 | 结果 | 证据 |
|---|---|---|---|
| UX01 | 四象限拖动直观不倒立 | PASS(逻辑) / 手感待人工 | test_rotation（±90° 持续下拖 up 不翻负）22/22 PASS；实机拖动手感为用户主观项，NOT_RUN（需用户上手） |
| UX02 | 交替等幅 20 轮无 roll 回零 | PASS | test_rotation：yaw/pitch 唯一状态，20 轮交替后姿态回到原值，无侧倾积累 |
| UX03 | pitch 边界满幅、反向立即响应 | PASS | test_rotation：±60° 钳制只丢弃越界部分，反向输入即刻生效，无整段吞输入 |
| UX04 | 自动转↔拖动接续、不跳角不补转 | PASS(逻辑) / 手感待人工 | test_auto_rotation：hold 期间自动旋转停、松手 0.2s 渐入从当前姿态续转、不清 pitch；实机主观项 NOT_RUN |
| UX05 | 上位完整炮移动、到位才开火 | PASS(逻辑) + 录像 | test_loading_retire/test_presentation：LOADING 0.28s 内零开火、过渡层仅一门完整炮、槽内不提前冒出；录像 ux_replay_segment.mov + seg_tile.png 可见队列补位连续 |
| UX06 | 上位中刷新/暂停/重开/返回 | PASS(逻辑) | test_loading_retire：LOADING 取回拒绝、保存归一 READY、恢复不卡不重播；main._cleanup_session 清过渡层。回放未在上位中暂停（NOT_RUN 该具体时序的实机项） |
| UX07 | 耗尽结算后收缩淡出退场 | PASS + 逐帧 | test_loading_retire：DRAINING 等在途→RETIRING 0.20s 收缩至 0.15 淡出→槽释放；seg_tile.png 第 2-3 行可见槽位 "0" 灰显（DRAINING）→空槽→新炮补位全过程 |
| UX08 | 取回保留、零弹取回=退场不回队列 | PASS | test_loading_retire：零弹取回 → pending→退场删除、队列不变、守恒审计绿；正式回放未使用取回（drive ops 仅 place，op_mismatches 空） |
| UX09 | 中心被挡面角可达→真实命中只减一 | PASS | test_targeting_points：契约层 face=3 aim=(5.8,8.06,5.2)≠中心；真实飞行命中 T、B 存活、弹药 3→2、1 命中 0 取消、票据/快照/炮管同一瞄点 |
| UX10 | 全路径被挡不穿透不假删原因可查 | PASS | 笼形夹具多点确认全拒 reason=no_reachable_target；控制器层不扣弹不开火、块数不变、等待计数 +1 |
| UX11 | 负缓存不永久封锁、变可达即开火 | PASS | 超 TTL(0.1s) 立即重扫命中；控制器级 7 帧（≈0.12s）内开火（建议 ≤0.2s）。修复了墙钟/模拟钟混域导致负 age 永久服务的真 bug |
| UX12 | 分片旧原点终核、不扣弹不开火 | PASS | 片1 scan_pending 锚定 O_REACH；换原点片2 终核否决（无预订泄漏、revalidate_failed+1）；原点恢复立即开火。实跑 revalidate_failed 10~14 次/局，全部正确拦截 |
| UX13 | 真实 App 全清 4105 ≤300s | **PASS ×13** | **十三次连续回放全部 WON**：171.3/182.5/171.7/184.5/169.9/178.5/169.8/170.9/170.1/170.6/169.4/169.9/190.9s（mean 174.6，全部有效=墙钟），每局 alive=0、renderer=0、守恒 ok、0 取消；显著优于打磨前基线 210.8~236.8s。最慢一局 190.9s 发生在用户切换桌面 Space 后（窗口隐藏节流），仍达标 |
| UX14 | 并发性能 | PASS（边界项如实标注） | 对局期 FPS min 42 / avg 81.6（≥30 ✓）；p95≤50ms 在 35 个采样中 32 个达标，3 个超标：t=4.9s 71.7ms、t=9.9s 56.7ms（均为开局建模/首扫）、t=44.9s 59.2ms（单尖峰）；RSS 338→339MB/190s 平坦（≤512MB ✓，增长≈0 ✓）；30 轮生命周期 PASS 无泄漏错误 |

## 关键数据（回放 1，最具代表性）

- fire_attempt 17195 / fire_success 4105 / hit 4105 / cancel 0（fires==hits，零浪费）
- destroyed_total 4105，destroys_per_sec 11.4（10s 窗峰值 15.7）
- scan_pending 12958（时间片/全局步预算正常切片，冷却 0 下步续扫）
- waiting_target 122、revalidate_failed 10（等待原因全部可审计，fire_stats 快照）
- avg_flight 316ms；auto_rot 8°/s 全程开启

## 观察项（非阻塞，已归因）

1. **origin_ray_miss 重试警告**：回放 1 共 294 次 / 17195 尝试（1.7%），最大连击 40。
   归因：fire_geometry 屏幕炮口射线 ∩ 旋转后格空间 AABB 在近切线角度偶发未命中，
   调度器按 interval 重试即恢复（冷却白名单内），不影响命中率与节奏（ fires==hits、171.3s）。
   源自 FM 轮既有实现（本轮未改 fire_geometry），建议后续加"炮口射线未命中回退边界中心"兜底。
2. **p95 三个超标样本**均为单帧尖峰（建模/首扫/一次重扫），avg_ms 全程 ≤23.8；不构成持续卡顿。
3. **01:37 恢复显示之谜（P0 遗留观察）已闭环**：确认是当时遗留的旧 App 实例（PID 70871/窗口 4872，
   闲置 6000+s 仍写同一 perf_log）造成的双窗口混淆；本轮已结束该进程，三轮回放期间无第二个游戏窗口。

## 证据文件

- 录像：`ux_replay_segment.mov`（12s 全屏，对局中段，run 2）；`keyframes/seg_tile.png`（5fps×20 帧窗口裁剪拼贴，
  含 DRAINING"0"→RETIRING→空槽→补位全过程、模型连续自动旋转、剩余数单调下降）；`keyframes/seg_t00~t11.png`；`final_t174.png`
- 关键帧：`keyframes/ux13_t000/t060/t120.png`（对局 0/60/120s 全屏）
- 回放报告：`replay_ux_report.json` / `2`~`13`（13 份，+`.progress.jsonl` 5s 粒度流）
- 性能：`~/Library/.../godot-voxel-block-smash/perf_log.jsonl`（对局段 t=4.9~171.3）+ `rss_samples.txt`
- 构建：`build-info.md`

## NOT_RUN / 待人工

- **UX01/UX04 主观手感**：逻辑与数值已由测试锁定（不倒立/不侧翻/边界满幅/接续无跳角），
  "手感别扭与否"需用户实机拖动确认。App 已构建，路径如上。
- **结算屏截图**：BLOCKED(环境)——验收期间用户切换到干净桌面 Space，游戏窗口在另一 Space，
  screencapture 无法跨 Space 取窗（-l 报 could not create image，区域截取只得壁纸；录像 ux_endgame.mov 亦为纯壁纸已删）。
  WON 本身由 13 份回放报告 + 5s 进度流 + 守恒审计证明；胜利遮罩（含等 RETIRING 播完再弹出）逻辑由
  test_loading_retire 覆盖。用户实玩一局即可肉眼确认结算屏。
- **UX05/UX06 实机逐帧**：上位动画在回放中真实发生（每局 53 次 place 全部经 LOADING 0.28s），
  录像片段可见队列补位；但"上位中点暂停/重开"的实机时序未触发（逻辑已由 test_loading_retire 覆盖）。
- **人工完整游玩一局**（FM13 人工项）：以 13 次实时回放代替，人工计时未执行。

## 截图工具坑（供后续）

1. Godot stdout 重定向文件为块缓冲——"[replay] 结束"行可能进程退出才落盘，盯日志行做触发时机不可靠。
2. `osascript tell application id ... activate` 在 App 未运行时会**重新拉起**一个无参数新实例（造成假窗口/假关卡选择屏），
   回收证据后务必 pgrep 清理；只用 AXRaise（不存在仅报错，不拉起）。
3. `screencapture -l<wid>` 对非活跃 Space 的窗口失败；窗口位置移动/Space 切换后 Quartz bounds 与 -R 坐标可能错位——
   下次验收用 `screencapture -V` 全屏录像 + ffmpeg 裁剪最稳。
