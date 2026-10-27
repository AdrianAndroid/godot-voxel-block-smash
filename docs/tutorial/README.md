# 从零理解并复现 Godot 体素消除游戏

这是一套面向“会编程、第一次使用 Godot”的中文实战教程。我们从空场景开始，逐步显示模型、搭建玩法、理解旋转中的弹道、改善选靶与动画，最后学习如何用数据证明游戏能正常完成一局。每章回答三个问题：怎么做，为什么这样做，怎样验证。

源码基线固定为 `003648e3ac102692c9722b441ba2f801c2f6ac1d`。编写日期为 2026-10-27。源码引用的行号只对这个基线负责；历史报告可能对应其前序 dirty 构建，不能将它们改写成对任意后来版本的证明。写作期间只新增教程，没有修改游戏实现，也没有启动新的游戏、导出或性能测试。

## 学习路线

| 章 | 内容 | 建议练习时间 |
|---|---|---|
| [01](01-godot-basics.md) | 编辑器、节点、场景、脚本和信号 | 1～2 小时 |
| [02](02-project-and-rules.md) | 从空工程建立竖屏配置与规则 | 1～2 小时 |
| [03](03-data-model.md) | JSON、模型校验、配表与数据边界 | 2～3 小时 |
| [04](04-voxel-rendering.md) | 显示 4105 块、实例化与删除同步 | 2～4 小时 |
| [05](05-main-scene.md) | 静态节点树和运行时装配 | 2～3 小时 |
| [06](06-gameplay-transactions.md) | 队列、槽位、票据和发射事务 | 3～4 小时 |
| [07](07-local-ballistics.md) | 格空间弹道、连续碰撞和事件投影 | 3～5 小时 |
| [08](08-target-selection.md) | 多点选靶、时间片、缓存与时钟 | 3～5 小时 |
| [09](09-input-and-rotation.md) | 拖动、输入归属、自动旋转接续 | 2～4 小时 |
| [10](10-loading-and-retiring.md) | 上位与退场状态机、保存恢复 | 2～4 小时 |
| [11](11-performance-engineering.md) | 四个优化案例与证据边界 | 3～5 小时 |
| [12](12-testing-and-evidence.md) | 分层测试、回放、守恒与诚实验收 | 2～4 小时 |
| [13](13-build-and-delivery.md) | Mac 导出、构建标识与交付闭环 | 2～4 小时 |

完整练习建议分配 27～49 小时。这是学习预算，不是项目历史工时。已有 Godot 经验可以先读第 3、6、7、8 章，但不要跳过测试隔离约定。

## 在 GitHub 上阅读

章节目录和上一章/下一章使用相对链接，教程目录上传后即可点击。每处源码引用提供三种入口：

