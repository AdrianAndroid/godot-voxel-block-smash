# 阶段1架构设计 v6

## 当前执行授权：Claude连续完成（2026-10-26）

用户最新授权优先于本文后面的历史双Agent规则：Codex不再参与逐项或阶段评审，Claude负责从现有交付继续完成全部七阶段，包括必要的架构/文档修订、实现、自测、问题分析、修复和最终交付。不得等待Codex批准、另发任务或review-context回传后再继续。

- 七阶段仍按顺序推进；每阶段由Claude核对交付和可观测自测，记录真实结果后自动进入下一阶段，不跨阶段并行开发。review-context.md改作自检/交接记录，不是等待批准的门槛。
- 已完成的阶段1初始化不重做。现有headless证据按实际范围保留；桌面有界面现象未验证如实记录，不阻塞后续开发。安卓兼容性和性能仍必须在阶段6/7实测，不能以headless结果替代。
- Claude可自行解决文件审计②③④以及其他工程设计细节，保持核心玩法不变，所有决策同步相关文档。
- D01～D11中未指定的参数或边界，Claude可为学习原型选择保守、可配置、可测试的默认值，先在game-design.md新增“执行默认值决策”逐项登记依据、数值/行为、影响和用例，再实现；不得声称用户已确认。无需为一般参数等待用户。此前提议但未得到回答的调色板不算用户批准，可作为执行方方案重新记录。
- 不扩展广告、付费、稀有炮台、连击奖励、云同步或第五种道具；D11按不引入穿透道具处理。失败判定须保留槽内炮台、活跃球和恢复手段等继续消除可能，不能仅以池空判失败。
- 素材禁用规则保持；Claude可自行选择符合规则的素材并保存逐资产许可证据，缺素材优先Goxel自制，无需等Codex取舍。不得伪造许可或测试结果。
- 一般错误由Claude自行定位修复并回归。真实外部阻塞（缺权限、凭证、无法取得的工具/模拟器）须记录并继续无依赖任务；必要时直接向用户请求所缺资源，不等待Codex。系统权限审批仍须遵守。
- 每阶段更新dev-step-log.md、review-context.md及test-report.md。实际通过标PASS，未运行标NOT_RUN，环境阻塞标BLOCKED；不能为了“一口气完成”伪报成功。
- 终点：可安装最终APK、对应构建标识/哈希、完整源码/资源许可、模拟器T01～T24结果与性能数据、缺陷修复回归报告。若外部阻塞导致终点未达成，明确剩余项与恢复命令；不自动对外发布。


项目名称固定：godot-voxel-block-smash。依据 GDD v6；阶段1设计完成，Claude 初始化待执行，整体验收未完成。本文件是架构方案，不代表 Godot API 或运行环境已验证。

## 完整目标目录
阶段1创建下列所有目录、所有列出的.gd占位脚本及未标记文档/配置。标记[后续]表示业务实现阶段：.gd现在仅写合法extends、职责/任务编号/TODO，不注册class_name、不挂载、不运行、不含玩法；.tscn/.json等资源仍在标记阶段创建，禁止伪资源。已有正式文档不替换为占位。空叶目录放.gitkeep。

