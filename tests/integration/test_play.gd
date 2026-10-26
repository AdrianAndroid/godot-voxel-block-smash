extends SceneTree

# CQ-20261026 玩法集成自测：一键上位→自动补位→同色自动射击→真实命中消块→全部清零→胜利。
# 全程只通过控制器正常操作（place_front/use_prop），不直接删块、不改胜负、不取回（FM/F3）。
# 另含：失败真值表/通关后操作拒绝/关卡切换 v2 快照/陈旧事件拒绝。
# 运行：godot --headless --path . -s tests/integration/test_play.gd

var _failures := 0
var _events: Array = []  # [{event, args}]
var _origin_worlds: Array = []  # 世界固定炮口候选（不同高度/方位角）
var _origin_idx := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")


func _initialize() -> void:
	# FM/F0：隔离测试存档目录，禁止触碰真实进度
	LevelRepository.set_save_dir("user://test_saves/play_%d" % OS.get_process_id())
	assert(LevelRepository.is_isolated())
	call_deferred("_run")


# 世界固定炮口（真机契约：炮口不动，模型在其下方自动旋转 → 格空间原点连续环绕）。
# FM/F3：旧"格空间方向跳变"替身方向量化太粗，窄可达窗口（~15°）被系统性漏扫；
# 连续环绕 = 真实验收配置（自动旋转 8°/s，45s 扫完全部偏航角）。
func _aim_for(gc: Node) -> Callable:
	var sys: RefCounted = gc.ball_physics.system
	var half: float = sys.boundary_half
	_origin_worlds.clear()
	# 前下偏轴 / 前中 / 前上 / 侧下 / 正下偏轴（格空间局部→世界，一次定型）
	for local0 in [
		sys.boundary_center + Vector3(half * 0.3, -(half - 0.5), -(half - 0.5)),
		sys.boundary_center + Vector3(0, 0, -(half - 0.5)),
		sys.boundary_center + Vector3(-half * 0.3, (half - 0.5) * 0.6, -(half - 0.5)),
		sys.boundary_center + Vector3(-(half - 0.5), -(half - 0.5) * 0.4, half * 0.2),
		sys.boundary_center + Vector3(half * 0.5, -(half - 0.5), half * 0.3),
	]:
		_origin_worlds.append(gc.voxel_model.world_from_grid() * (local0 as Vector3))
	_origin_idx = 0
	return func(_slot_index: int) -> Dictionary:
		var wfg: Transform3D = gc.voxel_model.world_from_grid()
		var w0: Vector3 = _origin_worlds[_origin_idx]
		return {"ok": true, "origin": w0, "origin_grid": wfg.affine_inverse() * w0}


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
	# FM/F3：无取回——槽满等待时靠自动旋转连续环绕重暴露 + 无进展时切换炮口高度。
	var max_streak := 0
	var last_alive := 300
	var since_progress := 0
	var steps := 0
	while gc.session.outcome == "RUNNING" and steps < 300000:
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
				print("  [play] alive=%d steps=%d origin=%d" % [alive, steps, _origin_idx])
		else:
			since_progress += 1
			if since_progress >= 600:  # 10 秒无进展 → 换炮口高度/方位（模拟玩家拖拽俯仰）
				since_progress = 0
				_origin_idx = (_origin_idx + 1) % _origin_worlds.size()
	var diag := _diag(gc)
	_check(gc.session.outcome == "WON" and won.n == 1, "正常操作完整通关（事件一次）",
		"outcome=%s alive=%d steps=%d\n%s" % [gc.session.outcome,
			gc.voxel_manager.alive_count(), steps, diag])
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

	_rm_tree(LevelRepository.save_dir)  # 清理隔离测试目录

	if _failures == 0:
		print("TEST_PASS test_play")
	else:
		print("TEST_FAIL test_play failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


# 驾驶策略（与离线验证器贪心一致，均为 CQ 允许的正常操作）：
# 1) 空槽 → 上"有可达同色目标"的列首；2) 有空槽时停泊不可达列首以暴露其后炮台；
# 3) FM/F3：无取回——满槽且有炮台等待目标时，先用 add_slot 解锁槽位，
#    其余交给主循环的无进展旋转周期重暴露
func _drive(gc: Node) -> void:
	if gc.session.outcome != "RUNNING":
		return
	var wfg: Transform3D = gc.voxel_model.world_from_grid()
	var origin: Vector3 = wfg.affine_inverse() * (_origin_worlds[_origin_idx] as Vector3)
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
		# 停泊：没有可达列首且有空槽 → 上一个列首腾出队列深度
		# FM/F3：无取回后不再有"机动槽"概念，最后一个空槽也用于推进队列
		if _free_count(gc) >= 1:
			for c in 5:
				if not gc.session.queue_columns[c].is_empty():
					gc.place_front(c)
					return
	else:
		# FM/F3：无取回。槽满且存在等待目标的炮台 → 有 add_slot 库存就开槽
		var waiting := false
		for i in 5:
			var tid := int(gc.session.slots[i])
			if tid >= 0 and gc.session.turrets[tid].state == "WAITING_TARGET":
				waiting = true
		if waiting and gc.session.unlocked_slots < gc.rules.max_slots \
				and int(gc.session.prop_counts.get("add_slot", 0)) > 0:
			gc.use_prop("add_slot")

func _free_count(gc: Node) -> int:
	var n := 0
	for i in mini(gc.session.unlocked_slots, 5):
		if int(gc.session.slots[i]) == -1:
			n += 1
	return n


# FM/F3 无取回死局诊断：槽位/队列/发射统计，便于定位是槽位饥饿还是种子不可解
func _diag(gc: Node) -> String:
	var lines: Array = []
	for i in 5:
		var tid := int(gc.session.slots[i])
		if tid < 0:
			lines.append("slot%d=-" % i)
		else:
			var t: Dictionary = gc.session.turrets.get(tid, {})
			lines.append("slot%d=tid%d c%s ammo%d %s fly%d" % [i, tid, str(t.get("color_id", "?")),
				int(t.get("ammo_remaining", 0)), str(t.get("state", "?")), int(t.get("in_flight", 0))])
	var qlens: Array = []
	for col in gc.session.queue_columns:
		qlens.append((col as Array).size())
	lines.append("queue=%s props=%s stats=%s" % [str(qlens), str(gc.session.prop_counts),
		str(gc.fire_stats.snapshot())])
	return "\n".join(lines)


# 原点切换由 _origin_idx 驱动（见 _aim_for）：世界固定炮口 + 模型自动旋转连续环绕。

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
