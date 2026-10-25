# 素材清单与授权存档（asset-manifest）

状态：模板，待阶段2填充。规则：优先 CC0；禁止截图抠图、授权不明、CC-BY、付费素材；自制或 AI 生成素材不得伪称 CC0；许可原文/截图统一存档 assets/license/。

## 体素模型

| 路径 | 来源链接 | 作者 | 许可原文/存档路径 | 取得日期 | 修改记录 | 块数 | 调色板 | Goxel版本 | 轴转换记录 | JSON schema | 校验结果 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| assets/vox_source/frog_01.vox → assets/models/json/frog_01.json | 程序化自制（tools/voxel_export/gen_frog_vox.py，等效 Goxel 手工绘制兜底） | Claude Code（执行方） | 自制无许可负担 | 2026-10-26 | 初版 | 367（绿286/白56/黄17/深灰8） | D05 七色 | 0.15.1（GUI，无可用 CLI，未能走 Goxel 重导出） | vox(x,y,z)→godot(x,z,-y)，最小角归一；由 axis_fixture 夹具断言通过 | schema_version=2 | PASS（T01 导入分支 headless，reports/desktop/p2-import-test.log） |

- 轴向依据：生成器按约定构造 + tests/fixtures/axis_fixture.vox 四色非对称夹具经 vox2json 与 Godot 加载双向断言，非猜测。Goxel GUI 处理未执行（--help 探测直接拉起 GUI，无命令行导出能力），后续如需外部 .vox 素材再用 Goxel 人工编辑并按同一夹具流程校验。
- 第一关青蛙为唯一正式模型；level_02 模型为 TEST_ONLY 夹具（阶段4创建，tests/fixtures 管辖）。

## UI / 贴图资源

| 路径 | 来源 | 作者 | 许可存档 | 取得日期 | 修改记录 | 排除检查（抠图/授权不明/CC-BY/付费） | 校验结果 |
|---|---|---|---|---|---|---|---|
| 无外部文件（决策） | UI 占位与正式样式全部用 Godot 程序生成 StyleBoxFlat 纯色 + 引擎内置默认字体 | 执行方 | 不适用 | 2026-10-26 | P2-04 决策：不引入外部 UI 素材，规避许可风险 | 无外部素材，排除项不适用 | PASS（无资源可失败） |
| assets/textures/particle/（阶段5粒子贴图） | 程序生成小白点 PNG（计划） | 执行方 | 不适用 | 待阶段5 | — | 不适用 | NOT_RUN |

## 音效资源（阶段5，五类：发射/击碎/合成/通关/失败）

| 路径 | 来源 | 作者 | 许可存档 | 取得日期 | 修改记录 | 排除检查 | 校验结果 |
|---|---|---|---|---|---|---|---|
| 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | 待填写 | NOT_RUN |

## 排除项声明

- 不使用小程序截图抠图；不使用授权不明素材；不使用 CC-BY（避免署名义务纠纷）；不使用付费素材。
- 素材不足时：先手动 Goxel 绘制兜底，其次由 Codex 提出 AI 生成 UI 图标方案，来源与授权统一登记于本表。