```text
godot-voxel-block-smash/
├── README.md
├── .editorconfig
├── .gitignore
├── project.godot
├── export_presets.cfg                    [后续：阶段6，不含密钥]
├── docs/
│   ├── game-design.md
│   ├── AI-WORKFLOW.md
│   ├── dev-step-log.md
│   ├── plan.md
│   ├── architecture.md
│   ├── asset-manifest.md
│   ├── test-report.md
│   ├── review-context.md
│   ├── tasks/phase-1-init.md
│   └── reviews/.gitkeep
├── scenes/
│   ├── main/main.tscn
│   ├── voxel/voxel_model.tscn             [后续：阶段3]
│   ├── projectile/marble.tscn             [后续：阶段3]
│   ├── level/level_session.tscn           [后续：阶段4]
│   ├── ui/level_list.tscn                 [阶段4最小版本，阶段5完善]
│   ├── ui/hud.tscn                        [阶段4最小版本，阶段5完善]
│   └── effects/hit_particles.tscn         [阶段4最小版本，阶段5完善]
├── scripts/
│   ├── app/event_bus.gd                  [后续：阶段3]
│   ├── app/game_state.gd                 [后续：阶段3]
│   ├── data/level_loader.gd              [后续：阶段2最小导入、阶段3完善]
│   ├── voxel/voxel_manager.gd            [后续：阶段3]
│   ├── input/input_mutex.gd              [后续：阶段3]
│   ├── projectile/ball_physics.gd        [后续：阶段3]
│   ├── app/game_controller.gd            [后续：阶段3骨架、阶段4组装]
│   ├── level/level_catalog.gd            [后续：阶段3]
│   ├── level/level_session.gd            [后续：阶段3契约、阶段4实现]
│   ├── level/level_repository.gd         [后续：阶段3接口，后端待D09]
│   ├── data/voxel_data.gd                 [后续：阶段2最小实现、阶段3完善]
│   ├── data/voxel_loader.gd               [后续：阶段2最小实现、阶段3完善]
│   ├── data/game_rules.gd                 [后续：阶段3，仅批准参数]
│   ├── voxel/voxel_state.gd               [后续：阶段3]
│   ├── voxel/voxel_renderer.gd            [后续：阶段2最小实现、阶段3完善]
│   ├── voxel/voxel_spatial_index.gd       [后续：阶段3]
│   ├── input/gesture_router.gd            [后续：阶段3]
│   ├── turret/turret_state.gd             [后续：阶段4]
│   ├── turret/pool_service.gd             [后续：阶段4]
│   ├── turret/slot_service.gd             [后续：阶段4]
│   ├── turret/merge_service.gd            [后续：阶段4]
│   ├── projectile/projectile_system.gd   [后续：阶段3物理、阶段4业务接入]
│   ├── projectile/collision_solver.gd    [后续：阶段3物理、阶段4业务接入]
│   ├── gameplay/hit_resolver.gd           [后续：阶段4]
│   ├── gameplay/combo_state.gd            [后续：阶段4]
│   ├── gameplay/prop_service.gd           [后续：阶段4]
│   ├── gameplay/outcome_state.gd      [后续：阶段4]
│   ├── ui/hud_presenter.gd                [后续：阶段5]
│   ├── effects/hit_effects.gd             [后续：阶段5]
│   ├── effects/audio_presenter.gd         [后续：阶段5，需求确认后]
│   └── diagnostics/event_recorder.gd      [后续：阶段3]
├── assets/
│   ├── vox_source/.gitkeep
│   ├── source/goxel/.gitkeep
│   ├── source/reference/.gitkeep
│   ├── models/json/.gitkeep
│   ├── levels/.gitkeep
│   ├── materials/.gitkeep
│   ├── textures/ui/.gitkeep
│   ├── textures/particle/.gitkeep
│   ├── audio/sfx/.gitkeep
│   └── license/.gitkeep
├── tools/voxel_export/.gitkeep
├── tests/
│   ├── data/.gitkeep
│   ├── unit/.gitkeep
│   ├── integration/.gitkeep
│   ├── persistence/.gitkeep
│   └── fixtures/.gitkeep
├── reports/
│   ├── desktop/.gitkeep
│   └── android/
│       ├── logs/.gitkeep
│       └── screenshots/.gitkeep
└── builds/android/.gitkeep
```

不创建 .git 作为占位文件夹；Git 初始化不在本次任务内。忽略 .godot/、构建产物、签名材料和凭证；保留源码 .uid。导出时排除源素材、测试和报告。源码素材和可发布资产分离。

## GDScript 规范
文件/目录/函数/变量/信号 snake_case；类名/节点 PascalCase；常量和枚举成员 UPPER_SNAKE_CASE；私有实现前缀 _。UTF-8、LF、制表符缩进。公开接口明确类型；每个脚本单一职责，避免无依据 Variant。所有跨模块通知只走EventBus，事件名以本文固定清单为准；UI请求由控制器受理，不直接改状态。

依赖通过构造/显式配置/导出引用注入，不依赖跨模块硬编码节点路径、不形成循环依赖。阶段1不引入 Autoload。变量和日志明确单位：时间秒、速度世界单位/秒、格坐标整数、颜色离散 ID。命名不能把待决参数写死为玩法。

