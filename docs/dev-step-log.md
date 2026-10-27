# 开发步骤日志

只追加历史。当前状态以最近记录为准；设计完成、执行完成、验收通过分别记录。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：首先尝试读取三份基础文档，均不存在；检查项目目录为空。根据本轮用户要求建立 game-design.md 已知约束登记与缺失需求清单、AI-WORKFLOW.md 七阶段与权限/交接规范；完成 architecture.md 目标目录、GDScript 命名、模块职责与依赖、单 MultiMesh 和索引设计、手势隔离、自身中心旋转、数据契约、性能风险及阶段门禁设计；生成 docs/tasks/phase-1-init.md，拆分 P1-01 目录初始化、P1-02 工程说明与配置、P1-03 空 Godot 工程、P1-04 文档模板、P1-05 验证、P1-06 交接。未编写游戏脚本、未创建正式资源、未执行安卓测试。
【当前进度】：阶段1架构设计完成；工程目录/空工程初始化待 Claude 执行，阶段1整体验收尚未完成。阶段2～7未启动。完整 GDD 原文缺失，本次登记不能替代完整 GDD。
【下发给Claude的任务】：文档任务 P1-INIT 已准备，按 docs/tasks/phase-1-init.md 顺序执行 P1-01～P1-06，保留已有设计文档，只创建指定目录/占位模板/空工程，提交 review-context.md 与验证证据。本轮未通过调度器启动或发送给 Claude，不将任务文档准备记作 Agent 已执行。
【风险记录】：缺少完整玩法参数、素材需求与测试用例，相关后续工作不得猜测推进；Godot 小版本、Goxel 轴向与导出能力、安卓模拟器渲染兼容性未验证。单 MultiMesh 颜色与删除索引同步、旋转后的局部碰撞、UI 手势归属与重置事件残留需重点评审。OpenViking 经验检索返回 ModelNotOpen，未获得历史经验；未更改服务配置。
【下一步触发条件】：Claude 完成交付、review-context.md 上传后继续阶段1评审；需求方补全 game-design.md 的素材要求与玩法/性能测试条目后，按阶段门禁继续，不跳阶段。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：先读取三份基础文档，核实当前只有5份设计文档、无Godot工程与Git仓库。依据本轮明确规则更新game-design.md为GDD v2：场景三区、九宫格炮台、最多5槽、同色消除/异色反弹、弹量、合成、连击、四道具和清空通关；替代旧“无关卡”与冷却/重置假设，保留历史日志。定义G01～G12观测规则、D01～D07未决门禁、T01～T14测试用例。更新AI-WORKFLOW七阶段、固定职责、无视觉验收和证据闭环。重写architecture完整目标树、命名规范、模块/依赖、JSON v2调色板、事务不变量、单MultiMesh映射、连续碰撞方案和量化日志。重写P1-INIT-v2，逐项列出前置、步骤、交付、观测与失败处理；本轮仅修改设计文档，未越权创建工程或游戏实现。
【当前进度】：阶段1全部架构设计完成；工程目录/空工程/占位模板待Claude初始化，整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：docs/tasks/phase-1-init.md中的P1-01目录、P1-02说明配置、P1-03空Godot4工程、P1-04占位模板、P1-05验证、P1-06交接。验收观测：目录符合设计、固定名称、仅Main:Node3D、无提前玩法实现、两次Godot检查有命令/退出码/日志、未执行玩法标NOT_RUN、交接可追溯。任务已落实为可领取文档，未通过调度器启动Claude，不宣称正在执行。
【风险记录】：D01～D07包含合成位置、槽初值、球停止/多球/反射后轨迹、道具持续范围、素材/随机分布、UI与性能阈值等，禁止执行Agent擅定。重点风险为高速球穿透、旋转碰撞错位、多球重复删除、实例映射、弹量/道具事务和模拟器兼容；Godot版本与环境仍待验证。Codex不得以视觉想象验收，必须有行为/量化日志及现象文字。OpenViking经验检索返回ModelNotOpen，未使用历史经验、未修改服务配置。
【下一步触发条件】：Claude执行P1-INIT-v2并交付review-context.md及验证证据后，Codex对照GDD评审；有问题下发定界修复，无问题才标阶段1验收通过。阶段2正式素材任务须D05素材范围明确，不提前跨阶段。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：本轮接手先读三份基础文档及architecture.md、tasks/phase-1-init.md。核实阶段1全部设计（目标目录树、GDScript命名规范、模块职责/依赖、数据契约schema_version=2、碰撞与单MultiMesh渲染方案、观测与性能风险、阶段1验收门禁）已完成；用户本轮重复下发"从阶段1开始"指令，按工作流识别为已完成项，不重复设计、不重复生成任务文档。登记环境进展：Goxel 0.15.1已经Homebrew安装至/Applications并解除Gatekeeper拦截、进程启动验证通过（属阶段2工具链准备，不代表阶段2启动）。登记早前对话中的vox→JSON导出草案（tools/vox2json.py尚未落盘，且其格式与现行数据契约冲突，见风险）。
【当前进度】：阶段1设计完成；P1-INIT-v2（P1-01～P1-06）待Claude执行，阶段1整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：维持既有任务文档docs/tasks/phase-1-init.md不变，按P1-01目录→P1-02说明配置→P1-03空Godot4工程→P1-04文档模板→P1-05验证→P1-06交接顺序执行，验收观测项以该文档为准。实际调度状态：任务文档就绪，等待用户启动Claude执行会话，不宣称Agent正在执行。
【风险记录】：①数据契约冲突——早前对话草案JSON为逐块hex颜色字段，与architecture.md的schema_version=2（palette+color_id离散匹配，对应G04）不一致；裁定以architecture.md为准，vox2json.py归入阶段2任务并须按schema v2重写。②D01～D07未决项不变，禁止执行Agent擅定数值。③P1-03前置风险：本机Godot4可执行文件是否已安装未验证，缺失则按任务文档记BLOCKED不伪造。④Goxel 0.15.1的.vox导出轴向未经夹具实测，阶段2必须用非对称三轴标色夹具验证。⑤Codex无画面输入，一切验收依赖行为/量化日志与现象文字。
【下一步触发条件】：用户确认调度后，Claude执行P1-INIT-v2并交付review-context.md及验证证据；Codex对照GDD与任务观测项评审，通过才标阶段1验收通过，再按阶段门禁（D05素材范围）评估是否下发阶段2任务。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：先读取三份基础文档及既有架构和任务单，在已完成设计上增量更新而非重复开发。GDD升级v3，纳入独立纯色/精准匹配、模型自由3D旋转而UI固定、满槽拒绝、未发射炮台取回、逐个发射、仅池内有限合成、出界消失/停止清零且连击不加伤害、消耗型道具与下一发效果、本局永久槽解锁、失败条件、关卡列表及各关独立保存。扩展G01～G15、D01～D09、T01～T21。架构v3补齐关卡场景/脚本/资源/保存测试目录，定义LevelCatalog/LevelSession/LevelRepository、OutcomeState、has_fired、道具库存/待发/快照边界、切关隔离与恢复校验；保留schema_version=2模型契约及既有命名/单MultiMesh规范。更新七阶段评审内容和P1-INIT-v3初始化任务，所有子任务保留交付、观测和失败处理。
【当前进度】：阶段1针对最新需求的设计完成；工程初始化及整体验收仍待Claude交付；阶段2～7未启动。本轮只修改设计文档，未创建玩法实现或假称完成模拟器测试。
【下发给Claude的任务】：按docs/tasks/phase-1-init.md的P1-INIT-v3依次执行P1-01～P1-06：按更新目录建占位、创建说明配置、空Godot4工程、报告模板、执行导入/启动检查、提交review-context.md。观测新增level目录、assets/levels、tests/persistence齐备，测试模板列T01～T21且未运行标NOT_RUN；原有名称/空Main根/命令退出码证据要求不变。任务文档已就绪，未实际启动Claude。
【风险记录】：失败条件“池无可用炮台/无法继续消除”与槽中炮台、活跃球及随机排的关系待D08，不擅定真值表或胜负同帧优先级。D09待明确跨进程保存与切关时飞行球处理；D02待明确合成上限及超限策略；D01/D03/D04/D05/D06/D07余项依然受门禁约束。风险包括跨关状态污染、迟到事件误写、存取不完整、取回复制炮台、下一发效果泄漏、高速穿透和模拟器性能。历史Goxel安装记录本轮未复核，不作为工程验收证据；本轮无新增环境验证。
【下一步触发条件】：Claude完成P1-INIT-v3并交付review-context.md和原始验证日志后，Codex逐项评审；通过才标阶段1整体验收完成。阶段2另发任务并先明确素材范围；后续实现前解决相关D项，不能以默认玩法代替需求。


【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：先读取三份基础文档、现有架构和任务单，复用已完成目录结构、GDScript规范、模块划分和数据契约，不重复开发。按本轮明确需求更新GDD v4、架构v4及P1-INIT-v4：补充九宫格空位不可选、模型空白区域旋转、粒子无碰撞、任意指成功发射清除待发标记但保留该球快照、随机排保留槽中炮台；取消旧版停止阈值结束弹珠规则，统一出界结束并清零连击；明确不做广告/付费/问号稀有炮台/连击奖励。新增T22粒子开关轨迹与命中一致性验证，初始化测试模板更新为T01～T22。未创建游戏实现或执行工程初始化。
【当前进度】：阶段1全部设计已完成并同步本轮规则；Claude工程初始化待执行，阶段1整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：P1-INIT-v4，按docs/tasks/phase-1-init.md执行P1-01目录及.gitkeep、P1-02说明与配置、P1-03空Godot4工程、P1-04三份报告模板、P1-05导入和启动验证、P1-06交接。观测要求：目录符合architecture完整目标树、固定项目名、仅Main:Node3D、无玩法实现、两次运行有命令/退出码/原始日志、T01～T22未运行标NOT_RUN，交付review-context.md。任务文档就绪，本轮未实际启动Claude。
【风险记录】：D01～D09余项仍须按阶段澄清，不自行设置合成上限、性能阈值、失败真值表或存档范围。模型空白交互区域的命中判定待D06；任意指待发标记与已发射球快照须分离；粒子不得污染碰撞。Godot与模拟器环境未验证。GitHub上传请求此前因沙箱外认证检查被中断，尚未创建仓库或上传；本轮不将上传计作工程交付。当前运行时无可用OpenViking经验检索工具，未获得新增经验。
【下一步触发条件】：Claude按P1-INIT-v4完成交付并提供docs/review-context.md与原始验证日志后，Codex按任务观测项评审；通过后才标阶段1整体验收完成。阶段2须明确D05素材范围并另发任务。


【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：读取三份基础文档，通过Chrome飞书文件的查看代码模式逐段核对交付原文第0～14节。更新GDD v5并登记来源链接；补齐关卡号/区域布局/道具次数、轻量碰撞、同色击碎后剩余弹道继续反弹、完整本期排除项及原文12项测试映射。新增T23重复操作稳定性与内存趋势、T24布局绑定验证；补充D10重置语义、D11穿透道具范围歧义，不自行扩展玩法。同步architecture v5、P1-INIT-v5及工作流测试门禁，完成文档一致性核对。
【当前进度】：阶段1设计已按交付文件补齐；工程初始化待Claude执行，整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：执行docs/tasks/phase-1-init.md的P1-INIT-v5，顺序P1-01～P1-06不变；报告模板预列T01～T24为NOT_RUN，并保留D01～D11依赖；目录、空Main根、命令/退出码/原始日志等观测要求不变。本轮仅更新任务文档，未实际调度Claude。
【风险记录】：交付原文未提供合成上限、性能阈值、失败边界真值表、存档范围等精确参数，不能将D项误记已解决。重置仅见于稳定性测试，穿透道具仅见于含糊排除项，相关实现待澄清；商业解锁禁项不取消加槽位道具，云同步禁项不取消各关独立保存。未执行Godot或安卓测试。
【下一步触发条件】：Claude按P1-INIT-v5提供review-context.md和原始验证日志后进入阶段1评审；受影响玩法实现前澄清相应D项。


【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：读取三份基础文档与架构/任务单，将用户两轮七阶段方案及通信规则写入docs/plan.md（PLAN v2），逐项列出任务编号、前置、交付物、观测验证、阶段风险及通用失败/交接规范。同步GDD v6、architecture v6、P1-INIT-v6和AI-WORKFLOW。明确阶段1相机/环境光及全部可解析占位.gd，替代历史仅空根和禁止占位约束；阶段2青蛙/原始vox/授权记录/最小导入/UI占位；阶段3底层物理和六个模块入口；阶段4完整玩法含独立关卡保存；阶段5五类音效与终局弹窗；阶段6量化适配；阶段7全量闭环。固定十个event_bus事件、只读快照参数、串行时序、防重入/去重/切关解绑；所有跨模块通知走总线。未创建工程/占位脚本或启动执行Agent。
【当前进度】：阶段1设计已完成并更新；目录、占位脚本、基础Godot工程待Claude实际初始化，阶段1整体验收未完成；阶段2～7仅计划就绪。
【下发给Claude的任务】：执行docs/tasks/phase-1-init.md的P1-INIT-v6（P1-01～06），目录与占位脚本精确对照architecture；保留正式文档；建立Main/Camera3D/WorldEnvironment；提交占位解析、工程导入/启动命令和退出码、执行端现象文字及review-context.md。阶段2～7依据plan门禁逐阶段推进，不跳阶段；本轮未实际调度。
【风险记录】：总线循环、重入、乱序和旧关事件污染需专项验证；事件载荷不得携带可释放节点。占位脚本不代表模块实现，禁止将所有通知误当成已提交状态事件，ball_hit_voxel是碰撞事实。素材优先CC0且授权不明不使用；Godot/安卓兼容与性能阈值尚未验证；D01～D11剩余项仍受门禁，失败不能简化为池空。新增青蛙/音效范围已登记GDD，不猜测参数。
【下一步触发条件】：Claude完成P1-INIT-v6并提供review-context.md及验证证据后，Codex评审；通过才进入阶段2，相关未决项在受影响实现前澄清。


