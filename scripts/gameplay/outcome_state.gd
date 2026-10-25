extends RefCounted

# P4-08 胜负（G12/G14 + D08）：完整事务后评估；通关优先；胜负互斥且只发一次。

const PoolService := preload("res://scripts/gameplay/pool_service.gd")

var _bus: RefCounted
var _settled := false


func setup(bus: RefCounted) -> void:
	_bus = bus
	_settled = false


# 失败真值表（D08）：余块>0 且 池空 且 槽空 且 活跃球=0 且 随机排剩余=0
func evaluate(session: RefCounted, alive_count: int, active_balls: int,
		level_id: String, meta: Dictionary) -> String:
	if _settled or session.outcome != "RUNNING":
		return session.outcome
	if alive_count == 0:
		session.outcome = "WON"
		_settled = true
		_bus.publish("level_win", [level_id], meta)
		return session.outcome
	if PoolService.is_empty(session) and session.slots.is_empty() \
			and active_balls == 0 and int(session.prop_counts.get("shuffle", 0)) <= 0:
		session.outcome = "LOST"
		_settled = true
		_bus.publish("level_lose", [level_id, alive_count], meta)
	return session.outcome
