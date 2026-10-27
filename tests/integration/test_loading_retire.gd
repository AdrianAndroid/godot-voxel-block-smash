extends SceneTree

# 2026-10-27 P2/P3（交互打磨方案 §4/§5，UX05~UX08 逻辑层）：
# ① LOADING 真阶段：上位后 0.28s 模拟时钟内不开火，到点转 READY 并注册调度（不依赖 Tween 回调）
# ② 上位中取回拒绝；保存把 LOADING 归一为 READY（恢复不重播、不卡位）
# ③ 耗尽路径：DRAINING 等在途结算 → RETIRING 0.20s 保留槽位 → 释放槽位删除炮台（不瞬间消失）
# ④ 零弹取回（含在途结算后归零）= 退场删除，不回队列（UX08）
# ⑤ outcome 终局后 step() 仍推进 RETIRING 时钟（胜利遮罩延后由 retiring_active() 支撑）
# 运行：godot --headless --path . -s tests/integration/test_loading_retire.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")


func _initialize() -> void:
	LevelRepository.set_save_dir("user://test_saves/loading_retire_%d" % OS.get_process_id())
	assert(LevelRepository.is_isolated())
	call_deferred("_run")


func _make_gc() -> Node:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	gc.origin_resolver = _aim_for(gc)
	return gc


func _aim_for(gc: Node) -> Callable:
	var sys: RefCounted = gc.ball_physics.system
	# 动态原点：每次按当前模型姿态重算（自动旋转期间原点不漂移）
	return func(_slot_index: int) -> Dictionary:
		var wfg: Transform3D = gc.voxel_model.world_from_grid()
		var o: Vector3 = wfg * (sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0))
		return {"ok": true, "origin": o, "origin_grid": wfg.affine_inverse() * o}


func _nonempty_column(gc: Node) -> int:
	for c in 5:
		if not gc.session.queue_columns[c].is_empty():
			return c
	return -1