【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：读取三份基础文档，将用户提供的双Agent协作规范合并AI-WORKFLOW：固定职责、串行阶段、任务/回执模板、三类评审、测试闭环及素材规范。保留已有日志和实际状态，不使用空白初始模板重置历史。同步PLAN v3、architecture、P1-INIT-v6及GDD素材约束；增加assets/vox_source和textures/particle，授权目录统一assets/license，Goxel编辑源保留source/goxel。明确禁止抠图/授权不明/CC-BY/付费素材，逐资产核验，兜底先手绘再AI图标方案。保留跨模块通知全部走event_bus的既有严格契约及十事件清单；阶段7全量测试不替代前六阶段自测。
【当前进度】：阶段1设计与协作规范已更新；工程/占位脚本初始化仍待Claude，整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：按现行P1-INIT-v6执行P1-01～06，使用更新后的architecture目录；资产模板包含许可存档、取得日期、修改记录及禁用类别检查；提交可解析占位脚本、基础工程导入/启动证据、review-context.md和真实执行日志。本轮未实际调度Claude。
【风险记录】：素材站点不等于许可证明，自制或AI资产不得伪称CC0；旧licenses路径不得继续使用。相机/环境光与可解析占位约束保持有效，阶段1不制作素材。D01～D11剩余参数及Godot/模拟器环境风险仍存在，不能写暂无风险或将设计完成当工程验收。
【下一步触发条件】：Claude完成初始化并交付review-context.md及原始验证证据后，Codex做架构/逻辑/风险评审；通过当前阶段后才进入下一阶段。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：核对实际文件、架构目标树、P1交付清单、GDD未决项和Git状态，新增docs/file-audit.md。核对前共6份设计文档及.gitignore，无Godot工程，31个目标占位脚本实际0个。验证builds/android/.gitkeep被builds/规则忽略；记录P3-02事件描述与碰撞事实契约不一致、阶段4最小UI/粒子与阶段5文件标记不一致、关卡配置文件级契约待补问题。未改工程配置或实现。
【当前进度】：阶段1设计文档已具备，但发现待修正文档细节；实际初始化与整体验收未完成；阶段2～7未启动。
【下发给Claude的任务】：维持P1-INIT-v6；执行前阅读file-audit.md。P1-02修正忽略规则并验证.gitkeep保留/APK忽略/.uid保留，其余按P1-01～06交付目录、31个占位脚本、基础工程、三份报告模板和真实验证日志。本轮未调度Claude；文档契约修订由Codex负责。
【风险记录】：此前日志的Git未初始化状态已过时：本次确认存在本地提交d935e5e，remote为空；最新文档尚未提交，不能宣称GitHub同步。忽略规则会导致占位目录丢失；事件类别和阶段文件边界会误导执行；D项及Godot/模拟器环境仍未验证。
【下一步触发条件】：修正文档表述后Claude完成P1交付并提供review-context.md及原始日志，Codex评审；关卡JSON契约须在P2-02前明确。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Claude Code
【完成工作】：按用户"开始工作"指令执行P1-INIT-v6全部子任务（本会话经用户直接授权承担执行方角色）。P1-01：按architecture v6目标树创建全部目录、31个可解析占位.gd（仅extends RefCounted+职责/阶段/TODO）、26个.gitkeep。P1-02：创建README.md/.editorconfig，按file-audit问题①修复.gitignore（builds逐级排除，git check-ignore验证：.gitkeep保留、APK忽略、.uid保留）。P1-03：创建project.godot（固定项目名、主场景、gl_compatibility）与scenes/main/main.tscn（Main:Node3D+Camera3D current+WorldEnvironment环境光）。P1-04：创建asset-manifest/test-report（T01～T24预列NOT_RUN）/review-context三模板。P1-05：验证全部通过——Godot 4.7.2.stable.ed1daf0bf；31个占位脚本--check-only解析exit 0；headless编辑器导入exit 0无错误；主场景headless启动2帧exit 0；报告与原始日志落盘reports/desktop/。P1-06：填充review-context.md（READY_FOR_REVIEW）并追加本日志。
【当前进度】：阶段1执行完成、交付就绪；整体验收待Codex评审，不自称通过；阶段2～7未启动。
【下发给Claude的任务】：无（本轮执行方即Claude Code）；待Codex评审意见，如有返工按具体P1编号执行。
【风险记录】：file-audit问题②③④为Codex文档修订项（plan事件表述、阶段4/5文件边界、level_01.json文件级契约），未触碰；GitHub远程未配置（gh登录失效，待用户授权gh auth login），不能宣称已同步；gl_compatibility在安卓模拟器的兼容性待阶段6实测；headless验证不代表画面/性能验收。
【下一步触发条件】：Codex读取docs/review-context.md与reports/desktop/p1-init-validation.md评审；通过则标记阶段1验收完成并按D05门禁评估阶段2任务下发；发现问题按P1编号下发定界修复。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：按用户最新指令改为Claude连续自主执行模式，取消Codex逐项/阶段评审等待；在工作流、计划、架构、GDD和阶段1任务顶部加入优先授权，新增tasks/claude-autonomous.md。授权Claude自行修订工程文档、选择并记录可配置原型默认值、素材取舍、自测修复与推进；保留七阶段串行、核心玩法、素材限制和真实测试证据。修正file-audit②事件分类、③阶段4最小UI/粒子与阶段5完善边界、④最小关卡JSON契约。
【当前进度】：P1初始化已交付，静态结构和既有headless日志已核对；不再等待Codex整体验收。桌面有界面现象仍未验证，按新授权不阻塞继续；阶段2～7由Claude自主完成。
【下发给Claude的任务】：CLAUDE-ALL，读取docs/tasks/claude-autonomous.md，核实现有产物后从P2-01连续执行至P7-04；先记录D05调色板默认方案，再逐项解决相关D项；每阶段自检后自动继续，最终交付APK/哈希、模拟器测试与性能报告。仅落盘任务，本轮未启动Claude会话。
【风险记录】：用户取消的是Codex评审依赖，不是测试真实性要求；headless不等于画面/性能验收，安卓gl_compatibility待实测。无回复的调色板提案不算确认；默认值须标执行方决定。工具、权限、凭证或模拟器缺失仍可能构成外部阻塞，不伪报完成。
【下一步触发条件】：Claude直接按CLAUDE-ALL继续，无需Codex回复或批准；最终交付或遇真实外部阻塞时向用户汇报。

【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Claude Code
【完成工作】：阶段2完成。GDD新增"执行默认值决策"表（D01～D11全部登记原型默认值：槽初值3/上限99合成/球速12/出界立方体边界/道具次数3-1-2-2/七色调色板/竖屏/API33模拟器阈值/失败真值表/user://存档/HUD重置/不引入穿透道具）。P2-01：程序化自制青蛙frog_01.vox（367块：绿286/白56/黄17/深灰8，符合300～1200）+非对称三轴夹具axis_fixture.vox；Goxel无CLI能力（--help拉起GUI已终止），素材走自制兜底路径并如实登记asset-manifest。P2-02：vox2json.py（schema_version=2，vox(x,y,z)→godot(x,z,-y)，最小角归一，精确RGB匹配七色，重复坐标/未知色/数量越界拒绝）导出frog_01.json；level_01.json最小关卡配置（rules空对象，阶段4填充）。P2-03：VoxelData/VoxelLoader/VoxelRenderer最小实现（单MultiMesh+CPU镜像）；T01导入分支13断言全PASS（300/1200合法、重复坐标/非法色/数量/schema拒绝、frog 367块、单MultiMesh无逐块节点、颜色镜像一致、轴向夹具映射正确）。P2-04：决策UI全部程序生成StyleBoxFlat+内置字体，不引入外部素材，登记asset-manifest。发现并修复两处执行缺陷：loader Vector3字符串索引bug、headless dummy渲染器MultiMesh缓冲不回读（改CPU镜像断言并记录限制）。修复README尾部异常行并更新执行模式说明。
【当前进度】：阶段1、2完成；阶段3开始（核心底层框架）。
【下发给Claude的任务】：P3-01～P3-05连续执行：体素管理器（存活集/空间索引/尾交换删除）、事件总线+EventRecorder、球体连续碰撞物理、输入互斥与手势路由、关卡数据接口。
【风险记录】：GPU缓冲颜色回读在headless不可用，桌面/模拟器轮次需补验（已记test-report）；level_02夹具关卡未建（阶段4任务）；D项默认值未经用户确认（已按要求登记）；GitHub推送仍阻塞于gh登录。
【下一步触发条件】：自动继续P3-01，无需等待。

## 阶段3 核心底层框架（CLAUDE-ALL 自主执行，2026-10-26）
- 范围：P3-01 体素管理（存活集/空间索引/单MultiMesh尾交换删除）→ P3-05 关卡配置/会话/存档。
- 交付：voxel_state/voxel_spatial_index/voxel_renderer/voxel_manager；event_bus/event_recorder；collision_solver/projectile_system/ball_physics；input_mutex/gesture_router；level_catalog/level_session/level_repository；voxel_model.tscn/marble.tscn；game_controller.gd 骨架。
- 自测（全部 headless 可复现）：
  - tests/unit/test_voxel.gd 9/9 PASS（含重复删除拒绝、尾交换双向映射一致）
  - tests/unit/test_event_bus.gd 8/8 PASS（顺序/去重/陈旧代拒绝/防重入/切关解绑/未知事件拒绝）
  - tests/unit/test_input.gd 10/10 PASS（UI不旋转/0.01rad每px/首指/俯仰钳制/失焦清理）
  - tests/integration/test_ball.gd 8/8 PASS（反射公式/大步长不穿透/出界一次/旋转模型命中与世界法线）
  - tests/persistence/test_persistence.gd 12/12 PASS（配置契约/路径穿越拒绝/会话独立/存档往返/版本拒绝/损坏拒绝）
- 修复记录：墙面命中期望修正（命中近侧膨胀面 x=1.35 而非远侧 -0.35）；两处 GDScript 类型推断报错改显式标注；game_controller 对齐实际 API（ball_physics.setup/set_level、session_generation、边界按 bbox 半径+8）。
- 遗留：headless 为 dummy renderer，GPU 缓冲读回验证推迟到桌面/模拟器轮；事件总线退出泄漏告警为 SceneTree 脚本退出常态，不影响断言。

## 阶段4 核心玩法实现（CLAUDE-ALL 自主执行，2026-10-26）
- 范围：P4-01 九宫格池 → P4-09 关卡集成（P4-01~09 全部）。
- 交付：scripts/gameplay/{pool_service,slot_service,merge_service,combo_state,prop_service,hit_resolver,outcome_state}.gd；game_controller.gd 全量编排（安放/取回/发射事务/合成/道具/步进/胜负/存档恢复）；projectile_system/ball_physics 弹珠携带 color_id+any_color；level_01.json 显式规则；assets/models/json/grid_300.json + tests/fixtures/level_02.json（TEST_ONLY 关卡夹具，不进生产关卡列表）。
- 自测（headless 可复现）：
  - tests/unit/test_gameplay.gd 25/25 PASS（池/槽/合成上限拒绝/四道具次数与效果）
  - tests/integration/test_play.gd 29/29 PASS（发射事务2→1→0、同色删除/异色反弹、连击事件、速度×2=24恢复12、任意指异色消除、失败真值表、通关一次、通关后拒绝、A→B→A恢复、旧代事件拒绝）
  - 阶段3五套回归全部 PASS
- 修复记录：GDScript 多行 lambda 实参解析限制→改命名谓词；弹珠颜色随机导致同色命中不确定→测试显式对齐颜色；combo_update 复用 voxel_destroyed 的 event_id 被去重拒绝→hit_resolver 派发独立 event_id。
- 执行方决策（未用户确认，已在GDD登记范围内）：最小池/槽 UI 与粒子表现并入阶段5统一交付，阶段4仅逻辑层+事件证据。

## 阶段5 UI/音效/特效（CLAUDE-ALL 自主执行，2026-10-26）
- 范围：P5-01~P5-05。HUD（顶部关卡号/剩余数、槽行、九宫格、四道具、用尽隐藏、选中高亮，全程序化 StyleBoxFlat 屏幕空间固定布局不随模型旋转）；关卡列表 presenter；命中粒子（一次性 CPUParticles3D，16/次、寿命0.8s、总量上限512超限丢弃计数）+ 连击飘字 Label3D；五类正弦 WAV（tools/gen_sfx.py，无外部素材）；AudioPresenter 一事件一播放（总线 event_id 去重保证）；main.gd/main.tscn 装配（手势旋转、关卡列表进入、终局存档）。
- 清理：删除 7 个已被正式实现取代的占位脚本（scripts/effects、turret、ui 目录）。
- 自测：tests/unit/test_presentation.gd 22/22 PASS（HUD 同步/隐藏/高亮、音效计数与去重、粒子上限 4 放行 1 丢弃、关卡列表回调）；WAV 经 --import 后 ResourceLoader 可加载；主场景 headless 冒烟无脚本错误。
- 遗留：音效"可听到"与 UI 视觉验证属桌面/模拟器轮（T24），headless 无法覆盖，已记录。

