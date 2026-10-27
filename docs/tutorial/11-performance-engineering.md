# 第 11 章：性能工程从正确的问题开始

[上一章](10-loading-and-retiring.md) · [总目录](README.md) · [下一章](12-testing-and-evidence.md)

## 本章目标

通过 HUD 刷新、球对象回收、扫描预算和 p95 解读四个案例，学习“现象→定位→修复→验证”的完整方法。理解为什么没有每项独立 A/B 数据时不能给它们分摊最终提速百分比，以及为什么平均 FPS 足够高仍然可能不满足尾延迟要求。

## 概念讲解：先定义测量对象和分母

一帧包含输入、脚本、物理、渲染提交、GPU 工作和等待。只测 GDScript 函数不能代表端到端帧时间；只看 FPS 也不能知道 CPU 和 GPU 谁慢。[scripts/diagnostics/perf_monitor.gd:31](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/diagnostics/perf_monitor.gd.txt:31)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/diagnostics/perf_monitor.gd#L31) · [仓库内快照](source-baseline/scripts/diagnostics/perf_monitor.gd.txt)） 收集帧 delta，每约五秒排序计算平均和 p95，并写 JSONL。它记录的是窗口统计，不能从一个 p95 数字反推出某一个具体函数耗时。

PerfProbe 给选靶、球步进、HUD 刷新、碎片等阶段打点，见 [scripts/diagnostics/perf_probe.gd:6](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/diagnostics/perf_probe.gd.txt:6)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/diagnostics/perf_probe.gd#L6) · [仓库内快照](source-baseline/scripts/diagnostics/perf_probe.gd.txt)）。当前交付源码开关为 false，因此没有探针数据不等于所有函数零成本。性能报告必须记录是否启用探针，因为测量本身有开销；“关闭探针”也不等于性能监视器和所有日志都关闭。

内存指标同样不能混用。Godot 静态内存 API 在历史导出环境返回 0，于是报告用操作系统 RSS 佐证。这个 0 是观测接口缺口，不是游戏零内存。Android PSS、Mac RSS、GPU 显存和引擎内部统计不能直接混在一列比较，应分别注明口径、单位、采样方式。

## 动手步骤：四个真实案例

### 案例一：一次命中触发多次 HUD 刷新

现象：高频事件可能每次都刷新全部控件，短时间内重复布局和文本更新。定位时先数调用次数，再测每次耗时。如果单次 0.2ms，一帧执行十次就是 2ms，不能因单次“很快”忽略它。当前修复是事件设置 `_refresh_dirty`，在 `_process` 中集中执行一次，用户直接操作仍可以即时刷新。

实现位置 [scripts/presentation/hud_presenter.gd:47](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/presentation/hud_presenter.gd.txt:47)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/presentation/hud_presenter.gd#L47) · [仓库内快照](source-baseline/scripts/presentation/hud_presenter.gd.txt)） 和 [scripts/presentation/hud_presenter.gd:588](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/presentation/hud_presenter.gd.txt:588)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/presentation/hud_presenter.gd#L588) · [仓库内快照](source-baseline/scripts/presentation/hud_presenter.gd.txt)）。不要把它概括成“任何情况下每帧最多一次 refresh”，因为直接调用路径仍存在。准确说法是事件驱动刷新按帧合并。验证应统计实际调用和控件表现，而不是只搜索到一个 dirty 字段就算优化完成。

历史整体回放可作为合并后的系统证据，但没有找到只开关 HUD 合并的独立 FPS 对照。因此本案例的单项提速幅度写 NOT_MEASURED。建议实验固定种子和相同回放，记录 refresh 次数/帧、总耗时和交互延迟；如果省了调用却让数字慢一秒更新，也不能算成功。

### 案例二：结束球仍留在容器

现象：活跃球数上限只有 30，运行对象却可能随累计发射增加。定位不能只看 active_count，要检查 `_balls.size()` 和结束历史长度。当前 [scripts/projectile/projectile_system.gd:14](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/projectile/projectile_system.gd.txt:14)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/projectile/projectile_system.gd#L14) · [仓库内快照](source-baseline/scripts/projectile/projectile_system.gd.txt)） 将历史限制为 64，BallPhysics 在结果事件派发后回收 ended 球。顺序保证接收方仍能取得必要快照。

修复目标有两个：活跃集合保持有界；结束和命中事件仍带完整 shot_id、颜色和位置。若先回收再派发，内存曲线很好看但结算丢失，这不是有效优化。已有多球测试和生命周期测试用于回归，UX 的 RSS 约 338→339MB 是系统级稳定证据，不能独归因于这一项。

建议读者在实验副本观察十局、二十局后的容器计数，而不是只比较启动前后两个内存读数。分配器可能保留已释放的页，RSS 不立即下降不等于泄漏；持续对象计数增长比短时内存抖动更有诊断价值。需要同时看逻辑对象数量与进程长期趋势。

### 案例三：预算写了却没有约束所有路径

现象：配置了 3ms 扫描预算，旋转时仍出现长步。定位发现预算判断放在昂贵操作之后，前面的 continue 分支绕过检查。修复移到候选循环顶部，并保存正确桶内游标。对应开发记录 [docs/dev-step-log.md:391](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/docs/dev-step-log.md.txt:391)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/docs/dev-step-log.md#L391) · [仓库内快照](source-baseline/docs/dev-step-log.md.txt)）。

验证包括极小预算下分片结果等价、不会跳过半桶、轮转游标前进。后来增加每步 6ms 共享预算，避免五门炮各花 3ms。注意不是单次预算从 3 改成 6；这两个维度分别限制单次查询和一轮调度。第 8 章指出的热点与建桶范围仍需额外 profiling，所以不要把配置值当成硬实时保证。