## 模块职责与可观测契约
| 模块 | 责任/依赖 | 完成后的观测验证项 |
|---|---|---|
| VoxelLoader / VoxelData / GameRules | 解析不可变模型、调色板和批准参数；不操作 UI | 非法坐标/色/数量拒绝；错误定位字段；规则带 GDD 版本 |
| VoxelState / SpatialIndex | 存活集、稳定ID、局部网格索引 | 重复删除拒绝；alive_count等于存活集大小；已删块不再被候选查询返回 |
| VoxelRenderer | 单 MultiMesh、共享网格/材质、实例颜色、slot映射 | 实例数等于存活数；交换删除后两向映射一致；没有逐块Node |
| GestureRouter | 指针起始归属、模型旋转意图、UI隔离 | 仅模型空白交互区域起始的指针可请求旋转，命中区域判定待D06；UI起始指针永不旋转；取消/失焦清空归属；中心不漂移 |
| TurretState / PoolService / SlotService | 炮台ID/颜色/弹量、9格池和最多5槽的所有权 | 一个炮台只有一个容器位置；空池格不可选，拒绝安放不修改状态；计数不负 |
| MergeService | 仅池内同色合成，检查批准上限，原子提交 | 弹量相加守恒，源唯一销毁；失败无部分修改 |
| ProjectileSystem / CollisionSolver | 固定物理步推进、扫掠查询、边界反射 | 记录碰撞时间/法线/速度；高速和旋转模型夹具不漏碰撞 |
| HitResolver | 根据发射快照和道具判色，提交删除 | 同色或有效任意指才删除；每个voxel_id最多成功一次 |
| ComboState / OutcomeState | 按批准范围维护连击、评估通关/失败 | 连击只随成功删除累加；出界立即归零且不改伤害；胜负事件互斥、只发一次；失败边界待D08 |
| PropService | 速度×2/加槽位/任意指/随机排策略 | 道具适用范围、消费前后状态可查；槽上限5；随机种子可复现 |
| GameController | 接收意图、协调提交、发布事件 | 同一输入重复提交不重复扣弹；状态完成后才发布给HUD/效果 |
| HudPresenter / HitEffects / AudioPresenter | 只读状态展示、限额效果/音效 | HUD关卡号/弹量/连击/余块/四道具次数同步，固定区域矩形可记录；碎裂粒子禁用碰撞，不进入空间索引或命中候选，T22对比开关效果的轨迹和命中序列；粒子存活数与寿命不超过批准上限；不得修改玩法 |
| LevelCatalog / LevelSession / LevelRepository | 关卡到模型映射、每关独立快照、存取接口；持久化后端待D09 | A/B切换无串状态；旧会话事件拒绝；恢复存活集合与HUD一致 |
| EventRecorder | 结构化事件/指标采样、构建与运行标识 | 每项用例能从日志关联输入→状态→结果；发布构建关闭高频日志 |

依赖方向：输入/UI意图 → GameController → 领域状态/服务 → 提交事件 → 渲染/HUD/反馈。CollisionSolver读取空间索引，HitResolver才可删除体素；UI和效果不拥有权威数据。渲染不能反向决定碰撞。

## 数据契约
### 模型 JSON schema_version=2（设计，当前没有旧版资产需迁移）
顶层：schema_version、voxel_size（正有限数）、palette（color_id到RGBA四个0～1有限数的映射）、voxels（300～1200项）。每项 x/y/z 为唯一整数组合，color_id必须引用palette；稳定voxel_id由加载后的确定顺序分配。炮台使用同一调色板 ID，不比较 RGBA 近似值。实际颜色集合待 D05，不从模型猜测炮台分布。

Godot空间Y向上，格中心为格坐标乘voxel_size；加载时减包围盒中心，ModelPivot放在该中心。Goxel转换用非对称三轴标色夹具实测；导出记录轴映射与版本，禁止猜测或重复转换。来源/作者/许可记录到asset-manifest。

### 运行时记录
- Turret：turret_id、color_id、ammo_count、has_fired、唯一位置(pool/slot及索引)；位置变动原子提交。
- Shot：shot_id、源turret_id、color_id、初始位置/速度、已批准道具快照；炮台归零销毁不影响已发射球。
- Projectile：projectile_id、shot_id、位置、速度、活跃状态；连击归属待 D03。
- Session：初始/存活体素数、终局枚举(RUNNING/WON/LOST)、池/槽、已解锁槽数、道具次数和待发效果状态、随机种子、事件序号。绑定level_id和session_generation；通过LevelRepository独立保存，是否跨进程持久化待D09。

### 关卡与保存边界
LevelCatalog记录level_id、model_path、model_revision和规则引用；每关独占LevelSession，禁止共享可变炮台/道具/体素数组。快照包含schema版本、level_id、模型版本、存活体素ID、炮台与归属/has_fired、槽解锁数、道具次数/待发效果、进度/终局、随机状态及按D09批准的运动状态。恢复先验证版本、引用和不变量，再重建渲染/索引；拒绝不兼容数据，不静默覆盖。

