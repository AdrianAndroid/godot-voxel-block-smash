# FM/F5 构建标识（build-info）

## 最终交付构建（PerfProbe 关闭，FM 验收 run-4 所用二进制）

- 构建时间：2026-10-27 01:16（本地）
- .app 路径：`builds/macos/VoxelBlockSmash.app`（export preset "macOS"，export-release）
- 可执行 SHA256：`b7d946af2ead172fb1c5ec2ed274b12013fa491ff18ac6c2e862587bcade4295`
  （`Contents/MacOS/godot-voxel-block-smash`，universal，170134032 字节）
- 与验收 run-1/2/3 二进制（SHA `cc81fa5e…f7dbf0`）的唯一差异：`perf_probe.gd` ENABLED true→false
  （探针调用编译期内联为空，玩法代码零差异）；run-4 全流程证据均出自本最终构建
- 源码提交：git HEAD `31417c52a650ec5adc17dccf179edd9c27a8bbe9`（"成品"）
- dirty 状态：F0~F5 全部改动未提交（工作区含玩法/测试/报告改动；详见 `git status`）
- 模型哈希：frog_02.json MD5 `6a76e2453bc882b8013e38cb6850f5cf`（4105 体素）
- 环境：macOS 15.7.9 (24G830) x86_64；CPU Intel Core i7-8700B @3.20GHz；GPU Intel UHD Graphics 630
- Godot：4.7.2 stable（/usr/local/bin/godot）；导出模板 4.7.2.stable
- 渲染后端/窗口：540×1200 窗口（手机竖屏比例，鼠标即点按，未开 emulate_touch）；macOS 失焦只清手势不暂停（失焦时间计入 FM13 有效局时）
- 规则配置（level_01.json）：ball_speed=120 格/秒、auto_fire_interval=0.09s、max_in_flight_per_turret=6、max_active_projectiles=30、auto_rot_deg_per_sec=8.0、initial_slots=3、queue_seed=4

## 历史构建（验收 run-1/2/3，PerfProbe 开启）

- 构建时间：2026-10-26 23:57（本地）
- .app 路径：`builds/macos/VoxelBlockSmash.app`（export preset "macOS"，export-release）
- 可执行 SHA256：`cc81fa5ee0bcd22356f928a33cc0470f9015517652332557cbfd786735f7dbf0`
  （`Contents/MacOS/godot-voxel-block-smash`，universal，170134032 字节）
- 源码提交：git HEAD `31417c52a650ec5adc17dccf179edd9c27a8bbe9`（"成品"）
- dirty 状态：F0~F4 全部改动未提交（工作区含 24 个修改文件 + 新增 fire_stats/夹具/测试/FM 报告等；详见 `git status`）
- 模型哈希：frog_02.json MD5 `6a76e2453bc882b8013e38cb6850f5cf`（4105 体素）
- 环境：macOS 15.7.9 (24G830) x86_64；CPU Intel Core i7-8700B @3.20GHz；GPU Intel UHD Graphics 630
- Godot：4.7.2 stable（/usr/local/bin/godot）；导出模板 4.7.2.stable
- 渲染后端/窗口：540×1200 窗口（手机竖屏比例，鼠标即点按，未开 emulate_touch）；macOS 失焦只清手势不暂停（失焦时间计入 FM13 有效局时）
- 规则配置（level_01.json）：ball_speed=100 格/秒、auto_fire_interval=0.10s、max_in_flight_per_turret=6、max_active_projectiles=30、auto_rot_deg_per_sec=8.0、queue_seed=4
