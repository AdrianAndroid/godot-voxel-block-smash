extends SceneTree

# CQ-20261026 玩法集成自测：一键上位→自动补位→同色自动射击→真实命中消块→全部清零→胜利。
# 全程只通过控制器正常操作（place_front/return_turret/use_prop），不直接删块、不改胜负。
# 另含：失败真值表/通关后操作拒绝/关卡切换 v2 快照/陈旧事件拒绝。
# 运行：godot --headless --path . -s tests/integration/test_play.gd

var _failures := 0
var _events: Array = []  # [{event, args}]
var _cur_dir := Vector3(0, -1, 0)  # 当前发射原点方向（格空间，绕模型循环）

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


# 出界盒内部、贴盒面的发射原点（与真机"射线∩边界AABB内移"契约等价的测试替身）。
# 注意：弹球物理在格空间扫掠，旋转模型世界变换不改变格空间几何——
# 真机上是"相机/炮口固定、模型旋转"使格空间原点移动；测试替身等价地直接移动格空间原点。
func _aim_for(gc: Node) -> Callable:
	return func(_slot_index: int) -> Dictionary:
		var origin_grid := _origin_grid(gc)
		var world: Vector3 = gc.voxel_model.world_from_grid() * origin_grid
		return {"ok": true, "origin": world, "origin_grid": origin_grid}


func _origin_grid(gc: Node) -> Vector3:
	var sys: RefCounted = gc.ball_physics.system
	return sys.boundary_center + _cur_dir * (sys.boundary_half - 0.5)