## 阶段6 安卓打包（CLAUDE-ALL 自主执行，2026-10-26，完成）
- P6-01：export_presets.cfg（包名 com.learning.godotvoxelblocksmash，arm64-v8a+x86_64，沉浸式竖屏，全部权限关闭，无密钥入仓库，调试签名用编辑器已配置 keystore）。
- 环境：Godot 4.7.2.stable / export templates 4.7.2.stable（本机原缺 Android 模板，已从官方 release 提取 android_debug/release.apk 安装）/ Java 21 (ms-21.0.10) / SDK ~/Library/Android/sdk。
- 修复：导出要求 ETC2/ASTC 纹理压缩 → project.godot 开启 textures/vram_compression/import_etc2_astc。
- P6-02 触屏适配修复（设备实测驱动）：竖屏方向字符串被忽略改整数枚举 orientation=1（aapt2 验证 AndroidManifest screenOrientation=1）；模型 attach 重复中心偏移导致不可见→移除二次偏移；tscn Transform3D 字面量行主序误写列主序致相机俯角反向→转置修正；CanvasLayer 下 Control 尺寸0+keep_offsets 致底部 UI 出屏→显式锚点+size=get_viewport_rect().size。
- 最终产物：builds/android/godot-voxel-block-smash-debug.apk（调试签名，apksigner 校验通过），最终 SHA256=75f6fd2cde4b15d8c229b31c652925fcfa6f7b6b903a22477f20bcb4aad9cdad（阶段7 修复 event_recorder flush 后重建；中间版本哈希 2531939c…/4b01fa57… 已被取代）。
- 为阶段7取证新增：diagnostics/perf_monitor.gd（FPS/avg/p95/内存周期写 user://perf_log.jsonl）、main.gd 进关时 recorder.open()；桌面诊断探针 tools/render_probe.gd、tools/scene_probe.gd（可视化调试，加速设备问题定位）。

## 阶段7 模拟器验证（CLAUDE-ALL 自主执行，2026-10-26，完成）
- 环境核对：AVD voxel_test_api33 = API 33 / x86_64 / 1080x2400，与 D07 目标逐项一致（getprop/wm size 实测）；渲染后端 SwiftShader 软渲染。
- 安装启动：adb install 成功、竖屏启动、首次系统沉浸式提示框（"Viewing full screen"）已识别并点击消除，不属应用缺陷。
- 设备玩法证据链（event_log_device.jsonl 全量记录）：进关 level_loaded → 安放绿卡 → 发射 turret_fire（ammo 3→2→1→0 归零移除）→ ball_hit_voxel/voxel_destroyed×7 → 剩余367→360；四道具实测：加槽解锁第4槽（用尽按钮隐藏）、任意指紫球 any_color:true 删除绿块、速度×2 实测模长24.0下一发恢复12.0、随机排九格全刷槽位不变；combo_update×11 出界归零；单指滑动模型绕中心旋转（截图 device_rotated_shuffled.png）。
- 跨进程持久化（G15/D09）：KEYCODE_HOME 触发 APPLICATION_PAUSED 落盘 → force-stop → 重启进关：剩余359、4槽、道具计数、九格池卡与离开前完全一致（截图 device_session_restored.png）。
- 修复记录：event_recorder._write 未 flush 导致 Android 上 event_log.jsonl 0 字节（perf_monitor 有 flush 故正常）→ 每行 flush + 暂停/退出 recorder.close() → 重建重装后日志完整。
- 性能（如实记录，不推定通过）：perf_log_device.jsonl — FPS 平均10.0/峰值12.2（D07≥30 FAIL）、p95 峰值143.1ms（≤50 FAIL）、内存峰值57.1MB（≤512MB PASS）、35s 窗口增长10.4%（窗口不足60s，样本不足）。SwiftShader 无 GPU 加速为主要归因，需真机复测。T23 的30轮/120s 未完整执行，标记部分执行。
- headless 最终回归：9 套（event_bus/input/voxel/gameplay/presentation/persistence/import/ball/play）全部 exit=0，合计 145 行 PASS。
- 测试报告：docs/test-report.md 终轮填写完成 — T01~T12/T14~T22/T24 PASS，T13 FAIL（性能环境受限），T23 部分执行。
- 遗留：GitHub 推送阻塞于用户交互登录（gh auth login 需用户本人执行）；真机性能复测；T23 完整30轮。

## 可玩性补齐设计交接（2026-10-26，Codex）
- 按最新用户指令改为Codex只负责代码/架构设计、Claude负责实现。
- 新增 docs/tasks/playability-gap-fix.md 与 docs/playability-architecture.md：球体渲染池、碎裂mesh/颜色、触摸释放、HUD闭环、有效色池、移动验收，以及跨局清理/旧存档generation/可解性等附加缺口。
- 本轮短暂实现草稿已备份 /tmp/voxel-playability-reference 并撤回，运行时代码与导出配置恢复至本轮开始版本；其他来源的未跟踪证据文件保留。
- 本轮未交付新APK、未执行实际通关及30局；仅设计就绪。Claude启动指令见架构文档第8节，尚未向其他任务发送消息或自动调度Claude。

## 三张参考图补充审计（2026-10-26，Codex）
- 对照b97cdf7确认球渲染装配、粒子mesh、HUD连击、触屏释放与拉伸仍待实现。
- 在 docs/playability-architecture.md 第9节补充拖尾、多球可读性、炮台/槽状态、连击显示策略、分区布局、材质与道具待生效反馈设计。
- 区分截图可见现象与无法证明的玩法；保留3×3、四色青蛙及独立点击发射，不引入广告、问号炮台或新模型。仅文档变更，未执行游戏代码或打包。


## 入槽自动连发规则澄清（2026-10-26，Codex）
- 用户明确炮台在炮位即连续发射，弹数0消失。更新G02/T04及可玩性任务/架构第10节，替代历史点击逐发。
- 设计稳定turret_id调度、成功才扣弹、多个炮位独立冷却、生命周期停止、下一发道具确定性消费；发射间隔0.25秒仅为执行建议。仅文档变更，待Claude实现。

## 可玩性补齐实现 A→E（CLAUDE 执行，2026-10-26，进行中）
- 按 playability-architecture §8 启动指令实施。先核验架构文档自基线 9c0025b 未变（md5 f3291c389243c2ea100ac9c483339cdd），按已读版本实现。
- A 基础：auto_fire_scheduler.gd（0.25s 间隔、稳定 turret_id、失败不扣弹下周期重试+限频日志、弹尽/取回注销）；game_rules.gd 增 auto_fire_interval；ball_physics event_id 混入 session_generation 防重开后总线去重碰撞。
- B 表现：marble_presenter.gd（turret_fire 生成可见球、帧同步 ball_snapshot、出界/失效幂等回收、idle 池上限32、颜色随炮台 palette）；hit_effects.gd 重写（BoxMesh 碎块+被消块体素色材质、命中点飘字、generation token 隔离旧 timer）；audio_presenter.gd 增 stop_all。
- C 控制：game_controller.gd 重构（每局全新 EventBus；调色板=模型实际 color_ids 去重注入 rules；旧档无效色显式迁移保留 id/弹数/来源格/has_fired 并记录日志；恢复后 session_generation 保留本次运行代号；恢复有弹炮台重新注册调度；fire_slot 走表现层注入 origin_resolver；stop_session/set_paused 会话边界）。
- D 界面/装配：hud_presenter.gd 重构（底部顺序槽行→池格→道具；点击已占位槽不发射仅提示"炮台入槽后自动连发"；取回模式开关；结算全屏遮罩 MOUSE_FILTER_STOP+重开/返回信号；连击标签 combo_update 专属订阅、refresh 不清；道具失败 toast；待发标记；slot_screen_center）；main.gd 重构（§3 固定生命周期 enter_level/restart_current_level/return_to_list；发射原点=槽屏幕中心相机射线∩边界AABB 内移0.1、朝模型中心，废除 (i-2)*2/-half*0.8 硬编码；_input 释放兜底；退后台 cancel_all+set_paused+落盘）；project.godot 拉伸 canvas_items+expand。
- E 测试：新增 tests/integration/test_auto_fire.gd（30 断言全 PASS：无点击恰好2发弹尽消失、多炮台独立+压缩不漏不重、失败不扣弹重试、待发道具仅一发、取回停止、恢复代号保留+重注册、无效色迁移、弹珠表现生成/同步/回收）；test_presentation.gd 增 13 断言（点槽不发射、取回模式、结算遮罩、连击标签、待发标记、槽屏幕中心）全 PASS；10 套 headless 全绿；主场景 headless 冒烟 exit=0 无 SCRIPT ERROR。
- 文档：GDD 执行默认决策新增 D12（auto_fire_interval=0.25 执行方默认）+ D03 发射起点改为相机射线∩边界AABB 描述；README 同步入槽自动连发。
- 待办：APK 重建（versionCode=2/0.2.0）、真机完整通关验收（安放→自动连发→可见球→碎裂→全清→通关弹窗→重开）、T23 30 轮、双端性能、提交推送。


## 十二项优化分步设计交付（CQ-20261026）
【时间】：2026-10-26（Asia/Shanghai）
【执行人】：Codex
【完成工作】：新增 docs/tasks/cannon-queue-redesign.md，覆盖用户十二项需求，制定 S00→S11 顺序任务、模块和状态契约、每色 Q+S+F=V 守恒、一发一块及取消返还、五列随机长度队列、列首点击上位和补位、跟手与上方构图、4000～5000块青蛙、自制炮台素材、道具冲突处理、v2存档、16项验收用例和Claude提示词；docs/plan.md增加当前任务入口。
【当前进度】：仅设计完成；游戏代码、素材、测试和APK未在本轮执行。已有未提交可玩性改动保持原样。
【下发给Claude的任务】：CQ-20261026 / S00→S11；用户自行交接。此前Orca只读发现被沙箱阻止，升级权限请求由用户中止；未发送任务、未启动Claude。本轮按用户纠正不再调度Agent。
【风险记录】：严格每色守恒要求替代旧反弹多消、随机造弹及异色万能弹；相关行为在新设计中明确标注。队列守恒不等于可解，正式关卡需有验证解和真实UI完整通关。旧模型设备性能结果不能替代新模型验收。
【下一步触发条件】：用户将新任务文档交给Claude；Claude从S00核对当前工作区，按顺序实现、自测、记录，不等待Codex批准。

## CQ-20261026 / S00 基线、复现与文档契约（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S00
前置步骤及证据：已读 cannon-queue-redesign.md、plan.md、game-design.md、architecture.md、playability-architecture.md、最新日志与测试报告；Pixel 7a（35181JEHN08868）adb 在线核实。
修改文件与作用：新增 reports/desktop/cq/s00-baseline.md（基线+复现+替代映射+接口契约）、reports/android/cq/cq-acceptance.md（CQ-T01~T16 全 NOT_RUN）、reports/android/cq/{env-baseline.txt,event_log_cq_baseline.jsonl,perf_log_cq_baseline.jsonl} 与 4 张截图证据、reports/desktop/cq/git-baseline-diff.txt；game-design.md 增"本轮规则替代声明"；architecture.md 增"CQ-20261026 架构增量"（新模块/状态契约/事件白名单/存档 v2）。
本步实现/参数决定：基线=9c0025b+16改动+6未跟踪（可玩性补齐 A~E），不撤销；"发了不消"根因=已证实（中心盲射隧道+异色反弹陷阱，run_id 1792985373 事件流：194发仅149毁、卡死段69发0毁）；旋转反向=真实错误（main.gd 本地欧拉角累加，不同朝向轴翻转），方向符号待 S02 标记法实测。
实际命令、退出码、设备、构建标识：adb getprop/dumpsys/screencap 均 exit=0；Pixel 7a Android17 API37 arm64-v8a 1080×2400；已装 versionCode=2/0.2.0；Godot 4.7.2.stable。
测试：S00 不产生用例结果；CQ-T01~T16 NOT_RUN（reports/android/cq/cq-acceptance.md）。
截图或录屏现象及日志路径：reports/android/cq/cq_rot_before/after.png（右滑眼球质心x仅+5px）、px3_v3_stall.png（中空隧道卡死 218 余块）、px3_restart.png（纯色矩形池卡、模型居中）。
颜色守恒统计：本步无运行事务；旧模型基线 V0={绿286,白56,黄17,深灰8}=367。
未解决问题与修复计划：旋转方向符号待 S02 实测；v3 驱动发现道具按钮隐藏后 HBox 重排导致盲点偏移（v4 已用截图分段检测解决，供 S11 驱动复用）。
下一步：S00 通过条件满足（根因已证实、设备无阻塞），进入 S01 精细青蛙。

## CQ-20261026 / S01 精细青蛙与容量（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S01
前置步骤及证据：S00 完成（reports/desktop/cq/s00-baseline.md）。
修改文件与作用：新增 tools/voxel_export/gen_frog02_vox.py（程序化自制 frog_02：身体+加厚头部双椭球、白眼球+深灰瞳孔、黄腹、浅绿背脊、四肢+橙脚趾、橙嘴线）、tools/voxel_export/preview_render.py（正交投影预览工具）；assets/vox_source/frog_02.vox + assets/models/json/frog_02.json；gen_frog_vox.py/vox2json.py 调色板+浅绿(8)/橙(9)、vox2json 上限 1200→6000；voxel_loader.gd MAX_VOXELS 1200→6000；voxel_renderer.gd 块缝=格距3%（2%~4% 区间，碰撞仍按逻辑格）；gen_fixtures.py 增 model_6000/bad_count_high 夹具；level_01.json→frog_02.json、model_revision=2.0-f867f19c33c4；test_import.gd 增 frog_02/6000/6001 断言；test_play.gd 修复"异色不删除"用例自身缺陷（原球色与目标同色、此前偶然通过；改为瞄准最底面体素+异色球）。
本步实现/参数决定：frog_02=4105 块（目标 4000~5000 内）；六色=绿3167/黄311/浅绿299/白218/橙80/深灰30，均有对应消除源，无有炮无块；bbox=(0,0,0)~(28,19,17)；voxel_size=1.0；sha256=f867f19c33c43dbbd1035c6fc52e184471a141ff6ef334bceb37b2f737eb70c5；容量上限 6000 为任务指定默认值。块缝 3% 为执行方决定（任务允许 2~4%）。
实际命令、退出码、设备、构建标识：gen_frog02_vox.py/vox2json.py/gen_fixtures.py/preview_render.py 均 exit=0；10 套 headless 全 TEST_PASS（含修复后 test_play）。
测试：CQ-T02 PASS（4105 唯一体素、每色统计断言一致、palette 完整、越界仍拒绝）；T01 回归 PASS（300/1200/6000 合法、非法坐标/色/数量/schema 拒绝）；其余套件回归 PASS。
截图或录屏现象及日志路径：reports/desktop/cq/frog_02_front.png / frog_02_side.png（正面可见眼白+瞳孔+橙嘴+黄腹+橙趾，侧面可见背脊轮廓）。
颜色守恒统计：V0={1:3167,4:311,6:218,7:30,8:299,9:80}，总计 4105；本步无运行事务。
未解决问题与修复计划：frog_02 在真机的渲染/性能未测（S02 构图、S10 性能覆盖）；青蛙正面朝向沿用 frog_01 约定（vox+y=正面），S02 跟手验收时复核。
下一步：S01 通过条件满足，进入 S02 跟手旋转与上方构图。

