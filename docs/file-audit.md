# 文件与交付缺口核对

时间：2026-10-26（Asia/Shanghai）。核对基准：GDD v6、architecture v6、PLAN v3、P1-INIT-v6。此报告不是阶段验收通过记录。

## 实际文件

核对前除.git外共7个文件：.gitignore以及docs/game-design.md、AI-WORKFLOW.md、dev-step-log.md、architecture.md、plan.md、tasks/phase-1-init.md。本轮新增本报告并追加日志。

## 当前阶段缺项

- README.md、.editorconfig、project.godot、scenes/main/main.tscn。
- scenes/、scripts/、assets/、tools/、tests/、reports/、builds/及架构列出的子目录；docs/reviews/也未创建。
- architecture目标树中的31个可解析占位.gd，实际0个。
- docs/asset-manifest.md、docs/test-report.md、docs/review-context.md。
- reports/desktop/p1-init-validation.md、占位解析/编辑器导入/主场景启动原始日志、准确Godot版本/路径/渲染器证据及执行端运行现象文字。

这些由Claude按P1-01～06交付；Codex收到证据才能评审。未运行Godot，不能判断环境是否可用。

## 发现的问题与修订任务

1. .gitignore第5行忽略builds/父目录，后面的!builds/**/.gitkeep不能恢复其中占位。已运行git check-ignore -v builds/android/.gitkeep，结果命中builds/。Claude在P1-02保留现有配置并修正父目录/子目录排除顺序；验收要求.gitkeep不被忽略、APK仍被忽略、.uid不被忽略。当前仅记录问题，未改配置。
2. plan.md P3-02写“只发布已提交事件”，但architecture明确ball_hit_voxel为删除判定前的碰撞事实。需将该行区分“碰撞事实”与“已提交状态事件”，避免实现遗漏命中事件；按architecture详细契约评审。
3. architecture目标树把level_list.tscn、hud.tscn、hit_particles.tscn标为阶段5，而plan阶段4要求最小列表/UI/粒子。需明确这些文件阶段4建最小版本、阶段5完善，或在阶段4明确临时验证场景路径，避免执行方误判跳阶段。
4. 模型JSON schema已有文字契约，但assets/levels/level_01.json的必填字段、类型、规则引用格式及错误处理还未形成完整文件级契约；须在P2-02执行前补齐。正式弹量/道具/存档等参数依旧按GDD D项确认，不由导入工具猜测。

## 后续阶段缺项（当前无需提前创建）

阶段2的原始vox、青蛙JSON、导出工具、最小导入实现、UI贴图及授权存档；阶段3～5的业务/物理/UI/音效实现；阶段6的导出配置/APK；阶段7的模拟器测试证据。现阶段没有这些文件是正常待办，不应跳阶段补齐。

D01～D11仍有未决内容，包括槽初值、合成上限、球体参数/边界、道具次数、调色板/分布、UI操作参数、性能阈值、失败真值表、保存范围、重置和穿透道具歧义。它们不阻塞阶段1基础初始化，仅阻塞相关后续任务。

## Git状态

本地Git已经初始化，最新提交为d935e5e（阶段1设计文档v3）；当前5份已跟踪文档有修改，plan.md未跟踪。git remote -v输出为空：此本地仓库未配置远端，不能据此声称已同步GitHub。未联网核实远端仓库是否存在。本轮新增报告与日志变更也未提交。

## 下一步

先修正文档中的阶段/事件表述，再由Claude执行P1-01～06并修正忽略规则；保留已有正式文档和Git历史。初始化交接之前不标阶段1验收完成。
