extends RefCounted

# 胜负（CQ-20261026 §2.2/§2.3 + S08）：
# - 胜利：全清且无未结算票据时才判胜，只发一次（S08 §4）。
# - 没有同色可达目标是正常等待，不判负（§2.3）。
# - 死局判负仅当能证明没有剩余恢复操作；在每色严格守恒下 Q+S+F=V 恒成立，
#   队列+槽位全空且无在途 ⇒ V=0；此时余块>0 说明守恒被打破，
#   记 integrity_error（outcome=ERROR），不包装成正常失败（S08 §6）。
# - 胜负互斥且只发一次。

const CannonQueue := preload("res://scripts/gameplay/cannon_queue_service.gd")
const SlotService := preload("res://scripts/gameplay/slot_service.gd")

var _bus: RefCounted
var _settled := false


func setup(bus: RefCounted) -> void:
	_bus = bus
	_settled = false


func evaluate(session: RefCounted, alive_count: int, active_balls: int,
		pending_tickets: int, level_id: String, meta: Dictionary) -> String:
	if _settled or session.outcome != "RUNNING":
		return session.outcome
	if alive_count == 0:
		if pending_tickets > 0:
			return session.outcome  # S08 §4：还有未结算票据，等结算后才判胜
		session.outcome = "WON"
		_settled = true
		_bus.publish("level_win", [level_id], meta)
		return session.outcome
	if _queues_empty(session) and SlotService.is_empty(session) and active_balls == 0 \
			and pending_tickets == 0:
		# S08 §6：守恒正确时此分支不可达（V=Q+S+F=0）；到达=完整性破坏
		session.outcome = "ERROR"
		_settled = true
		_bus.publish("integrity_error", [level_id, alive_count], meta)
	return session.outcome


func _queues_empty(session: RefCounted) -> bool:
	for col in session.queue_columns:
		if not (col as Array).is_empty():
			return false
	return true
