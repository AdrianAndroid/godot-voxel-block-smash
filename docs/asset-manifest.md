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

## 音效（自制，程序化生成）
| 文件 | 用途 | 来源 | 许可 |
|---|---|---|---|
| assets/audio/sfx/fire.wav | 发射 | tools/gen_sfx.py 正弦合成 880Hz/0.12s | 自研无许可风险 |
| assets/audio/sfx/shatter.wav | 击碎 | gen_sfx.py 扫频1200→400Hz/0.18s | 同上 |
| assets/audio/sfx/merge.wav | 合成 | gen_sfx.py 双音660+990Hz/0.15s | 同上 |
| assets/audio/sfx/win.wav | 通关 | gen_sfx.py 琶音523/659/784Hz | 同上 |
| assets/audio/sfx/lose.wav | 失败 | gen_sfx.py 扫频440→220Hz/0.6s | 同上 |
| assets/vox_source/frog_02.vox → assets/models/json/frog_02.json | 程序化自制（tools/voxel_export/gen_frog02_vox.py，参数化椭球组合：身体/加厚头部/眼白+瞳孔/黄腹/浅绿背脊/四肢+橙脚趾/橙嘴线） | Claude Code（执行方） | 自制无许可负担 | 2026-10-26 | CQ-20261026/S01 初版 | 4105（绿3167/黄311/浅绿299/白218/橙80/深灰30） | 9色 palette（实际用6色） | 同上（纯程序生成，无 Goxel CLI） | 同 frog_01 映射；唯一坐标校验通过 | schema_version=2，sha256=f867f19c33c4… | PASS（test_import 新断言：4105/每色一致/6000边界/6001拒绝） |

## 炮台贴图（CQ-20261026/S06，程序化自制 CC0）
| 文件 | 用途 | 来源 | 作者 | 许可 | 取得日期 | 校验结果 |
|---|---|---|---|---|---|---|
| assets/cannons/cannon_base.png | 炮台底座（256² RGBA） | tools/cannon_gen.py（PIL 程序生成：圆角矩形+铆钉） | Claude Code（执行方） | 自制 CC0，无许可负担 | 2026-10-26 | PASS（bbox 校验+目视） |
| assets/cannons/cannon_body.png | 炮身（白色供 palette 染色，圆心(128,150) r=86） | 同上 | 同上 | 同上 | 2026-10-26 | PASS |
| assets/cannons/cannon_barrel.png | 炮管（枢轴(128,150) 朝上，深色炮口环，枢轴→炮口124px） | 同上 | 同上 | 同上 | 2026-10-26 | PASS |
| assets/cannons/cannon_flash.png | 炮口闪光（64² 径向星形 (255,244,200)） | 同上 | 同上 | 同上 | 2026-10-26 | PASS |
