extends RefCounted

# P4-04 合成（G06 + D02）：仅九宫格内、同色、弹量相加、上限 99 超限拒绝。纯逻辑。

const PoolService := preload("res://scripts/gameplay/pool_service.gd")


static func merge(session: RefCounted, rules: RefCounted, idx_a: int, idx_b: int) -> Dictionary:
	if idx_a == idx_b:
		return {"ok": false, "reason": "same_index"}
	var a: Dictionary = PoolService.turret_at(session, idx_a)
	var b: Dictionary = PoolService.turret_at(session, idx_b)
	if a.is_empty() or b.is_empty():
		return {"ok": false, "reason": "empty_slot"}
	if a.color_id != b.color_id:
		return {"ok": false, "reason": "color_mismatch"}  # 状态不变
	var total: int = a.ammo_count + b.ammo_count
	if total > rules.merge_max:
		return {"ok": false, "reason": "overflow"}  # D02：超限拒绝，不截断
	a.ammo_count = total
	session.pool[idx_b] = {}
	return {"ok": true, "turret": a.duplicate(true), "merged_id": b.turret_id}
