extends SceneTree

# CQ-20261026/S03~S05 玩法服务自测（纯逻辑层）：固定五槽/合成/道具/胜负
# 五列守恒队列生成见 tests/unit/test_cannon_queue.gd
# 运行：godot --headless --path . -s tests/unit/test_gameplay.gd

var _failures := 0

const Session := preload("res://scripts/level/level_session.gd")
const Rules := preload("res://scripts/data/game_rules.gd")
const Queue := preload("res://scripts/gameplay/cannon_queue_service.gd")
const Slot := preload("res://scripts/gameplay/slot_service.gd")
const Merge := preload("res://scripts/gameplay/merge_service.gd")
const Props := preload("res://scripts/gameplay/prop_service.gd")
const Outcome := preload("res://scripts/gameplay/outcome_state.gd")


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var r: RefCounted = Rules.new()
	r.merge_max = 160

	# --- 固定五槽（CQ §2.1/S04） ---
	var s: RefCounted = Session.new()
	s.unlocked_slots = 3
	Slot.init_slots(s)
	_check(s.slots == [-1, -1, -1, -1, -1], "固定五槽初始化全空", str(s.slots))
	_check(Slot.capacity(s, r) == 3, "容量=已解锁3", "")
	_check(Slot.is_free(s, r, 2) and not Slot.is_free(s, r, 3), "第4槽未解锁不可用", "")
	s.turrets[11] = {"turret_id": 11, "color_id": 1, "ammo_remaining": 30, "origin_column": 0}
	_check(Slot.place_at(s, 1, 11), "放槽1", "")
	_check(Slot.leftmost_free(s, r) == 0, "最左空闲=0（空位不压缩）", "")
	_check(not Slot.place_at(s, 1, 12), "占用槽拒绝", "")
	_check(Slot.slot_index_of(s, 11) == 1 and Slot.slot_turret_id(s, 1) == 11, "turret_id 定位槽位", "")
	_check(Slot.remove_at(s, 1) == 11 and int(s.slots[1]) == -1, "移除后空位保留原位", "")
	s.unlocked_slots = 5
	_check(Slot.leftmost_free(s, r) == 0, "解锁5槽后最左空闲=0", "")

	# --- 合成（CQ §2.4：两列列首、同色、≤160 不截断） ---
	var s3: RefCounted = Session.new()
	Queue.generate(s3, {1: 100, 2: 100}, RandomNumberGenerator.new())  # 至少两列有炮
	s3.turrets.clear()
	for c in 5:
		s3.queue_columns[c] = []
	s3.turrets[1] = {"turret_id": 1, "color_id": 2, "ammo_remaining": 70, "origin_column": 0}
	s3.turrets[2] = {"turret_id": 2, "color_id": 2, "ammo_remaining": 80, "origin_column": 1}
	s3.turrets[3] = {"turret_id": 3, "color_id": 3, "ammo_remaining": 10, "origin_column": 2}
	s3.queue_columns[0] = [1]
	s3.queue_columns[1] = [2]
	s3.queue_columns[2] = [3]
	var m: Dictionary = Merge.merge_columns(s3, r, 0, 1)
	_check(m.ok and int(m.turret.ammo_remaining) == 150, "同色合成 70+80=150", str(m))
	_check(s3.queue_columns[1].is_empty() and not s3.turrets.has(2), "来源列弹出/被合成炮台清除", "")
	_check(not Merge.merge_columns(s3, r, 0, 2).ok, "异色拒绝", "")
	s3.queue_columns[2] = [3]
	s3.turrets[3].color_id = 2
	s3.turrets[3].ammo_remaining = 20
	var m2: Dictionary = Merge.merge_columns(s3, r, 0, 2)
	_check(not m2.ok and m2.reason == "overflow" and int(s3.turrets[1].ammo_remaining) == 150
		and int(s3.turrets[3].ammo_remaining) == 20, "超限拒绝且不截断（150+20>160）", str(m2))
	_check(not Merge.merge_columns(s3, r, 0, 1).ok, "空列合成拒绝", "")
	_check(not Merge.merge_columns(s3, r, 0, 0).ok, "同列合成拒绝", "")

	# --- 道具（CQ §2.4：随机排只重排现有炮台） ---
	var s4: RefCounted = Session.new()
	s4.prop_counts = {"speed_x2": 3, "add_slot": 1, "designated_target": 2, "shuffle": 2}  # CQ/S08
	var props := Props.new()
	props.setup(null)
	Slot.init_slots(s4)
	s4.turrets[21] = {"turret_id": 21, "color_id": 1, "ammo_remaining": 30, "origin_column": 0}
	s4.turrets[22] = {"turret_id": 22, "color_id": 4, "ammo_remaining": 40, "origin_column": 0}
	s4.queue_columns = [[21, 22], [], [], [], []]
	var res: Dictionary = props.use(s4, r, "shuffle", rng, {})
	_check(res.ok and res.count_after == 1, "随机排扣次数 2→1", str(res))
	var col0: Array = s4.queue_columns[0]
	col0.sort()
	_check(col0 == [21, 22] and int(s4.turrets[21].ammo_remaining) == 30,
		"随机排保留 ID/颜色/弹量（仅重排）", str(s4.queue_columns[0]))
	s4.queue_columns = [[21], [], [], [], []]
	s4.queue_columns[0].pop_back()  # 队列全空
	var sh_before: int = s4.prop_counts.shuffle
	_check(not props.use(s4, r, "shuffle", rng, {}).ok
		and int(s4.prop_counts.shuffle) == sh_before, "无牌可洗不执行不扣次数", "")
	# FM/F4：每列最多 1 门（总数≥2 但无可洗排列）同样拒绝不扣次数
	s4.queue_columns = [[21], [22], [], [], []]
	_check(not props.use(s4, r, "shuffle", rng, {}).ok
		and int(s4.prop_counts.shuffle) == sh_before, "每列≤1门无可洗排列不扣次数", "")
	s4.prop_counts.shuffle = 0
	_check(not props.use(s4, r, "shuffle", rng, {}).ok and int(s4.prop_counts.shuffle) == 0,
		"次数归零拒绝且不负", "")

	res = props.use(s4, r, "add_slot", rng, {})
	_check(res.ok and s4.unlocked_slots == 4, "加槽 3→4", str(res))
	s4.unlocked_slots = 5
	var cnt_before: int = s4.prop_counts.add_slot
	_check(not props.use(s4, r, "add_slot", rng, {}).ok and s4.unlocked_slots == 5
		and int(s4.prop_counts.add_slot) == cnt_before, "满5槽拒绝且不消耗", "")

	res = props.use(s4, r, "speed_x2", rng, {})
	_check(res.ok and s4.pending_effects.speed_x2, "速度×2待发设置", str(res))
	# FM/F4：已待发时重复使用拒绝且不扣次数（双击守卫）
	var sx_before: int = s4.prop_counts.speed_x2
	_check(not props.use(s4, r, "speed_x2", rng, {}).ok
		and int(s4.prop_counts.speed_x2) == sx_before, "速度×2已待发拒绝不扣次数", "")
	# CQ/S08 §2.4：指定目标激活只进选择模式、不扣次；重复激活拒绝
	res = props.use(s4, r, "designated_target", rng, {})
	_check(res.ok and bool(s4.pending_effects.get("designated_selecting", false))
		and int(s4.prop_counts.designated_target) == 2, "指定目标进选择模式不扣次", str(res))
	_check(not props.use(s4, r, "designated_target", rng, {}).ok
		and int(s4.prop_counts.designated_target) == 2, "选择中重复激活拒绝且不扣次", "")
	_check(not props.use(s4, r, "no_such_prop", rng, {}).ok, "未知道具拒绝", "")
	s4.outcome = "WON"
	_check(not props.use(s4, r, "speed_x2", rng, {}).ok, "终局后道具拒绝", "")

	# --- 胜负（CQ §2.3 + S08：无目标不判负；死局=完整性错误；胜利需无未结算票据） ---
	var s5: RefCounted = Session.new()
	Slot.init_slots(s5)
	s5.queue_columns = [[], [], [], [], []]
	var oc := Outcome.new()
	var bus := preload("res://scripts/app/event_bus.gd").new()
	oc.setup(bus)
	var _eid := [90000]
	var meta := func() -> Dictionary:
		_eid[0] += 1
		return {"event_id": _eid[0], "level_id": "level_01", "session_generation": 1, "physics_tick": 0}
	# S08 §6：余块>0、队列槽全空、无球无票据 → 守恒被破坏，记完整性错误而非正常判负
	var ierrs := {"n": 0}
	bus.subscribe("integrity_error", func(_a: Array, _m: Dictionary) -> void: ierrs.n += 1, "level_01")
	_check(oc.evaluate(s5, 10, 0, 0, "level_01", meta.call()) == "ERROR"
		and s5.outcome == "ERROR" and ierrs.n == 1, "全空+余块记完整性错误（不包装成失败）", "")
	var s6: RefCounted = Session.new()
	Slot.init_slots(s6)
	s6.queue_columns = [[], [], [], [], []]
	var oc2 := Outcome.new()
	oc2.setup(bus)
	# 有在途球不判负
	_check(oc2.evaluate(s6, 10, 1, 1, "level_01", meta.call()) == "RUNNING", "有在途球不判负", "")
	# 队列非空不判负（等待目标是正常态）
	s6.queue_columns[0] = [99]
	s6.turrets[99] = {"turret_id": 99, "color_id": 1, "ammo_remaining": 5}
	_check(oc2.evaluate(s6, 10, 0, 0, "level_01", meta.call()) == "RUNNING", "队列有炮不判负", "")
	# S08 §4：全清但有未结算票据 → 暂不判胜
	_check(oc2.evaluate(s6, 0, 1, 1, "level_01", meta.call()) == "RUNNING", "全清有未结算票据不判胜", "")
	# 通关优先且只发一次
	var wins := {"n": 0}
	bus.subscribe("level_win", func(_a: Array, _m: Dictionary) -> void: wins.n += 1, "level_01")
	_check(oc2.evaluate(s6, 0, 0, 0, "level_01", meta.call()) == "WON" and wins.n == 1, "全清通关发一次", "")
	oc2.evaluate(s6, 0, 0, 0, "level_01", meta.call())
	_check(wins.n == 1, "通关不重复发布", "")

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
