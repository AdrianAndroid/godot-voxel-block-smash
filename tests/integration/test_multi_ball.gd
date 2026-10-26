extends SceneTree

# FM/F2 多球连发门禁（FM05~FM08）：
#  FM05 单炮实测发射率 ≥90%×(1/interval)（多球在途，冷却不等落地）
#  FM06 多炮并发在途 + 预订互斥（任意时刻 pending 票据目标体素唯一）
#  FM07 乱序结算：后发先结算不破坏状态/守恒
#  FM08 幂等重放：重复命中/重复取消事件不产生二次副作用
# 运行：godot --headless --path . -s tests/integration/test_multi_ball.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")


func _initialize() -> void:
	LevelRepository.set_save_dir("user://test_saves/multi_ball_%d" % OS.get_process_id())
	assert(LevelRepository.is_isolated())
	call_deferred("_run")


func _aim_for(gc: Node) -> Callable:
	# 原点在世界空间固定（真机语义：炮口世界位置不动，模型在其下方旋转）；
	# 格空间原点每次调用按当前变换回算——旋转因此不断暴露新射界面。
	var sys: RefCounted = gc.ball_physics.system
	var half: float = sys.boundary_half
	# 前下方偏轴原点（真机炮口契约：屏幕底部偏外槽位，射线∩边界盒前下缘）；
	# 偏轴 + 模型旋转 → 格空间原点绕模型水平环绕，旋转持续暴露新侧面目标
	var local0: Vector3 = sys.boundary_center + Vector3(half * 0.3, -(half - 0.5), -(half - 0.5))
	var world0: Vector3 = gc.voxel_model.world_from_grid() * local0
	return func(_slot_index: int) -> Dictionary:
		var wfg: Transform3D = gc.voxel_model.world_from_grid()
		return {"ok": true, "origin": world0, "origin_grid": wfg.affine_inverse() * world0}


func _mk(level_path: String = "res://assets/levels/level_01.json") -> Node:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	gc.start_level(level_path)
	gc.origin_resolver = _aim_for(gc)
	return gc


func _meta(gc: Node, eid: int) -> Dictionary:
	return {"event_id": eid, "level_id": "level_01",
		"session_generation": gc.session.session_generation, "physics_tick": 0}


# 某炮台全部 PENDING 票据（按 shot_id 升序）
func _pending_tickets(gc: Node, tid: int) -> Array:
	var out: Array = []
	for sid in gc.shot_ledger.tickets:
		var t: Dictionary = gc.shot_ledger.tickets[sid]
		if int(t.turret_id) == tid and t.status == "PENDING":
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.shot_id) < int(b.shot_id))
	return out


