# 第 3 章：数据层是游戏规则的入口

[← 上一页：第 2 章：让工程配置服务于游戏规则](02-project-and-rules.md) · [总目录](README.md) · [下一页：第 4 章：用一个渲染节点显示 4105 个方块 →](04-voxel-rendering.md)

## 本章目标

不用编辑器手摆 4105 个方块，而是理解一份模型 JSON 如何变成内存里的坐标、颜色和包围盒。完成后，你能统计每种颜色的数量，解释 schema 版本与模型版本的区别，并用现有导入测试验证坏数据被拒绝。更重要的是，能够区分只读模型、运行状态和磁盘存档，不再把它们都叫“游戏数据”。

## 概念讲解：三份数据承担三种责任

模型数据描述最初有哪些块，每一块在哪里、是什么颜色。这些属性在一局内不需要改变，因此项目把 positions、color_ids 和 palette 放在 VoxelData。运行状态只回答当前哪些 ID 还活着。删除一块不必从原始坐标数组抹掉一行；那样会让后面全部 ID 位移，使票据、索引和报告的引用失效。

存档则是在某一时刻恢复游戏所需的快照。它保存存活 ID、炮台和队列等局内状态，并用模型哈希判断快照能否套回当前模型。模型文件不等于存档，修改模型文件也不等于玩家消除了一块。这个边界在编辑器里似乎多余，直到你需要支持重开和恢复，它才显示价值。

模型 schema 版本描述字段协议，当前 loader 支持 2。`model_revision` 描述资产版本；内容哈希用来检验具体内容。即使 schema 没变，同一个 ID 对应的坐标也可能因重新导出资产而变化，所以“版本号仍为 2”不能证明旧存档安全。字段协议兼容与数据身份相同，是两个独立问题。

[scripts/data/voxel_loader.gd:11](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/data/voxel_loader.gd.txt:11)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/data/voxel_loader.gd#L11) · [仓库内快照](source-baseline/scripts/data/voxel_loader.gd.txt)） 是读取入口。它检查文件存在、顶层对象、允许字段、voxel_size、调色板和每个体素坐标。允许块数为 300～6000，测试的小夹具通过 `enforce_range=false` 绕开数量范围，但不等于绕开全部校验。生产加载不应该为了让坏资产过关随意关掉校验。

## 动手步骤：观察格式，再形成类型

先从真实文件打印头几个体素，而不是打开数千行后凭眼睛判断。下面命令也检查坐标唯一性和颜色引用，帮助你把错误定位到“数据入口”而非后面的渲染黑屏。

```bash
python3 - <<'PY'
import json, os
from pathlib import Path
from collections import Counter
p=Path(os.environ['TUTORIAL_LAB'])/'assets/models/json/frog_02.json'
d=json.loads(p.read_text())
print('schema',d['schema_version'],'voxel_size',d['voxel_size'])
print('前三块',d['voxels'][:3])
counts=Counter(v['color_id'] for v in d['voxels'])
print('分色数量',dict(sorted(counts.items())))
coords={(v['x'],v['y'],v['z']) for v in d['voxels']}
assert len(coords)==len(d['voxels'])
assert all(str(v['color_id']) in d['palette'] for v in d['voxels'])
assert sum(counts.values())==4105
PY
```

这个基线的分色数量为 1→3167、4→311、6→218、7→30、8→299、9→80，可与历史回放报告的 solution.color_counts 交叉核对。注意颜色 ID 不要求从 1 连续到 6，也不能用数组下标直接猜色号。规则文件里某个历史默认调色板列表不能覆盖实际模型里的 8、9 色号，真正的颜色集合应跟随模型读取。

下面是结构说明用的教学简化 JSON，不是能通过生产数量校验的完整关卡：

```json
{
  "schema_version": 2,
  "voxel_size": 1.0,
  "palette": {"1": [0.3, 0.8, 0.2, 1.0]},
  "voxels": [{"x": 0, "y": 0, "z": 0, "color_id": 1}]
}
```

JSON 对象的键是字符串，所以 palette 读入后要转换成整数色号。后面存档恢复也会遇到同一个问题：内存字典可能以整数炮台 ID 为键，落盘再读取后变成字符串。不能只在最后 restore 时转换，却在前置 validate 时仍按整数查询。数据归一化必须早于依赖归一化结果的校验。

读取后 VoxelData 使用 PackedVector3Array 与 PackedInt32Array 保存坐标和颜色，见 [scripts/data/voxel_data.gd:8](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/data/voxel_data.gd.txt:8)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/data/voxel_data.gd#L8) · [仓库内快照](source-baseline/scripts/data/voxel_data.gd.txt)）。它还保存包围盒最小、最大坐标，通过 `center_offset()` 计算中心。中心取两端平均值可能是半整数，这不影响体素原始格坐标为整数。渲染时减去中心，模型就能围绕自身中心旋转，而不是绕 JSON 原点公转。

