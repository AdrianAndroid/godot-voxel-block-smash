# 第 12 章：让测试说明自己究竟证明了什么

[上一章](11-performance-engineering.md) · [总目录](README.md) · [下一章](13-build-and-delivery.md)

## 本章目标

找到真实测试入口，运行分层套件，读取十三份历史回放，并为证据划清边界。完成后，你能分别回答：纯逻辑是否正确、实际控制器是否协作正常、导出 App 是否真实完成一局、动画是否被观察过，以及哪些仍需人工确认。

## 概念讲解：测试层级不是质量等级

单元测试（Unit Test）使用小输入，定位失败快。例如测试票据重复结算只需创建一张票，不需要整个青蛙。集成测试（Integration Test）连接控制器、模型、物理和服务，证明接口契约一致。导出回放启动真实 App，通过公开操作驱动完整流程。人工测试观察触感、视觉连续和可理解性。这些测试回答不同问题，不能相互替代。

headless 只是无图形界面的运行方式，不意味着被执行内容都是单元测试。加载真实控制器和完整模型的脚本依然是集成测试；反过来，真实 App 被自动回放驱动也不等于人工试玩。写报告时把“运行方式”和“测试层级”分开，读者才知道通过的含义。

当前测试多数继承 SceneTree，在 `_initialize` 中准备环境，以 quit(0/1) 返回结果。它们不依赖某个不存在的统一框架入口。提示词中的 `tests/run_tests.gd` 只是示意，仓库实际没有这个文件。当前发现 21 个 test_*.gd，与历史 UX 报告的 21/21 对应；这只是入口数量核对，不表示本次重新执行了全部套件。

## 动手步骤：发现入口、隔离、再运行

先用 Python 列出测试，避免 shell glob 在不同 shell 下行为不一致：

```bash
python3 - <<'PY'
import os
from pathlib import Path
r=Path(os.environ['TUTORIAL_LAB'])
tests=sorted((r/'tests').rglob('test_*.gd'))
for p in tests:
    print(p.relative_to(r))
print('suite_files=',len(tests))
PY
```

再看保存隔离 [scripts/level/level_repository.gd:10](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/level/level_repository.gd.txt:10)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/level/level_repository.gd#L10) · [仓库内快照](source-baseline/scripts/level/level_repository.gd.txt)）。涉及磁盘的集成测试在开始时注入 `user://test_saves/<name>_<pid>`。目录隔离不仅保护玩家进度，还防止两个套件互相覆盖，产生依赖执行顺序的假失败。我们的练习副本另有独立应用名，形成额外保护，但不能因此在测试代码里省略隔离约定。

下面是串行运行器，命令即写在教程中，不假装仓库已有该脚本。每套设 120 秒上限，日志输出到新的 /tmp 目录，不覆盖历史证据。任何超时或脚本错误都计失败，同时继续收集其他套件结果。它适用于本基线的小型测试；若未来新增长测，应显式调整对应预算，而非取消所有超时。

```bash
python3 - <<'PY'
import os, subprocess, tempfile
from pathlib import Path
r=Path(os.environ['TUTORIAL_LAB'])
engine=os.environ['GODOT_BIN']
out=Path(tempfile.mkdtemp(prefix='voxel-test-results-'))
bad=[]; tests=sorted((r/'tests').rglob('test_*.gd'))
for p in tests:
    rel=str(p.relative_to(r)); log=out/(p.stem+'.log')
    try:
        run=subprocess.run([engine,'--headless','--path',str(r),'-s',rel],
            stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
        log.write_text(run.stdout)
        ok=(run.returncode==0 and 'TEST_PASS' in run.stdout
            and 'SCRIPT ERROR' not in run.stdout and 'TEST_FAIL' not in run.stdout)
        print('PASS' if ok else 'FAIL',rel)
        if not ok: bad.append(rel)
    except subprocess.TimeoutExpired as e:
        output=e.stdout or b''
        log.write_text(output.decode(errors='replace') if isinstance(output,bytes) else output)
        print('TIMEOUT',rel); bad.append(rel)
print('logs=',out,'total=',len(tests),'failed=',len(bad))
raise SystemExit(1 if bad else 0)
PY
```

判断退出码与 TEST_PASS 双重条件可以发现一部分“测试没真正跑起来”的情况，但并非完美。若断言根本没覆盖风险，再严格的运行器也只证明错误测试顺利结束。设计用例时先写具体反例，例如同一目标被两炮预订、负 age、零弹取回、上位中保存，而不是只验证函数返回类型。

存档验证必须经过真实 JSON 文件：保存→读取→校验→启动恢复，而不是只把内存快照交给 restore。[tests/integration/test_loading_retire.gd:84](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/tests/integration/test_loading_retire.gd.txt:84)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/tests/integration/test_loading_retire.gd#L84) · [仓库内快照](source-baseline/tests/integration/test_loading_retire.gd.txt)） 就读回落盘结果再启动新控制器。这样才有机会发现键类型变化和状态归一错误。坏 JSON 与文件不存在也要走不同分支，不能都默认为新游戏。

### 守恒是局部规则组成的检查网

对每种颜色定义 Q 为队列弹药，S 为槽内剩余弹药，F 为在途票据，V 为活块，D 为已删块。正常过程应满足 `Q+S+F=V` 与 `V+D=V0`。这不是需要保密的反作弊技巧，而是普通资源守恒。它能发现丢弹、重复退款和假减计数，不能单独证明几何命中正确，所以必须结合碰撞夹具和回放。