func _run() -> void:
	# ========== 完整通关：grid_300 夹具（300 块，五色各 60） ==========
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://tests/fixtures/level_02.json")
	_check(r.ok, "夹具关卡启动", str(r))
	_check(gc.voxel_manager.alive_count() == 300, "存活 300 块", "")
	var total_ammo := 0
	for tid in gc.session.turrets:
		total_ammo += int(gc.session.turrets[tid].ammo_remaining)
	_check(total_ammo == 300, "开局弹药总数=300（逐色守恒）", "%d" % total_ammo)
	for e in gc.bus.EVENTS:
		gc.bus.subscribe(e, func(args: Array, meta: Dictionary) -> void:
			_events.append({"event": e, "args": args, "seq": meta.get("sequence", 0)}), "level_02")
	var won := {"n": 0}
	gc.bus.subscribe("level_win", func(_a: Array, _m: Dictionary) -> void: won.n += 1, "level_02")
	gc.origin_resolver = _aim_for(gc)

	# 贪心驾驶（模拟玩家正常操作）：有空槽就上"有可达同色目标"的列首；
	# 列首都不可达时取回一个等待中的炮台换列（CQ 允许的正常操作）。
	var max_streak := 0
	var last_alive := 300
	var since_progress := 0
	var steps := 0
	var orient_idx := 0
	while gc.session.outcome == "RUNNING" and steps < 120000:
		steps += 1
		gc.step(1.0 / 60.0)
		# 连击观察
		for e in _events:
			if e.event == "combo_update":
				max_streak = maxi(max_streak, int(e.args[0]))
		_events.clear()
		# 驾驶：每隔几步尝试补位
		if steps % 5 == 0:
			_drive(gc)
		var alive: int = gc.voxel_manager.alive_count()
		if alive < last_alive:
			last_alive = alive
			since_progress = 0
			if alive % 50 == 0 or alive < 20:
				print("  [play] alive=%d steps=%d orient=%d" % [alive, steps, orient_idx])
		else:
			since_progress += 1
			if since_progress >= 900:  # 15 秒无进展 → 换朝向（模拟玩家拖拽旋转）
				since_progress = 0
				orient_idx += 1
				_apply_orientation(gc, orient_idx)
	_check(gc.session.outcome == "WON" and won.n == 1, "正常操作完整通关（事件一次）",
		"outcome=%s alive=%d steps=%d" % [gc.session.outcome, gc.voxel_manager.alive_count(), steps])
	_check(gc.voxel_manager.alive_count() == 0, "全部清零", "")
	var audit: Dictionary = gc.conservation_audit()
	_check(audit.ok, "终局守恒：Q+S+F=V=0 逐色成立", str(audit))
	_check(max_streak >= 2, "全局连击出现 x2+", "max=%d" % max_streak)
	_check(not gc.place_front(0).ok and not gc.use_prop("speed_x2").ok, "通关后操作拒绝", "")

	# ========== 死局真值表（CQ/S08 §6）：队列+槽全空、余块>0、无在途 → 完整性错误，不包装成正常失败 ==========
	var gc2: Node = GameControllerScript.new()
	root.add_child(gc2)
	gc2.start_level("res://tests/fixtures/level_02.json")
	var ierrs := {"n": 0}
	gc2.bus.subscribe("integrity_error", func(_a: Array, _m: Dictionary) -> void: ierrs.n += 1, "level_02")
	gc2.session.queue_columns = [[], [], [], [], []]
	gc2.session.turrets.clear()
	for i in 5:
		gc2.session.slots[i] = -1
	gc2.step(0.016)
	_check(gc2.session.outcome == "ERROR" and ierrs.n == 1, "死局记完整性错误且只发一次", "n=%d" % ierrs.n)
	gc2.step(0.016)
	_check(ierrs.n == 1, "完整性错误不重复发布", "n=%d" % ierrs.n)

	# ========== 关卡切换 A→B→A（G15，v2 快照） ==========
	var ga: Node = GameControllerScript.new()
	root.add_child(ga)
	ga.start_level("res://assets/levels/level_01.json")
	var col_a := -1
	for c in 5:
		if not ga.session.queue_columns[c].is_empty():
			col_a = c
			break
	ga.place_front(col_a)
	var snap_a: Dictionary = ga.session.to_snapshot()
	var gb: Node = GameControllerScript.new()
	root.add_child(gb)
	var rb: Dictionary = gb.start_level("res://tests/fixtures/level_02.json")
	_check(rb.ok and gb.session.level_id == "level_02" and gb.voxel_manager.alive_count() == 300,
		"进入B（测试夹具）", str(rb))
	gb.place_front(0)
	# B 的操作不影响 A 的快照
	var snap_tid := -1
	for i in 5:
		if int(snap_a.slots[i]) >= 0:
			snap_tid = int(snap_a.slots[i])
	_check(snap_tid >= 0 and snap_a.turrets.has(snap_tid)
		and int((snap_a.turrets[snap_tid] as Dictionary).ammo_remaining) > 0, "B 操作不改 A 快照", "")
	var ga2: Node = GameControllerScript.new()
	root.add_child(ga2)
	var ra: Dictionary = ga2.start_level("res://assets/levels/level_01.json", snap_a)
	_check(ra.ok and ga2.session.slots.find(snap_tid) >= 0
		and ga2.session.queue_columns[col_a].size() == (snap_a.queue_columns[col_a] as Array).size(),
		"返回A恢复槽位/队列状态", str(ra))
	# 陈旧事件拒绝：同一总线内重开关卡后，旧 generation 事件不应投递
	var old_gen: int = ga2.session.session_generation
	ga2.start_level("res://assets/levels/level_01.json")
	var stale_ok: bool = ga2.bus.publish("voxel_destroyed", [{"voxel_id": 0}, {}],
		{"event_id": 999999, "level_id": "level_01", "session_generation": old_gen, "physics_tick": 0})
	_check(not stale_ok, "切关后旧代事件拒绝", "")

	DirAccess.remove_absolute("user://saves/level_01.json")
	DirAccess.remove_absolute("user://saves/level_02.json")

	if _failures == 0:
		print("TEST_PASS test_play")
	else:
		print("TEST_FAIL test_play failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


# 驾驶策略（与离线验证器贪心一致，均为 CQ 允许的正常操作）：
# 1) 空槽 → 上"有可达同色目标"的列首；2) ≥2 空槽时停泊不可达列首以暴露其后炮台；
# 3) 满槽时取回一个 WAITING_TARGET 炮台腾位置
func _drive(gc: Node) -> void:
	if gc.session.outcome != "RUNNING":
		return
	var origin := _origin_grid(gc)
	var free_slot := _leftmost_free(gc)
	if free_slot >= 0:
		for c in 5:
			var col: Array = gc.session.queue_columns[c]
			if col.is_empty():
				continue
			var t: Dictionary = gc.session.turrets[int(col[0])]
			var found: Dictionary = gc.target_selector.find_target(int(t.color_id), origin,
				gc.shot_ledger.is_available)
			if found.get("ok", false):
				gc.place_front(c)
				return
		# 停泊：没有可达列首且空槽 ≥2 → 上一个列首腾出队列深度
		if _free_count(gc) >= 2:
			for c in 5:
				if not gc.session.queue_columns[c].is_empty():
					gc.place_front(c)
					return
	else:
		for i in 5:
			var tid := int(gc.session.slots[i])
			if tid >= 0 and gc.session.turrets[tid].state == "WAITING_TARGET" \
					and int(gc.session.turrets[tid].get("in_flight", 0)) == 0:
				gc.return_turret(i)
				return


func _free_count(gc: Node) -> int:
	var n := 0
	for i in mini(gc.session.unlocked_slots, 5):
		if int(gc.session.slots[i]) == -1:
			n += 1
	return n


# 原点方向循环：6 轴向 + 12 棱向（等价真机"拖拽旋转模型使炮口相对模型换向"）
func _apply_orientation(gc: Node, idx: int) -> void:
	var dirs := [
		Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
		Vector3(1, -1, 0), Vector3(-1, -1, 0), Vector3(0, -1, 1), Vector3(0, -1, -1),
		Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1),
		Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3(0, 1, 1), Vector3(0, 1, -1),
	]
	_cur_dir = dirs[idx % dirs.size()].normalized()
	# 同步旋转模型姿态（对格空间弹道无影响，仅保持与真机表现一致）
	gc.voxel_model.global_transform.basis = Basis.from_euler(
		Vector3(0.0, deg_to_rad(float(idx % 18) * 20.0), 0.0))


func _leftmost_free(gc: Node) -> int:
	for i in mini(gc.session.unlocked_slots, 5):
		if int(gc.session.slots[i]) == -1:
			return i
	return -1


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
