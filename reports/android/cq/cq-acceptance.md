# CQ-20261026 验收表（真机 Pixel 7a 为最终验收环境）

初始化：2026-10-26，全部 NOT_RUN。证据归档 reports/android/cq/ 与 reports/desktop/cq/。

| ID | 场景 | 状态 | 证据路径 | 备注 |
|---|---|---|---|---|
| CQ-T01 | 默认/侧面视角四向拖拽跟手 | PASS(桌面) | tests/unit/test_rotation.gd 7断言 | S02 |
| CQ-T02 | 新青蛙导入与颜色统计（4000~5000 唯一体素） | PASS(桌面) | tests/integration/test_import.gd | S01 |
| CQ-T03 | 不同种子五列生成（合法/可变长/每色守恒） | PASS(桌面) | reports/desktop/cq/s03-solution.json | S03 |
| CQ-T04 | 点击列首/后排/满槽/连点 | PASS(桌面) | tests/unit/test_gameplay.gd | S04 |
| CQ-T05 | 固定中间槽弹尽不横移 | PASS(桌面) | tests/unit/test_gameplay.gd | S04 |
| CQ-T06 | 可达同色命中/异色遮挡/无同色不扣 | PASS(桌面) | tests/integration/test_auto_fire.gd | S05 |
| CQ-T07 | 两炮抢同一体素 | PASS(桌面) | tests/unit/test_shot_ledger.gd | S05 |
| CQ-T08 | 在途旋转/超时/出界/失效返还 | PASS(桌面) | tests/integration/test_auto_fire.gd | S05 |
| CQ-T09 | 最后一发失效与成功 | PASS(桌面) | tests/integration/test_auto_fire.gd | S05 |
| CQ-T10 | 随机排/合成/取回/加槽守恒 | PASS(桌面) | tests/unit/test_gameplay.gd（合成150=70+80/超限拒绝/随机排保ID色弹量/无牌不扣）；tests/integration/test_auto_fire.gd（取回事务） | S08 |
| CQ-T11 | 指定目标/速度×2 | PASS(桌面) | tests/integration/test_designated.gd（激活不扣次/异色·预订·点空不扣次/接受扣次/优先发射/失效提示不退款）；tests/unit/test_gameplay.gd（速度×2待发） | S08 |
| CQ-T12 | 飞行中后台/退出/恢复 | PASS(桌面) | test_auto_fire 恢复重新注册+代号隔离；test_persistence v2 往返（rng_state 续跑）；真机 30 轮生命周期待 S11 | S09 |
| CQ-T13 | v1 档/模型变更/坏档 | PASS(桌面) | test_auto_fire 三类坏档拒绝（无效色/守恒破坏/模型变更）；main 备份+提示重开；真机流程待 S11 | S09 |
| CQ-T14 | 多分辨率/长队列/触摸滚动 | NOT_RUN | | S07 |
| CQ-T15 | 真实完整通关（每色守恒、真实命中清零） | NOT_RUN | | S11 |
| CQ-T16 | 新模型性能与 30 轮稳定性 | NOT_RUN | | S10/S11 |
