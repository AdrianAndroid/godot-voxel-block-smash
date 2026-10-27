# 教程生成提示词：从零用 Godot 开发 3D 体素打砖块游戏

> 用途：交给 AI（或自己）按此提示词生成一套完整教程。
> 教程蓝本：本仓库 godot-voxel-block-smash（git 003648e），一个真实完成并验收过的项目。

---

## 一、角色与目标

你是一位既懂 Godot 4.x 引擎、又有真实项目交付经验的游戏开发布道者。
基于本仓库的真实实现，写一套**从零开始**的教程，带读者用 Godot 4.7.2 开发出一个
"3D 体素模型 + 炮台连发消除"的完整可玩、可测试、可打包的游戏。

教程的核心价值不是复述 API，而是回答三个问题：
1. **怎么做**（具体节点怎么加、代码怎么写、参数怎么配）；
2. **为什么这么做**（每个架构/性能/测试决策背后的理由和替代方案）；
3. **怎么验证做对了**（测试与验收，而不是"看起来能跑"）。

## 二、目标读者

- 会基本编程（任何语言），**没用过 Godot** 或只跟着示例做过 2D 小游戏。
- 想做一个完整 3D 小游戏并学会工程化方法（测试、性能、打包）的人。
- 环境假设：macOS（教程主平台），Godot 4.7.2，中文读者。

## 三、产出形式

- 输出到 `docs/tutorial/`，一个 `README.md` 总目录 + 每章一个 markdown 文件（`01-xxx.md` 起编号）。
- 全文中文；代码块用 GDScript/INI/Bash，附行内注释。
- 每章统一结构：**本章目标 → 概念讲解（为什么）→ 动手步骤（怎么做，含节点树/代码/配置截图位）→ 踩坑记录（真实发生的坑）→ 验证方法（怎么确认做对了）→ 小结**。
- 章节末尾给"本章完成后你应该能看到什么"的可检查状态。

## 四、章节大纲（必须全部覆盖，顺序即学习路径）

### 第 1 章 Godot 从零起步
- 安装 4.7.2、编辑器五大面板（场景/文件系统/检查器/节点/输出）的心智模型。
- 核心概念：节点(Node)=积木、场景(Scene)=可复用的节点树、脚本挂在节点上、信号(Signal)=节点间通信。
- 用本项目的 `scenes/main/main.tscn` 作为"最终你要建出的场景树"预览，建立全局认识。

### 第 2 章 项目初始化与游戏设计
- 新建工程；`project.godot` 关键配置逐行讲：540×1200 竖屏（window_width/height_override + resizable=false）、`stretch=canvas_items/keep`、为什么选 `gl_compatibility` 渲染器（老集显 UHD 630 兼容性）。
- 游戏设计一章讲清规则：体素模型 4105 块、按颜色消除、炮台队列 3 槽、一发一块、同色命中、全清获胜、≤300 秒节奏目标。对照 `docs/game-design.md`。

### 第 3 章 数据层：体素模型与配置
- 体素 JSON 格式（`assets/models/json/frog_02.json`）怎么组织；`voxel_loader/voxel_data` 怎么读。
- `game_rules.gd`：为什么所有可调参数集中一处（ball_speed、auto_fire_interval、max_in_flight、auto_rot_deg_per_sec…），配表驱动而不是写死。

### 第 4 章 渲染 4105 个方块：性能第一课
- 先写"朴素版"（每块一个 MeshInstance3D），实测帧率崩塌，引出为什么不行。
- 再看真实方案 `voxel_renderer.gd`：合并/实例化渲染的思路，renderer_instances 为什么必须压到个位数。
- 销毁方块时渲染与数据（state/index/计数）怎么保持同步——这是后面"守恒审计"的地基。

### 第 5 章 搭主场景：节点是怎么一个个加上去的
- 对照 `scenes/main/main.tscn` 逐节点讲解：每层为什么存在、挂什么脚本（`main.gd` 协调层）。
- 相机/灯光/俯视视角的选择；voxel_model.tscn 子场景怎么嵌。
- 讲"组合优于继承"在 Godot 里的落地方式。

### 第 6 章 玩法核心循环：炮台、队列、发射
- 炮台队列服务 `cannon_queue_service.gd`、槽位 `slot_service.gd`、合成 `merge_service.gd`：3 槽队列的状态机设计，为什么用服务类而不是把逻辑塞场景脚本。
- 发射链路：`fire_geometry.gd`（屏幕炮口→格空间原点）→ `shot_ledger.gd`（预订票据：为什么"目标被多人抢"需要票据而不是简单的目标指针）→ `projectile_system.gd`。

### 第 7 章 弹道：让子弹在模型旋转时仍然命中（本项目最难的坑）
- 问题引入：世界坐标出膛方向只算一次，模型一转子弹就脱靶（mismatch 根源）。
- 解法演进：局部空间锁定弹道（球记录 local_pos/local_dir，步进在格空间扫掠，事件派发时才用当前矩阵转世界）。对照 `ball_physics.gd` / `projectile_system.gd`。
- 讲解扫掠碰撞（连续 vs 离散）、`collision_solver.gd` 分工。
- 这一章是"为什么"密度最高的一章，要讲透坐标系选择。

### 第 8 章 选靶 AI：炮台怎么自己找目标
- `target_selector.gd`：暴露面多点扫掠契约（aim_grid_point/face_id/origin_used/geometry_version）。
- 性能设计：3ms→6ms 步预算、分片断点续扫（scan_pending 不是错误是切片）、负缓存及其失效条件（gen+tver+TTL 0.1s）。
- 真实 bug 复盘：墙钟/模拟钟混域导致负缓存永久服务（age 为负）——一节完整的"时钟域"教学案例。
- 可审计性：等待原因（waiting_target/no_reachable_target/revalidate_failed）全部计数可查，绝不"穿透异色块或改数字伪造命中"。