- **原文件:行号**：供当前 Codex 本地阅读，指向本机只读快照。
- **GitHub 源码**：指向 [项目仓库](https://github.com/AdrianAndroid/godot-voxel-block-smash) 的固定提交 `003648e3ac102692c9722b441ba2f801c2f6ac1d`，使用 `#L行号` 定位，不随分支更新漂移。
- **仓库内快照**：使用相对路径，随 `docs/tutorial/source-baseline/` 一起上传即可打开，不依赖本机目录；文件标签中的行号可用于定位原实现。

上传时请保留整个 `docs/tutorial/` 目录。GitHub源码链接要求上述提交已推送到该仓库，私有仓库还需要阅读权限。本次仅生成并校验链接结构，未推送文件；远端访问受当前环境SSH网络限制，未确认提交在线可访问。

## 环境与运行约定

需要 macOS、Git、Python 3、与项目匹配的 Godot 4.7.2，以及最后导出时使用的同版本模板。版本字符串来自项目和历史构建证据；本教程不声称其他版本一定兼容。编辑器操作可参阅 [Godot 官方入门](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html)，具体实现以仓库代码为准。

下面在同一个终端执行一次。它从固定提交创建独立练习副本，不复制其他开发者尚未提交的改动，不操作正在开发的工作区。`git archive` 仅导出受 Git 跟踪的内容，因此历史 APK、App、录屏等文件未必存在于副本。

```bash
export TUTORIAL_REPO='/Users/zhaojian/code/godot-voxel-block-smash'
export TUTORIAL_BASE='003648e3ac102692c9722b441ba2f801c2f6ac1d'
export TUTORIAL_LAB="$(mktemp -d /tmp/voxel-tutorial.XXXXXX)"
export GODOT_BIN="$(command -v godot || true)"
if [ -z "$GODOT_BIN" ]; then
  export GODOT_BIN='/Applications/Godot.app/Contents/MacOS/Godot'
fi
test -x "$GODOT_BIN" || { echo '请设置实际 Godot 可执行文件路径'; exit 1; }
"$GODOT_BIN" --version
python3 - <<'PY'
import os, subprocess, tarfile, io
from pathlib import Path
repo, rev, lab = (os.environ[k] for k in
                  ('TUTORIAL_REPO','TUTORIAL_BASE','TUTORIAL_LAB'))
data = subprocess.check_output(['git','-C',repo,'archive',rev])
with tarfile.open(fileobj=io.BytesIO(data)) as archive:
    archive.extractall(lab, filter='data')
p = Path(lab)/'project.godot'
s = p.read_text()
# 独立应用名使 user:// 与真实游戏分离；这一改动仅发生在练习副本。
s = s.replace('config/name="godot-voxel-block-smash"',
              'config/name="voxel-tutorial-' + Path(lab).name + '"')
p.write_text(s)
print('练习目录：', lab)
PY
```

这段解包使用支持 `filter='data'` 的 Python（建议 3.12 或更新）。若本机 Python 更旧，可升级独立 Python 环境后再做练习；不要去修改真实游戏以绕过环境问题。后续命令统一使用 `$TUTORIAL_LAB`，不要替换成正在工作的仓库路径。新终端需重新设置变量；可打印变量确认自己操作的目录。

练习有两条线：第 1～4 章在练习副本中的独立 `sandbox` 工程，从空场景走到模型显示；第 5 章起打开同一副本的完整项目，沿真实模块逐步理解并调用现成接口。我们没有伪造一套“从空目录粘贴十三段就重建整个游戏”的代码；完整实现由固定提交提供，教学片段负责解释和做最小实验。

## 对原提示词的事实校正

- 当前关卡五列队列、五槽全开；三行是每列可见窗口，不是三槽。旧解文件中的 `slots:3` 是生成解时的元信息。
- `MultiMeshInstance3D` 渲染节点是一个，方块实例开局仍为 4105。`renderer_instances` 应与存活方块数一致，不该压到个位数。
- 默认速度是 100 格/秒，当前关卡覆盖成 120；默认间隔 0.10 秒，关卡覆盖成 0.09 秒。
- 选靶单次预算 3000 微秒、每物理步共享预算 6000 微秒并存；不是把所有 3ms 改成 6ms。
- 当前测试文件实际为 21 个，与 UX 报告的 21/21 对应；本次只核对清单，没有重新运行全部套件。
- 当前普通玩法为自动射击。第 6 章“手动发射”采用显式调用一次公开控制器入口的实验，不给生产 UI 增加手动射击按钮。
- 没有找到逐方块节点方案“实测帧率崩塌”的对照原始记录。本教程把它写成待读者测量的对比实验，不杜撰数字。
- 历史 UX 数据有 3 个 p95 超标窗口，不能表述为所有窗口满足 50ms。`fires==hits`、守恒和截图共同构成证据，不是对任何作弊行为的形式化证明。

## 证据规则

标注“当前源码”表示可静态核对；标注“历史实测”表示来自仓库已有报告；标注“教学简化版”表示为解释而缩小的实验；标注“建议实验/待运行”表示本次没有执行。截图位置是占位说明，绝不冒充本次生成的截图。

章节保留目标、概念、动手、踩坑、验证、小结六个段落，以提示词详细结构为准。源码链接标签给出原文件及基线行号，点击打开 source-baseline 中逐字保存的 .txt 文档快照，行号与固定提交完全一致。这样其他开发进程继续修改源码时，本教程引用不会漂移；快照不是另一套游戏实现，不参与运行。搬迁仓库后可根据链接标签中的原始路径定位。教程附引用索引和校验记录，便于维护者批量检查。

## 文档验收与源码索引

- [本次文档校验记录](VALIDATION.md)
- [固定源码引用清单](source-references.json)
- source-baseline/ 保存引用所需文件在固定提交的逐字文本快照，仅供阅读。
