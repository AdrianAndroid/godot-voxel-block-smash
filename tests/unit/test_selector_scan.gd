extends SceneTree

# FM/F2 选靶扫描自测（FM09/FM10）：
#  - 时间片断点续扫与全量扫描结果一致（小预算注入，不丢候选不饿死）
#  - 负缓存随 transform_version 失效（旋转后负结论不跨姿态服务）
#  - 轮转起始桶推进（持续旋转下有界轮转）
# 运行：godot --headless --path . -s tests/unit/test_selector_scan.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _mk_selector() -> Array:  # [selector, manager, data]
	var loader := preload("res://scripts/data/voxel_loader.gd")
	var manager_script := preload("res://scripts/voxel/voxel_manager.gd")
	var r: Dictionary = loader.load_from_json("res://assets/models/json/frog_02.json", false)
	var m: RefCounted = manager_script.new()
	m.build(r.data)
	var sel: RefCounted = preload("res://scripts/gameplay/target_selector.gd").new()
	sel.setup(m, 0.35)
	return [sel, m, r.data]


func _run() -> void:
	var all_true := func(_vid: int) -> bool: return true
	# P4：多点确认使否定全扫更慢，单次调用可能返回 scan_pending——抽到终态（断点续扫
	# 语义由上文专属用例验证，这里只关心缓存/游标语义）
	var drain := func(sel: RefCounted, color: int, origin: Vector3) -> Dictionary:
		var r: Dictionary = {}
		for i in 200000:
			r = sel.find_target(color, origin, all_true)
			if str(r.get("reason", "")) != "scan_pending":
				break
		return r

	# --- 全量基准：模型正下方原点，颜色 1（3167 块）必有可达目标 ---
	var parts: Array = _mk_selector()
	var sel: RefCounted = parts[0]
	var data: RefCounted = parts[2]
	var origin := Vector3(data.center_offset().x, data.bounds_min.y - 9.0, data.center_offset().z)
	var full: Dictionary = sel.find_target(1, origin, all_true)
	_check(full.ok, "全量扫描找到颜色1目标", str(full))
	var full_vid := int(full.get("voxel_id", -1))

	# --- 1µs 预算：切片续扫，结果必须与全量一致且会终止 ---
	var parts2: Array = _mk_selector()
	var sel2: RefCounted = parts2[0]
	sel2.scan_budget_us = 1
	var sliced_vid := -1
	var pendings := 0
	var calls := 0
	for i in 200000:
		calls += 1
		var r2: Dictionary = sel2.find_target(1, origin, all_true)
		if r2.ok:
			sliced_vid = int(r2.voxel_id)
			break
		if str(r2.get("reason", "")) == "scan_pending":
			pendings += 1
		else:
			break  # no_reachable_target 等终态
	_check(sliced_vid == full_vid, "切片扫描结果==全量扫描", "sliced=%d full=%d" % [sliced_vid, full_vid])
	print("  INFO: 命中路径切片 calls=%d pendings=%d（近桶早退，切片少属正常）" % [calls, pendings])

	# --- 覆盖性：无目标场景（原点埋模型中心）小预算必须切片走完全部前沿候选，
	#     最终给出与全量一致的否定结论（证明断点续扫不丢候选、不饿死） ---
	var parts2b: Array = _mk_selector()
	var sel2b: RefCounted = parts2b[0]
	var inside0: Vector3 = data.center_offset()
	sel2b.scan_budget_us = 1
	var neg_pendings := 0
	var neg_done := ""
	for i in 200000:
		var r3: Dictionary = sel2b.find_target(1, inside0, all_true)
		if str(r3.get("reason", "")) == "scan_pending":
			neg_pendings += 1
		else:
			neg_done = str(r3.get("reason", ""))
			break
	var frontier_n: int = (sel2b._frontier.get(1, []) as Array).size()
	_check(neg_done == "no_reachable_target" or neg_done == "no_alive_color",
		"切片全扫否定终止", "reason=%s" % neg_done)
	_check(neg_pendings >= int(frontier_n * 0.9),
		"切片覆盖≈全部前沿候选", "pendings=%d frontier=%d" % [neg_pendings, frontier_n])
	print("  INFO: 否定全扫 pendings=%d frontier=%d" % [neg_pendings, frontier_n])

	# --- 无目标场景：原点埋进模型中心（所有暴露面背向原点）→ 全扫否定并写负缓存 ---
	var parts3: Array = _mk_selector()
	var sel3: RefCounted = parts3[0]
	var inside: Vector3 = data.center_offset()
	var neg1: Dictionary = drain.call(sel3, 1, inside)
	_check(not neg1.ok, "模型内部原点无可达目标", str(neg1))
	var calls_before: int = sel3.dbg_neg_served
	drain.call(sel3, 1, inside)
	_check(sel3.dbg_neg_served == calls_before + 1, "同 gen+tver 负缓存服务", "")
	# P4 §6.3：负缓存 = gen 匹配 且（tver 精确匹配 或 TTL≤0.1s 模拟秒退避）。
	# 几何未变（同 tver）长期服务；tver 变化且超 TTL 才重扫（UX11 不永久封锁）。
	sel3.set_transform_version(sel3._tver + 1)
	var dbg_at: int = sel3.dbg_neg_served
	drain.call(sel3, 1, inside)
	_check(sel3.dbg_neg_served == dbg_at + 1, "tver 变化 TTL 内负缓存仍服务", "")
	sel3.set_clock(1.0e9)  # 模拟时钟远超 TTL → 负缓存失效重扫
	drain.call(sel3, 1, inside)
	_check(sel3.dbg_neg_served == dbg_at + 1, "tver 变化且超 TTL 负缓存失效（重扫）", "")
	sel3.set_clock(-1.0)
	drain.call(sel3, 1, inside + Vector3(4, 0, 0))  # 原点跨格 → 新 ckey 重扫
	_check(sel3.dbg_neg_served == dbg_at + 1, "原点跨格负缓存失效（重新实扫）", "")
	# 删除推进 gen 也使负缓存失效（既有语义保持；on_voxel_destroyed 是 gen 唯一入口）
	var parts4: Array = _mk_selector()
	var sel4: RefCounted = parts4[0]
	drain.call(sel4, 1, inside)
	var dbg4: int = sel4.dbg_neg_served
	drain.call(sel4, 1, inside)
	_check(sel4.dbg_neg_served == dbg4 + 1, "gen 稳定负缓存服务", "")
	sel4.on_voxel_destroyed(0)  # 任意删除推进 gen（frontier 增量维护由 manager 路径负责）
	drain.call(sel4, 1, inside)
	_check(sel4.dbg_neg_served == dbg4 + 1, "gen 变化负缓存失效（重新实扫）", "")

	# --- 轮转起始桶：完整扫一轮后 _rr_cursor 前进 ---
	var parts5: Array = _mk_selector()
	var sel5: RefCounted = parts5[0]
	var c0: int = int(sel5._rr_cursor.get(1, 0))
	drain.call(sel5, 1, inside)  # 完整否定扫
	var c1: int = int(sel5._rr_cursor.get(1, 0))
	_check(c1 == (c0 + 1) % 24, "全扫后轮转起始桶前进", "%d→%d" % [c0, c1])

	if _failures == 0:
		print("TEST_PASS test_selector_scan")
	else:
		print("TEST_FAIL test_selector_scan failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
