# 测试报告（test-report）

状态：最终轮（阶段7 完成，2026-10-26，CLAUDE-ALL 自主执行）。T01~T12、T14~T22、T24 PASS；T13 性能项 FAIL（SwiftShader 软渲染环境，如实记录）；T23 部分执行未判 PASS。桌面 headless 检查不单独充当玩法通过证据——所有玩法用例均有 headless 断言 + 安卓模拟器设备证据双重覆盖（除纯逻辑分支注明处）。

## 通用信息（最终轮）

- 构建标识 / APK 哈希：builds/android/godot-voxel-block-smash-debug.apk，SHA256=75f6fd2cde4b15d8c229b31c652925fcfa6f7b6b903a22477f20bcb4aad9cdad（调试签名，apksigner 校验通过）
- GDD 版本：v6（含 2026-10-26 执行默认值决策登记 D01~D07）
- 环境：Android 模拟器 AVD voxel_test_api33 / Android API 33 / x86_64 / 1080x2400 竖屏 / 渲染后端 SwiftShader（软渲染，无 GPU 直通）；Godot 4.7.2.stable
- 固定种子 / 夹具：rules.rng_seed=7（level_01）；模型夹具 grid_300.json（300块，正式关卡 level_01 使用）、model_1200 夹具（T01 上限分支）、level_02.json（TEST_ONLY 关卡B）
- 行为日志路径：docs/evidence/event_log_device.jsonl（设备拉取）、docs/evidence/perf_log_device.jsonl；headless 日志 reports/desktop/*.log（9 套全部 exit=0）
- 测试者画面现象文字描述：关卡列表正常显示"第1关"；进关后青蛙模型居中、受光、颜色正确（绿身/白眼）；顶部"关卡 level_01 剩余 367"，消除后递减至 359；底部 4 道具按钮（用尽后"加槽"消失）、槽位行 3→4 槽、九宫格彩色炮台卡；单指拖动模型绕中心旋转；杀进程重进后状态完全恢复。截图附件：docs/evidence/device_level01_gameplay.png、device_rotated_shuffled.png、device_session_restored.png

## 用例结果

| 用例 | 状态 | 预期/实际摘要 | 指标实测值 vs 批准阈值 | 现象文字 | 证据路径 | 备注（D 依赖） |
|---|---|---|---|---|---|---|
| T01 | PASS | 预期：300/1200合法、非法（重复坐标/非法色/非法数量）拒绝、单MultiMesh；实际：test_voxel 13断言 + test_import 14断言全过，设备端存活367=实例367 | 实例数=存活数367；无逐块节点 | 设备上青蛙无缺块错色 | reports/desktop/test_voxel.log、test_import.log；docs/evidence/device_level01_gameplay.png | GPU缓冲回读以CPU镜像断言替代（headless），设备端目测无缺块 |
| T02 | PASS | 预期：拖动模型中心不变、UI起始手势不旋转、取消无残留；实际：test_input 11断言（手势路由/UI隔离/取消清理）+ 设备单指滑动模型绕中心旋转、点按UI按钮不触发旋转 | 旋转速率0.01弧度/像素（D06） | 滑动后模型俯视角度变化，中心不漂；点道具/池卡时模型不动 | reports/desktop/test_input.log；docs/evidence/device_rotated_shuffled.png | D06 |
| T03 | PASS | 预期：空位/越界不可选、安放归属唯一、非法操作不改状态；实际：test_gameplay（空位/越界/取出/放回拒绝）+ test_play（安放池0→槽、归属唯一）+ 设备点绿卡→点槽安放成功 | — | 设备上池卡消失、槽位显示炮台弹量 | reports/desktop/test_gameplay.log、test_play.log；event_log_device.jsonl | D01 |
| T04 | PASS | 预期：数量递减2→1→0、归零移除、第三次不生成球；实际：test_play 发射事务断言 + 设备事件日志 ammo 3→2→1→0、槽回"放置"、空槽不发射 | — | 槽位数字随发射递减，归零后炮台消失 | reports/desktop/test_play.log；event_log_device.jsonl（turret_fire×4 同一炮台） | — |
| T05 | PASS | 预期：同色2+3=5、源不重复、异色拒绝；实际：test_gameplay 合成40+50=90、仅保留一个结果、异色/空位拒绝 | 合成上限99（D02） | headless 逻辑断言 | reports/desktop/test_gameplay.log | D02 |
| T06 | PASS | 预期：同色删除一次、异色不删且反射有记录；实际：test_ball 8断言（反射公式v-2(v·n)n、命中膨胀面、大步长不隧道、旋转模型世界法线）+ test_play 同色删除/异色存活数不变 + 设备日志含 normal/vel_before/vel_after | 球半径0.35、基础速度12（D03） | 设备日志每次命中均记录法线与前后速度 | reports/desktop/test_ball.log、test_play.log；event_log_device.jsonl | D03 |
| T07 | PASS | 预期：连击递增、出界立即0、重复命中已删块不计数；实际：test_play 连击事件断言 + 设备日志 combo_update 连击递增（shot4 单球连毁4块）且 ball_out_of_bounds 后归零 | — | 设备日志 combo_update×11，出界后归0 | reports/desktop/test_play.log；event_log_device.jsonl | D03；连击不改变伤害（G07 设计常量） |
| T08 | PASS | 预期：速度×2下一发模长比2、弹量只减1、用后清除；实际：test_play 24/恢复12断言 + 设备 shot6 实测模长24.0、shot7 恢复12.0 | 实测24.0 vs 阈值2×12=24 | 设备日志速度精确翻倍后恢复 | reports/desktop/test_play.log；event_log_device.jsonl | D04 |
| T09 | PASS | 预期：解锁至上限5、第6次拒绝不覆盖不扣次；实际：test_gameplay 容量=min(已解锁,5)、满5拒绝不扣次 + 设备加槽后槽行3→4、道具消失 | 上限5（D01） | 设备上第4槽出现，"加槽"按钮用尽消失 | reports/desktop/test_gameplay.log；docs/evidence/device_rotated_shuffled.png | D01/D04；设备端未逐次解到5（逻辑分支已由单测覆盖） |
| T10 | PASS | 预期：任意指下一发删异色、失效后只反弹、事件含标识；实际：test_play 任意指消异色+用后清除 + 设备紫炮台(color5) any_color:true 删除绿块(color1)，后续普通发射 any_color:false | — | 设备日志 any_color 标识随球携带 | reports/desktop/test_play.log；event_log_device.jsonl | D04 |
| T11 | PASS | 预期：九格全刷新、槽炮台保持、ID不复用；实际：test_gameplay 随机排扣次2→1/整体刷新 + 设备 shuffle 后九张卡全部更换、槽位不变、item_activated 记录2→1 | 种子可复现（rng_seed=7） | 设备截图 shuffle 前后池卡完全不同 | reports/desktop/test_gameplay.log；device_rotated_shuffled.png；event_log_device.jsonl | D05 |
| T12 | PASS | 预期：剩余2→1→0不为负、通关事件一次、HUD同步；实际：test_play 全清通关 won==1、销毁幂等（destroy-once 防重复提交）、通关后安放/道具拒绝 | — | headless 断言；设备未打到全清（367块手动打不完，逻辑由套件构造） | reports/desktop/test_play.log | — |
| T13 | FAIL（如实记录） | 预期：FPS≥30、p95≤50ms、内存≤512MB、60s窗口增长≤10%；实际：FPS 平均10.0/峰值12.2（不达标）、p95 峰值143.1ms（不达标）、内存峰值57.1MB（达标）、35s窗口增长10.4%（窗口不足60s，样本不足） | FPS 10.0<30 FAIL；p95 143.1>50 FAIL；内存57.1MB<512MB PASS；增长样本不足 | SwiftShader 软渲染 x86_64 模拟器，无 GPU 加速，帧率受环境限制；游戏无卡顿死机 | docs/evidence/perf_log_device.jsonl | D07；1200块模型设备端未跑（上限分支见T01）；真实硬件需复测 |
| T14 | PASS | 预期：安装/启动/触屏无崩溃、环境日志齐全；实际：APK 安装成功、竖屏启动、触屏全部命中（关卡选择/安放/发射/道具/滑动）、两进程无崩溃、事件与性能日志齐全 | 竖屏 orientation=1（aapt2 验证 AndroidManifest） | 全部截图见附件；音效播放逻辑由 test_presentation 计数断言覆盖（设备可听性无法自动化，如实注明） | docs/evidence/*.png、*.jsonl；reports/desktop/test_presentation.log | 依赖其余用例；首次启动系统沉浸式提示框已识别并处理 |
| T15 | PASS | 预期：未发射取回保持ID/弹量、槽释放；已发射/池满拒绝无丢失；实际：test_gameplay 取回ID弹量不变、槽清空、已发射拒绝、拒绝不丢炮台 | — | headless 逻辑断言 | reports/desktop/test_gameplay.log | D01 |
| T16 | PASS | 预期：池内合成到99合法、超限拒绝不截断、槽内合成不可达；实际：test_gameplay 90+20超99拒绝双方不变、等上限合法；槽内无合成入口（UI 仅池卡间合成，设计隔离） | 上限99（D02） | headless 逻辑断言 | reports/desktop/test_gameplay.log | D02 |
| T17 | PASS | 预期：次数不负、归零消失、不重复生效、加槽本局保留、待发不泄漏；实际：test_gameplay 四道具扣次/拒绝不扣/不为负 + 设备速度×2与任意指均只影响下一发（shot7 恢复12）、加槽用尽按钮隐藏 | — | 设备道具计数 3→2、2→1、2→1，加槽归零消失 | reports/desktop/test_gameplay.log；event_log_device.jsonl；device_rotated_shuffled.png | D04 |
| T18 | PASS | 预期：只判失败一次、重复输入不重复终局；实际：test_play 失败真值表触发 lost==1 且重复评估不重复发布 | — | headless 断言（套件构造池槽空+无球+无随机排） | reports/desktop/test_play.log | D08 真值表已登记 |
| T19 | PASS | 预期：按D08真值表判断、禁止池空直接判负；实际：outcome_state 真值表=池空∧槽空∧活跃球0∧随机排0，胜利优先；test_play 覆盖池空但槽有炮台不判负等分支 | — | headless 断言 | reports/desktop/test_play.log | D08 已批准（执行方登记） |
| T20 | PASS | 预期：A/B各自状态无串用、回A恢复一致；实际：test_persistence A/B会话独立 + test_play A→B→A 恢复快照一致 + 设备跨进程恢复（剩余359、4槽、道具计数、池卡完全一致） | — | 设备杀进程重进后画面与离开前一致 | reports/desktop/test_persistence.log、test_play.log；device_session_restored.png | D09 |
| T21 | PASS | 预期：旧会话事件拒绝、恢复后实例=存活、跨进程恢复；实际：test_play 旧代事件拒绝（session_generation）+ test_persistence 版本999/损坏存档拒绝 + 设备跨进程恢复后存活359=HUD剩余359 | — | 设备恢复后剩余数与事件日志一致 | reports/desktop/test_play.log、test_persistence.log；event_log_device.jsonl | D09 跨进程分支已执行（非BLOCKED） |
| T22 | PASS | 预期：粒子不影响命中序列与消除结果、无粒子碰撞、上限受控；实际：粒子为纯视觉订阅者（CPUParticles3D 无碰撞体），test_presentation 粒子上限512/单次16/超限丢弃计数断言；消除逻辑测试在无粒子环境全部通过 | 单次16≤32、总量≤512、寿命0.8s（D07） | headless 断言 | reports/desktop/test_presentation.log | D07 |
| T23 | 部分执行（未判PASS） | 预期：30轮重复旋转/发射/合成+内存趋势；实际：设备执行多轮旋转/7次发射/合成道具操作无崩溃无闪退，但未满 D07 的30轮与120s时长；内存 51.7→57.1MB（35s窗口），无持续泄漏迹象但样本不足 | 见 T13 性能表 | 多轮操作后应用稳定 | docs/evidence/perf_log_device.jsonl、event_log_device.jsonl | D07/D10；轮次不足如实记录，不推定通过 |
| T24 | PASS | 预期：关卡号一致、剩余=存活、道具次数正确、用尽隐藏、固定UI不随模型转；实际：test_presentation HUD断言 + 设备截图：顶部"关卡 level_01"/剩余359=存活359、道具计数正确、加槽用尽隐藏、旋转模型时底部UI矩形不动 | — | 三张设备截图逐项可核对 | reports/desktop/test_presentation.log；docs/evidence/*.png | D06 |

## 性能指标汇总（T13/T23，阈值来自 D07 已批准值）

| 指标 | 实测值 | 批准阈值 | 判定 |
|---|---|---|---|
| FPS（稳态） | 平均 10.0 / 峰值 12.2 / 最低 8.6 | ≥30 | FAIL（SwiftShader 软渲染环境受限） |
| p95 / p99 帧时间（ms） | p95 峰值 143.1 / 平均 94.1~125.3 | p95≤50 | FAIL（同上） |
| 内存峰值 / 趋势采样 | 峰值 57.1MB；51.7→57.1（35s窗口 +10.4%） | ≤512MB；60s窗口≤10% | 峰值 PASS；趋势样本不足（窗口<60s） |
| 活跃球 / 粒子峰值 | 活跃球峰值 2（设备）/ 5（套件构造）；粒子上限512、单次16 | 球≤5；粒子≤512/次≤32 | PASS |
| 节点数 / 实例数 | 单 MultiMesh 单绘制，实例367=存活367，无逐块节点 | 单模型单 MultiMesh | PASS |
| 物理步耗时 | 未单独计时（帧时间含物理，见 p95） | — | 如实记录缺项 |

注：模拟器为 SwiftShader 软件渲染（无 GPU 直通），FPS/p95 不达标主要归因环境；D07 阈值为真实设备目标，需真机复测后方可判"流畅通过"。此判定不掩盖、不推定。

## 缺陷复现记录

1. 现象：设备端 event_log.jsonl 为 0 字节 → 证据：run-as ls 显示文件存在但空、perf_log 正常 → 复现：进关后任意操作 → 根因：event_recorder._write 未 flush，Android 上 close() 前缓冲不落盘（已证实，perf_monitor 有 flush 故正常）→ 修复：每行 store_line 后 flush + 退出/退后台时 recorder.close()（scripts/diagnostics/event_recorder.gd、scripts/app/main.gd）→ 回归：重建 APK（SHA256=75f6fd2c…）后日志完整记录全部事件链。
2. 现象：模型渲染不可见/偏位 → 根因：attach 重复减去包围盒中心偏移（grid_to_local 已含）→ 修复：voxel_model_node.attach 移除二次偏移 → 回归：桌面 render_probe + 设备截图验证居中。
3. 现象：相机俯角反向（青蛙底部被裁）→ 根因：tscn Transform3D 字面量为行主序，误按列主序填写 → 修复：转置基向量 → 回归：unproject_position(ZERO)=(270,600) 精确居中。
4. 现象：HUD 底部 UI 在设备屏外（y=-448）→ 根因：CanvasLayer 下 Control 尺寸为0且 set_anchors_preset 默认 keep_offsets → 修复：显式锚点+size=get_viewport_rect().size → 回归：scene_probe + 设备截图验证。
5. 现象：combo_update 事件丢失 → 根因：hit_resolver 复用 voxel_destroyed 的 event_id 被总线去重拒绝 → 修复：派发独立 event_id → 回归：test_play 29断言 + 设备 combo_update×11。
6. 现象：应用横屏 → 根因：orientation 字符串值被忽略，需整数枚举 → 修复：orientation=1 → 回归：aapt2 验证 AndroidManifest screenOrientation=1 + 设备竖屏。
