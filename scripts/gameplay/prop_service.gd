extends RefCounted

# P4-07 四道具（G08~G11/G13 + D04）：消耗型，激活即扣次数；次数不负；失败操作不扣。
# CQ-20261026 §2.4：随机排只重排五列中的现有炮台（保留 ID/颜色/弹量，不重生成）；
# 无可变化排列时不执行且不扣次数。

const CannonQueue := preload("res://scripts/gameplay/cannon_queue_service.gd")

# CQ-20261026/S08 §2.4："任意指"（异色万能弹）与每色严格守恒冲突，已移除，
# 改为 designated_target"指定目标"：激活只进入选择模式（不扣次），
# 接受合法选择（同色/可达/未预订）时才由控制器扣次；取消/异色/不可达不扣次。
const PROPS := ["speed_x2", "add_slot", "designated_target", "shuffle"]

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
			# FM/F4：已待发时不重复扣次（双击/连点守卫）
			if bool(session.pending_effects.get("speed_x2", false)):
				return {"ok": false, "reason": "already_pending"}
			session.pending_effects.speed_x2 = true   # 仅下一发（G08/D04）
		"designated_target":
			# CQ/S08：只进入选择模式，本步不扣次；合法选择被接受时由控制器扣次
			if bool(session.pending_effects.get("designated_selecting", false)):
				return {"ok": false, "reason": "already_selecting"}
			session.pending_effects["designated_selecting"] = true
			if _bus != null:
				_bus.publish("item_activated", [prop, count, count], meta)
			return {"ok": true, "prop": prop, "mode": "selecting",
				"count_before": count, "count_after": count}
		"add_slot":
			if session.unlocked_slots >= rules.max_slots:
				return {"ok": false, "reason": "slots_full"}  # 满槽不越界且不消耗（G09）
			session.unlocked_slots += 1
		"shuffle":
			# CQ §2.4：只重排尚在五列中的现有炮台；没有可变化的排列则不扣次数
			if not CannonQueue.shuffle_columns(session, rng):
				return {"ok": false, "reason": "nothing_to_shuffle"}
	session.prop_counts[prop] = count - 1
	if _bus != null:
		_bus.publish("item_activated", [prop, count, count - 1], meta)
	return {"ok": true, "prop": prop, "count_before": count, "count_after": count - 1}