func _run() -> void:
	# ===== FM05：grid_300 夹具单炮实测发射率（自动旋转开启，贴近验收姿态） =====
	var gc: Node = _mk("res://tests/fixtures/level_fm05.json")
	var lid: String = gc.session.level_id
	var col1 := -1
	var best := -1
	for c in 5:
		var col: Array = gc.session.queue_columns[c]
		if col.is_empty():
			continue
		var ammo_c: int = int(gc.session.turrets[int(col[0])].ammo_remaining)
		if ammo_c > best:
			best = ammo_c
			col1 = c
	_check(gc.place_front(col1).ok, "FM05 列首上位（弹药最多列）", "")
	var tid1: int = int(gc.session.slots[0])
	var ammo_init: int = int(gc.session.turrets[tid1].ammo_remaining)
	var fires := {"n": 0}
	gc.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires.n += 1, lid)
	var steps := 0
	var first_fire_step := -1
	var last_fire_step := -1
	for i in 3600:  # 60s 模拟上限
		var before: int = fires.n
		gc.step(1.0 / 60.0)
		steps += 1
		if fires.n > before:
			last_fire_step = steps
			if first_fire_step < 0:
				first_fire_step = steps
		if int(gc.session.slots[0]) == -1:
			break
	_check(fires.n == ammo_init, "FM05 打空弹药", "fires=%d ammo=%d" % [fires.n, ammo_init])
	var window_sec: float = maxf(float(last_fire_step - first_fire_step) / 60.0, 0.001)
	var rate: float = fires.n / window_sec
	var expect: float = 0.9 / gc.rules.auto_fire_interval
	_check(rate >= expect, "FM05 发射率 %.1f/s ≥ 90%%×(1/%.2fs)=%.1f/s" % [rate,
		gc.rules.auto_fire_interval, expect], "rate=%.2f" % rate)
	print("  INFO: FM05 fires=%d window=%.2fs rate=%.2f/s stats=%s" % [
		fires.n, window_sec, rate, str(gc.fire_stats.snapshot())])
	var audit1: Dictionary = gc.conservation_audit()
	_check(audit1.ok, "FM05 守恒审计", str(audit1))
	gc.queue_free()

	# ===== FM06：三炮并发 + 预订互斥 =====
	var gc2: Node = _mk()
	var placed := 0
	for c in 5:
		if placed >= 3:
			break
		if gc2.place_front(c).ok:
			placed += 1
	_check(placed == 3, "FM06 三炮上位", "placed=%d" % placed)
	var max_active := 0
	var exclusivity_ok := true
	for i in 600:  # 10s
		gc2.step(1.0 / 60.0)
		max_active = maxi(max_active, gc2.ball_physics.system.active_count())
		# 任意时刻：pending 票据数 == 预订表大小（目标体素唯一由字典键保证）
		if gc2.shot_ledger.pending_count() != gc2.shot_ledger.reservations.size():
			exclusivity_ok = false
	_check(max_active >= 3, "FM06 多球同时在途（峰值≥3）", "max_active=%d" % max_active)
	_check(exclusivity_ok, "FM06 预订互斥（pending==reservations 恒成立）", "")
	print("  INFO: FM06 max_active=%d" % max_active)
	gc2.queue_free()

	# ===== FM07/FM08：乱序结算 + 幂等重放（减速延长在途窗口凑齐多发） =====
	var gc3: Node = _mk()
	gc3.rules.ball_speed = 30.0  # 飞行 ~0.7s，在途窗口内攒 ≥3 发
	var col3 := -1
	for c in 5:
		if not gc3.session.queue_columns[c].is_empty():
			col3 = c
			break
	gc3.place_front(col3)
	var tid3: int = int(gc3.session.slots[0])
	for i in 600:
		gc3.step(1.0 / 60.0)
		if _pending_tickets(gc3, tid3).size() >= 3:
			break
	var tickets: Array = _pending_tickets(gc3, tid3)
	_check(tickets.size() >= 3, "FM07 同时在途≥3发", "pending=%d" % tickets.size())
	var alive0: int = gc3.voxel_manager.alive_count()
	var ammo0: int = int(gc3.session.turrets[tid3].ammo_remaining)
	# 乱序：最后发射的先结算（伪造其预订目标的命中事件）
	var last: Dictionary = tickets[tickets.size() - 1]
	var first: Dictionary = tickets[0]
	var ball_last: Dictionary = gc3.ball_physics.system.ball_snapshot(int(last.ball_id))
	gc3.bus.publish("ball_hit_voxel", [ball_last,
		{"voxel_id": int(last.target_voxel_id), "color_id": int(last.color_id)}], _meta(gc3, 70001))
	_check(not gc3.voxel_manager.is_alive(int(last.target_voxel_id)), "FM07 后发目标先被删", "")
	_check(gc3.shot_ledger.ticket_by_shot(int(last.shot_id)).status == "HIT", "FM07 后发票据 HIT", "")
	_check(gc3.shot_ledger.ticket_by_shot(int(first.shot_id)).status == "PENDING",
		"FM07 先发票据仍在途", "")
	# FM08a：同一命中事件重放（新 event_id，绕过总线去重，考验结算幂等）
	gc3.bus.publish("ball_hit_voxel", [ball_last,
		{"voxel_id": int(last.target_voxel_id), "color_id": int(last.color_id)}], _meta(gc3, 70002))
	_check(gc3.voxel_manager.alive_count() == alive0 - 1, "FM08 命中重放不二次删除", "")
	# FM08b：mismatch 取消重放只返还一次
	var mid: Dictionary = _pending_tickets(gc3, tid3)[0]
	var ball_mid: Dictionary = gc3.ball_physics.system.ball_snapshot(int(mid.ball_id))
	var wrong_vid := -1
	var wrong_color := -1
	for id in gc3.voxel_manager.state.alive_ids():
		if int(id) != int(mid.target_voxel_id):
			wrong_vid = int(id)
			wrong_color = gc3.voxel_manager.color_of(wrong_vid)
			break
	gc3.bus.publish("ball_hit_voxel", [ball_mid, {"voxel_id": wrong_vid, "color_id": wrong_color}],
		_meta(gc3, 70003))
	var ammo1: int = int(gc3.session.turrets[tid3].ammo_remaining)
	_check(ammo1 == ammo0 + 1, "FM08 mismatch 返还一次", "%d→%d" % [ammo0, ammo1])
	gc3.bus.publish("ball_hit_voxel", [ball_mid, {"voxel_id": wrong_vid, "color_id": wrong_color}],
		_meta(gc3, 70004))
	_check(int(gc3.session.turrets[tid3].ammo_remaining) == ammo1,
		"FM08 取消重放不重复返还", "")
	# 剩余在途弹全部结算完（真实飞行），守恒仍成立
	for i in 1200:
		gc3.step(1.0 / 60.0)
		if gc3.shot_ledger.pending_count() == 0:
			break
	var audit3: Dictionary = gc3.conservation_audit()
	_check(audit3.ok, "FM07/08 乱序+重放后守恒审计", str(audit3))
	gc3.queue_free()

	_rm_tree(LevelRepository.save_dir)
	if _failures == 0:
		print("TEST_PASS test_multi_ball")
	else:
		print("TEST_FAIL test_multi_ball failures=%d" % _failures)
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
