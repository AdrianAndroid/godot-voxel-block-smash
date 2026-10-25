extends RefCounted

# P4-07 四道具（G08~G11/G13 + D04）：消耗型，激活即扣次数；次数不负；失败操作不扣。

const PoolService := preload("res://scripts/gameplay/pool_service.gd")

const PROPS := ["speed_x2", "add_slot", "any_color", "shuffle"]

var _bus: RefCounted


func setup(bus: RefCounted) -> void:
	_bus = bus


# 返回 {ok, reason?, prop, count_before?, count_after?}
func use(session: RefCounted, rules: RefCounted, prop: String,
		rng: RandomNumberGenerator, meta: Dictionary) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	if prop not in PROPS:
		return {"ok": false, "reason": "unknown_prop"}
	var count := int(session.prop_counts.get(prop, 0))
	if count <= 0:
		return {"ok": false, "reason": "empty"}  # 次数不为负（G13）
	match prop:
		"speed_x2":
			session.pending_effects.speed_x2 = true   # 仅下一发（G08/D04）
		"any_color":
			session.pending_effects.any_color = true  # 仅下一发（G10）
		"add_slot":
			if session.unlocked_slots >= rules.max_slots:
				return {"ok": false, "reason": "slots_full"}  # 满槽不越界且不消耗（G09）
			session.unlocked_slots += 1
		"shuffle":
			PoolService.generate_pool(session, rules, rng)  # 仅刷新池，不动槽（G11）
	session.prop_counts[prop] = count - 1
	if _bus != null:
		_bus.publish("item_activated", [prop, count, count - 1], meta)
	return {"ok": true, "prop": prop, "count_before": count, "count_after": count - 1}