func _run() -> void:
	# --- ① LOADING 真阶段：时钟内不开火，到点 READY+注册 ---
	var gc := _make_gc()
	var col := _nonempty_column(gc)
	var fires := {"n": 0}
	gc.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires.n += 1, "level_01")
	var pr: Dictionary = gc.place_front(col)
	_check(pr.ok, "上位成功", str(pr))
	var tid := int(pr.turret_id)
	_check(str(gc.session.turrets[tid].state) == "LOADING", "上位后处于 LOADING（非立即 READY）",
		str(gc.session.turrets[tid].state))
	_check(gc.auto_fire.registered_count() == 0, "LOADING 期不注册调度（到位才开火）", "")
	for i in 10:  # 0.167s < 0.28s
		gc.step(1.0 / 60.0)
	_check(fires.n == 0 and str(gc.session.turrets[tid].state) == "LOADING",
		"LOADING 时钟内零开火", "fires=%d state=%s" % [fires.n, gc.session.turrets[tid].state])
	_check(gc.loading_progress(tid) > 0.4 and gc.loading_progress(tid) < 0.8,
		"LOADING 进度可读（表现层驱动用）", "%.2f" % gc.loading_progress(tid))
	for i in 10:  # 累计 0.33s > 0.28s
		gc.step(1.0 / 60.0)
	_check(str(gc.session.turrets[tid].state) in ["READY", "FIRING", "WAITING_TARGET"],
		"LOADING 到点离开 LOADING", str(gc.session.turrets[tid].state))
	_check(gc.auto_fire.registered_count() == 1, "落地后注册调度", "")
	_check(gc.loading_progress(tid) < 0.0, "落地后进度关闭", "")
	gc.stop_session()
	gc.queue_free()

	# --- ② 上位中取回拒绝 + 保存归一 ---
	gc = _make_gc()
	col = _nonempty_column(gc)
	pr = gc.place_front(col)
	tid = int(pr.turret_id)
	var rr: Dictionary = gc.return_turret(int(pr.slot))
	_check(not rr.ok and str(rr.get("reason", "")) == "loading", "LOADING 中取回拒绝", str(rr))
	var sv: Dictionary = gc.save_session()
	_check(sv.ok, "LOADING 中落盘", str(sv))
	var snap: Dictionary = LevelRepository.load_snapshot("level_01").snapshot
	var saved_state := ""
	for k in snap.get("turrets", {}):
		if int(k) == tid:
			saved_state = str(snap.turrets[k].get("state", ""))
	_check(saved_state == "READY", "保存把 LOADING 归一为 READY", saved_state)
	gc.stop_session()
	gc.queue_free()
	var gc2: Node = GameControllerScript.new()
	root.add_child(gc2)
	var rst: Dictionary = gc2.start_level("res://assets/levels/level_01.json", snap)
	_check(rst.ok and int(gc2.session.slots[0]) == tid
		and str(gc2.session.turrets[tid].state) == "READY",
		"恢复后不卡 LOADING、不重复出列", str(rst))
	gc2.stop_session()
	gc2.queue_free()

	# --- ③ 耗尽路径：DRAINING → RETIRING 保留槽位 → 释放 ---
	gc = _make_gc()
	col = _nonempty_column(gc)
	pr = gc.place_front(col)
	tid = int(pr.turret_id)
	var slot := int(pr.slot)
	for i in 20:  # 走完 LOADING
		gc.step(1.0 / 60.0)
	# 自然耗尽（不改写 ammo，守恒审计才有效）：末发出膛瞬间 ammo=0 且仍有在途 → DRAINING
	var guard := 0
	while str(gc.session.turrets.get(tid, {}).get("state", "")) != "DRAINING" and guard < 6000:
		guard += 1
		gc.step(1.0 / 60.0)
	_check(str(gc.session.turrets.get(tid, {}).get("state", "")) == "DRAINING",
		"弹尽即 DRAINING（槽位保留）", "guard=%d state=%s" % [guard, gc.session.turrets.get(tid, {}).get("state", "")])
	_check(int(gc.session.turrets.get(tid, {}).get("in_flight", 0)) > 0, "DRAINING 时末发仍在途",
		"in_flight=%s" % str(gc.session.turrets.get(tid, {}).get("in_flight", -1)))
	guard = 0
	while str(gc.session.turrets.get(tid, {}).get("state", "")) != "RETIRING" and guard < 600:
		guard += 1
		gc.step(1.0 / 60.0)
	_check(str(gc.session.turrets.get(tid, {}).get("state", "")) == "RETIRING",
		"在途结算后进入 RETIRING（非瞬间删除）", "guard=%d" % guard)
	_check(int(gc.session.slots[slot]) == tid, "RETIRING 期槽位仍保留（不与下一门重叠）", "")
	_check(gc.retire_progress(tid) >= 0.0, "RETIRING 进度可读", "")
	# 模拟终局：outcome 非 RUNNING 时 step 仍推进 RETIRING 时钟（P3 胜利遮罩延后支撑）
	gc.session.outcome = "WON"
	_check(gc.retiring_active(), "retiring_active() 为真（HUD 延后胜利遮罩）", "")
	for i in 15:  # 0.25s > RETIRE_SEC 0.20s
		gc.step(1.0 / 60.0)
	_check(int(gc.session.slots[slot]) == -1 and not gc.session.turrets.has(tid),
		"终局后 RETIRING 时钟照常走完：槽位释放、炮台删除", "")
	_check(not gc.retiring_active(), "retiring_active() 复位", "")
	var audit: Dictionary = gc.conservation_audit()
	_check(audit.ok, "耗尽退场后守恒审计", str(audit))
	gc.stop_session()
	gc.queue_free()

	# --- ④ 零弹取回：有在途→pending→结算后归零=退场删除（不回队列）---
	gc = _make_gc()
	col = _nonempty_column(gc)
	pr = gc.place_front(col)
	tid = int(pr.turret_id)
	slot = int(pr.slot)
	for i in 20:
		gc.step(1.0 / 60.0)
	var col_len0: int = gc.session.queue_columns[int(gc.session.turrets[tid].origin_column)].size()
	guard = 0
	# 自然打到 DRAINING（末发在途、弹量真实归零）再取回：UX08 零弹取回=退场不回队列
	while str(gc.session.turrets.get(tid, {}).get("state", "")) != "DRAINING" and guard < 6000:
		guard += 1
		gc.step(1.0 / 60.0)
	_check(str(gc.session.turrets.get(tid, {}).get("state", "")) == "DRAINING"
		and int(gc.session.turrets.get(tid, {}).get("in_flight", 0)) > 0,
		"零弹且有在途（DRAINING）", "guard=%d" % guard)
	var ret: Dictionary = gc.return_turret(slot)
	_check(ret.ok and ret.get("pending", false), "有在途取回=pending", str(ret))
	guard = 0
	while gc.session.turrets.has(tid) and guard < 600:
		guard += 1
		gc.step(1.0 / 60.0)
	_check(not gc.session.turrets.has(tid) and int(gc.session.slots[slot]) == -1,
		"零弹取回最终退场删除（UX08）", "guard=%d" % guard)
	# 不回队列：来源列长度不变（col 即 origin_column，因为 place_front 从该列出列）
	_check(gc.session.queue_columns[int(col)].size() == col_len0, "零弹取回不回队列",
		"%d→%d" % [col_len0, gc.session.queue_columns[int(col)].size()])
	var audit2: Dictionary = gc.conservation_audit()
	_check(audit2.ok, "零弹取回后守恒审计", str(audit2))
	gc.stop_session()
	gc.queue_free()

	LevelRepository.delete_save("level_01")
	DirAccess.remove_absolute(LevelRepository.save_dir)
	if _failures == 0:
		print("TEST_PASS test_loading_retire")
	else:
		print("TEST_FAIL test_loading_retire failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