每次状态转移只改变相应项：上位在 Q 与 S 间搬运；发射从 S 搬到 F；命中 F 与 V 同减；取消从 F 还回 S；合成和洗牌只重排。把这些关系写成概念表就足够理解审计，不需要把完整内部实现复制成教程的一半篇幅。入口见 [scripts/app/game_controller.gd:831](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/game_controller.gd.txt:831)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/game_controller.gd#L831) · [仓库内快照](source-baseline/scripts/app/game_controller.gd.txt)）。

### 十三连 WON 的实际证据

历史 UX 十三份报告给出 169.4～190.9 秒，全部真实剩余和可见实例为零，成功发射等于命中且零取消。可以离线重新汇总文件来验证报告没有抄错。以下只读命令在原仓库读取已有 JSON，不启动游戏，也不会生成新的性能结论：

```bash
python3 - <<'PY'
import os,json,statistics
from pathlib import Path
d=Path(os.environ['TUTORIAL_REPO'])/'reports/desktop/ux'
times=[]
for i in range(1,14):
    p=d/('replay_ux_report'+('' if i==1 else str(i))+'.json')
    r=json.loads(p.read_text()); s=r['fire_stats']
    ok=(r['result']=='WON' and r['alive_remaining']==0
        and r['renderer_instances']==0 and r['conservation_ok']
        and s['fire_success']==s['hit']==4105 and s['cancel_total']==0
        and r['effective_sec']<=300 and not r['op_mismatches'])
    print(p.name,r['effective_sec'],ok)
    assert ok,p
    times.append(r['effective_sec'])
print('min/max/mean',min(times),max(times),round(statistics.mean(times),2))
PY
```

注意历史摘要称 mean 174.6，应以重新计算的原始 JSON 为准，教程不把四舍五入或摘要笔误当权威。回放 solution 中 slots=3 是原解元信息，当前运行规则五槽全开；不能据此声称测试的就是三槽难度。报告中的 `pacing_target_210_240` 实际代码检查 0～240，而不是 210～240，见 [scripts/app/replay_runner.gd:124](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/replay_runner.gd.txt:124)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/replay_runner.gd#L124) · [仓库内快照](source-baseline/scripts/app/replay_runner.gd.txt)），应直接读取时间数值判断。

### 延伸练习：检查测试是否真的能失败

挑一个纯逻辑套件，在独立练习副本中临时把某个明确期望改错，例如把首次删除后预期存活数从3改成4。运行应返回非零，并出现对应失败信息；随后恢复文件。这个练习验证测试通道本身有效，不能在正在开发的仓库做，也不要把故意改坏的版本混入交付。如果改错期望仍PASS，需要先修测试运行或断言机制。

还应检查测试清理。失败提前返回时，临时文件是否留在隔离目录，节点是否影响下一套，静态变量是否重新初始化？独立进程运行套件能隔离一部分状态，但不能替代文件目录隔离。偶尔失败、单独重跑又通过，常常意味着共享状态或时间依赖，而不一定是机器太慢。

为人工用例也写失败条件。例如“上位动画正常”太宽泛，可以改成“源与目标不同时出现两门完整炮；数字随炮身移动；落位前不发射；重开后无残影”。录像审核者有了明确标准，就不会因为最后一帧很好看而忽略中间跳变。自动与人工测试都需要可判定的预期。

## 踩坑记录：PASS 也有范围

“十三连”表示同一路径在多个运行中稳定成功，不代表遍历了所有玩家操作、所有种子或所有设备。自动回放按照解里的 place/park 驱动上位，射击交给调度器，旋转交给自动旋转；它不会像真实玩家那样不断切换 pitch、误点道具或长按队列。人工试玩仍然有独立价值。

“零取消”是这批成功回放的质量信号，不是要求系统永远不允许取消。超时、目标失效和保存前收尾需要安全退款。如果为了数字漂亮删除取消保护，异常时反而丢资源。取消测试应该主动制造异常并确认恰好返还一次；完整回放则观察正常路径是否频繁触发异常。

胜利文字截图受桌面 Space 限制曾没截到，历史报告将它标记 BLOCKED。正确做法是保留机器清零证据，同时承认遮罩显示未得到对应截图，而不是拿另一局的画面填进去。同理，一次测试的 PASS 不能挪到另一个二进制上，构建身份也是证据的一部分。

## 验证方法

先执行你修改相关的套件，确定失败是否局部；通过后再扩大范围。全文档写作不需要重跑游戏全套，更不需要为证明命令存在把真实用户存档清空。本教程的写作验证只核对路径、行号、数据与文档结构；读者运行命令后的结果应另存为自己的实验记录。

本章完成后应该能得到真实测试清单、一次独立日志目录和十三份历史报告的离线汇总。每个结论注明“本次执行”“历史证据”“未执行”，让下一个维护者不用猜哪条数字来自哪次运行。

## 小结

可重复运行只是测试的基础，清楚解释结果范围才是工程能力。下一章把源码、二进制、日志和截图绑定起来，形成别人能够接手的交付。

[上一章](11-performance-engineering.md) · [下一章](13-build-and-delivery.md)
