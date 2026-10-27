extends SceneTree

# 2026-10-27 P4 选靶（交互打磨方案 §6，UX09~UX12）：
#  UX09 中心被挡、面角可达：中心检查失败而合法面点通过，真实飞行命中该块并只减一
#  UX10 所有炮口路径被异色挡住：不穿透、不假删、等待原因可查（fire_stats 计数）
#  UX11 同粗原点 key 内姿态变化后目标变可达：负缓存 TTL≤0.1s 不永久封锁，立即开火
#  UX12 分片扫描锚定旧原点：成功候选从当前原点终核，旧原点不可达结果不扣弹不开火
# 夹具：assets/models/json/ux_targeting_300.json —— T(5,8,5)色1、B(3,1,4)色2、
#       298 块色9 平板 y=20（凑 loader 下限，远离射线路径）。
# 关键原点（同 ckey 格 (1,-3,2)，probe_ux09b 数值验证）：
#   O_REACH=(3.5,-4.5,4.5) 中心被挡、-Y 面角点 (5.8,8.06,5.2) 可达
#   O_BLOCK=(2.1,-5.9,4.1) 全部瞄点被 B 挡住
# 运行：godot --headless --path . -s tests/integration/test_targeting_points.gd

var _failures := 0

const O_REACH := Vector3(3.5, -4.5, 4.5)
const O_BLOCK := Vector3(2.1, -5.9, 4.1)
const T_POS := Vector3(5, 8, 5)
const T_CENTER := Vector3(5.5, 8.5, 5.5)
const AIM_EXPECT := Vector3(5.8, 8.06, 5.2)
const LEVEL_UX := "res://tests/fixtures/level_ux_targeting.json"

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const TargetSelectorScript := preload("res://scripts/gameplay/target_selector.gd")


func _initialize() -> void:
	call_deferred("_run")


# --- 纯选择器夹具（2~15 块，无填充） ---
func _mk_sel(voxels: Array) -> RefCounted:
	var data := preload("res://scripts/data/voxel_data.gd").new()
	data.voxel_size = 1.0
	data.palette = {1: Color.RED, 2: Color.BLUE}
	var positions := PackedVector3Array()
	var color_ids := PackedInt32Array()
	var bmin := Vector3(INF, INF, INF)
	var bmax := Vector3(-INF, -INF, -INF)
	for v in voxels:
		positions.append(v[0])
		color_ids.append(int(v[1]))
		bmin = bmin.min(v[0])
		bmax = bmax.max(v[0])
	data.positions = positions
	data.color_ids = color_ids
	data.count = positions.size()
	data.bounds_min = bmin
	data.bounds_max = bmax
	var m: RefCounted = preload("res://scripts/voxel/voxel_manager.gd").new()
	m.build(data)
	var sel: RefCounted = TargetSelectorScript.new()
	sel.setup(m, 0.35)
	return sel


# --- 控制器级夹具（300 块关卡 + 白盒注入色1炮台到槽0） ---
func _mk_gc(origin_grid: Vector3, tid := 9001) -> Node:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level(LEVEL_UX)
	_check(r.ok, "UX 关卡启动", str(r))
	gc.session.turrets[tid] = {"turret_id": tid, "color_id": 1, "ammo_remaining": 3,
		"state": "READY", "origin_column": 0, "in_flight": 0, "has_fired": false}
	gc.session.slots[0] = tid
	var wfg: Transform3D = gc.voxel_model.world_from_grid()
	gc.origin_resolver = func(_slot: int) -> Dictionary:
		return {"ok": true, "origin": wfg * origin_grid, "origin_grid": origin_grid}
	return gc


