extends RefCounted

# CQ-20261026 §2.2 连击：全局连续命中序列——成功消除 +1，1.5 秒无成功命中清零。
# 替代旧"同球反弹次数"统计。仅视觉反馈，不加伤害、无额外消块奖励。

const WINDOW_SEC := 1.5

var streak := 0
var _since_hit := 1e9
var _bus: RefCounted
var _level_id := ""


func setup(bus: RefCounted, level_id: String) -> void:
	_bus = bus
	_level_id = level_id
	streak = 0
	_since_hit = 1e9


func on_destroy(meta: Dictionary) -> void:
	streak += 1
	_since_hit = 0.0
	_publish(meta)


func tick(dt: float, meta: Dictionary) -> void:
	if streak <= 0:
		return
	_since_hit += dt
	if _since_hit > WINDOW_SEC:
		streak = 0
		_publish(meta)


func _publish(meta: Dictionary) -> void:
	if _bus == null:
		return
	_bus.publish("combo_update", [streak], meta)
