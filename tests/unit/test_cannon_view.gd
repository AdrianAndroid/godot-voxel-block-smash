extends SceneTree

## CQ-20261026/S06：CannonView 单元测试——状态映射/炮口契约/瞄准/后坐闪光。

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var view = preload("res://scripts/presentation/cannon_view.gd").new()
	root.add_child(view)
	view.position = Vector2(10, 20)
	view.size = Vector2(200, 100)
	await process_frame  # 触发 _ready/_layout

	# 初始 empty：无炮身/炮管，显示"空"
	assert(view.state == "empty")
	assert(not view._body.visible and not view._barrel.visible)
	assert(view._state_label.text == "空")

	# 装填 front：白描边数字、炮管可见
	view.set_cannon(Color.GREEN, 160)
	view.set_visual_state("front")
	assert(view._label.text == "160" and view._label.visible)
	assert(view._barrel.visible and view._state_label.text == "")
	assert(view._label.label_settings.outline_size == 10)
	assert(view._label.label_settings.font_color == Color.WHITE)

	# 炮口契约：默认朝上，muzzle = pivot + dir*124/256*s（s=min(200,100)=100）
	var m0: Vector2 = view.muzzle_screen_center()
	var pivot := Vector2(10, 20) + Vector2((200 - 100) * 0.5, 0) \
		+ Vector2(128.0 / 256.0, 150.0 / 256.0) * 100.0
	var expect0 := pivot + Vector2(0, -1) * (124.0 / 256.0 * 100.0)
	assert(m0.is_equal_approx(expect0))

	# 瞄准：set_aim_dir 右转 90°，炮口随之移动；炮管旋转 atan2(dir.x,-dir.y)=PI/2
	view.set_aim_dir(Vector2.RIGHT)
	var m1: Vector2 = view.muzzle_screen_center()
	assert(m1.is_equal_approx(pivot + Vector2.RIGHT * (124.0 / 256.0 * 100.0)))
	assert(is_equal_approx(view._barrel.rotation, PI * 0.5))

	# 零向量不改方向
	view.set_aim_dir(Vector2.ZERO)
	assert(view.muzzle_screen_center().is_equal_approx(m1))

	# 后坐+闪光：fire_feedback 后闪光可见，0.25s 后隐藏且炮管归位
	view.fire_feedback()
	assert(view._flash.visible)
	await create_timer(0.25).timeout
	assert(not view._flash.visible)
	assert(view._barrel.position.is_equal_approx(Vector2.ZERO))

	# locked / draining / waiting 状态映射
	view.set_visual_state("locked")
	assert(view._state_label.text == "锁" and not view._barrel.visible)
	view.set_cannon(Color.RED, 0)
	view.set_visual_state("draining")
	assert(view._label.text == "0")
	view.set_visual_state("waiting")
	assert(view._barrel.visible and view._label.visible)
	view.set_visual_state("back")
	assert(not view._label.visible)  # 队列后排不显示弹药数字

	print("TEST_PASS test_cannon_view")
	quit()