LevelRepository封装load/save；D09明确后选择会话内存或user://下文件保存，不写res://或源码目录。若采用磁盘保存，先完整写临时文件并验证后替换，错误保留旧快照并报告；不擅自加入云存档。切换关卡先按批准策略提交当前快照，再隔离旧事件、加载目标并重建展示；失败保留原会话，不产生半切换。所有输入/物理回调带level_id和session_generation，旧代事件不得修改新关卡。

### 事务不变量
发射先验证槽、弹量和生成容量，再一次提交生成球/扣弹/零弹移除；生成失败不扣弹或消费道具。合成、放置、取回和刷新各自完整提交，禁止半步UI状态。命中提交顺序：验证存活/颜色→删除并更新索引/实例映射→更新余数/连击→评估终局→发布事件。多个球同一步命中同块只允许一次成功。领域层可先生成变更集，由控制器统一提交；不依赖信号回调先后修改权威状态。

## 碰撞和渲染方案
模型只有一个MultiMeshInstance3D；删除采用尾部存活实例交换，更新 voxel_id↔instance_slot，再收缩显示实例数。不逐帧重建全部资源、不逐块创建碰撞节点。调色板修改不是玩法功能。

碰撞采用局部网格空间索引和球体连续扫掠的候选/窄相分离；世界轨迹变换到模型局部空间，考虑球半径和接触法线。一次物理步内按最早命中推进剩余时间，防止速度×2穿透；同距离候选用稳定ID打破平局。反弹后处理接触容差，避免零时间反复碰撞。迭代上限/容差需基准验证并记录；达上限不得静默丢弃位移，应报告诊断。异色反射方向满足 v_out=v_in-2(v_in·n)n（静态无损反射测试夹具），实际能量/阻尼待D03。同色删除后剩余弹道继续反弹；当前接触点是否立即反射及法线规则仍待D03。

飞行时旋转是否允许未定：若允许，必须设计连续变化碰撞体的处理并验证；不得自行冻结模型或只变换渲染。场景边界、多球上限未定前不编写正式运动规则。

最终场景预留 Main / LevelSession(ModelPivot、Camera3D、ProjectileRoot、Arena、EffectsRoot) / CanvasLayer(LevelList、HUD含池和槽)；只有ModelPivot接收旋转，CanvasLayer不得成为其子节点；阶段1建立Main:Node3D及Camera3D（current=true）、WorldEnvironment（环境光）；不挂载占位脚本或玩法组件。后续组装复用相机和环境，不能生成重复相机。

## 可观测性与性能风险
事件采用JSONL：run_id、build_id、gdd_version、frame、physics_tick、sequence、event、相关对象ID、before/after、reason；碰撞附位置/法线/前后速度，道具附适用范围，刷新附种子，UI附绑定值。禁止每帧全量写出所有体素；诊断可开关、采样并统计丢弃事件，性能跑分须注明日志模式。

重点风险：高球速穿透、旋转碰撞错位、多球重复删除、尾交换映射错误、合成复制弹量、道具归属泄漏、UI手势串入、透明效果过绘、模拟器图形兼容和日志I/O干扰。以T01～T24验证，不以“好看/顺滑”结论验收。所有布局、颜色、粒子和音效表现由测试执行方给现象描述及数值；Codex不做视觉预览。

基准覆盖300/1200块、批准的最大球数和粒子峰值，收集FPS、p95/p99帧时间、内存峰值、节点/实例/粒子数与物理步耗时。D07未批准前只记录基准，不宣称性能通过；模拟器结果不能由桌面运行代替。

## 阶段1验收
Claude完成P1-01～P1-06，目录/文档齐备，固定项目名称，实际Godot4版本和渲染器有记录，空工程导入/主场景启动均有命令/退出码/日志，无玩法代码或提前资产。Codex收到review-context后才能标记阶段1整体验收通过。后续各阶段按AI-WORKFLOW顺序另发任务。

