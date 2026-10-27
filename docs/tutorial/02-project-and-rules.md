# 第 2 章：让工程配置服务于游戏规则

[上一章](01-godot-basics.md) · [总目录](README.md) · [下一章](03-data-model.md)

## 本章目标

建立一个能启动的竖屏空场景，理解逻辑视口与桌面窗口不是同一个尺寸，并写出这款游戏真正的规则。你应能解释为什么屏幕上有五列队列、五个槽位，而旧报告里仍然出现三槽；为什么 4105 是模型数据结果，而不是“游戏最多支持 4105 块”的硬编码限制。

本章把产品语义先固定下来。一个程序可能逻辑自洽，却做错了玩家想玩的东西。例如早期反弹球和当前一发一块消除可以共用部分碰撞代码，但节奏、弹药数量和失败判断完全不同。先确认正在实现哪一套规则，比先调整球速更重要。

## 概念讲解：四种容易混淆的尺寸

项目里的逻辑视口为 1080×2400，桌面窗口覆盖尺寸为 540×1200。前者决定界面布局计算的参考空间，后者决定桌面实际窗口的请求大小。操作系统还可能加标题栏，截图尺寸因此未必恰好是 540×1200。把截图的标题栏算成游戏高度，会使炮口与模型的屏幕坐标计算产生系统偏差。

`canvas_items` 与 `keep` 是拉伸模式和宽高比策略，不是“自动适配所有手机”的保证。它们约束画布随窗口变化的方式，按钮锚点、容器布局、系统安全区域仍需要单独处理。桌面关闭 `resizable` 能固定验收条件，却不能替代未来 Android 和 iOS 的屏幕适配。当前配置见 [project.godot:18](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/project.godot.txt:18)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/project.godot#L18) · [仓库内快照](source-baseline/project.godot.txt)）。

格空间尺寸又是另一回事。一个体素格可以对应某个模型单位，模型通过变换进入世界空间，再由相机投影到屏幕。540 像素宽与 54 格宽不存在天然的十倍关系。以后计算拖动灵敏度时会用屏幕尺寸，计算碰撞时则用格单位；把两者混起来会导致窗口缩放以后手感和命中同时改变。

项目选择 GL Compatibility，对应 [project.godot:29](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/project.godot.txt:29)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/project.godot#L29) · [仓库内快照](source-baseline/project.godot.txt)）。历史目标机是 Intel UHD 630 集成显卡，功能需求主要是大量相同立方体、基本光照和二维界面，因此选择兼容后端有合理依据。不过“兼容性适合本机”不等于“所有项目它都最快”，也不能仅靠切换后端修复选靶 CPU 循环。这个决策应与设备、画质需求和实测一起保存。

## 动手步骤：建立空场景并阅读正式规则

在 sandbox 中新建三维场景，根命名 `Main`，保存为 `main.tscn`。不要挂正式 `main.gd`，因为那个脚本依赖完整资源和服务。添加 Camera3D，位置设为 `(0, 0, 8)` 并设为当前相机。再添加 DirectionalLight3D。现在即使什么都看不到，空场景已经可以运行；相机没有可见物体可以拍摄，并不等于运行失败。

在项目设置搜索窗口相关参数，或将 sandbox 的配置替换为下面内容。教学配置沿用真实项目的尺寸和渲染选择，入口则指向刚创建的空场景。