## CQ-20261026 / S02 跟手旋转与上方构图（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S02
前置步骤及证据：S01 完成（frog_02 4105 块已入 level_01）。
修改文件与作用：scripts/app/main.gd（_apply_rotation 改为相机空间增量四元数 Basis(Q(up,rot.x)*Q(right,rot.y))*basis，替代本地欧拉累加；新增 _frame_model：包围球×1.08 拟合相机距离、直立相机下移使模型视觉中心落在内容区 y≈33%、灵敏度=PI/屏宽、初始姿态 yaw=π 正面朝相机）；scripts/input/gesture_router.gd（pitch_limit 1.4→1.2217=±70°）；tests/unit/test_input.gd 钳制断言同步；新增 tests/unit/test_rotation.gd（CQ-T01 标记法 7 断言）、tools/frame_probe.gd（多分辨率构图探针，headless 下 root.size 显式模拟长宽比）。
本步实现/参数决定：跟手方案=每步绕当前相机 up/right 轴的小增量旋转（任意朝向下前表面随手指同向移动）；俯仰越界时只保留偏航分量；构图参数：纵向拟合 0.44、横向 0.90、上移 0.16（透视非线性约再抬 1.7%，实测中心≈32%）。首轮 0.46/0.17 在 19.5:9/16:9 下包围球顶部 8.3% 越界（探针 FRAME_CLIP），调至 0.44/0.16 后三档全 FRAME_OK。
实际命令、退出码、设备、构建标识：Godot 4.7.2 headless；test_rotation.gd TEST_PASS（7/7）；frame_probe 1080×2400(20:9) x 8.3~91.7% y 13.3~52.8%、1230×2400(19.5:9) x 10.3~89.7% y 11.0~54.4%、4266×2400(16:9) x 38.5~61.5% y 11.0~54.4%，均 FRAME_OK，exit=0。
测试：CQ-T01 桌面投影证据 PASS（默认视角右/下拖瞳孔标记同向移动；偏航 90° 后固定前面标记仍同向；±70° 钳制；中心不漂移；横扫全宽≈180°）；真机画面复核随下一次 APK 构建（S07/S10）执行，当前记 NOT_RUN。
截图或录屏现象及日志路径：桌面无新截图；探针输出见本日志。
颜色守恒统计：本步无运行事务。
未解决问题与修复计划：真机方向/构图复核待 APK 重建后执行（设备仍跑旧 0.2.0 包）；模型区/槽位区 UI 分区在 S07 落地后复查不重叠。
下一步：S02 通过条件满足（桌面证据齐、真机部分列入构建后验收），进入 S03 五列守恒队列生成器。

## CQ-20261026 / S03 五列守恒队列生成器（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S03
前置步骤及证据：S02 完成（构图/跟手桌面证据齐）。
修改文件与作用：新增 scripts/gameplay/cannon_queue_service.gd（五列可变长队列：每色 V0[c] 拆分 30~80 普通炮+1~29 余数末门，拒绝采样 16 次+确定性兜底 clampi(rest-80,30,80)；Fisher-Yates 洗牌后前 5 门一列一门、其余随机落列；conservation_report/front_of/pop_front/push_front/column_lengths/shuffle_columns）；新增 tests/unit/test_cannon_queue.gd；新增 scripts/gameplay/fire_geometry.gd（槽位屏幕中心=(i+0.5)w/5,0.61h → 相机射线∩格空间边界AABB 内移0.1，运行时与验证器共用）；新增 tools/cq_verify.gd（离线可解性验证器：表面前沿+DDA 预过滤+扫掠确认，贪心策略=发射可达/上可达列首/≥2空槽停泊/满槽取回/90朝向循环）；assets/levels/level_01.json 写入 queue_seed=4、merge_max=160；level_catalog.gd 白名单+queue_seed。
本步实现/参数决定：列数=5、弹量 30~80（余数 1~29）为任务文档指定；种子来自关卡配置经离线验证（可解性属关卡数据契约）。
实际命令、退出码、设备、构建标识：Godot 4.7.2 headless；test_cannon_queue TEST_PASS（拆分边界/100样本五列≥1门/ID唯一/逐色守恒/总量=4105/种子复现/洗牌保留数据）；cq_verify.gd -- 1 100：VERIFY_PASS seed=4 actions=4260（种子1~3 贪心卡死、seed=4 全程可解），证据 reports/desktop/cq/s03-solution.json（691KB 全动作序列），exit=0。
测试：CQ-T03 桌面 PASS（不同种子生成合法/可变长/每色守恒）。
截图或录屏现象及日志路径：/tmp/cq_verify.log（VERIFY_PASS 行）；s03-solution.json。
颜色守恒统计：生成即守恒 sum(Q[c])==V0[c] 逐色成立，总弹药=4105=模型体素数。
未解决问题与修复计划：贪心策略对种子1~3失败属"贪心非全能"，不代表不可解；正式关卡固定 seed=4。
下一步：S03 通过，进入 S04 一键上位与固定五槽。

## CQ-20261026 / S04 一键上位、固定五槽与事务（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S04
前置步骤及证据：S03 完成（seed=4 验证解）。
修改文件与作用：scripts/gameplay/slot_service.gd 重写（固定五槽 int 数组、空位-1不压缩、leftmost_free/place_at/remove_at/slot_index_of）；scripts/level/level_session.gd 重写 v2（turrets 字典唯一所有者+queue_columns+slots+v0_counts；restore 归一化 JSON 往返的 String 键/float 数值为 int——实测修复坏档恢复 bug）；game_controller.gd 重写（place_front 原子事务：占槽→出列→READY→注册调度→queue_changed/slots_changed；return_turret 无在途立即回来源列队首、有在途 RETURN_PENDING 停新发射待结算）；merge_service.gd 重写（显式合成两列列首、同色、≤160不截断、被合成炮台弹药并入后清除）；prop_service.gd 随机排=shuffle_columns 只重排（无牌可洗不扣次数）；outcome_state.gd 重写（无目标不判负；队列+槽全空且无在途球才 LOST）；event_bus.gd 白名单+4（queue_changed/slots_changed/turret_state_changed/shot_resolved）；level_repository.gd 增 backup_save（v1→.v1.bak）；main.gd _on_level_chosen v1 旧档备份后重开。
本步实现/参数决定：槽位数据唯一容器=session.turrets，slots/queue_columns 只存 turret_id 引用；LOADING 动画归表现层，逻辑即 READY。
实际命令、退出码、设备、构建标识：Godot 4.7.2 headless；test_gameplay TEST_PASS（28 断言：固定五槽/最左空槽/占用拒绝/合成同色150/超160不截断/随机排保留ID弹量/无牌不扣/胜负真值表含不判负分支）；test_persistence TEST_PASS（v2 往返/键值归一化/v1拒绝/坏档拒绝），exit=0。
测试：CQ-T04/T05 桌面逻辑层 PASS（上位事务/空位不横移）；真机交互部分随 APK 验收。
截图或录屏现象及日志路径：无新截图；测试输出见 /tmp/test_*.log。
颜色守恒统计：合成/取回/随机排均不造弹不丢弹（test_gameplay 断言）。
未解决问题与修复计划：无。
下一步：S04 通过，进入 S05 目标化自动发射与射击账本。

## CQ-20261026 / S05 目标化自动发射、一发改一块与守恒（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S05
前置步骤及证据：S04 完成。
修改文件与作用：新增 scripts/gameplay/shot_ledger.gd（预订 voxel→shot 防双中、幂等结算、3s 超时扫描、逐色在途 F[c]、compact 64）；新增 scripts/gameplay/target_selector.gd（逐色表面前沿缓存+DDA 预过滤+扫掠确认，与验证器同规则）；game_controller.gd（try_auto_fire 只在有可达同色未预订目标时发射；_fire_at 预订→生成 stop_on_hit 球→成功才扣弹 S--F++；_on_ball_hit 命中预订目标且同色才删除 F--V--D++，否则返还 F--S++；出界/超时/保存前均返还；归零 DRAINING 暂留、最后一发结算后移除离场；conservation_audit 逐色 Q+S+F=V、V≤V0）；projectile_system.gd/ball_physics.gd 增 stop_on_hit（首个命中即停，一发一块）；auto_fire_scheduler.gd waiting_target/in_flight/no_ammo 静默重试；combo_state.gd 重写全局连击（1.5s 窗口）；hud_presenter.gd 全重写（五分区、五列列首+深度"还有n门"、五槽等宽、取回开关、结算遮罩、combo_update 全局 streak 签名）。
本步实现/参数决定：ball_radius=0.35、SHOT_TIMEOUT=3.0s（设计默认）；发射原点契约收敛 FireGeometry（main.gd _resolve_fire_origin 与 cq_verify 同一实现）。
实际命令、退出码、设备、构建标识：Godot 4.7.2 headless；13 套件全绿：test_shot_ledger（15断言）、test_auto_fire（37断言：80发真实打空离场+守恒审计/同色命中=预订目标/mismatch返还S++/无同色目标不发射不扣弹 WAITING_TARGET 不判负/取回两路径/恢复重注册/无效色迁移/弹珠表现）、test_play（13断言：grid_300 正常操作完整通关 8245步≈137s模拟、终局逐色 Q+S+F=V=0、全局连击x2+、通关后拒绝、失败真值表、A→B→A v2恢复、旧代事件拒绝）、test_presentation（五列HUD/点槽不发射/取回模式/全局连击标签/待发标记）、主场景 headless 120帧无 SCRIPT ERROR，exit=0。
测试：CQ-T06/T07/T08/T09 桌面逻辑层 PASS（可达才发射/预订防双中/超时出界返还/最后一发结算）；CQ-T15 桌面夹具版 PASS（真机 frog_02 完整通关待 S11）。
截图或录屏现象及日志路径：测试日志 /tmp/test_play.log 等。
颜色守恒统计：test_play 全程每销毁一批校验守恒，终局 Q+S+F=V=0 逐色成立；test_auto_fire 80 发耗尽后审计 ok。
未解决问题与修复计划：test_play 曾误用"旋转模型世界变换"驱动（格空间弹道不变）导致卡死，已修正为移动格空间原点（等价真机炮口相对模型换向）；真机触摸/画面验收随 S07~S11。
下一步：S05 通过，进入 S06 炮台素材与碎块表现。

## CQ-20261026 / S06 炮台素材（CLAUDE 执行，2026-10-26，进行中→暂停交接 Codex）
任务：CQ-20261026 / S06
前置步骤及证据：S05 完成（13 套件全绿，见上三条）。
修改文件与作用：新增 tools/cannon_gen.py（PIL 程序化矢量分层绘制，CC0 自制：圆角梯形底座/白色待染色炮身/金属灰炮管+深色炮口/64px 炮口闪光）→ assets/cannons/{cannon_base,cannon_body,cannon_barrel,cannon_flash}.png（256² 透明分层，炮管枢轴=(128,150)=炮身圆心，炮口尖≈(128,26)，距枢轴 124px）；hit_effects.gd 修复 combo_update 旧两参数签名（真机连击必崩隐患，已改 args[0]=全局 streak）。
本步实现/参数决定：素材方案=分层透明纹理+程序化炮管旋转（任务文档推荐路径）；炮身白色运行时按 palette color_id modulate 染色。
实际命令、退出码、设备、构建标识：python3 tools/cannon_gen.py exit=0（CANNON_GEN_OK，四图 bbox 校验通过）；test_presentation 回归 TEST_PASS；主场景 headless 60 帧 0 SCRIPT ERROR。
测试：本步无新用例；既有 13 套件保持全绿。
截图或录屏现象及日志路径：三张分层素材图已人工目检（轮廓清晰）。
颜色守恒统计：本步无运行事务。
未解决问题与修复计划（S06 剩余工作，交接）：
 1) 新建 scripts/presentation/cannon_view.gd（Control：base/body/barrel 三层 TextureRect KEEP_ASPECT_CENTERED 对齐 + 弹药数字 Label 白字粗描边 1~160 + pressed 信号；状态：queued/front/back/disabled/waiting/recoil/draining/locked；recoil() 后坐 tween + muzzle_flash() 闪光；muzzle_screen_center()=枢轴屏点+aim_dir×(124/256×实际边长)）。
 2) hud_presenter.gd：五槽与五列列首按钮换成 CannonView（锁槽/空槽/结算中/待取回状态映射），道具行不变。
 3) 炮管瞄准：HUD 每帧对有炮槽位计算炮口朝向（有 PENDING 票据→目标体素投影，否则模型中心投影），turret_fire 时后坐+闪光。
 4) 发射起点来自可见炮口：fire_geometry.gd 增 screen_point→origin 泛化；main.gd _resolve_fire_origin 改用 hud 炮口屏点（默认朝上偏移≈0.025h）；建议用炮口偏移重跑 tools/cq_verify.gd 复核 seed=4（失败则换种子并改 level_01.json queue_seed）。
 5) hit_effects.gd：碎片尺寸 bug（BoxMesh 0.08×scale 0.05~0.12 相乘过小）→ 目标碎片边长 0.08~0.18 体素（如 mesh 0.13 × scale 0.62~1.38）；加同色光圈；预算≤512、寿命≤0.8s 已满足。
 6) marble 亮球高光（emission）；每次删除只播一次效果（已满足）。
 7) 素材清单记录（作者/方法/源文件/日期）写入 assets 说明文件。
