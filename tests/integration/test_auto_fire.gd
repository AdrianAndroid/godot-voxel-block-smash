extends SceneTree

# CQ-20261026/S04~S05 集成自测：一键上位自动连发（同色可达才发射）/一发一块/
# 取消返还/归零暂留结算后移除/取回事务/恢复重新注册/坏档拒绝（CQ/S09）/弹珠表现。
# 运行：godot --headless --path . -s tests/integration/test_auto_fire.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


# 模型正下方的发射原点解析器（模拟表现层投影）：底面体素可达。
# 原点必须在出界判定盒【内部】（真机契约：相机射线∩边界AABB后内移0.1），否则出生即出界。
func _aim_for(gc: Node) -> Callable:
	return func(_slot_index: int) -> Dictionary:
		var sys: RefCounted = gc.ball_physics.system
		var origin_grid: Vector3 = sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0)
		var world: Vector3 = gc.voxel_model.world_from_grid() * origin_grid
		return {"ok": true, "origin": world, "origin_grid": origin_grid}


func _run() -> void:
	# --- 调色板 = 模型实际颜色；V0 = 各色体素数（守恒基准） ---
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	var model_colors := {}
	for id in range(gc.voxel_manager.data.count):
		model_colors[gc.voxel_manager.color_of(id)] = true
	_check(gc.rules.palette_color_ids.size() == model_colors.size(),
		"调色板=模型有效色去重", str(gc.rules.palette_color_ids))
	var want_w := {1: 3167, 4: 311, 6: 218, 7: 30, 8: 299, 9: 80}
	var w_ok := true
	for cid in want_w:
		if int(gc.session.v0_counts.get(cid, -1)) != want_w[cid]:
			w_ok = false
	_check(w_ok and gc.session.v0_counts.size() == want_w.size(),
		"V0=模型各色块数", str(gc.session.v0_counts))
	# 生成守恒：逐色队列弹药合计 == V0
	var total_ammo := 0
	for tid in gc.session.turrets:
		total_ammo += int(gc.session.turrets[tid].ammo_remaining)
	_check(total_ammo == 4105, "开局弹药总数=模型体素数 4105", "%d" % total_ammo)
	_check(gc.session.queue_columns.size() == 5, "五列队列", "")

	gc.origin_resolver = _aim_for(gc)
	var fires := {"n": 0, "ids": []}
	gc.bus.subscribe("turret_fire", func(a: Array, _m: Dictionary) -> void:
		fires.n += 1
		fires.ids.append(int(a[0].turret_id)), "level_01")

	# --- 一键上位：点列首 → 最左空槽 → 自动连发 → 真实弹药打空离场（全程守恒） ---
	# 选存活块最多的颜色的列首（保证下方射界全程可达），不改弹药（改弹药本身破坏守恒）
	var col := _column_with_color(gc, 1)  # 绿 3167 块
	if col < 0:
		col = _nonempty_column(gc)
	var p: Dictionary = gc.place_front(col)
	_check(p.ok and int(p.slot) == 0, "列首上位到最左空槽0", str(p))
	var tid1 := int(p.turret_id)
	var ammo1 := int(gc.session.turrets[tid1].ammo_remaining)
	for i in 9000:  # 150 秒模拟：每发飞行 <1s，足够打空 80 发
		gc.step(1.0 / 60.0)
		if int(gc.session.slots[0]) == -1:
			break
	_check(fires.n == ammo1, "无点击自动连发恰好打空 %d 发" % ammo1, "fires=%d" % fires.n)
	_check(int(gc.session.slots[0]) == -1 and not gc.session.turrets.has(tid1),
		"弹尽炮台结算后移除离场", "")
	_check(gc.auto_fire.registered_count() == 0, "弹尽后调度注销", "")
	var audit: Dictionary = gc.conservation_audit()
	_check(audit.ok, "守恒审计 Q+S+F=V、V≤V0", str(audit))

	# --- 同色命中删除 = 预订目标（一发一块）；mismatch 返还 ---
	var gc2: Node = GameControllerScript.new()
	root.add_child(gc2)
	gc2.start_level("res://assets/levels/level_01.json")
	gc2.origin_resolver = _aim_for(gc2)
	var hits := {"n": 0}
	var resolved: Array = []
	gc2.bus.subscribe("voxel_destroyed", func(_a: Array, _m: Dictionary) -> void: hits.n += 1, "level_01")
	gc2.bus.subscribe("shot_resolved", func(a: Array, _m: Dictionary) -> void:
		resolved.append([int(a[0]), str(a[1])]), "level_01")
	var col2 := _nonempty_column(gc2)
	gc2.place_front(col2)
	for i in 600:
		gc2.step(1.0 / 60.0)
		if hits.n >= 1:
			break
	_check(hits.n >= 1, "同色命中删除（预订目标）", "hits=%d" % hits.n)
	var hit_ok := false
	for e in resolved:
		if e[1] == "HIT":
			hit_ok = true
	_check(hit_ok, "shot_resolved HIT 发布", str(resolved))
	# mismatch 返还：占位炮台发射后，伪造异色命中事件 → 弹药返还（F-- S++）
	var tid2 := int(gc2.session.slots[0])
	if tid2 < 0:
		for c in 5:
			if gc2.place_front(c).ok:
				tid2 = int(gc2.session.slots[0])
				break
	var fired_ball := {"id": -1}
	gc2.bus.subscribe("turret_fire", func(a: Array, _m: Dictionary) -> void:
		fired_ball.id = int(a[1]), "level_01")
	for i in 600:
		gc2.step(1.0 / 60.0)
		if fired_ball.id > 0:
			break
	_check(fired_ball.id > 0, "第二门炮台发射", "")
	var ammo_before := int(gc2.session.turrets[tid2].ammo_remaining)
	var ball_snap: Dictionary = gc2.ball_physics.system.ball_snapshot(fired_ball.id)
	# 找一个非预订目标的存活体素（异色优先，模拟遮挡/旋转导致的误中）
	var wrong_vid := -1
	var wrong_color := -1
	var ticket: Dictionary = gc2.shot_ledger.ticket_by_ball(fired_ball.id)
	_check(not ticket.is_empty() and ticket.status == "PENDING", "票据仍在途", str(ticket))
	for id in gc2.voxel_manager.state.alive_ids():
		if int(id) != int(ticket.target_voxel_id):
			wrong_vid = int(id)
			wrong_color = gc2.voxel_manager.color_of(wrong_vid)
			break
	gc2.bus.publish("ball_hit_voxel", [ball_snap, {"voxel_id": wrong_vid, "color_id": wrong_color}],
		{"event_id": 30001, "level_id": "level_01", "session_generation": gc2.session.session_generation,
		"physics_tick": 0})
	_check(int(gc2.session.turrets[tid2].ammo_remaining) == ammo_before + 1,
		"mismatch 取消返还弹药 S++", "%d→%d" % [ammo_before, int(gc2.session.turrets[tid2].ammo_remaining)])
	var cancel_ok := false
	for e in resolved:
		if e[1].begins_with("CANCELLED"):
			cancel_ok = true
	_check(cancel_ok, "shot_resolved CANCELLED 发布", str(resolved))
	var audit2: Dictionary = gc2.conservation_audit()
	_check(audit2.ok, "mismatch 后守恒仍成立", str(audit2))

	# --- 无可达同色目标 → 等待不发射不扣弹（CQ §2.3） ---
	var gc3: Node = GameControllerScript.new()
	root.add_child(gc3)
	gc3.start_level("res://assets/levels/level_01.json")
	# 原点埋进模型中心上方被遮挡的位置不可控，改用"无该色存活"构造无目标：
	# 删除队列首炮颜色以外的做法太复杂，直接删除该色全部体素代价高；
	# 改为：占位后把炮台颜色改为不存在于模型的颜色（等价于无同色目标）。
	gc3.origin_resolver = _aim_for(gc3)
	var col3 := _nonempty_column(gc3)
	gc3.place_front(col3)
	var tid3 := int(gc3.session.slots[0])
	gc3.session.turrets[tid3].color_id = 77  # 模型无此色
	var fires3 := {"n": 0}
	gc3.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires3.n += 1, "level_01")
	var ammo3 := int(gc3.session.turrets[tid3].ammo_remaining)
	for i in 90:
		gc3.step(1.0 / 60.0)
	_check(fires3.n == 0 and int(gc3.session.turrets[tid3].ammo_remaining) == ammo3,
		"无同色目标不发射不扣弹", "fires=%d" % fires3.n)
	_check(gc3.session.turrets[tid3].state == "WAITING_TARGET", "进入 WAITING_TARGET 态",
		str(gc3.session.turrets[tid3].state))
	_check(gc3.session.outcome == "RUNNING", "无目标不判负", gc3.session.outcome)

	# --- 取回：无在途弹立即回来源列队首；有在途弹待结算后取回 ---
	var gc4: Node = GameControllerScript.new()
	root.add_child(gc4)
	gc4.start_level("res://assets/levels/level_01.json")
	gc4.origin_resolver = _aim_for(gc4)
	var col4 := _nonempty_column(gc4)
	gc4.place_front(col4)
	var tid4 := int(gc4.session.slots[0])
	var ocol := int(gc4.session.turrets[tid4].origin_column)
	var ret: Dictionary = gc4.return_turret(0)
	_check(ret.ok and not ret.get("pending", true), "未发射立即取回", str(ret))
	_check(int(gc4.session.slots[0]) == -1 and int(gc4.session.queue_columns[ocol][0]) == tid4,
		"取回到来源列队首", "")
	_check(gc4.auto_fire.registered_count() == 0, "取回后调度注销", "")
	# 有在途弹：先停发射，结算后完成取回
	gc4.place_front(ocol)
	gc4.session.turrets[tid4].ammo_remaining = 50  # 保证发射后不弹尽
	for i in 600:
		gc4.step(1.0 / 60.0)
		if int(gc4.session.turrets.get(tid4, {}).get("in_flight", 0)) > 0:
			break
	_check(int(gc4.session.turrets[tid4].get("in_flight", 0)) > 0, "有在途弹", "")
	var ret2: Dictionary = gc4.return_turret(int(gc4.session.slots.find(tid4)))
	_check(ret2.ok and ret2.get("pending", false), "有在途弹标记待取回", str(ret2))
	_check(gc4.session.turrets[tid4].state == "RETURN_PENDING", "RETURN_PENDING 态", "")
	for i in 1200:
		gc4.step(1.0 / 60.0)
		if int(gc4.session.slots[gc4.session.slots.find(tid4)] if gc4.session.slots.find(tid4) >= 0 else -1) == -1 \
				and int(gc4.session.queue_columns[ocol][0]) == tid4:
			break
	_check(int(gc4.session.queue_columns[ocol][0]) == tid4
		and gc4.session.slots.find(tid4) == -1, "结算后完成取回", "")

	# --- 恢复会话：保留本次运行代号；有弹炮台重新注册自动连发 ---
	var gc5: Node = GameControllerScript.new()
	root.add_child(gc5)
	gc5.start_level("res://assets/levels/level_01.json")
	var col5 := _nonempty_column(gc5)
	gc5.place_front(col5)
	var snap: Dictionary = gc5.session.to_snapshot()
	snap["session_generation"] = 999  # 模拟历史存档代号
	var gc6: Node = GameControllerScript.new()
	root.add_child(gc6)
	var r6: Dictionary = gc6.start_level("res://assets/levels/level_01.json", snap)
	_check(r6.ok, "恢复启动", str(r6))
	_check(gc6.session.session_generation != 999, "恢复后保留本次运行代号",
		str(gc6.session.session_generation))
	_check(gc6.auto_fire.registered_count() == 1, "恢复有弹炮台自动注册", "")

	# --- CQ/S09 §1：坏档校验——无效色/守恒破坏/模型变更的存档拒绝恢复（不静默迁移弹量） ---
	var snap2: Dictionary = gc5.session.to_snapshot()
	for tid in snap2.turrets:
		snap2.turrets[tid].color_id = 99  # 全部无效色
	var gc7: Node = GameControllerScript.new()
	root.add_child(gc7)
	var r7: Dictionary = gc7.start_level("res://assets/levels/level_01.json", snap2)
	_check(not r7.ok and str(r7.get("error", "")).contains("snapshot_invalid"),
		"无效色坏档拒绝恢复", str(r7))
	# 守恒破坏（弹药与存活不匹配）同样拒绝
	var snap3: Dictionary = gc5.session.to_snapshot()
	for tid in snap3.turrets:
		snap3.turrets[tid].ammo_remaining = int(snap3.turrets[tid].ammo_remaining) + 1
	var gc9: Node = GameControllerScript.new()
	root.add_child(gc9)
	var r9: Dictionary = gc9.start_level("res://assets/levels/level_01.json", snap3)
	_check(not r9.ok and str(r9.get("error", "")).contains("conservation_broken"),
		"守恒破坏坏档拒绝恢复", str(r9))
	# 模型哈希不符（模型已更新）→ 作废重开
	var snap4: Dictionary = gc5.session.to_snapshot()
	snap4.model_hash = "deadbeef"
	var gc10: Node = GameControllerScript.new()
	root.add_child(gc10)
	var r10: Dictionary = gc10.start_level("res://assets/levels/level_01.json", snap4)
	_check(not r10.ok and str(r10.get("error", "")) == "model_changed",
		"模型变更旧档作废", str(r10))

	# --- 弹珠表现：生成/位置同步/出界幂等回收 ---
	var gc8: Node = GameControllerScript.new()
	root.add_child(gc8)
	gc8.start_level("res://assets/levels/level_01.json")
	gc8.origin_resolver = _aim_for(gc8)
	var mp: Node3D = preload("res://scripts/presentation/marble_presenter.gd").new()
	mp.debug_logging = false
	root.add_child(mp)
	mp.bind(gc8)
	gc8.place_front(_nonempty_column(gc8))
	for i in 300:
		gc8.step(1.0 / 60.0)
		if mp.active_count() >= 1:
			break
	_check(mp.active_count() == 1, "发射生成表现球", "active=%d" % mp.active_count())
	var mp_ball := -1
	for id in mp._active:
		mp_ball = int(id)
	gc8.step(1.0 / 60.0)
	mp._process(0.016)  # 测试手动步进不经过帧循环，显式触发同步
	var snap8: Dictionary = gc8.ball_physics.system.ball_snapshot(mp_ball)
	_check(not snap8.is_empty() and mp.ball_node(mp_ball).global_position.is_equal_approx(snap8.pos),
		"位置跟随物理快照", "")
	gc8.ball_physics.system.end_ball(mp_ball)  # 模拟结束（表现层测试只验证回收路径）
	gc8.step(1.0 / 60.0)
	mp._process(0.016)
	_check(mp.active_count() == 0 and mp.idle_count() == 1, "失效球幂等回收入池",
		"active=%d idle=%d" % [mp.active_count(), mp.idle_count()])
	mp.clear()
	_check(mp.controller == null, "clear 解除绑定", "")

	DirAccess.remove_absolute("user://saves/level_01.json")

	if _failures == 0:
		print("TEST_PASS test_auto_fire")
	else:
		print("TEST_FAIL test_auto_fire failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _nonempty_column(gc: Node) -> int:
	for c in 5:
		if not gc.session.queue_columns[c].is_empty():
			return c
	return 0


func _column_with_color(gc: Node, color_id: int) -> int:
	for c in 5:
		var col: Array = gc.session.queue_columns[c]
		if not col.is_empty() and int(gc.session.turrets[int(col[0])].color_id) == color_id:
			return c
	return -1


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