规则层通过 [scripts/data/game_rules.gd:29](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/data/game_rules.gd.txt:29)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/data/game_rules.gd#L29) · [仓库内快照](source-baseline/scripts/data/game_rules.gd.txt)） 把默认值与关卡覆盖合并。集中默认值的好处是能查到参数语义，关卡覆盖的好处是可做不同节奏。但“配表驱动”不代表所有字段都自动可配置；只有 from_rules 实际解析的键才会生效。新增一个 JSON 键而不接解析，是典型的看似完成、运行不变。

当前有效参数值得做一张记录：ball_speed 120 格/秒、auto_fire_interval 0.09 秒、单炮最多 6 发在途、全局最多 30 发、自动旋转 8 度/秒、合成上限 160。LOADING 和 RETIRING 时长则在控制器里定义，不在 rules JSON 中。教程不应把“所有可调参数都集中一处”当作已经达到的事实；当前代码只是把主要玩法参数集中，仍有表现与调度常量分散。

为下一章准备最小资源副本。它只复制模型展示所需的已存在文件，路径保持不变，方便 preload 引用解析；不会运行正式主场景。

```bash
python3 - <<'PY'
import os,shutil
from pathlib import Path
r=Path(os.environ['TUTORIAL_LAB']); dst=r/'sandbox'
paths=['scripts/data/voxel_loader.gd','scripts/data/voxel_data.gd',
       'scripts/diagnostics/perf_probe.gd','assets/models/json/frog_02.json']
paths += [str(p.relative_to(r)) for p in (r/'scripts/voxel').glob('*.gd')]
for rel in paths:
    out=dst/rel; out.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(r/rel,out)
print('展示依赖已复制到',dst)
PY
```

### 延伸练习：让错误信息帮助资产制作

假设模型导出器输出了两个相同坐标，你希望错误信息只说“导入失败”，还是告诉你第二次出现的位置和第一次出现的索引？当前loader保存seen字典，正是为了让重复能被定位。资产作者不需要理解渲染器内部，只需要知道哪条体素记录违反约定。这种错误定位能减少跨角色沟通成本，尤其当模型来自脚本生成而不是手工编辑时。

再考虑颜色统计的用途。它不仅决定队列弹量，也可验证导出前后的调色板映射。如果视觉上两种绿色非常接近，程序仍按离散色号区分。重映射色号必须同时更新palette与体素引用，不能只把显示颜色调成一样就宣称它们可以合成。数值身份与视觉相似是不同概念，这在任何用颜色表达规则的游戏里都重要。

可以设计一个不运行渲染的资产检查流水线：解析成功、字段合法、坐标唯一、颜色可引用、数量在范围内、每色统计输出、模型哈希输出。每一步失败即停止后续展示。这样的流水线没有花哨界面，却能让未来新增十个关卡时少花很多人工查错时间。保持检查只读，不要在校验失败时擅自去重或补颜色，否则原始资产错误会被悄悄隐藏。

## 踩坑记录：校验不只是防崩溃

重复坐标如果不拒绝，会导致两块占同一空间。渲染可能看起来正常，但空间索引只能保存其中一个，最终出现“剩余一块永远找不到”。颜色引用不存在时，渲染可能套回默认色，而队列依旧按另一种色号分配弹药，问题会拖到最后才暴露。入口校验能够把这种几分钟后才出现的错误压缩成启动时一条明确消息。

当前 loader 对 color_id 的处理值得读者仔细观察：它判断是数值并通过 `int(cid)` 检查 palette，没有像坐标那样显式要求等于 floor。因此不能把它描述成“任何非整数色号都被严格拒绝”。教程忠于实现，也要指出输入契约的剩余边界。想加强校验，应在独立实验中先加 1.5 色号夹具，再决定生产修改，而不是在讲解时悄悄美化代码。

另一个坑是把序列化后的 RNG 状态当普通 JSON 浮点数。大型整数超出精确表示范围会让恢复后的随机序列改变。当前存档以十进制字符串保存 RNG 状态，这是为了可重放性，并非为了隐藏随机数。理解这个案例后，你会知道跨语言和跨文件的数据格式不能仅按“打印出来差不多”判断正确。

## 验证方法

先运行轻量导入套件，它覆盖合法模型、坏 schema、重复位置、坏颜色和数量范围。使用练习副本可避免引擎缓存和真实开发目录互相影响。

```bash
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" \
  -s tests/integration/test_import.gd
```

观察明确的 TEST_PASS 和进程退出码，而不是只看到最后一行打印就算通过。然后阅读失败夹具，尝试在纸上预测每个错误会在哪个字段被发现。你不必为了学习校验再次破坏完整青蛙文件；小夹具已经提供了更清楚的实验对象。

本章完成后你应该能输出 4105 与每色数量，解释模型中心如何得到，并说清为什么消除只改变存活集合而不改原始模型数组。下一章会让这些数据第一次变成真正看得见的三维模型。

## 小结

数据层把外部文件的自由格式收束成内部算法可以依赖的条件。它既决定正确性，也影响排错成本。不要等渲染、碰撞和存档都写完以后才补输入约束；那些模块越复杂，入口错误就越昂贵。

[← 上一页：第 2 章：让工程配置服务于游戏规则](02-project-and-rules.md) · [总目录](README.md) · [下一页：第 4 章：用一个渲染节点显示 4105 个方块 →](04-voxel-rendering.md)
