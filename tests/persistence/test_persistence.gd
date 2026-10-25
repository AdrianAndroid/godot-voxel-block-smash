extends SceneTree

# P3-05 关卡接口与持久化自测：配置校验/会话独立/存档往返/损坏拒绝/旧代拒绝
# 运行：godot --headless --path . -s tests/persistence/test_persistence.gd

var _failures := 0


func _initialize() -> void:
	var catalog := preload("res://scripts/level/level_catalog.gd")
	var session_script := preload("res://scripts/level/level_session.gd")
	var repo := preload("res://scripts/level/level_repository.gd")
	var level_loader := preload("res://scripts/data/level_loader.gd").new()

	# 关卡配置契约
	var c: Dictionary = catalog.load_config("res://assets/levels/level_01.json")
	_check(c.ok and c.config.level_id == "level_01" and c.config.display_number == 1, "level_01 配置合法", str(c))
	var bad: Dictionary = catalog.load_config("res://tests/fixtures/axis_fixture.json")
	_check(not bad.ok, "非关卡配置拒绝（缺字段）", "")
	# 路径穿越拒绝
	var traversal := {"schema_version": 1, "level_id": "x", "display_number": 1,
		"model_path": "res://assets/models/json/../../secret.json", "model_revision": "1", "rules": {}}
	var tp := "user://test_traversal.json"
	var f := FileAccess.open(tp, FileAccess.WRITE)
	f.store_string(JSON.stringify(traversal))
	f.close()
	_check(not catalog.load_config(tp).ok, "model_path 路径穿越拒绝", "")

	# 关卡装载（模型联动）
	var lv: Dictionary = level_loader.load_level("res://assets/levels/level_01.json")
	_check(lv.ok and lv.voxel_data.count == 367, "关卡装载联动模型", str(lv))

	# 会话独立：A/B 互不串
	var a: RefCounted = session_script.new()
	var b: RefCounted = session_script.new()
	a.level_id = "level_01"
	b.level_id = "level_02"
	a.alive_voxel_ids = [1, 2]
	a.outcome = "WON"
	_check(b.alive_voxel_ids.is_empty() and b.outcome == "RUNNING", "A 修改不影响 B", "")

	# 存档往返
	a.rng_seed = 42
	a.pool = [{"turret_id": 1, "color_id": 1, "ammo_count": 3, "has_fired": false}, {}, {}, {}, {}, {}, {}, {}, {}]
	var sr: Dictionary = repo.save(a.to_snapshot())
	_check(sr.ok, "存档写入", sr.get("error", ""))
	var lr: Dictionary = repo.load_snapshot("level_01")
	_check(lr.ok and lr.exists, "存档读取", lr.get("error", ""))
	var a2: RefCounted = session_script.new()
	a2.level_id = "level_01"
	_check(a2.restore(lr.snapshot), "快照恢复", "")
	_check(a2.rng_seed == 42 and a2.pool[0].get("ammo_count") == 3 and a2.outcome == "WON", "恢复内容一致", "")

	# 版本不兼容拒绝
	var bad_snap: Dictionary = a.to_snapshot()
	bad_snap["version"] = 999
	_check(not a2.restore(bad_snap), "不兼容快照拒绝", "")

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