```ini
config_version=5

[application]
config/name="Voxel Tutorial Sandbox"
run/main_scene="res://main.tscn"

[display]
window/size/viewport_width=1080
window/size/viewport_height=2400
window/size/window_width_override=540
window/size/window_height_override=1200
window/size/resizable=false
window/handheld/orientation=1
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

从终端启动，观察窗口比例，然后关闭它，避免后面练习多个实例同时运行。

```bash
"$GODOT_BIN" --path "$TUTORIAL_LAB/sandbox"
```

接下来阅读正式关卡 [assets/levels/level_01.json:9](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/assets/levels/level_01.json.txt:9)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/assets/levels/level_01.json#L9) · [仓库内快照](source-baseline/assets/levels/level_01.json.txt)），先抄一张“当前有效规则表”，不要抄历史文档标题里的默认值。当前五槽全开，五列队列。每列画面显示前三门，后面还有更多；“三”描述窗口深度，而非可用槽位数。普通炮按颜色携带弹药，玩家点击列首后上位，到位自动射击。只允许实际命中同色有效目标时消除一块。

模型初始块数应从 JSON 读取。开局为各颜色生成对应总弹药，再拆成多门炮分入队列。这样“还剩多少块”和“还剩多少可消除能力”能够建立数量关系。合成只是把两份同色弹药合并，不凭空增加弹药；洗牌只改变队列排列，不改变总量。取回目前保留测试用途，正式回放通关证据不能依赖它。

当前道具里速度×2影响的是下一次成功发射的速度修饰，不等于永久把全局发射间隔减半。指定目标也不是“任意颜色穿透弹”；它仍受当前合法性和可达性契约约束。过去名为“任意指”的规则已经演进，如果教程只按按钮印象解释，就会把旧功能教给读者。

再定义终局：方块真实清零、没有未结算发射和渲染残留，才进入胜利。暂时没有可达同色块是等待，不应仅因队列为空就判负。严格守恒下某些“无弹却有块”的状态反而意味着数据完整性错误。界面提示“转动模型或更换炮台”与系统宣布失败，是两种完全不同的产品反馈。

最后定义节奏目标。300 秒是有效游戏时间的交付目标，不是到点自动删掉剩余方块的倒计时规则。玩家暂停或不操作不能靠隐藏作弊强行满足目标。真实回放固定操作序列，才能把一次 170 秒与另一次 230 秒放到同一张表里比较。

> 📷 截图：540×1200 的空运行窗口与项目设置中的 1080×2400 逻辑视口；建议使用 sandbox 新截图，避免拿旧手机界面当作当前窗口设置的证据。

### 延伸练习：把产品要求写成反例

给每条规则写一个违反它的场景。对“一发一块”，反例是球穿过两块后连删两次；对“按颜色”，反例是绿色炮碰黄色块也减数；对“五槽固定”，反例是中间退场导致右侧炮口瞬移；对“全清胜利”，反例是屏幕剩余数字为零但还有一个可见实例。这些反例以后可以直接变成测试输入。规则若无法产生反例，通常还不够精确。

把规则参数和验收参数分开记。ball_speed 影响游戏运行，300秒是交付目标，120秒是性能采样时长。它们虽然都可能出现在JSON或文档里，角色完全不同。不要把采样结束当作游戏结束，也不要因达到通关时间上限就改变世界状态。用清晰命名隔离这几类参数，比依靠开发者一直记住区别可靠。

最后建立一张小决策表：当前选择、理由、替代方案、重新评估条件。兼容渲染的重新评估条件可能是换设备或增加画质功能；五槽配置可能因新关卡难度重新评估。记录条件让决策可演进，而不是把今天的默认值变成无法讨论的永久规则。学习工程化，不只是会配参数，也要知道什么时候应该重新测量。

## 踩坑记录：配置历史为何容易误导

项目曾因为桌面窗口请求尺寸过大，被系统可用屏幕高度限制，而比例策略又导致横向扩展，最终看起来接近方形。修复记录位于 [docs/dev-step-log.md:461](/Users/zhaojian/code/godot-voxel-block-smash/docs/tutorial/source-baseline/docs/dev-step-log.md.txt:461)（[GitHub 源码](https://github.com/AdrianAndroid/godot-voxel-block-smash/blob/003648e3ac102692c9722b441ba2f801c2f6ac1d/docs/dev-step-log.md#L461) · [仓库内快照](source-baseline/docs/dev-step-log.md.txt)）。这个案例的诊断顺序是先读实际窗口尺寸，再看视口和拉伸策略，而不是先修改按钮绝对位置。只修按钮会在另一个显示器上再次出错。

另一个真实陷阱是默认值与覆盖值。`game_rules.gd` 中默认速度 100，但当前关卡文件覆盖成 120；调度器字段初始化仍可能写 0.25，但 setup 收到的是规则解析后的值。搜索一个数字只能找到声明，不能自动找到运行值。最可靠的方法是沿“JSON→解析→rules→setup”走一遍，再在日志中记录实际生效参数。

历史文档还有三槽、加槽道具等表述。不要因此把当前五槽改回去，也不要删除旧报告来让历史显得一致。工程记录的作用是说明当时为何这样做，教程应为当前规则另建清晰入口。未来增加难度关卡，可以再次使用三槽，但那应是新关卡配置和对应验证，而不是默认值意外回退。

## 验证方法

空场景验证只检查运行成功、尺寸与比例、没有脚本错误。不要把“黑屏”本身记为失败。正式规则验证则可以不启动游戏：用下面命令打印关卡覆盖值与模型块数，确认读的是练习副本。

```bash
python3 - <<'PY'
import json, os
from pathlib import Path
r=Path(os.environ['TUTORIAL_LAB'])
level=json.loads((r/'assets/levels/level_01.json').read_text())
model=json.loads((r/level['model_path'].removeprefix('res://')).read_text())
print('关卡：',level['level_id'])
print('方块：',len(model['voxels']))
print('覆盖规则：',json.dumps(level['rules'],ensure_ascii=False,indent=2))
assert len(model['voxels']) == 4105
assert level['rules']['initial_slots'] == 5
PY
```

本章完成后你应该能看到一个正确比例的空窗口，并能讲清“视口、窗口、世界、格”四种空间。写下你确认的玩法约束，再进入模型数据层。这个顺序会让后续字段校验有明确依据：你校验的不是随意格式，而是游戏规则允许的输入。

## 小结

工程设置不是安装后只看一次的页面，它与输入坐标、相机和验证环境直接相连。当前值、默认值和历史值都可以合理存在，关键是明确谁在运行时生效。下一章将把这种思路扩展到整个模型和关卡数据。

[上一章](01-godot-basics.md) · [下一章](03-data-model.md)
