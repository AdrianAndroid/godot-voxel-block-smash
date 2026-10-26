# F0 基线

- 日期: 2026-10-26 21:20:42 CST
- HEAD: 31417c52a650ec5adc17dccf179edd9c27a8bbe9
- git status:
   M docs/reviews/2026-10-26-project-review-and-reference-gap.md
  ?? .claude/
  ?? docs/tasks/2026-10-26-fast-moving-target-clear-plan.md
  ?? reports/desktop/fm/
- frog_02 md5: 6a76e2453bc882b8013e38cb6850f5cf
- frog_02 sha256: f867f19c33c43dbbd1035c6fc52e184471a141ff6ef334bceb37b2f737eb70c5
- godot: 4.7.2.stable.official.ed1daf0bf
- macOS: 15.7.9 / x86_64
- CPU: Intel(R) Core(TM) i7-8700B CPU @ 3.20GHz
- 真实存档目录 (/Users/zhaojian/Library/Application Support/Godot/app_userdata/godot-voxel-block-smash/saves):
  (目录存在但无存档文件)

## 基线测试结果（隔离存档目录后）

| 测试 | 结果 |
|---|---|
| test_auto_fire | FAIL（3 项） |
| test_ball | PASS |
| test_cannon_queue | PASS |
| test_cannon_view | PASS |
| test_designated | PASS |
| test_event_bus | PASS |
| test_gameplay | PASS |
| test_import | PASS |
| test_input | PASS |
| test_persistence | PASS |
| test_play | PASS |
| test_presentation | PASS |
| test_rotation | PASS |
| test_shot_ledger | PASS |
| test_voxel | PASS |

已知基线失败：test_auto_fire 3 项（fires=281 vs 期望 80、弹尽炮台未移除、调度未注销）——在纯净 31417c5 worktree 复现，与本次改动无关；系 ball_speed 12→40 提交时未回归所致（提速后大量 mismatch/timeout 返还重射）。将在 F1/F2 局部弹道+多球改造中重写该测试假设。
