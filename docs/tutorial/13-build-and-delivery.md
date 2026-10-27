# 第 13 章：把能运行的工程变成可核验的交付

[上一章](12-testing-and-evidence.md) · [总目录](README.md)

## 本章目标

导出一个独立 macOS App，记录源码和二进制身份，按公开回放入口完成验收，再把结果交给其他人。这里“发布”指本地构建与交付闭环，不包含应用商店上传、签名公证或对外分发；现有仓库是学习项目，素材许可与外部分发权限不能从一次成功导出推导出来。

## 概念讲解：工程、资源包与可执行文件

编辑器运行读取源码工程，导出 App 使用模板可执行文件和导出资源。编辑器成功并不保证导出过滤正确；模板版本不匹配也可能引入不同运行行为。必须把 Godot 版本、模板、导出 preset 和资源范围一起记录。命令行流程可参照 [Godot 官方说明](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html)，具体支持参数以本机 `--help` 为准。

export_presets 中 macOS 预设使用 universal 架构，并排除 tests、tools、docs、reports、builds 和原始 vox 等文件。排除 tools 不妨碍当前回放，因为运行时回放器在 scripts/app 中。若教程误写成 tools/replay_runner.gd，读者可能以为导出后缺回放功能；路径核实因此是可复现教程的基本要求。

可执行 SHA256 证明某个文件字节相同，不一定证明整个 App 的资源相同。如果资源单独打包，只哈希二进制可能漏掉资源变化。当前历史报告给出了可执行哈希，也单列模型和关卡哈希。更完整的新交付应保存整个 App 的文件哈希清单，至少确保能区分“相同引擎二进制、不同关卡资源”。

## 动手步骤：构建一份属于本次练习的 App

先关闭自己前面启动的练习窗口。不要杀掉其他开发者正在运行的同名游戏。确保当前引擎安装了匹配的导出模板，输出到练习副本专用目录，不覆盖仓库现有交付包。

```bash
mkdir -p "$TUTORIAL_LAB/builds/tutorial"
"$GODOT_BIN" --headless --editor --path "$TUTORIAL_LAB" --import
"$GODOT_BIN" --headless --path "$TUTORIAL_LAB" \
  --export-release "macOS" "$TUTORIAL_LAB/builds/tutorial/VoxelTutorial.app"
```

这两步分别完成资源导入与导出。不要在多端同时重构建时反复执行；第一次缺模板就记录缺项，安装后再试。若导出返回失败，先保存错误原文，不要把“文件夹已经创建”当成功。空 App 目录、旧 App 和新构建成功是三种不同状态。

从 Info.plist 解析实际可执行名，不猜文件一定叫 Godot 或与 App 文件夹同名：

```bash
export TUTORIAL_APP="$TUTORIAL_LAB/builds/tutorial/VoxelTutorial.app"
export TUTORIAL_EXEC_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
  "$TUTORIAL_APP/Contents/Info.plist")"
export TUTORIAL_APP_BIN="$TUTORIAL_APP/Contents/MacOS/$TUTORIAL_EXEC_NAME"
test -x "$TUTORIAL_APP_BIN"
shasum -a 256 "$TUTORIAL_APP_BIN"
```

然后用下面脚本建立产物清单。它只读 App 文件，不修改包内容，也不会破坏签名。若未来用于签名发行，应在最终签名和公证完成后再记录最终交付身份。

```bash
python3 - <<'PY'
import os,hashlib,json
from pathlib import Path
app=Path(os.environ['TUTORIAL_APP'])
rows=[]
for p in sorted(app.rglob('*')):
    if p.is_file() and not p.is_symlink():
        rows.append({'path':str(p.relative_to(app)),
                     'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
out=app.parent/'app-file-hashes.json'
out.write_text(json.dumps(rows,indent=2))
print(out)
PY
```

历史 UX 构建报告 [reports/desktop/ux/build-info.md:5](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/reports/desktop/ux/build-info.md.txt:5)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/reports/desktop/ux/build-info.md#L5) · [仓库内快照](source-baseline/reports/desktop/ux/build-info.md.txt)） 的哈希属于当时包，不应该写进本次练习交付。它还注明基于 eab2e64、dirty 28 文件；教程源码固定在后续 003648e。两者的关联是历史开发演进，不是“同一 commit 的干净重建”。报告包含 dirty 并不使证据无效，但必须避免过度精确的可重建承诺。

### 驱动真实 App 回放

确认解文件存在于练习副本，使用真实已存在路径。回放入口读取 `--` 后的自定义参数，见 [scripts/app/replay_runner.gd:27](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/scripts/app/replay_runner.gd.txt:27)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/scripts/app/replay_runner.gd#L27) · [仓库内快照](source-baseline/scripts/app/replay_runner.gd.txt)）。它过滤解中的 fire 和 rotate 操作，只驱动 place/park；真正开火由游戏调度器决定，自动旋转持续改变可达性。回放没有直接把存活数写成零。

```bash
test -f "$TUTORIAL_LAB/reports/desktop/cq/s03-solution.json"
export TUTORIAL_RUN_DIR="$(mktemp -d /tmp/voxel-replay.XXXXXX)"
"$TUTORIAL_APP_BIN" -- \
  --replay="$TUTORIAL_LAB/reports/desktop/cq/s03-solution.json" \
  --replay-report="$TUTORIAL_RUN_DIR/replay.json" \
  --replay-max-sec=360
```

