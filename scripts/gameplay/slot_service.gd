extends RefCounted

# P4-02 发射槽：放入/取回/容量（G02）。槽元素 = 炮台字典 + origin_index（池来源格）。

static func capacity(session: RefCounted, rules: RefCounted) -> int:
	return mini(session.unlocked_slots, rules.max_slots)


static func place(session: RefCounted, rules: RefCounted, turret: Dictionary, origin_index: int) -> bool:
	if turret.is_empty() or session.slots.size() >= capacity(session, rules):
		return false  # 满槽拒绝（G02）
	var s := turret.duplicate(true)
	s["origin_index"] = origin_index
	session.slots.append(s)
	return true


# 取回：仅未发射炮台允许（G02）。返回 {ok, turret, origin_index}
static func take_back(session: RefCounted, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= session.slots.size():
		return {"ok": false, "reason": "bad_index"}
	var s: Dictionary = session.slots[slot_index]
	if s.get("has_fired", false):
		return {"ok": false, "reason": "has_fired"}
	session.slots.remove_at(slot_index)
	var t := s.duplicate(true)
	t.erase("origin_index")
	return {"ok": true, "turret": t, "origin_index": s.get("origin_index", -1)}


static func remove_at(session: RefCounted, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= session.slots.size():
		return {}
	var s: Dictionary = session.slots[slot_index]
	session.slots.remove_at(slot_index)
	return s


static func slot_at(session: RefCounted, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= session.slots.size():
		return {}
	return session.slots[slot_index]
