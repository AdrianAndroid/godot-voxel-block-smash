extends SceneTree

# P3-04 输入自测：UI 起始不旋转、模型空白区旋转、多指首指、取消/失焦清理
# 运行：godot --headless --path . -s tests/unit/test_input.gd

var _failures := 0


func _initialize() -> void:
	var router := preload("res://scripts/input/gesture_router.gd").new()

	# UI 起始指针永不旋转
	_check(not router.handle_press(1, true), "UI 起始不成为旋转指针", "")
	_check(router.handle_drag(1, Vector2(50, 0)) == Vector2.ZERO, "UI 拖动零旋转", "")
	router.handle_release(1)

	# 模型空白区旋转：0.01 弧度/像素
	_check(router.handle_press(2, false), "模型区起始成为旋转指针", "")
	var rot: Vector2 = router.handle_drag(2, Vector2(100, 50))
	_check(rot == Vector2(1.0, 0.5), "灵敏度 0.01rad/px", str(rot))
	_check(router.current_angles() == Vector2(1.0, 0.5), "角度累积", str(router.current_angles()))

	# 多指只认首指
	_check(not router.handle_press(3, false), "第二指忽略", "")
	_check(router.handle_drag(3, Vector2(100, 0)) == Vector2.ZERO, "第二指拖动零旋转", "")

	# 俯仰钳制（CQ-20261026/S02：±70°=1.2217rad）
	for i in 100:
		router.handle_drag(2, Vector2(0, 100))
	_check(router.current_angles().y <= 1.2217, "俯仰钳制≤70°", str(router.current_angles()))

	# 失焦清理后旧指针无效
	router.cancel_all()
	_check(router.handle_drag(2, Vector2(10, 0)) == Vector2.ZERO, "失焦后残留指针无效", "")
	_check(router.mutex.owner_of(2) == "", "归属清空", "")

	if _failures == 0:
		print("TEST_PASS test_input")
	else:
		print("TEST_FAIL test_input failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