### 第 9 章 交互：拖动旋转 + 自动旋转
- `gesture_router.gd` 只报原始位移、`input_mutex.gd` 输入互斥；控制器唯一持有 yaw/pitch（B=Rx(pitch)×Ry(yaw)），pitch±60° 满幅钳制。
- 自动旋转 8°/s：拖动 hold 停转、松手 0.2s 渐入从当前姿态续转、不跳角不补转不清俯仰（UX02/UX04 的验收语义）。
- `voxel_model_node.set_orientation` 唯一写入口 + transform_version 的用途。

### 第 10 章 状态机细节：上位 LOADING 与耗尽 RETIRING
- 上位为什么要有 0.28s LOADING（完整炮飞过场、到位才开火、上位中暂停/重开的正确处理）。
- 耗尽退场 DRAINING→RETIRING：等在途子弹结算完再收缩淡出 0.20s；零弹取回=退场不回队列。
- 对照 `test_loading_retire.gd` 讲"状态机怎么测"。

### 第 11 章 性能工程实战（全流程方法论）
- 方法论：先测量后优化，禁止猜。工具：`perf_monitor.gd`/`perf_probe.gd` 打点、perf_log.jsonl 采样、外部 `ps` 采 RSS（为什么 Godot 导出版 get_static_memory_usage 返回 0）。
- 案例 1：HUD 每事件全量刷新 → `_refresh_dirty` 按帧合并（≤1 次/帧）。
- 案例 2：弹球数组只增不删 → hit/ended 事件派发后回收 + 有界日志。
- 案例 3：选靶 3ms 预算漏检 continue 路径 → 预算检查移到迭代顶部。
- 案例 4：p95 尖峰归因（开局建模/首扫 vs 持续卡顿的区别）。
- 验收线怎么定：FPS≥30、p95≤50ms、RSS≤512MB 且 60s 增长≤10%，以及为什么>300s 一局算节奏 FAIL。

### 第 12 章 测试体系：从单元测试到真机验收
- Godot headless 测试的组织（21 个套件怎么跑：`godot --headless --path . -s tests/run_tests.gd` 形式，以仓库实际入口为准）。
- 分层：unit（纯逻辑）→ integration（真实控制器+夹具）→ 回放验收（`replay_runner.gd` 驱动真实 .app，解路径 JSON 实时 pacing，13 连 WON 证据）。
- 测试隔离红线：绝不碰真实存档（`user://test_saves/<name>_<pid>`）。
- 守恒审计（V+D=V0、fires==hits、0 取消）作为"没作弊"的机器证明。
- 诚实验收文化：NOT_RUN 就写 NOT_RUN，不用旧报告冒充本轮结果；单元测试绿≠手感好。

### 第 13 章 打包发布与验收闭环
- macOS export_presets 配置、命令行导出、SHA256 构建标识、build-info 记录（机型/CPU/GPU/提交/dirty）。
- 用回放 + 关键帧/录像做最终验收；性能数据怎么读。
- 常见工具坑：Godot stdout 块缓冲、screencapture 跨 Space 失败、旧实例污染 perf_log。

## 五、写作规则（硬性）

1. **真实性优先**：教程里每一段代码、路径、参数都必须与本仓库（003648e）一致；引用具体实现时给出 `文件:行号`。需要简化代码做教学示例时，明确标注"教学简化版，完整实现见 xx 文件"。
2. **命令必须可复现**：所有 godot/git/python 命令给出完整形式，读者复制即可跑。
3. **讲演进而非只讲结果**：性能与弹道等章节必须呈现"朴素做法→实测出问题→定位→修复→验收数据"的完整链条，引用真实数据（如 13 连 WON 169.4~190.9s、FPS min42/avg81.6、RSS 338→339MB、fire_attempt 17195/hit 4105/0 取消）。
4. **参数给真实值与调参历程**：如 ball_speed 40→100、auto_fire_interval 0.25→0.10、扫掠预算 3→6ms，说明每次改动的原因和验证方式。
5. **每章篇幅** 2000~4000 字（不含代码）；总篇幅 3~5 万字。宁深勿泛：宁可合并小节也不写"这里读者自行探索"式的水段。
6. **不泄露反作弊机制的内部细节到可被滥用的程度**：讲测试红线（不伪造命中/不改计数/不用计时删块冒充通关）作为工程伦理，但不需要逐行展开审计实现。
7. **截图占位**：需要截图处用 `> 📷 截图：xxx（建议来源：reports/desktop/ux/keyframes/…）` 占位并注明建议素材。
8. **术语表**：第 1 章给出 GDScript/节点/场景/信号/Autoload 等最小术语表；后文术语首次出现括注英文。

## 六、验收标准（教程本身怎么算写完）

- 13 章齐全，每章含五段式结构，章节间有"上一章/下一章"链接。
- 一名没用过 Godot 的读者按教程能做到：跑出空场景（第 2 章末）→ 看到体素模型渲染（第 4 章末）→ 手动发射消除方块（第 6 章末）→ 自动连发+旋转（第 9 章末）→ 完整一局可通关（第 10 章末）→ 会跑测试（第 12 章末）→ 打出 macOS 包（第 13 章末）。
- 抽查 10 处代码引用，file:line 全部真实存在。
- 所有验收数据与 `reports/desktop/ux/ux-acceptance.md`、`reports/desktop/fm/fm-matrix.md` 一致，不虚构。
- README.md 含：教程定位、读者画像、章节索引、预计学习时长、所需环境清单。
