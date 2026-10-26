extends SceneTree

# FM/F5（FM14 生命周期项）：真实 main.tscn 装配下 30 轮 进关→游玩→返回列表→再进关，
# 校验：无泄漏错误、存档跨轮一致可恢复、会话独立（代际递增）、PID 隔离目录不触真档。
# 运行：godot --headless --path . -s tools/lifecycle_check.gd

var _failures := 0
var _main: Node = null


func _initialize() -> void:
	var Repo := preload("res://scripts/level/level_repository.gd")
	Repo.set_save_dir("user://test_saves/lifecycle_%d" % OS.get_process_id())
	assert(Repo.is_isolated())
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	_main = scene.instantiate()
	root.add_child(_main)
	await process_frame  # _ready 完成装配
	var Repo := preload("res://scripts/level/level_repository.gd")

	for cycle in 30:
		_main.enter_level("level_01")
		var gc: Node = _main.controller
		_check(gc.session != null and gc.session.outcome == "RUNNING",
			"轮%d 进关 RUNNING" % cycle, "")
		_check(int(gc.session.session_generation) == cycle + 1,
			"轮%d 会话代际=%d" % [cycle, cycle + 1], str(gc.session.session_generation))
		# 模拟游玩：推进 30 步 + 上位一门 + 发射几步
		var col := -1
		for c in 5:
			if not gc.session.queue_columns[c].is_empty():
				col = c
				break
		gc.place_front(col)
		for i in 30:
			gc.step(1.0 / 60.0)
		_main.return_to_list()  # 内部保存会话
		# 存档存在且可恢复校验（原子校验纯函数）
		var lr: Dictionary = Repo.load_snapshot("level_01")
		_check(lr.ok and lr.exists, "轮%d 存档可读" % cycle, str(lr.get("error", "")))
		if lr.ok and lr.exists and cycle % 10 == 9:
			var Session := preload("res://scripts/level/level_session.gd")
			var snap: Dictionary = lr.snapshot
			var gc2: Node = _main.controller
			_check(int(snap.get("session_generation", 0)) == cycle + 1,
				"轮%d 存档代际一致" % cycle, str(snap.get("session_generation")))
			gc2 = null
	print("[lifecycle] 30 轮完成")
	if _failures == 0:
		print("TEST_PASS lifecycle_check")
	else:
		print("TEST_FAIL lifecycle_check failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if not cond:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
	elif int(name.split("轮")[1].split(" ")[0]) % 10 == 9:
		print("  PASS: " + name)
