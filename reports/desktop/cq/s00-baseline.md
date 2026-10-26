# CQ-20261026 / S00 基线、复现与文档契约

日期：2026-10-26（Asia/Shanghai）　执行人：Claude

## 1. 基线清单（不撤销他人工作）

- git HEAD：`9c0025b77cb2d9a74505ad0c802b0aef7f13edc9`（设计基线提交），工作区 dirty。
- 未提交改动：16 个修改文件 + 6 个未跟踪文件，全部为上一轮"可玩性补齐 A→E"交付（auto_fire_scheduler / marble_presenter / game_controller / hud_presenter / main 重构等），本任务以其为基线，禁止 reset。完整清单：`reports/desktop/cq/git-baseline-diff.txt`。
- 环境：Godot 4.7.2.stable；Pixel 7a / Android 17 (API 37) / arm64-v8a / 1080×2400；已装 APK versionCode=2 versionName=0.2.0。详见 `reports/android/cq/env-baseline.txt`。
- 设备在线核实：`adb devices` → 35181JEHN08868 device（本轮验收只用真机，不用模拟器）。

## 2. 十二条现象复现结论

| # | 现象 | 复现结论 | 证据 |
|---|---|---|---|
| 1 | 手指方向反了 | **真实错误（已证实代码根因）**：`scripts/app/main.gd:176-180` 用本地欧拉角累加（`rotation.y += dx`、`rotation.x = clamp(rotation.x + dy)`），不随相机/当前朝向变换基，不同朝向下轴向翻转；方向符号需 S02 标记法实测定论 | cq_rot_before/after.png（右滑 480px 后白眼球质心 x 仅 +5px，未跟手右移） |
| 2 | 底部没有大炮 | **真实缺失素材**：池卡为纯色矩形+数字（截图可见绿/白/黄/深色块卡片），无炮管/炮身/底座造型 | px3_restart.png 底部九格 |
| 3 | 点击后没有大炮上炮位 | **旧流程如此**：需"点卡片→再点槽位"两次点击；与新需求"一次点击直接上位"冲突 | v1~v3 驱动均须成对 tap 池格+槽位 |
| 4 | 自动上位/同列上移 | **真实缺失**：无队列结构，无从列首出队与补位概念 | 代码无 queue 结构（pool_service 固定 9 格） |
| 5 | 五列、每列随机个数 | **真实缺失**：`POOL_SIZE=9` 固定 3×3 | pool_service.gd |
| 6 | 数字总和等于模型块数 | **真实偏差**：开局 9 炮 × 弹量 1~5 ≈ 22 发 vs 367 块，远低于块数（旧设计如此，数学上不可清空，见 D13） | level_01.json / D13 实测记录 |
| 7 | 青蛙块太少 | **确认**：frog_01 = 367 块（绿286/白56/黄17/深灰8） | test_auto_fire.gd 权重断言、event_log |
| 8 | 子弹未消块 | **已证实根因（规则层）**：①中心盲射——所有球射向模型中心，外壳被凿穿后形成隧道，球穿膛而过不再触块；②异色反弹陷阱——白/黄/深灰球对绿色主体 0 消除；证据：v1 无旋转 179 发仅毁 36 块（白球 238 次命中 0 删除）；v3 带旋转 194 发毁 149 块后第 10 轮起 69 发 0 删除（剩余 218：顶盖绿162+眼白31+黄17+深灰8，弹道穿过中空核心） | event_log_cq_baseline.jsonl（run_id 1792985373）、px3_v3_stall.png |
| 9 | 同色才自动发射 | **真实缺失**：auto_fire 有弹即发，不查同色可达目标 | auto_fire_scheduler.gd |
| 10 | 缺大炮素材 | 同 #2，队列与炮位均无素材 | 截图 |
| 11 | 青蛙太居中 | **确认**：模型视觉中心≈屏幕垂直中心，与炮位/队列争夺空间 | px3_restart.png |
| 12 | 颜色和总数一致 | **真实偏差**：无每色守恒台账；任意指异色消除直接违反每色守恒；池色加权随机而非按 V0 精确拆分 | pool_service.gd / GDD G10 |

### "发了不消"链路字段记录（S00 要求）

