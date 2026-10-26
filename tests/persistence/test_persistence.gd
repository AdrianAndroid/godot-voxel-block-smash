extends SceneTree

# P3-05 关卡接口与持久化自测：配置校验/会话独立/存档往返/损坏拒绝/旧代拒绝
# CQ-20261026/S09：v2 快照 = 五列队列 + turrets 字典 + 固定五槽；v1 旧档拒绝（main 备份后重开）
# 运行：godot --headless --path . -s tests/persistence/test_persistence.gd

var _failures := 0


func _initialize() -> void:
	var catalog := preload("res://scripts/level/level_catalog.gd")
	var session_script := preload("res://scripts/level/level_session.gd")
	var repo := preload("res://scripts/level/level_repository.gd")
	var level_loader := preload("res://scripts/data/level_loader.gd").new()

	# FM/F0：隔离测试存档目录，禁止触碰真实进度
	var test_dir := "user://test_saves/persistence_%d" % OS.get_process_id()
	repo.set_save_dir(test_dir)
	assert(repo.is_isolated())

	# 关卡配置契约
	var c: Dictionary = catalog.load_config("res://assets/levels/level_01.json")
	_check(c.ok and c.config.level_id == "level_01" and c.config.display_number == 1
		and int(c.config.get("queue_seed", 0)) == 4, "level_01 配置合法（含 queue_seed=4）", str(c))
	var bad: Dictionary = catalog.load_config("res://tests/fixtures/axis_fixture.json")
	_check(not bad.ok, "非关卡配置拒绝（缺字段）", "")
	# 路径穿越拒绝
	var traversal := {"schema_version": 1, "level_id": "x", "display_number": 1,
		"model_path": "res://assets/models/json/../../secret.json", "model_revision": "1", "rules": {}}
	var tp := test_dir.path_join("test_traversal.json")
	DirAccess.make_dir_recursive_absolute(test_dir)
	var f := FileAccess.open(tp, FileAccess.WRITE)
	f.store_string(JSON.stringify(traversal))
	f.close()
	_check(not catalog.load_config(tp).ok, "model_path 路径穿越拒绝", "")

	# 关卡装载（模型联动）
	var lv: Dictionary = level_loader.load_level("res://assets/levels/level_01.json")
	_check(lv.ok and lv.voxel_data.count == 4105, "关卡装载联动模型（frog_02）", str(lv))

	# 会话独立：A/B 互不串
	var a: RefCounted = session_script.new()
	var b: RefCounted = session_script.new()
	a.level_id = "level_01"
	b.level_id = "level_02"
	a.alive_voxel_ids = [1, 2]
	a.outcome = "WON"
	_check(b.alive_voxel_ids.is_empty() and b.outcome == "RUNNING", "A 修改不影响 B", "")

	# v2 存档往返：五列队列 + turrets + 固定五槽 + S09（模型哈希/规则版本/RNG 状态）
	a.rng_seed = 4
	a.rng_state = 987654
	a.model_hash = "abc123"
	a.rules_version = 2
	a.turrets = {1: {"turret_id": 1, "color_id": 1, "ammo_remaining": 42,
		"origin_column": 0, "state": "READY", "has_fired": true, "in_flight": 0}}
	a.queue_columns = [[], [2], [], [], []]
	a.turrets[2] = {"turret_id": 2, "color_id": 4, "ammo_remaining": 33,
		"origin_column": 1, "state": "QUEUED", "has_fired": false}
	a.slots = [1, -1, -1, -1, -1]
	a.v0_counts = {1: 3167, 4: 311}
	var sr: Dictionary = repo.save(a.to_snapshot())
	_check(sr.ok, "存档写入", sr.get("error", ""))
	var lr: Dictionary = repo.load_snapshot("level_01")
	_check(lr.ok and lr.exists, "存档读取", lr.get("error", ""))
	var a2: RefCounted = session_script.new()
	a2.level_id = "level_01"
	_check(a2.restore(lr.snapshot), "v2 快照恢复", "")
	_check(a2.rng_seed == 4 and a2.outcome == "WON"
		and int(a2.turrets[1].ammo_remaining) == 42 and int(a2.slots[0]) == 1
		and a2.queue_columns[1] == [2] and int(a2.v0_counts[1]) == 3167,
		"恢复内容一致（队列/槽/turrets/V0）", str(a2.to_snapshot()))
	_check(a2.rng_state == 987654 and a2.model_hash == "abc123" and a2.rules_version == 2,
		"S09 字段往返（rng_state/model_hash/rules_version）", "")
	# S08 迁移：旧档 any_color → designated_target；选择模式不落盘
	var mig: Dictionary = a.to_snapshot()
	mig.prop_counts = {"speed_x2": 1, "any_color": 3}
	mig.pending_effects = {"speed_x2": false, "any_color": true}
	var a3: RefCounted = session_script.new()
	a3.level_id = "level_01"
	_check(a3.restore(mig) and int(a3.prop_counts.get("designated_target", -1)) == 3
		and not a3.prop_counts.has("any_color")
		and not bool(a3.pending_effects.get("designated_selecting", true)),
		"S08 道具迁移（any_color→designated_target，选择模式清空）", str(a3.prop_counts))

	# FM/F4：RNG 大 state 十进制字符串往返——恢复后继续同一随机序列（16 个 randi 一致）
	# 取一个超过 double 53bit 安全整数范围的 state，证明字符串往返无精度损失
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4
	var big_state: int = rng_a.state | 0x3000000000000001  # 强制高位（>2^53，double 无法精确表示）
	rng_a.state = big_state
	var expect: Array[int] = []
	for i in 16:
		expect.append(rng_a.randi())
	var snap_rng: Dictionary = a.to_snapshot()
	snap_rng.rng_seed = str(4)
	snap_rng.rng_state = str(big_state)
	# 走真实 JSON 序列化往返（number 会丢精度，字符串不会）
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snap_rng))
	var a4: RefCounted = session_script.new()
	a4.level_id = "level_01"
	_check(a4.restore(parsed) and a4.rng_state == big_state,
		"大 rng_state JSON 往返无精度损失", "%d vs %d" % [a4.rng_state, big_state])
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = a4.rng_seed
	rng_b.state = a4.rng_state
	var got: Array[int] = []
	for i in 16:
		got.append(rng_b.randi())
	_check(got == expect, "恢复后 16 个 randi 序列一致", "%s vs %s" % [str(got), str(expect)])
	# 旧档 number 兼容路径（double 精度内安全值仍可恢复）
	var snap_num: Dictionary = a.to_snapshot()
	snap_num.rng_seed = 4
	snap_num.rng_state = 987654
	var a5: RefCounted = session_script.new()
	a5.level_id = "level_01"
	_check(a5.restore(snap_num) and a5.rng_seed == 4 and a5.rng_state == 987654,
		"旧档 number rng 字段兼容恢复", "")

	# 版本不兼容拒绝（v1 旧档/未知版本）
	var bad_snap: Dictionary = a.to_snapshot()
	bad_snap["version"] = 1
	_check(not a2.restore(bad_snap), "v1 旧档拒绝", "")
	bad_snap["version"] = 999
	_check(not a2.restore(bad_snap), "未知版本快照拒绝", "")

	# 损坏存档拒绝（不静默覆盖）
	var sp: String = repo.save_path("level_02")
	var g := FileAccess.open(sp, FileAccess.WRITE)
	g.store_string("{corrupted")
	g.close()
	var lr2: Dictionary = repo.load_snapshot("level_02")
	_check(lr2.exists and not lr2.ok, "损坏存档拒绝", str(lr2))
	repo.delete_save("level_01")
	repo.delete_save("level_02")
	DirAccess.remove_absolute(tp)
	DirAccess.remove_absolute(test_dir)

	# 关卡列表排序
	var levels: Array = catalog.list_levels()
	_check(levels.size() >= 1 and levels[0].level_id == "level_01", "关卡列表", str(levels.size()))

	if _failures == 0:
		print("TEST_PASS test_persistence")
	else:
		print("TEST_FAIL test_persistence failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
