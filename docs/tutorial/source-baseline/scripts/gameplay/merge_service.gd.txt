extends RefCounted

# CQ-20261026 §2.4 合成：仅显式合成模式内、对两列列首的同色炮台操作；
# 弹量相加不截断、不造新弹；超过上限（默认 160）拒绝；结果落在目标列首。
# 纯逻辑，不依赖事件总线。

const CannonQueue := preload("res://scripts/gameplay/cannon_queue_service.gd")


# 合成 col_b 列首 → col_a 列首（目标列 = col_a）。返回 {ok, reason?, turret?, merged_id?}
static func merge_columns(session: RefCounted, rules: RefCounted, col_a: int, col_b: int) -> Dictionary:
	if col_a == col_b:
		return {"ok": false, "reason": "same_column"}
	var ta := CannonQueue.front_of(session, col_a)
	var tb := CannonQueue.front_of(session, col_b)
	if ta < 0 or tb < 0:
		return {"ok": false, "reason": "empty_column"}
	var a: Dictionary = session.turrets[ta]
	var b: Dictionary = session.turrets[tb]
	if int(a.color_id) != int(b.color_id):
		return {"ok": false, "reason": "color_mismatch"}  # 状态不变
	var total := int(a.ammo_remaining) + int(b.ammo_remaining)
	if total > rules.merge_max:
		return {"ok": false, "reason": "overflow"}  # 超限拒绝，不截断
	a.ammo_remaining = total
	CannonQueue.pop_front(session, col_b)
	session.turrets.erase(tb)  # 被合成炮台的弹药已并入 a，不凭空保留
	return {"ok": true, "turret": a.duplicate(true), "merged_id": tb}