运行上限 360 秒用于避免无界等待；通关达标仍按 300 秒判断，不能因为超时给了 360 就把 340 秒写 PASS。教程副本已改应用名称以隔离 user://，但你仍应检查报告、存档和 perf 输出目录，防止导出过程恢复了旧配置。实际回放不是本次教程编写时执行的命令，读者执行后才能得到自己的结果。

保持窗口可见并让机器处于稳定负载。历史最慢一局 190.9 秒与窗口切换到其他 Space 后节流有关，这说明桌面运行环境也影响墙钟。记录 effective_sec 和 wall_sec，不要只挑较小的一个。第 10 章提到最终退场和遮罩的计时缺口，也应在本次录像里补充观察。

### 关键帧和构建记录

截图至少覆盖开局、上位中、连续消除、退场和结算。截图说明写实际状态，不根据文件名猜事件。若使用全屏截图，先确认不会包含无关私人窗口。跨 Space 截不到游戏就标记 BLOCKED，别拿壁纸或旧图代替。使用 App 激活脚本时也需注意：某些激活方式在应用不存在时会新开无参数实例，污染回放观察。

build-info 建议包含：基线提交、dirty diff 的保存位置、引擎版本、导出参数、产物清单、测试设备、窗口尺寸、回放解哈希、报告路径和未完成项。不要把“我们已经测过”作为字段值；交付对象需要知道测的是哪个文件、在哪台机器、用什么入口。

> 📷 截图：本次新构建的上位与退场连续帧、最终胜利遮罩。历史示例目录为 reports/desktop/ux/keyframes；不得直接复制并标成新构建验收。

### 延伸练习：把交付当作另一个人的首次启动

假设接收者没有你的终端变量、编辑器缓存和开发目录，只拿到App与说明。哪些步骤仍然成立？应用资源必须包含在包里，不能引用/tmp下的模型；启动说明不能要求他猜可执行名；日志路径应该能从应用身份定位。用这个问题检查交付，比只在自己的开发机双击一次更有力量。

再区分构建证据和来源证明。哈希能证明文件未变化，但不能解释它如何构建出来。基线提交、dirty差异、模板版本和导出选项一起保存，才有机会重建相近产物。某些构建包含时间戳或签名，字节级完全一致未必可得，应提前说明追求的是功能复现还是可重复构建，不把两者混用。

最后写一段升级说明：这版改变了什么，哪些旧存档兼容，哪些测试重新执行，哪些平台尚未验证。这样Android或iOS维护者才能判断应同步哪些公共提交，而不用从几百行日志猜结论。教程到这里的终点不是一个漂亮压缩包，而是一条可追溯、可继续开发的工程路径。

## 踩坑记录：命令成功不等于交付闭环

Godot stdout 在重定向后可能延迟落盘，盯住某一行文本触发截图不可靠。回放器的 JSON 结果与退出码更适合确认结束；若需要在结算屏停留的五秒截图，使用可见状态或明确事件观测，不依赖日志即时性假设。脚本检查进程活着也只证明进程未退出，不说明游戏仍有进展。

当前回放把 `pacing_target_210_240` 设为 eff≤240，名字保留旧目标语义。交付摘要应按实际数字和当前要求重新判断。将旧字段直接翻译为“210～240 秒命中目标”会把 171 秒的报告解释错。字段名、注释和实现有冲突时，教程应该揭示冲突，不能任选一个最方便的版本。

同一测试报告可以包含 PASS、FAIL、NOT_RUN 和 BLOCKED。比如逻辑通关 PASS，p95 部分窗口超标，人工拖动手感未运行，结算截图受桌面环境阻塞。这样的报告比一行“全部完美”更能让使用者决定下一步。交付不是要求没有任何边界，而是要求边界被准确告知。

跨平台适配也应遵守同样原则。Mac 包成功不代表 Android 签名安装通过，更不代表 iOS 安全区域和后台恢复正确。公共玩法可以共享测试，但每个平台仍需对应工具链、输入、生命周期和真机性能验证。不要在本教程末尾用一个 export 命令承诺“三端自动适配完成”。

## 验证方法

检查产物可执行、Info.plist 正确、哈希清单存在；运行后检查 result、alive_remaining、renderer_instances、conservation_ok、fire_success、hit、cancel_total 和 op_mismatches。再核对录像里的剩余数和模型变化，确保机器结论与可见过程没有明显矛盾。

最后向另一个没有参加开发的人提供 App 路径、启动方式、预期画面、完成时间和已知限制。若对方只能靠你现场解释才能运行，交付文档还不完整。若报告无法对应到具体产物，即使曾经测得很好，也不能安全复用为下一个版本的证据。

本章完成后你应该拥有一个独立 App、一份构建清单、一轮真实回放结果，以及明确标注状态的验收记录。至此，学习路径从空场景、数据、渲染、事务、弹道、交互走到可交付游戏，工程闭环才真正完成。

## 小结

完成游戏不只是最后一个功能写完。你需要知道运行的是什么、结果怎样产生、别人怎样复现，以及哪些仍然未知。保留这些信息，让下一次性能优化、平台适配和玩法调整都有可靠起点。

[上一章](12-testing-and-evidence.md) · [返回总目录](README.md)