下一步：Codex 继续 S06 剩余 7 项 → S07 五列界面 → S08 指定目标/提示 → S09 存档 v2 完善 → S10 性能+APK → S11 真机完整通关验收（Pixel 7a 在线，勿用模拟器）。

## CQ-20261026 / S06 炮台素材（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S06（收尾上条 7 项剩余工作）
前置步骤及证据：S06 素材生成完成（上条）；Codex 因网络问题未接手，CLAUDE 继续。
修改文件与作用：
- scripts/presentation/cannon_view.gd（新增 class_name CannonView）：base/body/barrel/flash 四层 TextureRect，PIVOT_UV=(128,150)/256，MUZZLE_DIST_UV=124/256；API set_cannon(color,ammo)/set_visual_state/set_aim_dir/muzzle_screen_center/fire_feedback（后坐 0.05s+回位 0.09s+闪光 0.1s）；状态 empty/locked/back/waiting/draining/front；弹药数字白字 outline_size=10 支持 1~160。
- scripts/presentation/hud_presenter.gd：五槽与五列列首改用 CannonView（_slot_views/_column_views 替换 _slot_buttons/_column_buttons）；refresh 映射 DRAINING→draining、RETURN_PENDING/WAITING_TARGET→waiting、未解锁→locked、空槽→empty；新增 camera 注入 + _process 每帧炮管瞄准（shot_ledger.ticket_by_turret 取 PENDING 目标投影，否则模型中心）；_on_fire_feedback→fire_feedback；slot_muzzle_screen_center() 提供可见炮口屏点（空/锁槽回退槽位中心契约）。
- scripts/gameplay/fire_geometry.gd：新增 MUZZLE_LEN_UV/muzzle_screen_point()/screen_point_origin_world()，muzzle_origin_world 委托同一契约（运行时与离线验证器共用）。
- scripts/gameplay/shot_ledger.gd：新增 ticket_by_turret（瞄准用）。
- scripts/app/main.gd：enter_level 注入 hud.camera；_resolve_fire_origin 改用 hud.slot_muzzle_screen_center + screen_point_origin_world（hud 空/锁回退 FireGeometry.muzzle_screen_point）。
- scripts/presentation/hit_effects.gd：碎块棱长修复 0.13×scale 0.62~1.38=0.08~0.18 体素（原 0.08×0.05~0.12 过小）；新增 spawn_ring 同色光圈（TorusMesh unshaded+emission，0.3s 扩散淡出，不计粒子上限）。
- scripts/presentation/marble_presenter.gd：弹珠材质 emission=球色×0.6 提亮。
- docs/asset-manifest.md：四张炮台贴图来源登记（PIL 程序生成，tools/cannon_gen.py，CC0，2026-10-26）。
- tests/unit/test_cannon_view.gd（新建 16 断言：状态映射/炮口契约数学/瞄准/零向量/后坐闪光/锁/结算中/后排隐藏数字）；tests/unit/test_presentation.gd 更新 CannonView API（_slot_views/_column_views/state/锁/空 + 粒子+光圈子节点 8 + 棱长范围断言）。
实际命令、退出码、设备、构建标识：桌面 headless（macOS）；全部脚本 --check-only exit=0；14 套件全绿（test_cannon_queue/cannon_view/event_bus/gameplay/input/shot_ledger/voxel/rotation/presentation/persistence/auto_fire/ball/import/play，其中 test_play 全程通关 grid_300 复测 PASS）；主场景 headless --quit-after 3 exit=0、0 SCRIPT ERROR；tools/cq_verify.gd -- 4 1 → VERIFY_PASS seed=4 actions=4229（新炮口偏移契约下 seed=4 仍合法，level_01.json 无需改）。
测试：14/14 PASS（桌面 headless）；真机画面验收留 S10/S11。
截图或录屏现象及日志路径：reports/desktop/cq/s03-solution.json（验证器解）；素材图已目检。
颜色守恒统计：cq_verify 全程审计守恒（Q+S+F=V，V+D=V0）通过；test_auto_fire/test_play 守恒断言绿。
未解决问题与修复计划：炮管瞄准/闪光/光圈/弹珠提亮的真机目视验收合并至 S10/S11。
下一步：S07 五列界面打磨（深队列滚动/输入优先级/12px 移动阈值）。

## CQ-20261026 / S07 五列界面与完整上位表现（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S07
前置步骤及证据：S06 完成（14 套件全绿 + seed=4 复验 VERIFY_PASS，见上条）。
修改文件与作用：
- scripts/presentation/hud_presenter.gd：① 队列区每列改为 ColumnClip 裁切窗（内嵌类，mouse_filter=STOP 消费拖拽→拖队列不转模型）+ 3 门 CannonView 视图复用池（_column_pools，不为整列建节点）+ 深度标签（"还有 N 门"/"末门"/"上翻 N"）；② _col_offset 滚动偏移（scroll_column_by_px 整行吸附，只有 offset=0 的实际列首可操作，滚动不能把后排变列首）；③ ColumnClip._gui_input 12 逻辑像素阈值区分点击/滚动（SCROLL_THRESHOLD_PX）；④ 上位动画=残影飞行（0.18s 列首→槽位 TextureRect 残影）+ 槽位落位弹跳 + 队列整体上移一行（0.15s tween_method），数据事务先于动画，动画可被 refresh 打断；⑤ 守恒调试面板（仅 OS.is_debug_build()，"守恒"按钮切换 per-color Q/S/F/V/V0 表，调 controller.conservation_audit）；⑥ _on_column_tap：上翻状态点击只提示不上位、点窗口后排不操作。
- scripts/presentation/cannon_view.gd：新增 place_feedback() 落位弹跳（pivot 居中 1.15×0.08s→1.0×0.12s）。
- tests/unit/test_presentation.gd：新增 S07 断言 16 条（窗口映射/后排禁用/深度提示/5px 不滚 15px 滚/整行吸附/上翻点击不上位/点后排不操作/残影生成与回收/上移收敛），全套 51 断言。
本步实现/参数决定：滚动按整行吸附（不做像素级连续滚动，保证"只有实际列首可操作"语义清晰）；可见窗口=3（S07"至少前三门"）；调试面板只在 debug 构建出现。
实际命令、退出码、设备、构建标识：桌面 headless（macOS）；--check-only 解析 exit=0；14 套件全绿；主场景 headless exit=0、0 SCRIPT ERROR。
测试：14/14 PASS（桌面）；test_presentation 51 断言含全部 S07 新增。
截图或录屏现象及日志路径：三种长宽比完整界面+上位录屏属真机视觉验收，合并至 S10/S11（Pixel 7a）。
颜色守恒统计：本步无运行事务变更；test_auto_fire/test_play 守恒断言保持绿。
未解决问题与修复计划：真机触摸滚动/三种长宽比目视验收待 S10/S11。
下一步：S08 道具/合成/连击/终局对齐（指定目标替代任意指、胜利需无未结算票据、死局完整性错误、5 秒无进展提示、合成独立模式）。

## CQ-20261026 / S08 道具、合成、连击与终局规则对齐（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S08
前置步骤及证据：S07 完成（14 套件全绿，见上条）。
修改文件与作用：
- 指定目标替代任意指（§2.4）：prop_service.gd PROPS any_color→designated_target，激活只置 pending_effects.designated_selecting（不扣次，重复激活拒绝）；game_controller.gd 新增 designated_state/designated_cancel/designated_select_turret/designated_select_voxel——同色+未预订+confirm_reachable（target_selector 新增 confirm_reachable/pick_voxel，与正常选靶同一扫掠契约）全部通过才扣次并发 item_activated；try_auto_fire 经 _designated_target_for 优先锁定指定目标，失效清除并发 designated_expired（不退款）；turret 字典新增 designated_target 动态字段。
- 异色万能弹路径移除：projectile_system.spawn/ball_physics.spawn_ball 删 any_color 参数与字段；hit_resolver.gd（含旧异色消除+旧连击 API 的无引用死代码）删除。
- 存档/配置迁移：level_session.gd 默认 prop_counts/pending_effects 改 designated_target/designated_selecting，restore 时旧档 any_color 计数并入 designated_target、选择模式不落盘；game_rules.gd 默认值同步；level_01.json initial_props any_color:6→designated_target:6。
- 终局规则（S08 §4/§6）：outcome_state.evaluate 增 pending_tickets 参数——全清但有无未结算票据不判胜；死局分支（队列+槽全空、无球无票据、余块>0）在严格守恒下不可达，到达即守恒破坏 → outcome=ERROR + integrity_error 事件，不再包装成正常失败（level_lose 路径移除）；event_bus 白名单加 designated_expired/integrity_error。
- HUD（hud_presenter.gd）：道具行 any_color→"指定目标"（PROP_LABELS/PROP_PENDING 同步）；新增"合成"独立模式开关（非消耗道具，两列列首同色合成、失败提示、自动退出）；指定目标选择流程（点炮位选炮→main 路由模型点击→designated_pick_at，异色/遮挡/预订/点空分类提示且不扣次）；designated_expired→toast"指定目标已失效"；integrity_error→结算遮罩"数据完整性错误请重开本关"；5 秒无进展提示"旋转模型或更换炮台"（RUNNING 且未暂停才计时，消除/上位/发射/合成清零）。
- main.gd：模型点击路由——指定目标等选体素阶段、12px 内未移动的点按 designated_pick_at 处理（优先级高于旋转）；订阅 integrity_error 存档。
本步实现/参数决定：选择模式不持久化（恢复后不处于选择中）；指定目标在被接受后"下一发优先"，若取消返还目标仍存活则保持锁定（重试不额外扣次）；连击无改动（已是全局 1.5s 窗口、step() 受 is_running 门控天然暂停相容）。
实际命令、退出码、设备、构建标识：桌面 headless（macOS）；11 个改动脚本 --check-only 全过；15 套件全绿（新增 tests/integration/test_designated.gd 19 断言：不扣次三类拒绝/接受扣次/优先发射/失效提示不退款/全程守恒）；主场景 headless exit=0、0 SCRIPT ERROR。
测试：15/15 PASS（桌面）；test_gameplay 胜负真值表改为"全空+余块→integrity_error（不包装成失败）/全清有未结算票据不判胜"；test_play 死局用例同步改 ERROR。
截图或录屏现象及日志路径：桌面无画面；指定目标/合成模式/停滞提示的真机交互验收合并至 S10/S11。
颜色守恒统计：test_designated 末尾 conservation_audit 逐色 OK；test_auto_fire/test_play 守恒断言保持绿。
未解决问题与修复计划：指定目标点选与合成模式的真机触摸验收待 S10/S11。
下一步：S09 存档 v2 完善（模型哈希、RNG 状态）与生命周期。

## CQ-20261026 / S09 新存档与生命周期（CLAUDE 执行，2026-10-26，完成）
任务：CQ-20261026 / S09
前置步骤及证据：S08 完成（15 套件全绿，见上条）。
修改文件与作用：
- 快照 v2 字段（level_session.gd）：to_snapshot/restore 增 rng_state、model_hash、rules_version=2；restore 拒绝 version!=2；旧档迁移 any_color→designated_target 保留、designated_selecting 强制清零（选择模式不落盘）。
- 恢复校验（game_controller.gd）：_hash_model 用 HashingContext MD5（positions+colors 序列化 PackedFloat32Array 字节流）；恢复分支顺序 = session.restore → model_hash 不符("model_changed") → rules_version!=2("rules_version_changed") → 代号校验 → _validate_restored（炮台 ID 唯一、origin_column∈0..4、调色板颜色合法、逐色 Q+S==V，拒绝时 "snapshot_invalid: ..."）→ RNG 续跑（_rng.seed/_rng.state 双恢复）；_migrate_invalid_colors 移除（S09 §4 不静默迁移弹量）。修复 _validate_restored 中 var cid 类型推断解析错误（显式 int 标注）。
- 存档写入：save_session 前 session.rng_state = _rng.state；原子写（tmp+rename+校验）沿用既有实现。
- 旧档处置（main.gd + level_list_presenter.gd）：选关时 v1 旧档 → LevelRepository.backup_save 备份 + show_notice("关卡内容已更新，本关重新开始（旧档已备份）")后全新进入；恢复被拒（坏档/模型变更/规则变更/守恒破坏）→ 备份原档 + 全新会话重开，不静默覆盖；新增 show_notice UI。
本步实现/参数决定：v1 旧档不迁移只备份重开（文档 §4）；model_hash 覆盖模型全量几何与颜色，换模型即旧档作废；恢复后 session_generation 保留本次运行代号（旧事件天然失效）。
实际命令、退出码、设备、构建标识：桌面 headless（macOS）；5 个改动脚本 --check-only 全过；15 套件全绿（test_auto_fire 新增三类坏档拒绝断言：无效色 snapshot_invalid/弹药+1 conservation_broken/model_hash=deadbeef model_changed；test_persistence 新增 v2 往返 rng_state/model_hash/rules_version 与 any_color 迁移断言）；主场景 headless 8s exit=0、0 SCRIPT ERROR。
测试：15/15 PASS（桌面）。
截图或录屏现象及日志路径：桌面无画面；v1 备份提示与坏档重开的真机流程验收合并至 S10/S11。
颜色守恒统计：坏档守恒校验逐色 Q+S==V 拒绝 +1 弹药档；test_auto_fire/test_persistence 守恒断言保持绿。
未解决问题与修复计划：v1→v2 备份提示的真机目视、30 轮生命周期稳定性待 S10/S11。
下一步：S10 真机构建与性能（Pixel 7a 重打包 APK、版本号/SHA256 记录、FPS/p95/内存采样、三种长宽比截图）。

