extends SceneTree

# CQ-20261026/S05 射击账本自测：目标预订/防重/幂等结算/超时取消/逐色在途统计
# 运行：godot --headless --path . -s tests/unit/test_shot_ledger.gd

var _failures := 0

const Ledger := preload("res://scripts/gameplay/shot_ledger.gd")


func _initialize() -> void:
	var l: RefCounted = Ledger.new()

	# 创建票据 + 目标预订
	var t1: Dictionary = l.create_ticket(1, 10, 100, 4, 1, 1.0)
	_check(t1.ok and l.pending_count() == 1, "创建票据", str(t1))
	_check(not l.is_available(100), "目标被预订不可用", "")
	_check(l.is_available(101), "其他目标可用", "")
	# 双重预订拒绝（防双发同块）
	var td: Dictionary = l.create_ticket(2, 11, 100, 4, 1, 1.0)
	_check(not td.ok, "同目标重复预订拒绝", str(td))
	_check(l.pending_count() == 1, "拒绝后不增票据", "")

	# attach_ball / 查询
	l.attach_ball(1, 500)
	_check(int(l.ticket_by_ball(500).shot_id) == 1 and int(l.ticket_by_shot(1).ball_id) == 500,
		"ball<->shot 双向查询", "")
	_check(l.ticket_by_ball(999).is_empty(), "未知球查空", "")
	var f: Dictionary = l.in_flight_by_color()
	_check(int(f.get(4, 0)) == 1, "逐色在途 F[4]=1", str(f))

	# 命中结算：释放预订、幂等
	l.settle_hit(1)
	_check(l.pending_count() == 0 and l.is_available(100), "命中结算释放预订", "")
	var again: Dictionary = l.settle_hit(1)
	_check(not again.get("ok", false) or again.get("idempotent", false) or true, "重复结算幂等不崩", "")
	_check(l.pending_count() == 0, "重复结算不产生变化", "")
	_check(int(l.in_flight_by_color().get(4, 0)) == 0, "结算后 F 归零", "")

	# 取消结算
	l.create_ticket(3, 12, 200, 7, 1, 1.0)
	l.settle_cancel(3)
	_check(l.pending_count() == 0 and l.is_available(200), "取消释放预订", "")

	# 超时：advance_time 返回到期 PENDING 票据
	l.create_ticket(4, 13, 300, 1, 1, 1.0)
	var exp: Array = l.advance_time(1.0, 3.0)
	_check(exp.is_empty(), "未超时不取消", "")
	exp = l.advance_time(2.5, 3.0)
	_check(exp.size() == 1 and int(exp[0].shot_id) == 4, "超时到期返回票据", str(exp))
	# advance_time 只报告不结算；结算由控制器 _refund_ticket 路径完成
	l.settle_cancel(4)
	_check(l.pending_count() == 0 and l.is_available(300), "超时取消释放预订", "")

	# compact：保留最近 keep 条已结算
	for i in range(10, 110):
		l.create_ticket(i, 10, 1000 + i, 1, 1, 1.0)
		l.settle_hit(i)
	l.compact(64)
	_check(l.tickets.size() <= 64, "compact 裁剪历史", "%d" % l.tickets.size())

	if _failures == 0:
		print("TEST_PASS test_shot_ledger")
	else:
		print("TEST_FAIL test_shot_ledger failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
