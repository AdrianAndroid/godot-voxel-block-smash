extends SceneTree

# CQ-20261026/S08 集成自测：指定目标道具（替代旧"任意指"异色万能弹）。
# 契约：激活只进选择模式不扣次；异色/已预订/没选中都拒绝且不扣次；
# 合法选择（同色+可达+未预订）接受才扣次；自动发射优先锁定指定目标；
# 目标失效退出优先锁定并发 designated_expired（不退款），恢复普通同色选靶。
# 运行：godot --headless --path . -s tests/integration/test_designated.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


# 与 test_auto_fire 同一契约：模型正下方界内原点（底面体素可达）
func _aim_for(gc: Node) -> Callable:
	return func(_slot_index: int) -> Dictionary:
		var sys: RefCounted = gc.ball_physics.system
		var origin_grid: Vector3 = sys.boundary_center + Vector3(0, -(sys.boundary_half - 0.5), 0)
		var world: Vector3 = gc.voxel_model.world_from_grid() * origin_grid
		return {"ok": true, "origin": world, "origin_grid": origin_grid}


# 相机置于发射原点、看向目标：pick 射线与可达扫掠共线，首中即目标本身
func _cam_looking_at(cam: Camera3D, from_world: Vector3, target_world: Vector3) -> void:
	cam.global_position = from_world
	cam.look_at(target_world, Vector3.UP if absf((target_world - from_world).normalized().y) < 0.99 else Vector3.FORWARD)


