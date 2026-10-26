# FM01~FM20 验收证据矩阵

> 验收平台：macOS 图形 App（`builds/macos/VoxelBlockSmash.app`，最终构建 SHA256 `b7d946af…4295`，详见 build-info.md）。
> 真机回放四连：run-1 **WON 221.3s** / run-2 **WON 215.9s** / run-3 **WON 236.8s**（PerfProbe 开启构建）；
> run-4 **WON 210.8s** 在最终交付构建（PerfProbe 关闭，SHA `b7d946af…`）上复跑，报告 `replay_app_report4.json` + 胜利屏关键帧 r4_win_*.png。
> 状态口径：PASS=有对应证据；PARTIAL=有证据但未全覆盖字面要求；NOT_RUN=未执行（人工项）。

| FM | 要求 | 状态 | 证据 |
|----|------|------|------|
| FM01 | 真实连续射速（多球在途，冷却不等落地） | PASS | `test_auto_fire` / `test_ball` 绿；三连回放 fire_attempt≈15432、fire_success=4114、avg_flight_ms≈276-300、在途上限 6/炮 30 全局（fire_stats 快照，replay_app_report*.json） |
| FM02 | 旋转中在途弹命中锁定目标（模型局部空间弹道） | PASS | `tests/integration/test_local_ballistics.gd`（飞行中 ±90°/180°/俯仰/平移仍命中预订 ID，0 mismatch）；真机回放全程 8°/s 自动旋转下 4105/4105 命中 |
| FM03 | 合法同色命中真实删块（状态/索引/渲染/计数同步） | PASS | 终局 alive=0 且 renderer_instances=0（三连回放报告）；`_on_ball_hit` 删后断言 renderer==alive，否则 integrity_error（未触发） |
| FM04 | 一发一块（重复结算不计数） | PASS | `test_ball` 高速/大 dt/重复结算用例绿；回放 destroyed_total=4105=模型体素数，无超删 |
| FM05 | 射速达标（≥90%×1/interval） | PASS | test_multi_ball 平板夹具实测 10.11/s（interval=0.09 → 理论 11.1/s，91%）；回放 destroys_per_sec 峰值 17.1 |
| FM06 | 多炮并发预订互斥 | PASS | `test_multi_ball.gd`（3/5 炮并发预订互斥）绿 |
| FM07 | 乱序结算正确 | PASS | `test_multi_ball.gd` 乱序结算用例绿；回放跨炮乱序命中终局守恒绿 |
| FM08 | 幂等重放/重复事件安全 | PASS | `test_multi_ball.gd` 幂等重放用例绿；settle_cancel changed=false 直接返回（退款幂等） |
| FM09 | 选靶切片扫描==全量扫描 | PASS | `tests/unit/test_selector_scan.gd`：1µs 预算断点续扫结果==全量；否定扫覆盖≈全部前沿候选（pendings≥90%×frontier） |
| FM10 | 负缓存正确失效/服务 | PASS | 同测试：gen+ckey 语义（同格 tver 变化仍服务、跨格失效、gen 推进失效）；真机 scan_pending 三连 5091/8047/10201 次均最终服务成功（无饿死，wait_ratio 0.61-0.73） |
| FM11 | 存档持久化/恢复 | PASS(部分) | `test_persistence`（含 uint64 RNG 十进制往返 >2^53 大 state）绿；30 轮生命周期存档代际一致可读；App 后台/重开人工项 NOT_RUN |
| FM12 | 无取回可解性 + 全清 | PASS | cq_verify（严格无取回验证器）VERIFY_PASS seed=4；s03-solution.json 4175 动作 return×0；真机回放 4105→0 全清 ×3 |
| FM13 | 一局有效时间 ≤300s（目标 210~240） | PASS | 三连 WON：221.3 / 215.9 / 236.8s（effective==wall，无暂停）；pacing PASS ×3；人工 UI 游玩计时 NOT_RUN（由用户实玩确认） |
| FM14 | 连续运行性能（FPS≥30、p95≤50ms、内存≤512MB、60s 增长≤10%）+ 30 轮生命周期 | PASS | run-4 perf_log 分析见下节（~240s 连续采样）；`tools/lifecycle_check.gd` 30 轮 TEST_PASS |
| FM15 | 全测试绿 + 人工道具/选择/滚动 | PASS(部分) | 19/19 套件 PASS（含 test_auto_rotation / test_selector_scan / test_multi_ball / test_persistence / test_local_ballistics）；人工合成/指定目标/三排滚动 NOT_RUN |
| FM16 | 测试不触真实存档 | PASS | 全套件隔离目录 `user://test_saves/<name>_<pid>`；真档 `user://saves/level_01.json` 全套件前后 shasum 不变（REAL_SAVE_UNCHANGED）；perf_log 同步隔离 |
| FM17 | 自动旋转：CCW 8°/s、帧率无关、拖拽暂停/松手接续 | PASS | `test_auto_rotation`：10s≈79.2°、30/60/120Hz 5s  pairwise≤0.5°、按住冻结/松手无跳角（单步≤8/60°）；cliclick 实拖关键帧 r3_pre/mid/post_drag.png（朝向可见变化） |
| FM18 | 指定目标选择/暂停/结算时停转 | PASS | `test_auto_rotation`：designated_selecting 冻结、_paused 冻结、tver 旋转时 +1/步、按住不变；`auto_rotate_enabled=false` 全停 |
| FM19 | 自动旋转开启下 1000+ 发零旋转致 cancel | PASS | test_local_ballistics 自动旋转开启 1000 发 0 旋转致取消；真机 4114 发仅 2/5/9 次 mismatch cancel（0.05%~0.22%，合法：预订块被同行先消） |
| FM20 | 指定目标稳定 + 自动旋转开启全清 ≤300s | PASS | `test_designated` 绿；三连真机回放全部在自动旋转 8°/s 开启下全清且 ≤300s |