## CQ-20261026 / S10 进行中——真机触摸修复 + 选靶/物理性能优化与回归修复（CLAUDE 执行，2026-10-26，进行中）
任务：CQ-20261026 / S10（真机性能与交互验收）
前置步骤及证据：S09 完成（15 套件全绿）；S10 已构建安装 APK 0.3.0（version_code=3）于 Pixel 7a（35181JEHN08868）。
本轮修改文件与作用：
- 真机队列列触摸失效根因修复（hud_presenter.gd）：CannonView._ready() 在 add_child 时把 mouse_filter 重置为 STOP，吞掉队列区全部触摸；池视图 IGNORE 必须在 add_child 之后设置。修复后真机点击列首上位→自动补位→同色自动发射链路实测可用。
- 选靶性能（target_selector.gd）：逐色表面前沿去重集合（_frontier_set）防膨胀；暴露面位掩码 _face_mask（删除时 6 邻增量补面）+ 面半空间预过滤（首中必经暴露面，dot 阈值 0.4 便宜剔除背向候选）；结果负缓存 _target_cache（粗量化 key=颜色+原点 0.5 格，gen 失效）；热点 _last_target（上次目标+6 邻同色复核，可达性单调只减不增保证安全）；全扫描时间片 ≤3ms 断点续扫（_scan_state 按 key+gen，预订跳过时不缓存否定）。
- 空间索引重写（voxel_spatial_index.gd）：键 Vector3i→打包 int（21bit/轴），27 邻域改预计算打包偏移表 OFF27 免每格 27 次 Vector3i 构造+对象哈希；build 保留 Vector3i 转换的四舍五入语义。
- 关键回归与修复：重写后 test_designated 2 断言失败（designated_expired 不发）+ test_ball 4 断言失败。定位：打包键以位掩码表示坐标，球从模型界外负格坐标（底面下方边界原点）起飞，DDA 经过负格时掩码回绕 + 正邻域偏移加法会溢出 int64 符号位 → 邻域查找漏掉坐标 0 平面真实体素 → 球穿模不命中。修复：pack/pack_v 统一加 2^10 坐标偏置（[-1024, ~2^21) 坐标全非负，加减不借位）。test_ball 失败为测试自身直填 _cell 仍用 Vector3i 键，改用 pack_v 后通过。
- 调试输出清理：main.gd [input]、hud_presenter.gd [clip]/[hud]/[layout]/[perf]、game_controller.gd [perf] find_target 探针全部移除；target_selector.gd 孤儿 _ph0 移除（时间片 _slice_t0 为功能代码保留）。
- 新增调试工具（tools/，不入运行时）：debug_spatial_index.gd（OFF27 全坐标 [-40,40] 对照 pack 直算 off_bad=0、at() 4105 全命中、几何暴力 7053 期望候选 0 漏——含界外负坐标起点）、debug_designated.gd（指定目标流逐步追踪，修复后 vid=631 首发命中、expired=1、锁定清除）。
实际命令、退出码、设备、构建标识：桌面 headless（macOS）godot 4.7.2；索引三项校验全 0；debug_designated 确认首发命中；15 套件全绿（回归后复跑）。真机 APK 待清理后重建（当前设备安装包仍含调试输出与修复前索引）。
测试：15/15 PASS（桌面）；tools/cq_verify.gd 后台复跑中（验证选靶+索引改动后离线通关仍成立）。
截图或录屏现象及日志路径：reports/android/cq/s10/（此前截图：关卡列表/进关/上位修复后/五炮台并列）。
颜色守恒统计：15 套件内含守恒断言全绿；cq_verify 复跑待结果。
未解决问题与修复计划：修复前 APK 仍在设备上，需重建重装；120s 稳态性能采样（≥30FPS、p95≤50ms、≤512MB、60s 增长≤10%）待新包重做。
下一步：cq_verify 复跑确认 → 重建 APK（记录 commit/脏状态/模型哈希/APK SHA256）→ Pixel 7a 装包 → 120s 性能采样 + 三长宽比截图 → S10 收尾。

## CQ-20261026 / S10 平台转向记录（2026-10-26，用户指示）
用户指示：放弃 Android 打包循环，改 Mac app 开发（540×1200 手机屏幕比例窗口），平台不重要，优先可玩。CQ 文档中真机强制条款（T11-T16 真机部分）由用户本人暂停；后续性能/稳定性验收在 Mac 进行，Android 仅在用户要求时回归。
已完成（转向前）：APK 0.3.2/code5（SHA256 a2999d4b…57f8）装 Pixel 7a；旋转压力下暴露持续 7.5fps 死亡螺旋（p95 140ms+，物理追帧放大）；cq_verify 复跑 VERIFY_PASS（seed=4 actions=4229，扫描共享几何改动后仍成立）。
进行中：PerfProbe 子系统耗时探针已入代码（find_target/ball_step/hud_refresh/spawn_burst/mm_remove/scheduler_tick，5s 窗写 perf_log.jsonl probe 字段），用于在 Mac 定位旋转后扫帧尖刺的真实元凶。
下一步：Mac 窗口复现旋转压力场景 → 读 probe 分布 → 对症修复 → 15 套件 + cq_verify 回归。

## FM / F1 进行中——局部锁定弹道 + mismatch 风暴根因修复（CLAUDE 执行，2026-10-26）
任务：docs/tasks/2026-10-26-fast-moving-target-clear-plan.md F0~F1。
前置步骤及证据：F0 基线 reports/desktop/fm/f0-baseline.md（14/15，test_auto_fire 3 个 ball_speed=40 遗留失败）；存档目录注入 LevelRepository.set_save_dir + 全部测试隔离 user://test_saves/<name>_<pid>。
本轮修改文件与作用：
- F1 局部空间弹道：projectile_system.gd 重写（球记录 local_pos/local_dir，step 纯局部推进，spawn_local，erase_ball 即回收+有界 _ended_log）；ball_physics.gd 门面按本步 wfg 投影事件；game_controller._fire_at 改用 origin_grid 局部出膛方向；voxel_model_node.set_orientation 唯一姿态写入口+transform_version；marble_presenter 按当前 wfg×local_pos 投影。
- **mismatch 风暴根因**（tools/debug_refund_storm.gd：18 HIT/94 mismatch → 修复后 80 HIT/0 mismatch/80 发打空离场）：voxel_spatial_index._dda_cells 用 `signi(d.x)` 取浮点方向符号，signi 先把 float 截断成 int——步长分量 |d|<1 时全部归 0，step=(0,0,0)，DDA 空转到 4096 守卫返回起点格副本，候选只剩起点格 27 邻域；高速（speed40 步长 0.667）球贴近格边界起飞时，进入目标格的那一步候选漏掉目标 → 球停进预订目标扩张盒内 → start-inside 规则永久不可命中 → 蹭到邻格扩张盒 mismatch 返还 → 重发风暴（fires=281）。低速（speed12 步长 0.2）时起点格邻域足以覆盖，缺陷被掩盖。同类缺陷同步修复：target_selector._los_blocked、tools/cq_verify._los_blocked 共 3 处改 `int(signf(...))`。
- 回归：test_ball 新增"亚单位步长候选含终点邻格体素/进入扩张盒的那一步即命中"夹具（精确复现失败段 (10.818,2.9996,8.5)→(10.680,3.6517,8.5)）；test_designated "点空处" 改为指向模型外向下 -200（修复后 pick 是全程真实扫掠，向上 200 真穿模型命中——旧断言依赖缺陷）。
实际命令、退出码、设备、构建标识：桌面 headless godot 4.7.2；debug_refund_storm 修复后 ammo0=80 fires=80 HIT×80 alive=4025 炮台离场；15/15 套件全绿。
测试：15/15 PASS（桌面 headless）。
颜色守恒统计：修复路径不改计数语义；test_auto_fire 守恒审计（Q+S+F=V、V≤V0）绿。
未解决问题与修复计划：test_local_ballistics.gd（FM01-04 门禁：飞行中旋转/俯仰/平移仍中预订目标）未建。
下一步：建 tests/integration/test_local_ballistics.gd → F1 门禁 → F2 多球连发。

## FM / F2 完成——多球连发 + 选靶扫描修复 + 发射统计 + 自动旋转（CLAUDE 执行，2026-10-26）
任务：docs/tasks/2026-10-26-fast-moving-target-clear-plan.md F2（FM05~FM10）+ §11 自动旋转机制。
前置步骤及证据：F1 完成（18 套件含 test_local_ballistics 门禁全绿；mismatch 风暴根因=DDA signi 截断，已修）。
本轮修改文件与作用：
- 配置：game_rules.gd 新增 max_in_flight_per_turret=6/max_active_projectiles=30/auto_rot_deg_per_sec=8.0，auto_fire_interval→0.10，ball_speed→100.0（格/秒）；from_rules 解析新键；level_01.json 同步。
- 多球：try_auto_fire 闸门 in_flight>=1 → max_in_flight_per_turret（reason in_flight_cap）+ 全局 global_cap；auto_fire_scheduler 白名单加 in_flight_cap/global_cap，scan_pending/waiting_target 冷却置 0（下一物理步续扫，§5.3），成功冷却相位保留 clamp（防低帧率爆发也防拖慢）；shot_ledger 加 latest_ticket_by_turret（HUD 炮管瞄准已迁移）+ pending_count_by_turret。
- §6 原子命中提交：_on_ball_hit 重排 校验→destroy→成功才 settle_hit/事件；destroy 失败发 integrity_error（不静默退款）；删后断言 renderer.instance_count==alive_count；_refund_ticket 先看 settle_cancel.changed 幂等（多球乱序/重放不再重复加弹）。
- target_selector：预算检查移到内层循环每次迭代顶部（覆盖三条 continue 路径）；断点改 {start,k,ii} 整桶扫完才推进（修 §2.1 续扫跳过半扫桶漏扫）；ckey floori；负缓存 gen+tver 双匹配 + set_transform_version 每步注入；持续旋转负缓存不服务，改有界轮转学标 _rr_cursor（同 tver 完整扫完才许写负缓存）；缓存 256 有界裁剪；scan_budget_us 可注入 + dbg_neg_served 观测点。
- §11 自动旋转：game_controller.step 顶部 _apply_auto_rotation（选靶/推进前，每步至多一次 tver 递增）；+Y 正角=俯视逆时针；set_rotation_hold 由 main 模型区按下/释放/cancel_all/退后台/失焦注入；0.2s 渐入接续不回弹；指定目标选择中暂停；macOS 失焦只清手势不暂停；auto_rot_speed_deg 读数接口。
- 统计：新建 fire_stats.gd（attempt/success/hit/cancel 分类/waiting/scan_pending/10s 滚动每秒消除/飞行时长/等待占比/有效局时时钟）；perf_monitor stats_provider 合入 perf_log.jsonl；main.gd 接线。
- 关键发现（影响验收理解）：实体模型单炮只能消当前逼近壳上的同色块，壳耗尽即饿死——roguelike 式推进依赖多色炮台轮换暴露内部块；grid_300 单炮 6~9 发后永久 starving 属【正确玩法语义】。FM05 改用单色薄板夹具 assets/models/json/plate_300.json + tests/fixtures/level_fm05.json（注意 level_catalog MODEL_PREFIX 白名单只收 res://assets/models/json/）。
- 测试原点契约修正：三处 _aim_for 改为【世界空间固定原点，每次调用按当前 wfg 回算格原点】（真机语义：炮口世界不动、模型在下旋转，旋转才暴露新目标）；正下方原点位于旋转轴上永不移动是测试假象。
- 测试：新建 test_multi_ball.gd（FM05 grid_300/plate 夹具实测 10.11/s ≥ 9/s 门槛、80 发 7.92s 打空、零取消；FM06 三炮并发峰值在途 10 + 任意时刻 pending==reservations；FM07 后发先结算；FM08 命中/取消重放零二次副作用+守恒绿）；新建 test_selector_scan.gd（1µs 预算切片结果==全量、否定全扫 1132 切片覆盖 870 前沿、gen+tver 负缓存失效、轮转推进）；test_auto_fire 加多球峰值在途≥2 断言；test_local_ballistics 适配 waiting_target 续扫语义。
实际命令、退出码、设备、构建标识：桌面 headless godot 4.7.2；18/18 套件全绿（含两个新套件）。
测试：18/18 PASS（桌面 headless）。
颜色守恒统计：test_multi_ball FM05/FM07/FM08 守恒审计绿；test_auto_fire 守恒断言绿。
未解决问题与修复计划：取回流程仍在（F3 移除）；cq_verify 仍含 return 步（F3 重解）；自动旋转真机/窗口目视与 test_auto_rotation.gd 探针未建（F5/FM17-18）。
下一步：F3——删 HUD 取回按钮/模式/分支 + 控制器 return_turret/_do_return_to_column/_settle_return_pending + STATE_RETURN_PENDING/push_front，rules_version→3 状态白名单，cq_verify 去 return 重找种子。