func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	gc.origin_resolver = _aim_for(gc)
	var cam := Camera3D.new()
	root.add_child(cam)

	# 上位一门颜色1（绿 3167，底面必可达）的列首
	var col := -1
	for c in 5:
		var qcol: Array = gc.session.queue_columns[c]
		if not qcol.is_empty() and int(gc.session.turrets[int(qcol[0])].color_id) == 1:
			col = c
			break
	_check(col >= 0, "存在颜色1列首", "")
	var pres: Dictionary = gc.place_front(col)
	_check(pres.ok, "列首上位", str(pres))
	var slot := int(pres.slot)
	var tid := int(pres.turret_id)

	# 当前可达同色目标（与自动发射同一选择器）
	var o: Dictionary = gc.origin_resolver.call(slot)
	var normal: Dictionary = gc.target_selector.find_target(1, o.origin_grid, gc.shot_ledger.is_available)
	_check(normal.get("ok", false), "存在可达同色目标", str(normal))
	var vid1 := int(normal.voxel_id)

	# --- 激活只进选择模式，不扣次 ---
	var cnt0 := int(gc.session.prop_counts.designated_target)
	var ures: Dictionary = gc.use_prop("designated_target")
	_check(ures.ok and bool(gc.session.pending_effects.get("designated_selecting", false))
		and int(gc.session.prop_counts.designated_target) == cnt0, "激活进选择模式不扣次", str(ures))
	_check(gc.designated_state().get("selecting", false), "选择模式状态查询", "")

	# 未选炮位直接点模型 → 拒绝不扣次
	var wfg: Transform3D = gc.voxel_model.world_from_grid()
	var v1_world: Vector3 = wfg * (gc.voxel_manager.data.positions[vid1] + Vector3(0.5, 0.5, 0.5))
	_cam_looking_at(cam, o.origin, v1_world)
	var screen1: Vector2 = cam.unproject_position(v1_world)
	var nres: Dictionary = gc.designated_select_voxel(screen1, cam)
	_check(not nres.ok and nres.reason == "no_turret"
		and int(gc.session.prop_counts.designated_target) == cnt0, "未选炮位点模型拒绝不扣次", str(nres))

	# 选炮位（空槽拒绝）
	_check(not gc.designated_select_turret(4).ok, "空槽不能指定", "")
	var tres: Dictionary = gc.designated_select_turret(slot)
	_check(tres.ok and int(gc.designated_state().slot) == slot, "选择炮位", str(tres))

	# 异色目标：拒绝且不扣次
	var other: Dictionary = gc.target_selector.find_target(4, o.origin_grid, gc.shot_ledger.is_available)
	if other.get("ok", false):
		var w4: Vector3 = wfg * (gc.voxel_manager.data.positions[int(other.voxel_id)] + Vector3(0.5, 0.5, 0.5))
		_cam_looking_at(cam, o.origin, w4)
		var wres: Dictionary = gc.designated_select_voxel(cam.unproject_position(w4), cam)
		_check(not wres.ok and wres.reason == "wrong_color"
			and int(gc.session.prop_counts.designated_target) == cnt0, "异色拒绝不扣次", str(wres))
	# 没选中（指向空处）：拒绝不扣次。
	# 注意必须指向模型【外】的方向（向下远离模型）：FM/DDA 修复后 pick 射线是全程真实
	# 扫掠，向上 200 会真的穿过模型命中体素（旧版靠 DDA 缺陷才"点空"）。
	_cam_looking_at(cam, o.origin, o.origin + Vector3(0, -200, 0))
	var eres: Dictionary = gc.designated_select_voxel(cam.unproject_position(o.origin + Vector3(0, -200, 0)), cam)
	_check(not eres.ok and int(gc.session.prop_counts.designated_target) == cnt0,
		"点空处拒绝不扣次", str(eres))

	# 已预订目标：伪造在途票据 → 拒绝不扣次
	var booked: Dictionary = gc.shot_ledger.create_ticket(99001, 999, vid1, 1,
		gc.session.session_generation, 1.0)
	_check(booked.ok, "伪造预订", str(booked))
	_cam_looking_at(cam, o.origin, v1_world)
	var rres: Dictionary = gc.designated_select_voxel(cam.unproject_position(v1_world), cam)
	_check(not rres.ok and rres.reason == "reserved"
		and int(gc.session.prop_counts.designated_target) == cnt0, "已预订拒绝不扣次", str(rres))
	gc.shot_ledger.settle_cancel(99001)

	# 取消模式不扣次，可重新激活
	gc.designated_cancel()
	_check(not gc.designated_state().selecting
		and int(gc.session.prop_counts.designated_target) == cnt0, "取消选择不扣次", "")
	gc.use_prop("designated_target")
	gc.designated_select_turret(slot)

	# --- 合法选择：同色+可达+未预订 → 接受才扣次 ---
	_cam_looking_at(cam, o.origin, v1_world)
	var ares: Dictionary = gc.designated_select_voxel(cam.unproject_position(v1_world), cam)
	_check(ares.ok and int(ares.voxel_id) == vid1
		and int(gc.session.prop_counts.designated_target) == cnt0 - 1
		and int(gc.session.turrets[tid].get("designated_target", -1)) == vid1,
		"合法选择接受并扣次", str(ares))
	_check(not gc.designated_state().selecting, "接受后退出选择模式", "")

	# --- 自动发射优先锁定指定目标（直接调发射入口，绕过调度冷却） ---
	var fired := {"n": 0, "vid": -1}
	gc.bus.subscribe("turret_fire", func(a: Array, _m: Dictionary) -> void:
		fired.n += 1
		fired.vid = int(a[0].get("target_voxel_id", -1)), "level_01")
	var fres: Dictionary = gc.try_auto_fire(slot)
	_check(fres.ok and fired.n == 1 and fired.vid == vid1, "指定目标优先发射",
		"res=%s n=%d vid=%d want=%d" % [str(fres), fired.n, fired.vid, vid1])

	# --- 目标被消灭后失效：退出优先锁定、发 designated_expired、恢复普通选靶 ---
	var expired := {"n": 0}
	gc.bus.subscribe("designated_expired", func(_a: Array, _m: Dictionary) -> void:
		expired.n += 1, "level_01")
	for i in 4000:
		gc.step(0.05)
		if expired.n == 0 and int(gc.session.turrets.get(tid, {}).get("in_flight", 0)) == 0:
			gc.try_auto_fire(slot)  # 命中结算后再次尝试：目标已消灭 → 失效退出
		if expired.n > 0:
			break
	_check(expired.n == 1, "指定目标失效提示一次（不退款）", "n=%d" % expired.n)
	_check(int(gc.session.turrets.get(tid, {}).get("designated_target", -1)) == -1
		or not gc.session.turrets.has(tid), "失效后优先锁定清除", "")
	_check(int(gc.session.prop_counts.designated_target) == cnt0 - 1, "失效不退款", "")

	# 全程守恒
	var audit: Dictionary = gc.conservation_audit()
	_check(audit.ok, "指定目标全程逐色守恒", str(audit))

	if _failures == 0:
		print("TEST_PASS test_designated")
	else:
		print("TEST_FAIL test_designated failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
