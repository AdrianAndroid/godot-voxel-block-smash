# godot-voxel-block-smash

Godot 4 3D 方块击碎学习原型，玩法对标小程序游戏《这关消一消》。**仅个人学习自用，不对外发布、不分发**；最终验收在安卓模拟器完成。

⚠️ 当前项目处于**阶段1（初始化）**：本仓库尚不含可玩游戏，README 不构成"可玩"声明。

## 目标形态（依据 GDD v6）

- 上方：独立纯色体素拼成的立体模型，仅拖拽模型空白区域可自由 3D 旋转，UI 固定不随转。
- 中部：最多 5 个发射槽，从下方炮台池安放/取回，点击槽内炮台逐个独立发射。
- 底部：3×3 九宫格炮台池（炮台带颜色+弹珠数）与四种消耗型道具按钮。
- 弹珠只能击碎同色方块，异色反弹；出界消失并清零连击。
- 方块全清通关；无法继续消除则失败。
- 关卡列表进入，每关绑定独立模型并独立保存本局炮台/道具/进度。

## 环境

- 开发机：Intel Mac mini（macOS）
- 引擎：Godot 4.7.2 stable（`/usr/local/bin/godot`，渲染器 gl_compatibility）
- 体素编辑器：Goxel 0.15.1（`/Applications/Goxel.app`）
- 安卓验收：模拟器（设备/API/ABI/分辨率/性能阈值待 D07 批准）

## 打开工程

```
godot --editor --path /Users/zhaojian/code/godot-voxel-block-smash
```

主场景：`scenes/main/main.tscn`（Main:Node3D + Camera3D + WorldEnvironment，无玩法内容）。

## 文档导航

| 文件 | 作用 |
|---|---|
| docs/game-design.md | GDD（当前 v6）：权威规则 G01～G15、未决项 D01～D11、测试用例 T01～T24 |
| docs/AI-WORKFLOW.md | Agent 职责、七阶段流程、交接与日志规范 |
| docs/architecture.md | 目录树、GDScript 规范、模块契约、数据契约、事件清单 |
| docs/plan.md | 七阶段执行计划与任务表 |
| docs/dev-step-log.md | 追加式开发日志（最新状态以末尾记录为准） |
| docs/file-audit.md | 文件与交付缺口核对 |
| docs/tasks/phase-1-init.md | 当前执行任务单 P1-INIT-v6 |
| docs/asset-manifest.md | 素材来源/许可登记（模板） |
| docs/test-report.md | 测试报告（T01～T24 预列 NOT_RUN） |
| docs/review-context.md | 执行方交接文档 |

## 未决项（禁止执行方自定数值）

D01 槽初值/取回细节、D02 合成上限、D03 球体参数/边界/多球、D04 道具次数与扣次时点、D05 调色板/分布、D06 UI 布局与输入参数、D07 性能阈值、D08 失败真值表、D09 存档范围、D10 重置语义、D11 穿透道具歧义——详见 GDD，逐项澄清后方可实现相关功能。

## 协作分工

- Codex：架构/规范/评审/修复方案，不看游戏画面，只凭行为日志与量化指标验收。
- Claude Code：唯一执行方，只按任务单落地，不改 GDD/架构、不跳阶段。
- 安卓模拟器测试端：运行构建、收集日志与画面现象文字。