## FM / F3 完成——取回流程：先移除后按用户决定保留 + 无取回可解性已证（CLAUDE 执行，2026-10-26）
任务：docs/tasks/2026-10-26-fast-moving-target-clear-plan.md F3。
前置步骤及证据：F2 完成（18/18 绿）。
本轮经过：
1. 按 F3 计划移除取回：HUD 按钮/模式/分支、控制器 return_turret/_do_return_to_column/_settle_return_pending、CannonQueue.STATE_RETURN_PENDING/push_front、rules_version→3+状态白名单、测试改造。
2. test_play 无取回驾驶死局（grid_300，alive=72/209/228 三次）→ tools/probe_stuck.gd 探针定位：可达窗口窄至 15° 量级（c4/c1 在 yaw15/pitch-60），离散朝向跳变系统性漏扫；c5 块被 c3 包围需间接暴露（正确玩法语义）。
3. **驾驶模型重写为世界固定炮口 + 模型自动旋转连续环绕**（真机验收配置）：格空间原点随 8°/s 自动旋转连续环绕模型，无进展只切炮口高度/方位（5 候选）。结果：6483 步=108s 全清 300 块，零取回，守恒绿。
4. **用户决定（2026-10-26）："为了测试方便，保留取回功能吧"** → 取回流程全部恢复（HUD/控制器/队列/测试），rules_version 回滚维持 2，状态白名单保留（含 RETURN_PENDING 合法、BOGUS 拒绝）；cq_verify 保留"无取回"更严格规则。
本轮修改文件与作用：
- 恢复：game_controller.gd（return_turret/_do_return_to_column/_settle_return_pending + _settle_ticket 收尾调用）、hud_presenter.gd（按钮/模式/toggle/状态映射）、cannon_queue_service.gd（STATE_RETURN_PENDING/push_front）、test_presentation/test_auto_fire 取回用例。
- 保留：VALID_TURRET_STATES 白名单校验（新增 BOGUS 拒绝用例 + RETURN_PENDING 恢复通过用例）。
- test_play.gd：_aim_for 改世界固定炮口（5 候选高度/方位），删除格空间方向跳变 _apply_orientation；_drive 无取回（停泊用满最后一槽 + add_slot）；死局诊断 _diag（槽位/队列/fire_stats）；步数上限 300000。
- cq_verify.gd：删除 return 操作（块4），死局=仅旋转、全周无进展=拒种；注释注明"验证器刻意更严格，游戏内取回保留"。
实际命令、退出码、设备、构建标识：桌面 headless godot 4.7.2；cq_verify `godot --headless --path . -s tools/cq_verify.gd -- 1 200` 首种即过。
测试：全套件绿（test_play/test_presentation/test_auto_fire/test_persistence + 全部 unit/integration）。
**无取回可解性证据（FM12 核心交付物）**：cq_verify 无取回 VERIFY_PASS seed=4（与 level_01.json 现 queue_seed 一致，无需改关卡）；s03-solution.json=4175 动作（fire×4105 恰好一块一发、place×50、park×3、rotate×17、**return×0**）。
颜色守恒统计：test_play 终局 Q+S+F=V=0 逐色绿；cq_verify 生成守恒报告绿。
未解决问题与修复计划：无（F3 门禁达成：cq_verify 无 return PASS + test_play 无 return 通关 grid_300）。
下一步：F4 剩余缺陷合并——initial_slots 应用（level_session:21）、speed_x2 already_pending 守卫、shuffle 每列≥2 守卫+单测、原子恢复（纯 validate_snapshot：alive 去重/范围、next_turret_id、锁槽 -1、V+D=V0 重算）、RNG 十进制字符串往返、HUD 同帧合并刷新、胜利校验加 active_balls==0&&renderer==0、运行中暂停按钮、交付前 PerfProbe ENABLED=false。

## FM / F4 完成——剩余缺陷合并（CLAUDE 执行，2026-10-26）
任务：docs/tasks/2026-10-26-fast-moving-target-clear-plan.md F4（计划 F4.1~F4.8；PerfProbe 关闭留待 F5 交付构建前）。
前置步骤及证据：F3 完成（取回按用户决定保留 + 无取回可解性 cq_verify PASS seed=4）。
本轮修改文件与作用：
- game_controller.gd：新局 unlocked_slots=clampi(rules.initial_slots,1,max_slots)（initial_slots 死配置激活）；_evaluate_outcome 传入 renderer.instance_count()；原子恢复接线——start_level 恢复前纯校验 validate_snapshot（含 VALID_TURRET_STATES 白名单/调色板/color_of 回调），旧 _validate_restored 删除（迁入纯函数）。
- level_session.gd：rng_seed/rng_state 十进制字符串往返 + _u64_from_json 兼容旧 number；新增静态 validate_snapshot（版本/归属、alive 去重+范围 [0,model_count)、turret id/键一致+状态白名单+origin_column 0-4+颜色合法、next_turret_id>max、队列/槽引用存在且唯一、锁槽必须 -1、槽位 <max_slots、逐色守恒 Q+S==V 用 color_of 重算）。
- outcome_state.gd：胜利判据加 active_balls==0 && renderer_instances==0（默认 -1=跳过，不破坏既有调用）；存活归零但实例未归零 → outcome=ERROR + integrity_error(renderer_desync)。
- prop_service.gd：speed_x2 已待发守卫 already_pending 不扣次数。
- cannon_queue_service.gd：shuffle 可洗前提从"总数<2"收紧为"至少一列≥2"（每列≤1 门时洗牌无意义，此前白扣次数）。
- hud_presenter.gd：事件订阅改置 _refresh_dirty 脏标，_process 每帧至多合并 refresh 一次（用户直接操作仍即时）；运行中暂停按钮 + 暂停遮罩（继续/重开本关/返回列表，走 _paused 门，仅 RUNNING 可暂停）；is_pause_overlay_visible 供 main 后台恢复不冲掉手动暂停；main.gd APPLICATION_RESUMED 加遮罩守卫。
- 测试：test_gameplay 加 shuffle 每列≤1 拒绝不扣 + speed_x2 已待发拒绝不扣；test_persistence 加大 rng_state（>2^53）JSON 往返无精度损失 + 恢复后 16 个 randi 序列一致 + 旧档 number 兼容；test_cannon_queue shuffle 夹具改 {1:300,4:270}（抽屉原理保证一列≥2，匹配收紧后可洗前提）。
实际命令、退出码、设备、构建标识：桌面 headless godot 4.7.2；逐套件 `godot --headless --path . -s <test>` 全 exit=0。
测试：18/18 PASS（桌面 headless，含 test_play 6483 步=108s 全清 grid_300 复跑通过；日志 reports/desktop/fm/f4/test_play.log）。
颜色守恒统计：test_play/test_auto_fire/test_multi_ball 守恒断言全绿（本轮未改动守恒路径）。
未解决问题与修复计划：HUD 合并刷新的"≤1 次/帧"PerfProbe 实测证明、PerfProbe ENABLED=false 交付开关，均在 F5 调参/构建阶段完成。
下一步：F5 macOS App 验收——export preset + .app 构建 + 可执行 SHA256 + build-info.md；tools/replay_runner.gd 实时回放 s03-solution.json；FM01~FM20 证据矩阵；节奏调优环（ball_speed 100-140/interval 0.08-0.12/max_in_flight 6-8 → 210~240s 有效局时）；cliclick+screencapture 关键帧；30 轮生命周期；新建 test_auto_rotation.gd 探针。

## FM / F5 完成——macOS App 验收与交付构建（CLAUDE 执行，2026-10-27）
任务：docs/tasks/2026-10-26-fast-moving-target-clear-plan.md F5（计划 F5.1~F5.5：构建/回放器/FM 矩阵/节奏调优/输入证据）。
前置步骤及证据：F4 完成（18/18 绿 + 全部缺陷合并）；基线 git 31417c5。
本轮修改文件与作用：
- auto_fire_scheduler.gd：waiting_target 冷却 0→0.25s（WAIT_RETRY_SEC，8°/s 下仅转 2° 不损机会粒度，扫描量降 ~15×）；scan_pending 仍 0 冷却即续。
- target_selector.gd：负缓存服务条件 gen+tver 双匹配 → gen+ckey（ckey=原点 2 格量化，floori）；扫描锚定 origin0/ckey0（多片扫描原点逐片漂移曾产出混合原点伪否定，锚定后消除）；_rr_cursor 轮转保持。
- main.gd：perf 日志隔离（is_isolated 时写隔离目录，修并发测试清真机采样竞态）；装配 replay_runner。
- replay_runner.gd（新）：CLI --replay/--replay-report/--replay-max-sec；place/park 按解列序驱动公开 API（place_front），fire 交自动连发、rotate 交自动旋转；5s JSONL 进度；报告含 pacing/fire_stats/守恒/渲染残留；结算屏停 5s 供关键帧。
- test_auto_rotation.gd（新，FM17/18）：俯视探针 CCW 符号+速率（10s≈79.2°）、30/60/120Hz 角位移一致（pairwise≤0.5°）、按住冻结/松手无跳角、指定选择/暂停冻结、tver +1/步、enabled=false 全停（PhiTracker 首点锚定修复）。
- tools/lifecycle_check.gd（新，FM14）：30 轮进关→游玩→返回列表，代际/存档/隔离校验。
- export_presets.cfg：[preset.1] macOS（universal runnable）；level_01.json 调优落点 ball_speed=120/interval=0.09。
- 交付构建：perf_probe.gd ENABLED=false（唯一与 run-1/2/3 二进制的源码差异）。
实际命令、退出码、设备、构建标识：`godot --headless --path . --export-release "macOS"` exit=0；最终 .app SHA256 b7d946af…4295（build-info.md）；实机 macOS 15.7.9 i7-8700B/UHD630，540×1200 窗口。
测试：最终源码全套件 19/19 PASS；lifecycle 30 轮 TEST_PASS；真档 shasum 前后不变（FM16）。
**真机回放四连 WON（自动旋转 8°/s 全开）**：221.3s / 215.9s / 236.8s（探针构建）+ **210.8s**（最终交付构建 run-4）——全部 ≤300s 且 210~240 目标带内；每局 4105/4105 命中、mismatch cancel 2/5/9/3（≤0.22%）、守恒绿、alive=0、renderer=0、op_mismatches=0。
FM14 性能（run-4 perf_log + run-5 RSS）：FPS min53.4/avg75.4；p95 max29.8ms；RSS 峰值 291.8MB、最差 60s 增长 +4.7% 趋平。（mem_static_mb 全 0 为 macOS 导出 API 缺口，已用 ps RSS 外部佐证。）
关键帧：t000/060/120/180 + r3_pre/mid/post_drag（cliclick 实拖朝向可见变化）+ r4_win_1..6（通关屏）。
节奏根因记录：持续旋转下 tver 每步递增 → 负缓存永不服务 → 饥饿炮全量重扫（实测 wait_ratio 0.889/scan_pending 20250）；修复=WAIT_RETRY_SEC + 锚定扫描原点 + ckey 负缓存。
未解决问题与修复计划：人工项（UI 实玩计时/后台重开/合成指定滚动）NOT_RUN 留用户确认；wait_ratio 0.57~0.73 偏高但 pacing 已达标，不继续优化。
下一步：FM 任务全部完成，交付物齐（fm-matrix.md / build-info.md / 四份回放报告 / perf_log_run4.jsonl / 关键帧）。等用户实玩确认人工项后可提交 git。

## 用户调整：去掉槽位锁 + 手机比例窗口（2026-10-27）
任务：用户两条指令——① 去掉锁；② 窗口大小用手机屏幕的窗口大小。
本轮修改文件与作用：
- assets/levels/level_01.json：rules.initial_slots 3→5（5 槽全解锁，"锁"消失）；initial_props 移除 add_slot（全解锁后该道具无意义；HUD refresh 对 count=0 道具按钮自动隐藏，界面无死按钮）。
- scripts/data/game_rules.gd：默认 initial_slots 3→5、默认 initial_props 同步移除 add_slot。prop_service 仍保留 add_slot 实现（test_gameplay 满槽拒绝用例依赖）。
- project.godot：窗口 window_width_override=540 / window_height_override=1200（9:20 手机竖屏）、resizable=false、stretch aspect expand→keep（修复 1080×2400 视口被 macOS 夹成 1080×1366 近方形后 expand 横向扩边的问题）。
实际命令、退出码、设备、构建标识：`godot --headless --path . --export-release "macOS"` exit=0；新 .app SHA256 53abd9ae9bf097dac7cfb80a3ac8c399999cd9f75b5a58575ea333d7fcbe8d60。
测试：全套件 19/19 PASS（桌面 headless）；真机目检：窗口 540×1228（含标题栏）、槽位行 3 占用+2 空、无"锁"、道具行无"加槽"、存档正常恢复续玩。
未解决问题与修复计划：无。replay_runner 开局的 use_prop("add_slot") 现在会返回失败并记录在报告 meta（无害，5 槽开局节奏只会更好）。
下一步：等用户实玩确认（此前 FM 人工项：UI 实玩计时/后台重开/合成指定滚动）后提交 git。

## 2026-10-27 交互打磨（P0 核查 + §9 收尾修复）

改动文件、目的：按 `docs/tasks/2026-10-27-interaction-polish-plan.md` 启动 P0~P5。
- P0 核查结论：旋转两套角度（gesture_router 内部 _yaw/_pitch vs main 四元数累乘）、上位瞬移（place_front 立即 READY + HUD ghost 只有 TEX_BODY）、耗尽瞬消（_settle_ticket 直接 erase+空槽）、选靶仅中心瞄点/分片旧原点无终核/负缓存无 TTL——全部在源码中复核属实，逐项进入 P1~P4。
- **§9 修复 1（真 bug，probe 证实）**：`level_session.gd` validate_snapshot 在 restore() 键归一化之前用 `turrets.has(int)` 查键，而磁盘 JSON 读回后键是 String——真实中局存档（槽位非空/队列有引用）恒被拒（`queue_refs_missing_turret`），玩家重启必丢进度。修复：validate_snapshot 开头把 turrets 键归一化为 int 再校验。补磁盘端到端用例（test_persistence：控制器中局落盘→磁盘读回→断言键为 String→start_level 恢复成功且 alive/slots 一致）。
- **§9 修复 2**：`level_repository.backup_save` 不再忽略 rename 返回值（失败返回空串+push_warning，先删旧 .bak 再备份）；main.gd 所有 save_session 调用收敛到 `_save_checked()` 检查返回值并告警；坏档备份失败时明确提示"原档仍在"。
- 遗留观察（未完全定位，不影响修复结论）：01:37 验证启动时窗口曾短暂显示疑似恢复态（剩余3705），与校验恒失败矛盾；当时存在两个 voxel 窗口（4856 旧、4872 新），点击坐标同时落在两者区域内，疑为旧实例窗口所致。§9 修复后 E2E 已证明恢复链路正确，后续 UX 验收再观察。
测试：test_persistence 全 PASS（含新 E2E 用例）。
实际命令、退出码、设备、构建标识：`godot --headless --path . -s tests/persistence/test_persistence.gd` exit=0（桌面 headless）。
未解决问题与修复计划：P1~P4 待实施；01:37 恢复显示之谜留 UX 验收观察。
下一步：P1 旋转——控制器唯一 yaw/pitch 状态（B=Rx(pitch)×Ry(yaw)×B0，pitch±60°），gesture_router 只报原始像素位移，输入在 step() 顶部统一应用。

