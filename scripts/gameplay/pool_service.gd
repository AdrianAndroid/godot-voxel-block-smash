extends RefCounted

# P4-01 炮台池（3×3）：生成/选择/取放/整体刷新（G03/G11）。纯逻辑，不依赖事件总线。

const POOL_SIZE := 9


static func make_turret(session: RefCounted, color_id: int, ammo: int) -> Dictionary:
	var t := {"turret_id": session.next_turret_id, "color_id": color_id,
		"ammo_count": ammo, "has_fired": false}
	session.next_turret_id += 1
	return t


static func generate_pool(session: RefCounted, rules: RefCounted, rng: RandomNumberGenerator) -> void:
	session.pool.clear()
	for i in POOL_SIZE:
		var color_id: int = rules.palette_color_ids[rng.randi_range(0, rules.palette_color_ids.size() - 1)]
		var ammo := rng.randi_range(rules.turret_ammo_min, rules.turret_ammo_max)
		session.pool.append(make_turret(session, color_id, ammo))


static func is_empty(session: RefCounted) -> bool:
	for t in session.pool:
		if not t.is_empty():
			return false
	return true


static func turret_at(session: RefCounted, index: int) -> Dictionary:
	if index < 0 or index >= session.pool.size():
		return {}
	return session.pool[index]  # 空位返回 {}，调用方视为不可选（G03）


static func take(session: RefCounted, index: int) -> Dictionary:
	var t: Dictionary = turret_at(session, index)
	if t.is_empty():
		return {}
	session.pool[index] = {}
	return t


static func put_at(session: RefCounted, index: int, turret: Dictionary) -> bool:
	if index < 0 or index >= session.pool.size() or not session.pool[index].is_empty():
		return false
	session.pool[index] = turret
	return true
