extends SceneTree

# P4-01/02/04/07 玩法服务自测（纯逻辑层）：池/槽/合成/道具
# 运行：godot --headless --path . -s tests/unit/test_gameplay.gd

var _failures := 0

const Session := preload("res://scripts/level/level_session.gd")
const Rules := preload("res://scripts/data/game_rules.gd")
const Pool := preload("res://scripts/gameplay/pool_service.gd")
const Slot := preload("res://scripts/gameplay/slot_service.gd")
const Merge := preload("res://scripts/gameplay/merge_service.gd")
const Props := preload("res://scripts/gameplay/prop_service.gd")


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# --- 池生成与选择（G03） ---
	var s: RefCounted = Session.new()
	var r: RefCounted = Rules.new()
	Pool.generate_pool(s, r, rng)
	_check(s.pool.size() == 9, "池=9格", "%d" % s.pool.size())
	var all_filled := true
	for t in s.pool:
		if t.is_empty() or t.ammo_count < 1 or t.ammo_count > 5 or not (t.color_id in r.palette_color_ids):
			all_filled = false
	_check(all_filled, "生成炮台弹量1~5、颜色在调色板内", "")
	s.pool[4] = {}
	_check(Pool.turret_at(s, 4).is_empty(), "空位不可选", "")
	_check(Pool.turret_at(s, -1).is_empty() and Pool.turret_at(s, 9).is_empty(), "越界不可选", "")
	var t0: Dictionary = Pool.take(s, 0)
	_check(not t0.is_empty() and s.pool[0].is_empty(), "取出后池格清空", "")
	_check(Pool.put_at(s, 0, t0) and not Pool.put_at(s, 0, t0), "放回原格/占用拒绝", "")

	# --- 发射槽（G02） ---
	var s2: RefCounted = Session.new()
	s2.unlocked_slots = 3
	var placed := 0
	for i in 5:
		var t := Pool.make_turret(s2, 1, 2)
		if Slot.place(s2, r, t, i):
			placed += 1
	_check(placed == 3 and Slot.capacity(s2, r) == 3, "容量=已解锁槽，满槽拒绝", "placed=%d" % placed)
	var back: Dictionary = Slot.take_back(s2, 1)
	_check(back.ok and back.turret.turret_id != 0 and back.turret.ammo_count == 2, "未发射取回ID/弹量不变", str(back))
	_check(s2.slots.size() == 2, "取回后槽清空一格", "%d" % s2.slots.size())
	s2.slots[0].has_fired = true
	_check(not Slot.take_back(s2, 0).ok, "已发射炮台不可取回", "")
	_check(s2.slots.size() == 2, "拒绝取回不丢炮台", "%d" % s2.slots.size())

	# --- 合成（G06 + D02） ---
	var s3: RefCounted = Session.new()
	s3.pool = [{}, {}, {}, {}, {}, {}, {}, {}, {}]
	s3.pool[0] = Pool.make_turret(s3, 2, 40)
	s3.pool[1] = Pool.make_turret(s3, 2, 50)
	s3.pool[2] = Pool.make_turret(s3, 3, 10)
	var m: Dictionary = Merge.merge(s3, r, 0, 1)
	_check(m.ok and m.turret.ammo_count == 90, "同色合成弹量相加 40+50=90", str(m))
	_check(s3.pool[1].is_empty(), "合成后仅保留一个结果", "")
	_check(not Merge.merge(s3, r, 0, 2).ok, "异色拒绝", "")
	s3.pool[2] = Pool.make_turret(s3, 2, 20)
	_check(not Merge.merge(s3, r, 0, 2).ok and s3.pool[0].ammo_count == 90 and s3.pool[2].ammo_count == 20,
		"超限拒绝且状态不变（90+20>99）", "")
	_check(not Merge.merge(s3, r, 0, 5).ok, "空位合成拒绝", "")

	# --- 道具（G08~G11/G13 + D04） ---
	var s4: RefCounted = Session.new()
	var props := Props.new()
	props.setup(null)
	Pool.generate_pool(s4, r, rng)
	var before_ids: Array = s4.pool.map(func(t: Dictionary) -> int: return t.turret_id)
	var res: Dictionary = props.use(s4, r, "shuffle", rng, {})
	_check(res.ok and res.count_after == 1, "随机排扣次数 2→1", str(res))
	var after_ids: Array = s4.pool.map(func(t: Dictionary) -> int: return t.turret_id)
	_check(before_ids != after_ids and s4.pool.size() == 9, "随机排整体刷新池", "")
	Slot.place(s4, r, Pool.make_turret(s4, 5, 3), 0)
	var slot_id: int = s4.slots[0].turret_id
	props.use(s4, r, "shuffle", rng, {})
	_check(s4.slots[0].turret_id == slot_id, "随机排不动槽内炮台", "")
	_check(not props.use(s4, r, "shuffle", rng, {}).ok and int(s4.prop_counts.shuffle) == 0,
		"次数归零拒绝且不负", "%d" % s4.prop_counts.shuffle)

	res = props.use(s4, r, "add_slot", rng, {})
	_check(res.ok and s4.unlocked_slots == 4, "加槽 3→4", str(res))
	s4.unlocked_slots = 5
	var cnt_before: int = s4.prop_counts.add_slot
	_check(not props.use(s4, r, "add_slot", rng, {}).ok and s4.unlocked_slots == 5
		and int(s4.prop_counts.add_slot) == cnt_before, "满5槽拒绝且不消耗", "")

	res = props.use(s4, r, "speed_x2", rng, {})
	_check(res.ok and s4.pending_effects.speed_x2, "速度×2待发设置", str(res))
	res = props.use(s4, r, "any_color", rng, {})
	_check(res.ok and s4.pending_effects.any_color, "任意指待发设置", str(res))
	_check(not props.use(s4, r, "no_such_prop", rng, {}).ok, "未知道具拒绝", "")

	if _failures == 0:
		print("TEST_PASS test_gameplay")
	else:
		print("TEST_FAIL test_gameplay failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
