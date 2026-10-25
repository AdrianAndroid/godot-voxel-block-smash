extends RefCounted

# P4-06 连击（G07）：按球计数；成功删除 +1 并发布；球结束同次提交清零；仅视觉反馈，不加伤害。

var _combo: Dictionary = {}       # ball_id -> int
var _bus: RefCounted
var _level_id := ""


func setup(bus: RefCounted, level_id: String) -> void:
	_bus = bus
	_level_id = level_id


func combo_of(ball_id: int) -> int:
	return int(_combo.get(ball_id, 0))


func on_destroy(ball_id: int, meta: Dictionary) -> void:
	_combo[ball_id] = combo_of(ball_id) + 1
	_publish(ball_id, meta)


# 球结束（出界/逃逸）：连击清零，与结束同次提交（G07）
func on_ball_end(ball_id: int, meta: Dictionary) -> void:
	if combo_of(ball_id) > 0:
		_combo[ball_id] = 0
		_publish(ball_id, meta)
	_combo.erase(ball_id)


func _publish(ball_id: int, meta: Dictionary) -> void:
	if _bus == null:
		return
	_bus.publish("combo_update", [ball_id, combo_of(ball_id)], meta)