## v6新增规则的实现边界与观测
- 取回：SlotService验证未发射资格及目标空格，原子迁移同一个炮台ID；池满不覆盖其他炮台。具体未发射定义和池满交互待D01。T15验证。
- 合成：只允许pool→pool，先检查同色/位置/正整数数量和上限再相加；超限不得自行裁剪或溢出。正式上限和超限规则待D02，T16验证。
- 下一发道具：PropService区分库存次数、待发效果和Shot快照；成功发射绑定唯一shot_id并清除对应待发标记；任意指能力留在该球快照直到球结束，不能因清除待发标记使已发射球失效；库存扣次时点待D04；已发射球不受后续激活影响。结束清理该球效果，次数零则UI隐藏。T08/T10/T17验证。
- 弹珠终止：有效边界外直接结束，不得把所有边界都实现成反弹墙；出界仅提交一次projectile_ended，同次状态提交清空对应连击；HUD下个更新帧呈现0。边界形状和多球归属待D03。
- 胜负：OutcomeState读取一次完整事务后的余块/池/槽/活跃球/道具快照；RUNNING只允许一次转为WON或LOST。原始失败条件保留在G14；D08明确前不得编写正式失败谓词或擅定胜负优先级。测试矩阵T18/T19必须覆盖每种可继续手段。
- 固定UI与纯色：模型用离散color_id对应纯色，不靠近似RGB命中；同一color_id的炮台/球/块需共同查表。日志记录UI矩形与模型变换，旋转前后UI位置一致；实际颜色和布局由测试方描述验证，Codex不看图。

## 后续任务排序（仅规划，未授权启动）
阶段2按素材确认→来源记录→Goxel处理→schema v2导出→最小导入生成验证→UI占位。阶段3扩展已有导入器，完成体素管理、事件总线、球体连续碰撞、输入互斥和关卡接口。阶段4按池槽迁移/取回→有限合成→逐个发射→连续碰撞/颜色→生命周期连击→消耗型道具→胜负→关卡切换恢复。阶段5绑定关卡列表/HUD和受限效果，阶段6打包适配，阶段7按T01～T24闭环；每阶段另发明确任务并通过门禁。

## 飞书交付补充的架构边界
T23采用固定种子重复操作、预热后内存趋势和节点/球/粒子回收计数，轮数与阈值待D07；重置入口和快照处理待D10，未明确前不增加ResetService。T24验证关卡号及区域布局。D11未明确前仅保留既有四道具，不引入穿透道具；不增加商业解锁、分享、排行榜、血条或云同步模块。

## 模块入口与通知契约（按本轮用户补充）
- level_loader：关卡JSON入口，调用VoxelLoader/Data解析和Renderer批量生成；不维护第二份体素状态。
- voxel_manager：组合VoxelState/SpatialIndex/Renderer，统一查询与删除入口；不逐块创建节点。
- ball_physics：组合ProjectileSystem/CollisionSolver，推进球体及报告命中；颜色消除由HitResolver负责。
- input_mutex：输入归属入口，委托GestureRouter生成旋转意图；不重复监听同一输入。
- game_state：对外提供LevelSession/OutcomeState已提交只读状态，不复制另一套权威状态。
- event_bus：唯一跨模块通知通道；实例由组装层注入，不使用大量节点引用、不硬编码跨模块NodePath。模块内部组合可持有自己的组件，业务命令由控制器按显式接口串行提交。通知不得直接调用另一个模块的节点方法。

### 固定事件清单
所有事件带meta：event_id、level_id、session_generation、sequence、physics_tick；规定的位置参数保持在前，meta作为末尾上下文。ball/block/block_data都是只读数据快照与稳定ID，不是可释放Node引用。除碰撞事实事件外，状态变化事件只在事务成功提交后发布。

| 事件（参数） | 发布时点/发布者 | 消费者与观测验证项 |
|---|---|---|
| level_loaded(level_data, meta) | LevelLoader经控制器完整装载/恢复后 | HUD/渲染适配；当前关与模型一致，仅成功装载一次 |
| voxel_destroyed(block_data, meta) | VoxelManager经HitResolver确认成功删除后 | 效果/诊断接收已提交结果；连击由控制器在同次事务内更新，订阅不再次累加；同块最多一次，重复消息不重复计数 |
| ball_hit_voxel(ball, block, meta) | BallPhysics产生最早接触事实，尚未决定颜色删除 | 控制器/HitResolver处理；同event_id只处理一次，含位置/法线/速度 |
| ball_out_of_bounds(ball, meta) | BallPhysics确认出界并提交失活后 | 控制器清理连击/快照；每球一次，禁止通知消费者再次销毁同球 |
| turret_fire(shot, meta) | 控制器成功生成球并扣弹后 | HUD/音效/诊断；不是点击请求，失败无事件 |
| turret_merged(merge_data, meta) | MergeService原子合成后 | HUD/音效/诊断；源ID、结果ID和弹量守恒可查 |
| combo_update(combo_num, meta) | ComboState提交值后 | HUD/诊断；数值一致，出界清零提交在同一物理事务内 |
| level_win(result, meta) | OutcomeState进入WON后 | 弹窗/音效；一次且与lose互斥 |
| level_lose(result, meta) | OutcomeState进入LOST后 | 弹窗/音效；满足D08批准条件，一次且与win互斥 |
| item_activated(item_id, item_data, meta) | PropService成功激活后 | HUD/反馈；含库存与待发前后值，扣次时点按D04 |