func _run() -> void:
	var all_true := func(_vid: int) -> bool: return true

	# ===== UX09：中心被挡、面角可达（选择器契约层） =====
	var sel: RefCounted = _mk_sel([[T_POS, 1], [Vector3(3, 1, 4), 2]])
	_check(not sel.confirm_aim(0, T_CENTER, O_REACH), "UX09 中心瞄点确实被挡（防夹具失效）", "")
	var mp: Dictionary = sel.confirm_reachable_mp(0, O_REACH)
	_check(mp.get("ok", false) and int(mp.face_id) == 3
		and (mp.aim_grid_point as Vector3).distance_to(AIM_EXPECT) < 0.001,
		"UX09 -Y 面角点可达（face=3 aim=(5.8,8.06,5.2)）", str(mp))
	var ft: Dictionary = sel.find_target(1, O_REACH, all_true)
	_check(ft.get("ok", false) and int(ft.voxel_id) == 0
		and int(ft.face_id) == 3 and ft.has("origin_used") and ft.has("geometry_version")
		and (ft.aim_grid_point as Vector3) != T_CENTER,
		"UX09 find_target 契约 {voxel_id,aim,face_id,origin_used,geometry_version}", str(ft))
	_check(not sel.confirm_reachable_mp(0, O_BLOCK).get("ok", false),
		"UX09 对照：O_BLOCK 全瞄点被挡（同一夹具双向成立）", "")

	# ===== UX09：真实飞行命中该块并只减一 =====
	var gc: Node = _mk_gc(O_REACH)
	var fires := {"n": 0, "vid": -1, "aim": Vector3.ZERO}
	gc.bus.subscribe("turret_fire", func(a: Array, _m: Dictionary) -> void:
		fires.n += 1
		fires.vid = int(a[0].get("target_voxel_id", -1))
		fires.aim = a[0].get("aim_grid_point", Vector3.ZERO), "level_ux_targeting")
	var fres: Dictionary = gc.try_auto_fire(0)
	_check(fres.ok and fires.n == 1 and fires.vid == 0, "UX09 真实开火锁定 T", str(fres))
	_check((fires.aim as Vector3).distance_to(AIM_EXPECT) < 0.001,
		"UX09 发射快照瞄点=面角点（未换回中心）", str(fires.aim))
	var ticket: Dictionary = gc.shot_ledger.latest_ticket_by_turret(9001)
	_check((ticket.get("aim_grid_point", Vector3.ZERO) as Vector3).distance_to(AIM_EXPECT) < 0.001,
		"UX09 票据携带同一瞄点（炮管/弹道/预订同点）", str(ticket.get("aim_grid_point", "none")))
	var guard := 0
	while int(gc.session.turrets[9001].get("in_flight", 0)) > 0 and guard < 600:
		guard += 1
		gc.step(1.0 / 60.0)
	_check(not gc.voxel_manager.is_alive(0) and gc.voxel_manager.is_alive(1)
		and gc.voxel_manager.alive_count() == 299,
		"UX09 真实飞行命中 T 且只减一（B 存活）", "alive=%d guard=%d" % [gc.voxel_manager.alive_count(), guard])
	_check(int(gc.session.turrets[9001].ammo_remaining) == 2,
		"UX09 弹药 3→2（恰好一发一块）", str(gc.session.turrets[9001].ammo_remaining))
	var snap9: Dictionary = gc.fire_stats.snapshot()
	_check(int(gc.fire_stats.hit) == 1 and int(snap9.cancel_total) == 0,
		"UX09 1 命中 0 取消", str(snap9))
	gc.stop_session()
	gc.queue_free()

	# ===== UX10：全部炮口路径被挡 → 不穿透、不假删、等待原因可查 =====
	# 选择器层：笼形夹具（T 仅 -Y 暴露，y=5 有 3×3 色2 墙 + 五邻封堵）
	var cage := [[T_POS, 1]]
	for nb in [Vector3(4, 8, 5), Vector3(6, 8, 5), Vector3(5, 8, 4), Vector3(5, 8, 6), Vector3(5, 9, 5)]:
		cage.append([nb, 2])
	for wx in range(4, 7):
		for wz in range(4, 7):
			cage.append([Vector3(wx, 5, wz), 2])
	var sel2: RefCounted = _mk_sel(cage)
	_check(not sel2.confirm_reachable_mp(0, Vector3(5.5, -4.5, 5.5)).get("ok", false),
		"UX10 笼中目标多点确认全拒（不穿透）", "")
	var ft2: Dictionary = sel2.find_target(1, Vector3(5.5, -4.5, 5.5), all_true)
	_check(not ft2.get("ok", false) and str(ft2.get("reason", "")) == "no_reachable_target",
		"UX10 选靶否定原因=no_reachable_target（可查）", str(ft2))
	# 控制器层：O_BLOCK 下发射拒绝、不扣弹、无开火事件、等待计数+1、块数不变
	gc = _mk_gc(O_BLOCK)
	var fires10 := {"n": 0}
	gc.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires10.n += 1,
		"level_ux_targeting")
	var r10: Dictionary = gc.try_auto_fire(0)
	_check(not r10.get("ok", false) and fires10.n == 0
		and int(gc.session.turrets[9001].ammo_remaining) == 3
		and gc.voxel_manager.alive_count() == 300
		and int(gc.fire_stats.waiting_target) + int(gc.fire_stats.scan_pending) >= 1,
		"UX10 不穿透不假删不扣弹，等待原因计入统计", "res=%s stats=%s" % [str(r10), str(gc.fire_stats.snapshot())])
	gc.stop_session()
	gc.queue_free()

	# ===== UX11：同粗原点 key 内目标变可达 → 负缓存不永久封锁 =====
	# 选择器层：O_BLOCK 否定入缓存（同 ckey）；tver 变化 + TTL 内仍服务；超 TTL 立即重扫命中
	var sel3: RefCounted = _mk_sel([[T_POS, 1], [Vector3(3, 1, 4), 2]])
	var n1: Dictionary = sel3.find_target(1, O_BLOCK, all_true)
	_check(not n1.get("ok", false), "UX11 O_BLOCK 初次否定", str(n1))
	var served0: int = sel3.dbg_neg_served
	sel3.find_target(1, O_BLOCK, all_true)
	_check(sel3.dbg_neg_served == served0 + 1, "UX11 同 gen+tver 负缓存服务（便宜路径在）", "")
	sel3.set_transform_version(1)   # 姿态变化（旋转）
	sel3.set_clock(50.0)            # 写入时刻≈0（墙钟）→ 直接超 TTL
	var t11 := Time.get_ticks_usec()
	var n2: Dictionary = sel3.find_target(1, O_REACH, all_true)
	var us11 := Time.get_ticks_usec() - t11
	_check(n2.get("ok", false) and int(n2.voxel_id) == 0,
		"UX11 同 ckey 超 TTL 立即重扫命中（不永久封锁）", str(n2))
	_check(us11 < 200000, "UX11 变可达到出结果 <=0.2s（建议值）", "%dus" % us11)
	# 控制器层：被挡时 waiting；姿态推进（tver+TTL 超）后同 ckey 变可达立即开火
	gc = _mk_gc(O_BLOCK)
	gc.try_auto_fire(0)  # 写负缓存
	var w0: int = gc.fire_stats.waiting_target + gc.fire_stats.scan_pending
	gc.origin_resolver = func(_slot: int) -> Dictionary:
		return {"ok": true, "origin": gc.voxel_model.world_from_grid() * O_REACH, "origin_grid": O_REACH}
	var fired11 := false
	var frames11 := 0
	for i in 12:  # 12 帧 = 0.2s 模拟（自动旋转每步推 tver，模拟时钟超 TTL 0.1s）
		frames11 += 1
		gc.step(1.0 / 60.0)
		if gc.try_auto_fire(0).get("ok", false):
			fired11 = true
			break
	_check(fired11, "UX11 控制器级：变可达后 <=0.2s（%d 帧）开火" % frames11,
		"frames=%d" % frames11)
	_check(gc.fire_stats.waiting_target + gc.fire_stats.scan_pending > w0 or fired11,
		"UX11 等待原因全程可审计", str(gc.fire_stats.snapshot()))
	gc.stop_session()
	gc.queue_free()

	# ===== UX12：分片锚定旧原点 → 当前原点终核，失败不扣弹不开火 =====
	gc = _mk_gc(O_REACH)
	var sel4: RefCounted = gc.target_selector
	var fires12 := {"n": 0}
	gc.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires12.n += 1,
		"level_ux_targeting")
	# 片1：O_REACH 开扫，全局步预算强制为 0 → 立即 scan_pending，断点锚定 origin0=O_REACH
	sel4._budget_armed = true
	sel4._step_budget_left = 0
	var s1: Dictionary = gc.try_auto_fire(0)
	_check(not s1.get("ok", false) and str(s1.get("reason", "")) == "scan_pending",
		"UX12 片1 scan_pending（锚定 O_REACH）", str(s1))
	# 片2：换原点 O_BLOCK（同 ckey，续扫用锚定原点）→ 候选按 O_REACH 确认成功返回，
	#       控制器用 O_BLOCK 终核同一瞄点 → 失败：不扣弹、不开火、revalidate_failed 可审计
	gc.origin_resolver = func(_slot: int) -> Dictionary:
		return {"ok": true, "origin": gc.voxel_model.world_from_grid() * O_BLOCK, "origin_grid": O_BLOCK}
	sel4._step_budget_left = 999999
	var s2: Dictionary = gc.try_auto_fire(0)
	_check(not s2.get("ok", false) and str(s2.get("reason", "")) == "revalidate_failed"
		and fires12.n == 0 and int(gc.session.turrets[9001].ammo_remaining) == 3
		and gc.shot_ledger.pending_count() == 0,
		"UX12 旧原点成功候选被当前原点终核否决（不扣弹不开火无预订泄漏）",
		"res=%s fires=%d ammo=%d" % [str(s2), fires12.n, int(gc.session.turrets[9001].ammo_remaining)])
	_check(int(gc.fire_stats.revalidate_failed) == 1, "UX12 终核失败计数可审计",
		str(gc.fire_stats.snapshot()))
	# 片3：原点回到 O_REACH → 立即真实开火
	gc.origin_resolver = func(_slot: int) -> Dictionary:
		return {"ok": true, "origin": gc.voxel_model.world_from_grid() * O_REACH, "origin_grid": O_REACH}
	var s3: Dictionary = gc.try_auto_fire(0)
	_check(s3.get("ok", false) and fires12.n == 1, "UX12 原点恢复后立即开火", str(s3))
	gc.stop_session()
	gc.queue_free()

	if _failures == 0:
		print("TEST_PASS test_targeting_points")
	else:
		print("TEST_FAIL test_targeting_points failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