## FM14 性能明细

**run-4（最终构建，210.8s 连续游玩，perf_log_run4.jsonl 43 采样×5s）**：
- FPS：min 53.4 / avg 75.4 / max 94.7（≥30 ✓）
- p95 帧时：avg 20.7ms / max 29.8ms（≤50ms ✓）
- `mem_static_mb` 全 0：macOS 导出版 `OS.get_static_memory_usage()` 不工作（Godot 4 已知 API 缺口），内存改用外部 RSS 佐证 ↓

**run-5（同一最终二进制，ps RSS 外部采样 15s~155s）**：
- RSS：276.8MB（t=15s）→ 291.4MB（t=155s），峰值 291.8MB（≤512MB ✓）
- 最差 60s 窗口增长 +4.7%（t=15→75s），后段趋平（t=95→155s 仅 +0.9%）（≤10% ✓，无泄漏趋势）

**生命周期**：`tools/lifecycle_check.gd` 30 轮进关→游玩→返回列表 TEST_PASS（代际递增、存档可读、隔离目录）。

## run-4（最终交付构建）回放结果

- 结果 **WON**，有效/墙钟 **210.8s**（≤300 ✓，210~240 目标带内 ✓，四连中最快）
- 4105/4105 命中、3 次 mismatch cancel（0.07%）、守恒 ✓、alive=0、renderer=0、op_mismatches=0
- 胜利屏关键帧 `keyframes/r4_win_1..6.png`（"通关！" + 剩余 0 + 全槽空）

## 三连回放统计对照（FM01/05/13/19/20 数据源）

| run | 结果 | 有效s | 命中 | mismatch cancel | wait_ratio | scan_pending | 峰值dps | 守恒 | 渲染残留 |
|-----|------|-------|------|-----------------|-----------|--------------|---------|------|----------|
| 1 | WON | 221.3 | 4105/4105 | 2 (0.05%) | 0.606 | 5091 | 12.0 | ✓ | 0 |
| 2 | WON | 215.9 | 4105/4105 | 5 (0.12%) | 0.687 | 8047 | 17.1 | ✓ | 0 |
| 3 | WON | 236.8 | 4105/4105 | 9 (0.22%) | 0.733 | 10201 | 13.1 | ✓ | 0 |

## 已知未覆盖（诚实清单）

- 人工 UI 游玩计时（FM13 人工半）、App 后台/重开（FM11 人工半）、合成/指定目标/三排滚动人工操作（FM15 人工半）：NOT_RUN，留待用户实玩确认。
- wait_ratio 0.6~0.73 偏高（选靶等待占尝试比例），但 pacing 已稳定落入 210~240 目标带，判定达标。
