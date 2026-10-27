extends SceneTree

# CQ-20261026/S02 + CQ-T01：跟手旋转标记法自测（桌面投影证据，真机复核在 S11）。
# 瞳孔（深灰 color_id=7）为前表面标记：向右拖→标记屏幕 x 增大；向下拖→屏幕 y 增大；
# 默认视角与偏航 90° 后分别验证（90° 后取当前朝向相机的面重新选标记）。
# 运行：godot --headless --path . -s tests/unit/test_rotation.gd

var _failures := 0


func _initialize() -> void:
	# FM/F0：隔离测试存档目录（enter_level 会触发上一局保存），禁止触碰真实进度
	var repo := preload("res://scripts/level/level_repository.gd")
	repo.set_save_dir("user://test_saves/rotation_%d" % OS.get_process_id())
	assert(repo.is_isolated())
	call_deferred("_run")


func _run() -> void:
	var main: Node = preload("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.enter_level("level_01", {})

	# 默认视角：向右拖 → 瞳孔标记右移
	var before := _pupil_screen_centroid(main)
	_drag(main, Vector2(300, 0))
	var after := _pupil_screen_centroid(main)
	_check(after.x > before.x + 5.0, "默认视角右拖→瞳孔右移", "%.1f→%.1f" % [before.x, after.x])

	# 默认视角：向下拖 → 瞳孔下移（重新进关复位姿态）
	main.enter_level("level_01", {})
	before = _pupil_screen_centroid(main)
	_drag(main, Vector2(0, 300))
	after = _pupil_screen_centroid(main)
	_check(after.y > before.y + 5.0, "默认视角下拖→瞳孔下移", "%.1f→%.1f" % [before.y, after.y])

	# 偏航 90° 后：选当前最朝向相机的固定体素作标记，右拖仍右移、下拖仍下移
	main.enter_level("level_01", {})
	_drag(main, Vector2(540, 0))  # ≈90°（灵敏度 PI/宽）
	var marker := _front_voxel_id(main)
	before = _voxel_screen_pos(main, marker)
	_drag(main, Vector2(200, 0))
	after = _voxel_screen_pos(main, marker)
	_check(after.x > before.x + 3.0, "偏航90°后右拖→前面标记右移", "%.1f→%.1f" % [before.x, after.x])
	before = _voxel_screen_pos(main, marker)
	_drag(main, Vector2(0, 200))
	after = _voxel_screen_pos(main, marker)
	_check(after.y > before.y + 3.0, "偏航90°后下拖→前面标记下移", "%.1f→%.1f" % [before.y, after.y])

	# 俯仰边界：连续大幅下 drag 平滑截止于 60°（P1：越界部分丢弃、反向立即响应），中心不漂移
	main.enter_level("level_01", {})
	var center0: Vector3 = main.controller.voxel_model.global_transform.origin
	for i in 20:
		_drag(main, Vector2(0, 400))
	var basis: Basis = main.controller.voxel_model.global_transform.basis
	var tilt: float = asin(clampf((basis * Vector3(0, 0, -1)).normalized().dot(Vector3.UP), -1.0, 1.0))
	_check(absf(tilt) <= 1.0473, "俯仰钳制 ±60°（P1 新限位）", "tilt=%.3f" % tilt)
	_check(absf(absf(tilt) - 1.0472) < 0.01, "到达边界即满幅（不吞输入卡旧值）", "tilt=%.3f" % tilt)
	_check(center0.is_equal_approx(main.controller.voxel_model.global_transform.origin), "旋转中心不漂移", "")
	# UX03：边界处反向拖动立即离开（旧实现吞整段输入）
	_drag(main, Vector2(0, -50))
	var tilt2: float = asin(clampf((main.controller.voxel_model.global_transform.basis
		* Vector3(0, 0, -1)).normalized().dot(Vector3.UP), -1.0, 1.0))
	_check(absf(tilt2) < absf(tilt) - 0.02, "边界反向拖动立即响应", "%.3f→%.3f" % [tilt, tilt2])

	# UX02：交替右/下/左/上等幅拖动 20 轮——yaw/pitch 回到初值、无 roll 积累（up 不偏出竖直面）
	main.enter_level("level_01", {})
	var a0: Vector2 = main.controller.view_angles()
	for i in 20:
		_drag(main, Vector2(120, 0))
		_drag(main, Vector2(0, 120))
		_drag(main, Vector2(-120, 0))
		_drag(main, Vector2(0, -120))
	var a1: Vector2 = main.controller.view_angles()
	# yaw 在 ±PI 环绕等价（3.141593 vs -3.141593 是同一姿态），按环绕差比较
	_check(absf(wrapf(a1.x - a0.x, -PI, PI)) < 1e-4 and absf(a1.y - a0.y) < 1e-4,
		"交替等幅拖动 20 轮姿态回到初值（不积累侧倾）", "%s→%s" % [str(a0), str(a1)])
	var up_v: Vector3 = main.controller.voxel_model.global_transform.basis.y
	_check(absf(up_v.x) < 1e-4 and up_v.y > 0.999, "up 轴无 roll 分量", str(up_v))

	# UX01/侧面不倒立：yaw 偏到侧面（90°/270°）后大幅下拖，up.y 始终 >0（旧实现此处可倒立）
	for yaw_off in [PI / 2, -PI / 2]:
		main.enter_level("level_01", {})
		main.controller.set_view_pose(PI + yaw_off, 0.0)
		for i in 10:
			_drag(main, Vector2(0, 500))
		var up_side: Vector3 = main.controller.voxel_model.global_transform.basis.y
		_check(up_side.y > 0.4, "侧面（yaw%+d°）持续下拖不倒立" % int(rad_to_deg(yaw_off)),
			"up=%s pitch=%.2f" % [str(up_side), main.controller.view_angles().y])

	# 灵敏度：横扫展示区宽度 ≈180°
	main.enter_level("level_01", {})
	var w: float = root.get_visible_rect().size.x
	_drag(main, Vector2(w, 0))
	var front: Vector3 = (main.controller.voxel_model.global_transform.basis * Vector3(0, 0, -1)).normalized()
	_check(front.dot(Vector3(0, 0, 1)) < -0.99, "横扫全宽≈180°（前面转离相机）", str(front))

	main.queue_free()
	if _failures == 0:
		print("TEST_PASS test_rotation")
	else:
		print("TEST_FAIL test_rotation failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _drag(main: Node, delta: Vector2) -> void:
	main.router.handle_press(0, false)
	var px: Vector2 = main.router.handle_drag(0, delta)
	main._apply_rotation(px)
	main.router.handle_release(0)
	# P1：输入入队后在物理步统一应用；测试同步冲刷（dt=0：只应用手动增量，不推进玩法）
	main.controller._apply_view_rotation(0.0)


# 瞳孔（color_id=7）世界坐标屏幕投影质心
func _pupil_screen_centroid(main: Node) -> Vector2:
	return _centroid_of_color(main, 7)


func _centroid_of_color(main: Node, color_id: int) -> Vector2:
	var vm: Node3D = main.controller.voxel_model
	var data: RefCounted = vm.voxel_data
	var cam: Camera3D = main.camera
	var sum := Vector2.ZERO
	var n := 0
	for i in data.count:
		if data.color_ids[i] != color_id:
			continue
		var w: Vector3 = vm.world_from_grid() * (data.positions[i] + Vector3(0.5, 0.5, 0.5))
		if cam.is_position_behind(w):
			continue
		sum += cam.unproject_position(w)
		n += 1
	return sum / maxi(n, 1)


# 当前最朝向相机的体素 id（世界 z 最大）
func _front_voxel_id(main: Node) -> int:
	var vm: Node3D = main.controller.voxel_model
	var data: RefCounted = vm.voxel_data
	var best := -1
	var best_z := -INF
	for i in data.count:
		var w: Vector3 = vm.world_from_grid() * (data.positions[i] + Vector3(0.5, 0.5, 0.5))
		if w.z > best_z:
			best_z = w.z
			best = i
	return best


func _voxel_screen_pos(main: Node, voxel_id: int) -> Vector2:
	var vm: Node3D = main.controller.voxel_model
	var data: RefCounted = vm.voxel_data
	var w: Vector3 = vm.world_from_grid() * (data.positions[voxel_id] + Vector3(0.5, 0.5, 0.5))
	return main.camera.unproject_position(w)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
