extends SceneTree

# FM/F1 门禁（FM01~FM04）：模型局部空间锁定弹道——真实控制器发射后，
# 飞行途中对模型做 ±90°/180°/俯仰/平移变换，球仍沿局部轨迹命中【预订目标】本身；
# 暂停冻结推进；全程零 mismatch/timeout。
# 运行：godot --headless --path . -s tests/integration/test_local_ballistics.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")


func _initialize() -> void:
	LevelRepository.set_save_dir("user://test_saves/local_ballistics_%d" % OS.get_process_id())
	assert(LevelRepository.is_isolated())
	call_deferred("_run")


func _aim_for(gc: Node) -> Callable:
	# 原点在世界空间固定（真机语义：炮口世界位置不动，模型在其下方旋转）；
	# 格空间原点每次调用按当前变换回算——旋转因此不断暴露新射界面。
	var sys: RefCounted = gc.ball_physics.system
	var world0: Vector3 = gc.voxel_model.world_from_grid() * (
		sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0))
	return func(_slot_index: int) -> Dictionary:
		var wfg: Transform3D = gc.voxel_model.world_from_grid()
		return {"ok": true, "origin": world0, "origin_grid": wfg.affine_inverse() * world0}


# 变换序列：每步一种，覆盖 ±90°/180° 横转、俯仰、平移（平移不动 basis 不算姿态写）
# 2026-10-27 P1：姿态唯一来源是控制器 yaw/pitch 状态（step 顶部按状态重建 Basis），
# 测试姿态变化必须走 set_view_pose（生产写入口），直写 Basis 会被下一步覆盖。
func _apply_pose(gc: Node, k: int) -> void:
	match k % 5:
		0: gc.set_view_pose(PI / 2, 0.0)
		1: gc.set_view_pose(-PI / 2, 0.0)
		2: gc.set_view_pose(PI, 0.0)
		3: gc.set_view_pose(0.8, 0.5)   # 横转+俯仰组合（±60° 限位内）
		4: gc.set_view_pose(0.3, 0.0)
	if k % 5 == 4:
		var t: Transform3D = gc.voxel_model.global_transform
		t.origin = Vector3(2.0, 0.5, -1.5)  # 纯平移：世界锚点移动，局部弹道不受影响
		gc.voxel_model.global_transform = t


func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	gc.origin_resolver = _aim_for(gc)
	var col := -1
	for c in 5:
		if not gc.session.queue_columns[c].is_empty():
			col = c
			break
	var p0res: Dictionary = gc.place_front(col)
	_check(p0res.ok, "列首上位", "")
	gc.auto_fire.unregister(int(p0res.turret_id))  # 手动节奏：逐发观察

	# 连打 8 发：每发飞行途中逐步施加变换；断言命中=预订、零 mismatch/timeout
	var results: Array = []  # [shot_id, reason, booked_vid, destroyed_vid]
	var destroyed := {"vid": -1}
	gc.bus.subscribe("voxel_destroyed", func(a: Array, _m: Dictionary) -> void:
		destroyed.vid = int((a[0] as Dictionary).get("voxel_id", -1)), "level_01")
	gc.bus.subscribe("shot_resolved", func(a: Array, _m: Dictionary) -> void:
		results.append([int(a[0]), str(a[1])]), "level_01")
	var shots_done := 0
	var guard := 0
	var tver0: int = gc.voxel_model.transform_version
	while shots_done < 8 and guard < 20000:
		guard += 1
		var t: Dictionary = gc.session.turrets[int(gc.session.slots[0])] \
			if int(gc.session.slots[0]) >= 0 else {}
		if t.is_empty():
			break
		# 找一发：直接调控制器内部发射闸（公共路径 try_auto_fire）。
		# FM/F2：waiting_target/scan_pending 是正常等待——回正姿态推进一步再试，不当失败。
		if int(t.get("in_flight", 0)) == 0 and int(t.ammo_remaining) > 0 and results.size() == shots_done:
			var tr: Transform3D = gc.voxel_model.global_transform
			tr.origin = Vector3.ZERO
			gc.voxel_model.global_transform = tr
			gc.set_view_pose(0.0, 0.0)  # P1：回正姿态走控制器唯一写入口
			var fr: Dictionary = gc.try_auto_fire(0)  # 参数为槽位索引
			if not fr.ok:
				gc.step(1.0 / 60.0)
			continue
		var ticket: Dictionary = gc.shot_ledger.ticket_by_turret(int(t.turret_id))
		if not ticket.is_empty():
			var booked := int(ticket.target_voxel_id)
			var age0 := -1.0
			var ball_id := int(ticket.ball_id)
			# 飞行途中逐步变换 + 中途暂停冻结
			var k := 0
			while results.size() == shots_done and guard < 20000:
				guard += 1
				_apply_pose(gc, k)
				k += 1
				if k == 4:
					var snap0: Dictionary = gc.ball_physics.system.ball_snapshot(ball_id)
					age0 = float(snap0.get("age", -1.0))
					gc.set_paused(true)
					gc.step(1.0 / 60.0)
					gc.step(1.0 / 60.0)
					var snap1: Dictionary = gc.ball_physics.system.ball_snapshot(ball_id)
					_check(snap1.is_empty() or is_equal_approx(float(snap1.get("age", -2.0)), age0),
						"暂停冻结球龄", "%s→%s" % [str(age0), str(snap1.get("age", "?"))])
					gc.set_paused(false)
				gc.step(1.0 / 60.0)
			var reason: String = str(results[shots_done][1]) if results.size() > shots_done else "NO_RESOLVE"
			_check(reason == "HIT", "旋转中命中预订目标（非 mismatch/timeout）",
				"shot=%d reason=%s booked=%d" % [shots_done, reason, booked])
			_check(destroyed.vid == booked, "命中体素==预订体素",
				"destroyed=%d booked=%d" % [destroyed.vid, booked])
			shots_done += 1
		else:
			gc.step(1.0 / 60.0)
	_check(shots_done == 8, "完成 8 发样本", "shots=%d guard=%d" % [shots_done, guard])
	_check(gc.voxel_model.transform_version > tver0, "变换版本递增（写入口生效）", "")
	var audit: Dictionary = gc.conservation_audit()
	_check(audit.ok, "守恒审计", str(audit))

	_rm_tree(LevelRepository.save_dir)
	if _failures == 0:
		print("TEST_PASS test_local_ballistics")
	else:
		print("TEST_FAIL test_local_ballistics failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