## 2026-10-27 交互打磨 P1：旋转重构为控制器唯一 yaw/pitch 状态

改动文件、目的：
- `scripts/app/game_controller.gd`：新增唯一视角状态 `_view_yaw/_view_pitch`（+待应用输入队列 `_pending_dyaw/_dpitch`）；`_apply_view_rotation(dt)` 在 step() 顶部统一应用手动输入与自动旋转；姿态按 `B=Rx(pitch)×Ry(yaw)` 重建（外层 Rx 保证任意 yaw 下上下拖=屏幕俯仰、竖直轴不随 yaw 积累侧倾）；pitch 钳制 ±60°（越界部分丢弃、反向立即响应，不再整段吞输入）；自动旋转沿同一 yaw 轴保持当前 pitch（pitch=0 时与旧固定 +Y 行为等价）；start_level 切局重置视角与渐入状态（旧存档无姿态字段=默认正面 yaw=PI）。
- `scripts/input/gesture_router.gd`：删除内部 _yaw/_pitch/sensitivity/pitch_limit/current_angles——只路由已归属指针的原始像素位移（方案 §3.1 消除"两套角度"）。
- `scripts/app/main.gd`：`_apply_rotation` 改为像素位移×分轴灵敏度（横扫全宽≈180°、模型区纵扫≈120°）后入队控制器；`_frame_model` 不再直写 Basis（start_level 已校准初始姿态）。
- 测试迁移：test_input（原始位移透传断言）；test_rotation（同步冲刷 `_apply_view_rotation(0.0)`；钳制更新为 ±60°；新增 UX02 交替 20 轮回零无 roll、UX03 边界满幅+反向立即响应、UX01 侧面 ±90° 持续下拖不倒立）；test_auto_rotation / test_local_ballistics（姿态改写走 `set_view_pose` 唯一入口，禁止直写 Basis）。
实际命令、退出码、设备、构建标识：全套件 19/19 PASS（桌面 headless，各 `godot --headless -s tests/...` exit=0）。
未解决问题与修复计划：手感（UX01/03/04 主观项）待 P5 真机 App 拖动验收。
下一步：P2 上位——真 LOADING 阶段（模拟时钟 0.28s、到位才注册开火）+ 完整炮台过渡层动画。

## 2026-10-27 交互打磨 P2/P3：上位真阶段 + 耗尽退场收缩淡出

改动文件、目的：
- `scripts/app/game_controller.gd`：LOADING_SEC=0.28/RETIRE_SEC=0.20 模拟时钟常量；place_front → LOADING（不注册调度，到位才 READY+register+发 turret_ready[tid,slot]）；`loading_progress/retire_progress/retiring_active/_tick_transitions/_begin_retire`；`_settle_ticket` 按 ammo/in_flight 真实数值收尾（在途>0 等待 → RETURN_PENDING → 零弹退场、有弹回队列 → ammo≤0 → RETIRING）；return_turret 拒 LOADING/RETIRING，零弹取回=退场删除不回队列（UX08）；step() 在 outcome 非 RUNNING 时仍推进过渡时钟（胜利遮罩延后支撑）；save_session 把 LOADING 归一为 READY、RETIRING 立即结算完再快照（恢复不重播、不卡位）；VALID_TURRET_STATES += RETIRING。
- `scripts/gameplay/cannon_queue_service.gd`：STATE_RETIRING 常量。
- `scripts/presentation/cannon_view.gd`：新 "loading"（只显基座半亮，无炮管/数字）与 "retiring"（灰化归入 draining 组）状态。
- `scripts/presentation/hud_presenter.gd`：`_transition_layer` 过渡层 + `_transitions`（tid→完整 CannonView 飞行体）；bind() 清过渡+订阅 turret_ready/retire_finished；点列上位时若该列在上位中则 toast"上位中…"拒绝；`_begin_place_transition` 完整炮台（身/管/色/数）从队列位飞到槽位，逐帧由 `controller.loading_progress(tid)` 驱动（不依赖 Tween 回调，headless 不可卡）；`_tick_retire_visuals` 收缩 1→0.15 + 淡出；`_reset_slot_fx` 幂等复位；refresh 对 LOADING/RETIRING 显对应状态且禁用；WON 结算遮罩在 retiring_active() 期间延后（retire_finished 事件+_process 兜底）；`clear_transitions()` 供重开/返回清理；炮管瞄准与 muzzle 投影跳过 loading。
- `scripts/app/main.gd`：`_cleanup_session` 调 `hud.clear_transitions()`（重开/返回取消旧动画对象）。
- 测试迁移/新增：test_auto_fire（LOADING 中取回拒绝后等待落地再取回）；test_presentation（过渡层子节点断言、LOADING 等待）；tests/integration/test_loading_retire.gd（新，30 断言：LOADING 时钟内零开火/到点注册/进度可读；上位中取回拒绝；保存归一 READY 且恢复不卡；自然耗尽 DRAINING→RETIRING 保槽→释放删除；终局后 RETIRING 时钟照常走完；零弹取回 pending→退场删除不回队列；两路径守恒审计绿）。test_designated（LOADING 等待期屏蔽 origin_resolver 防调度抢先打掉指定目标）。
- 测试修复说明：test_loading_retire 首版改写 ammo_remaining 被守恒审计正确抓获（Q+S+F==V 每色守恒），改为自然耗尽路径——审计本身有效。
实际命令、退出码、设备、构建标识：全套件 20/20 PASS（桌面 headless，逐套件 `godot --headless --path . -s tests/...` exit=0，含新 test_loading_retire）。
未解决问题与修复计划：上位/退场动画观感（UX05/06/07 主观项）与胜利遮罩延后实测待 P5 真机 App 验收。
下一步：P4 选靶——暴露面多点真实扫掠契约 {voxel_id, aim_grid_point, face_id, origin_used, geometry_version}、_fire_at 发射前当前原点终核、负缓存 TTL≤100ms、等待原因可审计。

## 2026-10-27 交互打磨 P4：选靶——暴露面多点真实扫掠 + 负缓存有界失效 + 旧原点终核

改动文件、目的：
- `scripts/gameplay/target_selector.gd`：选靶从"仅中心瞄点"升级为多点契约 `{voxel_id, aim_grid_point, face_id, origin_used, geometry_version}`。中心被挡时对朝向原点的暴露面采样 5 点（面中心 + 0.2/0.8 内缩角，法向阈值 rel·n>0.2），瞄点向块内偏 0.06 格（DDA 终点=目标格不误伤自身，扫掠穿过扩张盒表面）；每点 DDA 预过滤+真实球半径完整扫掠，只有 first_hit==目标才接受——不穿透异色、不假删。新增 `confirm_reachable_mp`（指定目标与普通选靶同一多点接口）、`confirm_aim`（发射前终核）；`confirm_reachable` 委托 mp 版。负缓存条目带 `sim_t`：gen 匹配且（tver 精确匹配长期服务，或 TTL≤0.1s 短暂退避）——持续旋转下同粗原点格内目标变可达不永久封锁（UX11）；age<0（时钟域保护）不服务。`set_clock/begin_step`：模拟时钟注入 + 全局步预算 6ms 全炮台共享（分片候选顶部检查）。模拟时钟默认 0（独立使用 TTL 永不超时=FM/F5 语义，不混墙钟——实测墙钟写入 0.537s 与模拟时钟 0.016s 混域产生负 age 永久服务 bug，已修）。
- `scripts/app/game_controller.gd`：step() 每步 `set_clock(_sim_time)+begin_step()`；`_fire_at` 用契约 `aim_grid_point`（无则回退中心）算弹道、写入票据与事件快照（炮管瞄准/弹道/预订同点）；`try_auto_fire` 发射前终核——分片成功候选锚定旧原点（origin_used≠当前炮口）时用当前原点 confirm_aim 同一瞄点，失败不扣弹不开火、reason=revalidate_failed（UX12）；`designated_select_voxel/_designated_target_for` 走多点接口。
- `scripts/gameplay/auto_fire_scheduler.gd`：revalidate_failed 冷却 0（下一物理步重试，与 scan_pending 同）。
- `scripts/gameplay/fire_stats.gd`：revalidate_failed 计数（等待原因可审计，snapshot 带出）。
- `scripts/presentation/hud_presenter.gd`：炮管瞄准取票据 aim_grid_point（与弹道同点）。
- 测试迁移/新增：`tests/integration/test_targeting_points.gd`（新，27 断言；夹具 ux_targeting_300.json：T(5,8,5)色1+B(3,1,4)色2+298 色9 平板，几何经 probe 数值验证）——UX09 中心被挡面角可达：契约层（face=3 aim=(5.8,8.06,5.2)≠中心）+真实飞行命中 T 只减一（B 存活、弹药 3→2、1 命中 0 取消、票据/快照/炮管同点未换回中心）；UX10 笼形/全挡原点：多点确认全拒、不穿透不假删不扣弹、reason=no_reachable_target 计入统计；UX11 负缓存：同 gen+tver 服务、超 TTL 立即重扫命中（<0.2s）、控制器级 7 帧内开火；UX12 分片锚定旧原点：片1 scan_pending→换原点片2 终核否决（无预订泄漏、revalidate_failed+1）→原点恢复立即开火。test_selector_scan：drain 续扫辅助 + TTL 语义断言更新。
实际命令、退出码、设备、构建标识：全套件 21/21 PASS（桌面 headless，`godot --headless --path . -s tests/...` 逐个 exit=0，含新 test_targeting_points 27/27）。
未解决问题与修复计划：多点扫掠对真实关卡节奏/性能的影响（每秒扫掠次数、wait_ratio、revalidate_failed 占比）待 P5 全清回放量化；选靶手感（UX09/10/11 实机观感）待 P5 App 验收。
下一步：P5——全新 macOS .app 构建 + UX01~UX14 实机逐项验收（拖动/上位/退场/选靶观感，关键帧或录像）+ 全清回放 ≤300s（LOADING/RETIRING/新选靶全开）+ 性能（FPS≥30/p95≤50ms/RSS≤512MB/120s+/30 轮生命周期）+ 最终报告（含 .app SHA256 与诚实 NOT_RUN 项）。

## 2026-10-27 交互打磨 P5：集成验收——全新 .app + 13 连 WON 全清回放 + 性能/生命周期

改动文件、目的：无代码改动（纯验收）。全新导出 `builds/macos/VoxelBlockSmash.app`（SHA256 d3cf2eea…e153，build-info 见 reports/desktop/ux/build-info.md）。
- **UX13 全清回放 ×13 连 WON**：171.3/182.5/171.7/184.5/169.9/178.5/169.8/170.9/170.1/170.6/169.4/169.9/190.9s（mean 174.6s，全 ≤300s，有效=墙钟），每局 4105/4105、renderer=0、守恒绿、0 取消、revalidate_failed 7~18（旧原点终核正确拦截）。比打磨前基线 210.8~236.8s 快 ~20%。最慢 190.9s 发生在用户切走桌面 Space 后（窗口隐藏节流），仍达标。
- **UX14 性能**：对局期 FPS min 42/avg 81.6（≥30 ✓）；p95≤50ms 在 35 采样中 32 达标，3 个尖峰（开局建模 71.7/56.7ms、对局中 59.2ms 单点）；RSS 338→339MB/190s 平坦（≤512MB ✓、零增长 ✓）；tools/lifecycle_check.gd 30 轮进关/游玩/返回全 PASS 无泄漏。
- **视觉证据**：12s 对局录像 ux_replay_segment.mov + 5fps×20 帧窗口拼贴 seg_tile.png（可见连续自动旋转、剩余数单调下降、DRAINING"0"灰显→RETIRING→空槽→新炮补位全过程）。
- **01:37 恢复显示之谜闭环**：系遗留旧 App 实例（PID 70871/窗口 4872，闲置 6000+s 仍写同一 perf_log）造成双窗口混淆，已结束该进程。
- **观察项（非阻塞）**：origin_ray_miss 调度重试 294/17195（1.7%，最大连击 40），FM 轮既有（fire_geometry 屏幕射线∩旋转后格空间 AABB 近切线未命中），白名单冷却内恢复，不影响命中率；建议后续加炮口射线未命中回退边界中心。
实际命令、退出码：21/21 套件 exit=0；`godot --headless --path . --export-release "macOS"` exit=0；13 次 `.app -- --replay=…s03-solution.json` 全部 exit=0 WON；lifecycle_check exit=0。验收矩阵与 NOT_RUN 项：reports/desktop/ux/ux-acceptance.md。
未解决问题与修复计划：结算屏截图 BLOCKED(环境：用户切换桌面 Space 致跨 Space 截图失败，报告/测试已证 WON)；UX01/UX04 主观手感待用户实玩；截图工具坑（activate 会拉起新实例、stdout 块缓冲、跨 Space 截图失败）已记录进验收报告供后续。
下一步：等用户实玩确认手感（UX01/04）与逐项 UX 观感；用户确认后再提交 git（工作区 28 文件 dirty 未提交）。