历史旋转压力曾在 Pixel 7a 降到约 7.5fps；后续在 Mac 定位和优化，不构成同设备前后对照。Android、Mac、软件渲染模拟器的结果必须分开。准确结论是旧设备场景存在严重问题，当前 Mac 构建已有改善证据，而最新 Android 结果需另测。

### 案例四：p95 尖峰怎样归因

UX 报告记录 FPS 最低窗口值约 42、平均 81.6，35 个窗口中 32 个 p95≤50ms，三个窗口分别 71.7、56.7、59.2ms。前两个在开局，报告归因为建模和首扫；另一个归因为重扫尖峰。这是历史报告的解释，不是本次重新采集的 profiler 证明。

尤其要纠正“p95 超标说明只有一个坏帧”。p95 是窗口内排序位置，单个最大值未必影响它；没有逐帧序列就无法断言只一帧。也不能用平均耗时≤23.8ms证明尾延迟达标。若验收规定每个窗口均≤50ms，这一严格条件未完全满足，即使原报告总标题写 PASS，也应保留 3/35 的例外。

下一步验证可以区分启动窗口与稳定对局窗口，但规则必须预先制定，不能测完才随意排除难看的数据。给开局建模单列预算、记录首次可交互时间，可能比把所有异常一律归“加载正常”更符合玩家感受。稳定场景中的重扫尖峰仍应提供调用链或探针窗口关联。

### 参数演进：控制变量而非迷信数值

开发记录支持默认 ball_speed 从 40 提到 100，发射间隔从早期 0.25 到 0.10；F5 当前关卡进一步使用 120 和 0.09。UX 加入多点选靶与缓存修复后，历史通关从 FM 的 210.8～236.8 秒下降到 UX 的 169.4～190.9 秒。中间多项变化同时发生，不能把全部收益称为“球速提高带来 20%”。

扫描、射速、在途上限和球速彼此制约。上限太低时缩短间隔无效；没有可达目标时提高球速也无效；预算太松则逻辑吞吐增加却拖垮帧率。因此调参应先记录等待原因，再选一个变量做小范围实验，保留失败数据。任何只写最终推荐数字、没有单位和场景的配置建议都不够可复用。

### 延伸练习：写一张不会误导的优化表

表中至少有场景、构建、样本时长、参数、平均帧时、p95、命中吞吐、峰值内存与备注。每项优化先定义成功标准：例如刷新合并应减少重复调用，同时数字延迟不超过约一帧；球回收应使对象数量有界，同时所有结束事件仍被结算。只有性能收益而没有行为回归条件的实验，很容易把错误程序测得很快。

如果两次运行有差异，不急着下结论。检查是否同一关卡、同一随机种子、同一窗口可见性、同一后台负载。尤其在多个AI工作区同时导出时，CPU和磁盘竞争会改变结果。独立worktree隔离文件，不隔离硬件。可以并行写代码，但基准测量最好错峰，记录无法控制的外部因素。

没有单项前后数据时，仍可以交付有价值的结论：指出不合理控制流、给出回归用例、说明最终系统指标，并明确因果证据不足。诚实地写“没有单独量化收益”不会削弱教程，反而让读者学会不把相关性当因果。下一轮真正要投入优化工时时，这种边界会帮助决定先补哪项测量。

## 踩坑记录：观察工具也会改变现场

历史旧实例仍写同一 perf_log，使新运行的日志被污染。最直接的预防是每次测试独立输出目录、记录 PID 和构建哈希。不要只按进程名字批量杀游戏，因为另一位开发者可能正在测试同名实例。确认自己启动的进程后再结束，是多工作区并行时必要的操作边界。

stdout 重定向可能块缓冲，长时间没有打印不等于程序卡死。JSONL 定期 flush、进度文件和进程状态更适合判断活性。反过来，频繁 flush 也可能影响性能，因此诊断构建与交付构建要明确区分，不能把测量开销变成游戏常驻成本。

还有一个统计陷阱：历史 `destroys_per_sec=11.4` 是统计窗口值，不是 4105/171.3 的整局平均。整局平均约 24 块/秒，窗口值可以低于它，因为结尾颜色稀疏、等待更多。没有看实现就把两个值叫同一个“消除速度”，会错误判断报告矛盾。

## 验证方法

优先离线检查已有报告，不为写教程再启动十三局。第 12 章给出批量汇总脚本。需要新测量时固定构建、种子、窗口大小、后台状态和采样工具，单独运行一个游戏实例。人工手势和自动回放是两种 workload，应分开记录。

Mac 上采样指定进程 RSS 的示例，需先把变量设置为自己启动的实际 PID：

```bash
export TUTORIAL_GAME_PID=12345 # 替换为本次实际PID，不能照用示例数字。
ps -p "$TUTORIAL_GAME_PID" -o pid=,rss=,etime=,command=
```

若环境不允许 ps，就标记受限，不填估计内存。正式 120 秒采样、60 秒增长窗口和 30 轮生命周期只在需要验收时执行，不要在每次文字修改后重复。

本章完成后你应该能写出包含对象、指标、条件、证据和限制的性能结论，而非只有“优化后更流畅”。每个案例都给出了完整验证路径；缺少单项实测数据的地方明确留空，正是方法论的一部分。

## 小结

性能工程既优化程序，也优化判断。测量范围、单位、对照条件和统计口径正确，代码修改才有可信方向。下一章把这些证据组织成可重复运行的测试体系。

[上一章](10-loading-and-retiring.md) · [下一章](12-testing-and-evidence.md)
