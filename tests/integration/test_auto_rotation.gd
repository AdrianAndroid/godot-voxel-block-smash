extends SceneTree

# FM §11 / F5（FM17/FM18）：自动旋转俯视探针——
# ① 方向符号：绕固定世界 +Y 轴俯视逆时针（右手系 +Y 正角；探针实测标记体素 φ=atan2(x,z) 单调增）
# ② 速率：稳态 8°/s（0.2s 渐入期内累计 0.8°，T≥0.2s 总角 = 8T-0.8）
# ③ 帧率无关：30/60/120Hz 同 sim 时长角位移一致
# ④ 按住暂停立即冻结、松手接续无跳角；指定目标选择中暂停；_paused 门冻结
# ⑤ 每步至多一次 transform_version 递增
# 运行：godot --headless --path . -s tests/integration/test_auto_rotation.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")


func _initialize() -> void:
	LevelRepository.set_save_dir("user://test_saves/auto_rotation_%d" % OS.get_process_id())
	assert(LevelRepository.is_isolated())
	call_deferred("_run")


func _make_gc() -> Node:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	var r: Dictionary = gc.start_level("res://assets/levels/level_01.json")
	_check(r.ok, "关卡启动", str(r))
	return gc


# 标记体素绕世界 Y 轴的方位角（°），转轴=模型节点原点
func _marker_phi(gc: Node) -> float:
	var vid := int(gc.session.alive_voxel_ids[0])
	var grid_pos: Vector3 = gc.voxel_manager.data.positions[vid]
	var w: Vector3 = gc.voxel_model.world_from_grid() * grid_pos
	var o: Vector3 = gc.voxel_model.global_transform.origin
	return rad_to_deg(atan2(w.x - o.x, w.z - o.z))


# 连续角度追踪器（处理 ±180° 环绕）
class PhiTracker:
	var prev := 0.0
	var total := 0.0
	var started := false
	func push(phi: float) -> void:
		if not started:  # 首次只锚定 prev，不计入 total
			started = true
			prev = phi
			return
		var d := fmod(phi - prev + 540.0, 360.0) - 180.0
		total += d
		prev = phi


func _step_n(gc: Node, hz: float, seconds: float, tracker: PhiTracker = null) -> void:
	var dt := 1.0 / hz
	var n := int(round(seconds * hz))
	for i in n:
		gc.step(dt)
		if tracker != null:
			tracker.push(_marker_phi(gc))


func _run() -> void:
	# --- ①② 方向符号 + 稳态速率（60Hz × 10s，期望总角 = 8×10-0.8 = 79.2°） ---
	var gc := _make_gc()
	var t1 := PhiTracker.new()
	t1.push(_marker_phi(gc))
	_step_n(gc, 60.0, 10.0, t1)
	_check(t1.total > 70.0 and t1.total < 90.0,
		"俯视逆时针 8°/s（10s 累计≈79.2°）", "total=%.2f" % t1.total)
	_check(absf(gc.auto_rot_speed_deg() - 8.0) < 0.01, "稳态读数 8°/s",
		"speed=%.3f" % gc.auto_rot_speed_deg())

	# --- ③ 帧率无关：30/60/120Hz 各 5s（期望 39.2°），两两差 ≤0.5° ---
	var totals := {}
	for hz in [30.0, 60.0, 120.0]:
		gc.voxel_model.set_orientation(Basis.IDENTITY)
		gc._auto_rot_ease = 0.0
		var tr := PhiTracker.new()
		tr.push(_marker_phi(gc))
		_step_n(gc, hz, 5.0, tr)
		totals[hz] = tr.total
		_check(tr.total > 35.0 and tr.total < 43.0,
			"%dHz 5s 角位移≈39.2°" % int(hz), "total=%.2f" % tr.total)
	_check(absf(totals[30.0] - totals[120.0]) <= 0.5
		and absf(totals[60.0] - totals[120.0]) <= 0.5,
		"30/60/120Hz 角位移一致", str(totals))

	# --- ④a 按住冻结 + 松手接续无跳角 ---
	gc.voxel_model.set_orientation(Basis.IDENTITY)
	gc._auto_rot_ease = 0.0
	_step_n(gc, 60.0, 1.0)  # 渐入到满速
	gc.set_rotation_hold(true)
	_check(gc.auto_rot_speed_deg() == 0.0, "按住时等效角速度=0", "")
	var phi_hold0 := _marker_phi(gc)
	_step_n(gc, 60.0, 2.0)
	_check(is_equal_approx(_marker_phi(gc), phi_hold0), "按住期间角度完全冻结", "")
	gc.set_rotation_hold(false)
	var phi_rel := _marker_phi(gc)
	var max_step := 0.0
	var prev := phi_rel
	for i in 120:  # 2s：恢复旋转，逐步检查无跳角
		gc.step(1.0 / 60.0)
		var phi := _marker_phi(gc)
		var d := absf(fmod(phi - prev + 540.0, 360.0) - 180.0)
		max_step = maxf(max_step, d)
		prev = phi
	_check(max_step <= 8.0 / 60.0 + 1e-4, "松手接续无跳角（单步 ≤ 满速一步）",
		"max_step=%.5f" % max_step)
	_check(absf(fmod(prev - phi_rel + 540.0, 360.0) - 180.0) > 5.0, "松手后确实恢复旋转",
		"resumed_total=%.2f" % (prev - phi_rel))

	# --- ④b 指定目标选择中暂停 ---
	var phi_sel0 := _marker_phi(gc)
	gc.session.pending_effects["designated_selecting"] = true
	_step_n(gc, 60.0, 1.0)
	_check(is_equal_approx(_marker_phi(gc), phi_sel0), "指定目标选择中冻结", "")
	gc.session.pending_effects["designated_selecting"] = false

	# --- ④c _paused 门冻结 ---
	gc.set_paused(true)
	var phi_p0 := _marker_phi(gc)
	_step_n(gc, 60.0, 1.0)
	_check(is_equal_approx(_marker_phi(gc), phi_p0), "_paused 冻结（step 早退）", "")
	gc.set_paused(false)

	# --- ⑤ 每步至多一次 transform_version 递增 ---
	var tv0: int = gc.voxel_model.transform_version
	gc.step(1.0 / 60.0)
	var tv1: int = gc.voxel_model.transform_version
	_check(tv1 - tv0 == 1, "旋转激活时每步 tver 恰好 +1", "%d→%d" % [tv0, tv1])
	gc.set_rotation_hold(true)
	tv0 = gc.voxel_model.transform_version
	gc.step(1.0 / 60.0)
	_check(gc.voxel_model.transform_version == tv0, "持有时每步 tver 不变", "")
	gc.set_rotation_hold(false)

	# 开关关闭即全停
	gc.auto_rotate_enabled = false
	var phi_off := _marker_phi(gc)
	_step_n(gc, 60.0, 1.0)
	_check(is_equal_approx(_marker_phi(gc), phi_off), "auto_rotate_enabled=false 全停", "")

	if _failures == 0:
		print("TEST_PASS test_auto_rotation")
	else:
		print("TEST_FAIL test_auto_rotation failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
