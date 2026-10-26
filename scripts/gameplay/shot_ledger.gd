extends RefCounted

# CQ-20261026/S05：射击账本——目标预订、在途票据、幂等结算、分色守恒审计。
# 契约：reservations voxel_id->shot_id（同色目标唯一预订，防重复命中）；
# tickets shot_id->ShotTicket{shot_id,turret_id,ball_id,target_voxel_id,color_id,
#   session_generation,status(PENDING/HIT/CANCELLED),speed_modifier,age}。
# 结算幂等：只有 PENDING 可转移；重复结算返回原状态不产生副作用。

var tickets: Dictionary = {}       # shot_id -> ticket
var reservations: Dictionary = {}  # voxel_id -> shot_id


func is_available(voxel_id: int) -> bool:
	return not reservations.has(voxel_id)


func create_ticket(shot_id: int, turret_id: int, target_voxel_id: int, color_id: int,
		generation: int, speed_modifier: float) -> Dictionary:
	if reservations.has(target_voxel_id):
		return {"ok": false, "reason": "already_reserved"}
	var ticket := {
		"shot_id": shot_id, "turret_id": turret_id, "ball_id": -1,
		"target_voxel_id": target_voxel_id, "color_id": color_id,
		"session_generation": generation, "status": "PENDING",
		"speed_modifier": speed_modifier, "age": 0.0,
	}
	tickets[shot_id] = ticket
	reservations[target_voxel_id] = shot_id
	return {"ok": true, "ticket": ticket}


func attach_ball(shot_id: int, ball_id: int) -> void:
	var t: Dictionary = tickets.get(shot_id, {})
	if not t.is_empty():
		t.ball_id = ball_id


func ticket_by_shot(shot_id: int) -> Dictionary:
	return tickets.get(shot_id, {})


# 某炮台的当前在途票据（CQ/S06 炮管瞄准：每炮最多一颗在途，取第一个 PENDING）
func ticket_by_turret(turret_id: int) -> Dictionary:
	for id in tickets:
		var t: Dictionary = tickets[id]
		if int(t.turret_id) == turret_id and t.status == "PENDING":
			return t
	return {}


func ticket_by_ball(ball_id: int) -> Dictionary:
	for id in tickets:
		var t: Dictionary = tickets[id]
		if int(t.ball_id) == ball_id and t.status == "PENDING":
			return t
	return {}


# 幂等结算：PENDING -> HIT / CANCELLED；返回 {ok, changed, ticket}
func settle_hit(shot_id: int) -> Dictionary:
	return _settle(shot_id, "HIT")


func settle_cancel(shot_id: int) -> Dictionary:
	return _settle(shot_id, "CANCELLED")


func _settle(shot_id: int, to: String) -> Dictionary:
	var t: Dictionary = tickets.get(shot_id, {})
	if t.is_empty():
		return {"ok": false, "changed": false, "reason": "unknown_shot"}
	if t.status != "PENDING":
		return {"ok": true, "changed": false, "ticket": t}  # 幂等：已结算不重复
	t.status = to
	reservations.erase(int(t.target_voxel_id))
	return {"ok": true, "changed": true, "ticket": t}


# 超时扫描：age 累加由调用方驱动；返回本次过期的 PENDING 票据数组
func advance_time(dt: float, timeout_sec: float) -> Array:
	var expired: Array = []
	for id in tickets:
		var t: Dictionary = tickets[id]
		if t.status != "PENDING":
			continue
		t.age = float(t.age) + dt
		if float(t.age) >= timeout_sec:
			expired.append(t)
	return expired


func pending_count() -> int:
	var n := 0
	for id in tickets:
		if tickets[id].status == "PENDING":
			n += 1
	return n


# 在途弹分色统计 F[c]
func in_flight_by_color() -> Dictionary:
	var f := {}
	for id in tickets:
		var t: Dictionary = tickets[id]
		if t.status == "PENDING":
			f[t.color_id] = int(f.get(t.color_id, 0)) + 1
	return f


# 清理已结算票据（保留最近 keep 条便于审计回放；预订已随结算释放）
func compact(keep: int = 64) -> void:
	var done: Array = []
	for id in tickets:
		if tickets[id].status != "PENDING":
			done.append(id)
	done.sort()
	while done.size() > keep:
		tickets.erase(done.pop_front())