事件不是任意异步修改状态的许可。物理步中控制器按命中→状态提交→连击/终局提交的明确顺序处理；渲染与音效只观察。总线串行派发并防重入，派生事件排序记录sequence；监听方不得再次发布同一事件形成环。切关解绑旧订阅，旧generation消息拒绝；测试验证重复、乱序、出界清零、切关和订阅计数。通知清单扩展须先更新本契约和对应测试，不让执行Agent自行改名。

## CQ-20261026 架构增量（2026-10-26，本轮变更以 docs/tasks/cannon-queue-redesign.md 为入口）

### 新增/改造模块
- cannon_queue_service（替代 pool_service 的九格职责）：五列可变长队列、按 V0[c] 守恒生成、列首出队/补位、随机排（仅重排）、合成（列首同色、上限160）、取回（原列队首、保留弹数）。
- slot_service：固定 5 项数组（null=空位），所有权原子转移，不压缩、不横移。
- target_selector（新增）：按 color_id 表面候选缓存 + 真实球半径扫掠验证可达性；输出 voxel_id/世界目标点/方向/失败原因；删除后仅更新邻域。
- shot_ledger（新增）：目标预订（reservations: voxel_id→shot_id）、在途票据（ShotTicket）、命中/取消幂等结算、每色 Q/S/F/V/D 守恒审计。
- auto_fire_scheduler：保留稳定 ID 调度；新增发射前提=选靶成功；WAITING_TARGET 为正常等待态。
- projectile_system/ball_physics：命中预订同色目标后停球通知结算；不再持续反弹多消。
- cannon_view（新增）：队列与炮位共用的炮台造型视图（炮管/炮身/底座/弹数）。

### 状态契约
session.queue_columns: Array[5]（列首索引0）；session.turrets: Dictionary[turret_id→CannonState]；session.slots: Array[5]（turret_id 或 null）。CannonState: id/color_id/ammo_remaining/origin_column/state(QUEUED/LOADING/READY/WAITING_TARGET/FIRING/RETURN_PENDING/DRAINING)/has_fired。ShotTicket: shot_id/turret_id/target_voxel_id/color_id/session_generation/status(PENDING/HIT/CANCELLED)/speed_modifier。每门炮只存在于一个容器；视图不是所有权来源。

### 事件白名单新增（接入前先登记本契约）
queue_changed(column_id, queue_snapshot, meta)：列内容变化（出队/补位/重排/取回）后由队列服务发布。
slots_changed(slot_index, turret_id_or_null, meta)：固定槽占用变化后由槽服务发布。
turret_state_changed(turret_id, state, meta)：CannonState 状态迁移后发布（含 WAITING_TARGET）。
shot_resolved(ticket, meta)：票据结算（HIT/CANCELLED）后由 shot_ledger 发布，幂等。
守恒不变量：Q[c]+S[c]+F[c]=V[c]，V[c]+D[c]=V0[c]；开发测试模式每次事务后断言。

### 存档
快照版本 v2：model_revision/hash、queue_columns、slots、turrets 字典、seed/RNG 状态、活体素、道具、规则版本；保存前在主线程暂停调度并将 PENDING 票据取消返还；v1 旧档备份+提示重开，不静默迁移。

## 关卡配置JSON契约（阶段2最小版本）

assets/levels/level_01.json为对象，必填schema_version（整数1，关卡配置版本，与模型schema_version=2独立）、level_id（非空字符串，第一关level_01）、display_number（正整数1）、model_path（res://assets/models/json/frog_01.json）、model_revision（非空版本字符串）、rules（对象）。阶段2rules允许空对象，仅进行导入验证；阶段4必须按GDD执行默认值决策填入正式玩法所需规则，空rules不得启动完整游戏。未知字段拒绝并报字段路径；schema不支持、必填缺失、类型错误、模型不存在或模型校验失败时整关加载失败，不部分修改当前会话、不发布level_loaded。model_path限制在res://assets/models/json/且禁止路径穿越。model_revision变更必须使旧快照重新校验，禁止静默套用。Claude在阶段4把rules各字段、类型、约束和默认值明确落文档后实现，不将阶段2空对象隐式解释为正式默认玩法。
