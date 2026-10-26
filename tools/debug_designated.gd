extends SceneTree

# 调试：复现 test_designated 后段——指定目标发射后球是否命中、in_flight 是否归零
const GameControllerScript := preload("res://scripts/app/game_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	print("start ok=%s" % str(r.ok))
	gc.origin_resolver = func(_s: int) -> Dictionary:
		var sys: RefCounted = gc.ball_physics.system
		var origin_grid: Vector3 = sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0)
		var world: Vector3 = gc.voxel_model.world_from_grid() * origin_grid
		return {"ok": true, "origin": world, "origin_grid": origin_grid}

	var col := -1
	for c in 5:
		var qcol: Array = gc.session.queue_columns[c]
		if not qcol.is_empty() and int(gc.session.turrets[int(qcol[0])].color_id) == 1:
			col = c
			break
	var pres: Dictionary = gc.place_front(col)
	var slot := int(pres.slot)
	var tid := int(pres.turret_id)
	print("placed slot=%d tid=%d" % [slot, tid])

	var o: Dictionary = gc.origin_resolver.call(slot)
	var normal: Dictionary = gc.target_selector.find_target(1, o.origin_grid, gc.shot_ledger.is_available)
	print("find_target: %s" % str(normal))
	var vid1 := int(normal.voxel_id)

	gc.use_prop("designated_target")
	gc.designated_select_turret(slot)
	var cam := Camera3D.new()
	root.add_child(cam)
	var wfg: Transform3D = gc.voxel_model.world_from_grid()
	var v1_world: Vector3 = wfg * (gc.voxel_manager.data.positions[vid1] + Vector3(0.5, 0.5, 0.5))
	cam.global_position = o.origin
	cam.look_at(v1_world, Vector3.UP if absf((v1_world - o.origin).normalized().y) < 0.99 else Vector3.FORWARD)
	var ares: Dictionary = gc.designated_select_voxel(cam.unproject_position(v1_world), cam)
	print("designate: %s" % str(ares))

	var expired := {"n": 0}
	gc.bus.subscribe("designated_expired", func(_a: Array, _m: Dictionary) -> void:
		expired.n += 1, "level_01")
	gc.bus.subscribe("voxel_destroyed", func(a: Array, _m: Dictionary) -> void:
		print("  destroyed vid=%d" % int(a[0].get("voxel_id", -1))), "level_01")
	gc.bus.subscribe("shot_timeout", func(a: Array, _m: Dictionary) -> void:
		print("  shot_timeout %s" % str(a[0])), "level_01")

	var fres: Dictionary = gc.try_auto_fire(slot)
	print("fire: ok=%s reason=%s" % [str(fres.get("ok")), str(fres.get("reason", ""))])
	var last_flight := -1
	for i in 400:
		gc.step(0.05)
		var flight := int(gc.session.turrets.get(tid, {}).get("in_flight", 0))
		if flight != last_flight:
			print("step=%d in_flight=%d alive(vid1)=%s" % [i, flight, str(gc.voxel_manager.is_alive(vid1))])
			last_flight = flight
		if expired.n == 0 and flight == 0:
			var rr: Dictionary = gc.try_auto_fire(slot)
			print("step=%d refire ok=%s reason=%s designated=%d" % [i, rr.get("ok", false),
				str(rr.get("reason", "")), int(gc.session.turrets.get(tid, {}).get("designated_target", -999))])
		if expired.n > 0:
			break
	print("expired.n=%d alive(vid1)=%s" % [expired.n, str(gc.voxel_manager.is_alive(vid1))])
	quit(0)