以 v3 会话（run_id 1792985373）事件流为准：炮色分布 fires={绿137,白42,深灰8,黄7}；命中 328 次；删除 destroys={绿124,白25}；发射起点=槽屏幕中心射线∩格空间 AABB 内移 0.1（main.gd `_resolve_fire_origin`）、方向=指向模型中心；world_from_grid=`global_transform * Transform3D(I, -center_offset)`；出界原因均为 `out_of_bounds`（格空间边界 half≈半宽+8）。卡死段（第10轮后）69 发 0 删：球经底部缺口进入中空腹腔、穿过中心隧道出界，或命中残余白/黄/深灰块异色反弹。根因=规则层"中心盲射+持续反弹多消"，非碰撞实现 bug——CQ 方案以同色选靶+一发一块替代。

## 3. 旧规则替代映射（S00 登记，GDD/架构已同步引用 CQ-20261026）

| 旧条款 | 旧内容 | CQ 替代 | 替代依据 |
|---|---|---|---|
| G02 | 从九宫格选炮安放；未发射可取回 | 五列列首点击直接上位；取回放宽为"无在途弹即可取回"（含已发射） | 任务 §2.1 |
| G03 | 3×3 炮台池、空位不可选 | 五列可变长队列，仅列首可点击 | 任务 §2.1 |
| G04 | 同色删一次、异色反弹不删（球继续飞） | 同色选靶才发射；一发只删一块即回收；误撞异色取消返还 | 任务 §2.2 |
| G07 | 持续反弹至出界、连击按球 | 命中即停球结算；连击=全局连续成功命中（1.5s 窗口） | 任务 §2.2 |
| G10 | 任意指=异色万能弹 | 改为"指定目标"（同色可达优先目标） | 任务 §2.4 |
| G11 | 随机排=重生成全新炮台 | 随机排=只重排五列现有炮台，不重造弹 | 任务 §2.4 |
| G14 | 失败真值表（池空+槽空+球0+shuffle0） | 仅可证明无恢复手段的死局判负；无同色目标≠失败 | 任务 S08/§2.3 |
| G15 | v1 存档格式 | v2 快照（模型 hash、五列、固定槽、票据结算后保存） | 任务 S09 |
| D02 | 合成上限99、点A点B | 显式合成模式、两列列首同色、上限160 | 任务 §2.4 |
| D03 | 中心盲射、反弹至多64次 | 同色选靶扫掠验证、命中即停 | 任务 §2.3/S05 |
| D05 | 弹量1~5均匀随机、加权色池 | 按 V0[c] 整数拆分（普通炮30~80发）、五列分配 | 任务 S03 |
| D08 | 失败真值表 | 同 G14 行 | 任务 S08 |
| D09 | 离开时弃置飞行球 | 保存前 PENDING 票据取消返还后快照 | 任务 S09 |
| 容量 | 300~1200 体素 | 目标 4000~5000、上限 6000 | 任务 S01 |
| 九宫格/中心盲射 | 3×3 固定池、射向模型中心 | 五列队列、同色可达选靶 | 任务 §2.1/§2.3 |

保留不变：事件总线唯一通知通道、单 MultiMesh 无逐块节点、CC0/自制素材规则、四道具清单（语义按 §2.4 调整）、G12 全清通关、竖屏。

## 4. 接口契约（S03~S05 实现依据，architecture.md 已同步）

```
session.queue_columns: Array[5]，每列 Array[turret_id]（索引0=列首，最靠近炮位）
session.turrets: Dictionary[turret_id -> CannonState]
session.slots: Array[5]，元素 turret_id 或 null（固定槽，不压缩）
CannonState: id, color_id, ammo_remaining, origin_column, state, has_fired
state: QUEUED / LOADING / READY / WAITING_TARGET / FIRING / RETURN_PENDING / DRAINING
ShotTicket: shot_id, turret_id, target_voxel_id, color_id, session_generation,
            status(PENDING/HIT/CANCELLED), speed_modifier
reservations: voxel_id -> shot_id
守恒：Q[c]+S[c]+F[c]=V[c]；V[c]+D[c]=V0[c]
```

新增事件（先入总线白名单再接入）：`queue_changed`、`slots_changed`、`turret_state_changed`、`shot_resolved`；`turret_fire` 继续承载成功创建球；`voxel_destroyed` 仅在删除提交后发布。

## 5. 报告目录与验收表

- 目录：`reports/desktop/cq/`（桌面/headless）、`reports/android/cq/`（真机）。
- 验收表：`reports/android/cq/cq-acceptance.md`，CQ-T01~T16 初始全部 NOT_RUN。

## 6. 结论

- "发射无消除"=**已证实根因**（中心盲射+异色反弹陷阱的规则层缺陷，设备事件流佐证），非待验证假设。
- 设备在线可用，无外部阻塞；进入 S01。
