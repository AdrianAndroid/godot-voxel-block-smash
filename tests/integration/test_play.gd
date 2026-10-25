extends SceneTree

# P4-03/05/06/07/08/09 玩法集成自测：发射事务/同色消除/连击/道具生效/胜负/关卡切换
# 运行：godot --headless --path . -s tests/integration/test_play.gd

var _failures := 0
var _events: Array = []  # [{event, args}]
var _probe_ball := -1
var _probe_gc: Node = null

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	_check(gc.session.pool.size() == 9 and gc.session.unlocked_slots == 3, "池9格/初始3槽", "")
	for e in gc.bus.EVENTS:
		gc.bus.subscribe(e, func(args: Array, meta: Dictionary) -> void:
			_events.append({"event": e, "args": args, "seq": meta.get("sequence", 0)}), "level_01")

	# --- 安放与发射事务（G02/G05） ---
	_check(not gc.place_turret(9).ok, "越界池格安放拒绝", "")
	_check(gc.place_turret(0).ok, "安放池0→槽", "")
	_check(gc.session.pool[0].is_empty() and gc.session.slots.size() == 1, "安放后归属唯一", "")
	gc.session.slots[0].ammo_count = 2
	gc.session.slots[0].color_id = gc.voxel_manager.color_of(_first_alive(gc))  # 保证同色命中
	var aim := _aim_at_voxel(gc, _first_alive(gc))
	var f1: Dictionary = gc.fire(0, aim.origin, aim.dir)
	_check(f1.ok and f1.ammo_left == 1, "首次发射扣弹 2→1", str(f1))
	var b1: Dictionary = gc.ball_physics.system.ball_snapshot(f1.ball_id)
	_check(is_equal_approx(b1.vel.length(), 12.0), "基础速度模长=12", str(b1.vel))
	var f2: Dictionary = gc.fire(0, aim.origin, aim.dir)
	_check(f2.ok and f2.ammo_left == 0 and gc.session.slots.is_empty(), "归零炮台移除", str(f2))
	_check(gc.ball_physics.system.active_count() == 2, "已发射球不受炮台移除影响", "")
	_check(not gc.fire(0, aim.origin, aim.dir).ok, "空槽不发射", "")

	# --- 同色消除 + 连击（G04/G07） ---
	var alive_before: int = gc.voxel_manager.alive_count()
	_step_until(gc, func() -> bool: return _has_event("voxel_destroyed"), 600)
	_check(_has_event("voxel_destroyed"), "同色命中删除（颜色来自炮台=命中块）", "")
	_check(gc.voxel_manager.alive_count() < alive_before, "存活数下降", "%d→%d" % [alive_before, gc.voxel_manager.alive_count()])
	_check(_has_event("combo_update"), "删除产生连击事件", "")

	# --- 异色反弹不删除（G04） ---
	var mism := _aim_at_voxel(gc, _find_voxel_of_color(gc, _other_color(gc)))
	_probe_ball = gc.ball_physics.spawn_ball(mism.origin, mism.dir * 12.0, 900, _other_color(gc), false)
	_probe_gc = gc
	var alive2: int = gc.voxel_manager.alive_count()
	_step_until(gc, _probe_bounced_or_dead, 1200)
	_check(gc.voxel_manager.alive_count() == alive2, "异色命中不删除", "%d→%d" % [alive2, gc.voxel_manager.alive_count()])

	# --- 出界清零连击（G07） ---
	_probe_ball = gc.ball_physics.spawn_ball(Vector3(0, -50, 0), Vector3(0, -12, 0), 901, 1, false)
	_probe_gc = gc
	_step_until(gc, func() -> bool: return _has_event("ball_out_of_bounds"), 600)
	_check(not gc.ball_physics.system.ball_snapshot(_probe_ball).get("active", true), "出界球结束", "")
	_check(_count_event("ball_out_of_bounds") >= 1, "出界事件提交", "")

	# --- 道具生效（G08/G10） ---
	gc.place_turret(1)
	gc.session.slots[0].ammo_count = 5
	gc.use_prop("speed_x2")
	var target := _aim_at_voxel(gc, _first_alive(gc))
	var fs: Dictionary = gc.fire(0, target.origin, target.dir)
	var bs: Dictionary = gc.ball_physics.system.ball_snapshot(fs.ball_id)
	_check(is_equal_approx(bs.vel.length(), 24.0), "速度×2下一发=24", str(bs.vel))
	_check(not gc.session.pending_effects.speed_x2, "速度×2用后清除", "")
	var fs2: Dictionary = gc.fire(0, target.origin, target.dir)
	_check(is_equal_approx(gc.ball_physics.system.ball_snapshot(fs2.ball_id).vel.length(), 12.0),
		"后续发射恢复12", "")

	# 任意指：异色炮台消除异色块
	gc.use_prop("any_color")
	var vid := _first_alive(gc)
	var vc: int = gc.voxel_manager.color_of(vid)
	gc.session.slots[0].color_id = _other_color_of(gc, vc)
	var aim2 := _aim_at_voxel(gc, vid)
	var fa: Dictionary = gc.fire(0, aim2.origin, aim2.dir)
	_step_until(gc, func() -> bool: return not gc.voxel_manager.is_alive(vid), 600)
	_check(not gc.voxel_manager.is_alive(vid), "任意指弹珠消除异色块", "")
	_check(not gc.session.pending_effects.any_color, "任意指发射后清除", "")

	# --- 胜负（G12/G14 + D08） ---
	# 失败真值表：余块>0、池空、槽空、无活跃球、随机排=0
	var gc2: Node = GameControllerScript.new()
	root.add_child(gc2)
	gc2.start_level("res://assets/levels/level_01.json")
	var lost := {"n": 0}
	gc2.bus.subscribe("level_lose", func(a: Array, m: Dictionary) -> void: lost.n += 1, "level_01")
	for i in 9:
		gc2.session.pool[i] = {}
	gc2.session.slots.clear()
	gc2.session.prop_counts.shuffle = 0
	gc2.step(0.016)
	_check(gc2.session.outcome == "LOST" and lost.n == 1, "失败真值表触发且只发一次", "n=%d" % lost.n)
	gc2.step(0.016)
	_check(lost.n == 1, "失败不重复发布", "n=%d" % lost.n)

	# 通关：清空所有块 → 一次 level_win；通关后操作拒绝
	var gc3: Node = GameControllerScript.new()
	root.add_child(gc3)
	gc3.start_level("res://assets/levels/level_01.json")
	var won := {"n": 0}
	gc3.bus.subscribe("level_win", func(a: Array, m: Dictionary) -> void: won.n += 1, "level_01")
	for id in gc3.voxel_manager.state.alive_ids():
		gc3.voxel_manager.destroy(id)
	gc3.step(0.016)
	gc3.step(0.016)
	_check(gc3.session.outcome == "WON" and won.n == 1, "全清通关且只发一次", "n=%d" % won.n)
	_check(not gc3.place_turret(0).ok and not gc3.use_prop("speed_x2").ok, "通关后操作拒绝", "")

	# --- 关卡切换 A→B→A（G15） ---
	var ga: Node = GameControllerScript.new()
	root.add_child(ga)
	ga.start_level("res://assets/levels/level_01.json")
	ga.place_turret(0)
	var snap_a: Dictionary = ga.session.to_snapshot()
	var gb: Node = GameControllerScript.new()
	root.add_child(gb)
	var rb: Dictionary = gb.start_level("res://tests/fixtures/level_02.json")
	_check(rb.ok and gb.session.level_id == "level_02" and gb.voxel_manager.alive_count() == 300,
		"进入B（测试夹具）", str(rb))
	gb.place_turret(0)
	_check(snap_a.pool[1].get("turret_id", -1) != -1, "B 操作不改 A 快照", "")
	var ga2: Node = GameControllerScript.new()
	root.add_child(ga2)
	var ra: Dictionary = ga2.start_level("res://assets/levels/level_01.json", snap_a)
	_check(ra.ok and ga2.session.slots.size() == 1 and ga2.session.pool[0].is_empty(),
		"返回A恢复炮台/槽状态", str(ra))
	# 陈旧事件拒绝：同一总线内重开关卡后，旧 generation 事件不应投递
	var old_gen: int = ga2.session.session_generation
	ga2.start_level("res://assets/levels/level_01.json")
	var stale_ok: bool = ga2.bus.publish("voxel_destroyed", [{"voxel_id": 0}, {}],
		{"event_id": 999999, "level_id": "level_01", "session_generation": old_gen, "physics_tick": 0})
	_check(not stale_ok, "切关后旧代事件拒绝", "")

	DirAccess.remove_absolute("user://saves/level_01.json")

	if _failures == 0:
		print("TEST_PASS test_play")
	else:
		print("TEST_FAIL test_play failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


# --- 工具 ---

func _aim_at_voxel(gc: Node, voxel_id: int) -> Dictionary:
	var data: RefCounted = gc.voxel_manager.data
	var grid_center: Vector3 = data.positions[voxel_id] + Vector3(0.5, 0.5, 0.5)
	var world: Vector3 = gc.voxel_model.world_from_grid() * grid_center
	var origin := world + Vector3(0, -8.0, 0)
	return {"origin": origin, "dir": (world - origin).normalized()}


func _first_alive(gc: Node) -> int:
	return int(gc.voxel_manager.state.alive_ids()[0])


func _find_voxel_of_color(gc: Node, color_id: int) -> int:
	for id in gc.voxel_manager.state.alive_ids():
		if gc.voxel_manager.color_of(id) == color_id:
			return id
	return _first_alive(gc)


func _other_color(gc: Node) -> int:
	var vid := _first_alive(gc)
	return _other_color_of(gc, gc.voxel_manager.color_of(vid))


func _other_color_of(gc: Node, color_id: int) -> int:
	for id in gc.voxel_manager.state.alive_ids():
		var c: int = gc.voxel_manager.color_of(id)
		if c != color_id:
			return c
	return 1 if color_id != 1 else 2


func _probe_bounced_or_dead() -> bool:
	var b: Dictionary = _probe_gc.ball_physics.system.ball_snapshot(_probe_ball)
	if b.is_empty():
		return true
	return int(b.get("bounces", 0)) > 0 or not bool(b.get("active", false))


func _step_until(gc: Node, cond: Callable, max_steps: int) -> void:
	for i in max_steps:
		gc.step(1.0 / 60.0)
		if cond.call():
			return


func _has_event(name: String) -> bool:
	for e in _events:
		if e.event == name:
			return true
	return false


func _count_event(name: String) -> int:
	var n := 0
	for e in _events:
		if e.event == name:
			n += 1
	return n


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
