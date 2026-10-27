extends RefCounted

# CQ-20261026/S04：固定五槽位（元素 = turret_id 或 -1 空位）。
# 空位不压缩、其他炮台不横向跳位；调度只用 turret_id；炮台数据唯一容器是 session.turrets。

const SLOT_COUNT := 5
const EMPTY := -1


static func init_slots(session: RefCounted) -> void:
	session.slots = []
	for i in SLOT_COUNT:
		session.slots.append(EMPTY)


static func capacity(session: RefCounted, rules: RefCounted) -> int:
	return mini(session.unlocked_slots, rules.max_slots)


static func is_free(session: RefCounted, rules: RefCounted, slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < capacity(session, rules) \
		and int(session.slots[slot_index]) == EMPTY


# 最左空闲已解锁槽位；无返回 -1
static func leftmost_free(session: RefCounted, rules: RefCounted) -> int:
	for i in capacity(session, rules):
		if int(session.slots[i]) == EMPTY:
			return i
	return -1


static func slot_turret_id(session: RefCounted, slot_index: int) -> int:
	if slot_index < 0 or slot_index >= session.slots.size():
		return EMPTY
	return int(session.slots[slot_index])


static func slot_turret(session: RefCounted, slot_index: int) -> Dictionary:
	var tid := slot_turret_id(session, slot_index)
	if tid == EMPTY:
		return {}
	return session.turrets.get(tid, {})


static func place_at(session: RefCounted, slot_index: int, turret_id: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or int(session.slots[slot_index]) != EMPTY:
		return false
	session.slots[slot_index] = turret_id
	return true


static func remove_at(session: RefCounted, slot_index: int) -> int:
	var tid := slot_turret_id(session, slot_index)
	if tid != EMPTY:
		session.slots[slot_index] = EMPTY
	return tid


static func occupied_count(session: RefCounted) -> int:
	var n := 0
	for i in SLOT_COUNT:
		if int(session.slots[i]) != EMPTY:
			n += 1
	return n


static func is_empty(session: RefCounted) -> bool:
	return occupied_count(session) == 0


static func slot_index_of(session: RefCounted, turret_id: int) -> int:
	for i in session.slots.size():
		if int(session.slots[i]) == turret_id:
			return i
	return -1
