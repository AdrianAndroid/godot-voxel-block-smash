extends SceneTree

# P3-02 事件总线自测：顺序/去重/陈旧拒绝/防重入/切关解绑/未知事件
# 运行：godot --headless --path . -s tests/unit/test_event_bus.gd

var _failures := 0
var _log: Array = []


func _initialize() -> void:
	var bus := preload("res://scripts/app/event_bus.gd").new()
	var meta := func(id: int, gen: int = 0) -> Dictionary:
		return {"event_id": id, "level_id": "level_01", "session_generation": gen, "physics_tick": 0}

	bus.subscribe("voxel_destroyed", func(args: Array, m: Dictionary) -> void: _log.append("a%d" % m.sequence), "level_01")
	bus.subscribe("voxel_destroyed", func(args: Array, m: Dictionary) -> void: _log.append("b%d" % m.sequence), "level_01")
	bus.publish("voxel_destroyed", [], meta.call(1))
	_check(_log == ["a1", "b1"], "串行顺序与sequence注入", str(_log))

	# event_id 去重
	_check(not bus.publish("voxel_destroyed", [], meta.call(1)), "同 event_id 拒绝", "")
	_check(_log.size() == 2, "监听只调一次", str(_log))

	# 陈旧代拒绝
	bus.set_generation("level_01", 5)
	_check(not bus.publish("voxel_destroyed", [], meta.call(2, 0)), "旧 generation 拒绝", "")
	_check(bus.publish("voxel_destroyed", [], meta.call(3, 5)), "当前 generation 接受", "")

	# 防重入：监听内发布派生事件 → 排队串行，不成环
	_log.clear()
	var bus2 := preload("res://scripts/app/event_bus.gd").new()
	bus2.subscribe("turret_fire", func(args: Array, m: Dictionary) -> void:
		_log.append("fire")
		bus2.publish("combo_update", [1], {"event_id": 100, "level_id": "L", "session_generation": 0, "physics_tick": 0})
	, "L")
	bus2.subscribe("combo_update", func(args: Array, m: Dictionary) -> void: _log.append("combo"), "L")
	bus2.publish("turret_fire", [], {"event_id": 99, "level_id": "L", "session_generation": 0, "physics_tick": 0})
	_check(_log == ["fire", "combo"], "防重入队列派发", str(_log))

	# 切关解绑
	bus.unsubscribe_level("level_01")
	_log.clear()
	bus.publish("voxel_destroyed", [], meta.call(4, 5))
	_check(_log.is_empty(), "切关解绑后无投递", str(_log))

	# 未知事件拒绝
	_check(not bus.publish("not_an_event", [], meta.call(5, 5)), "未知事件拒绝", "")

	if _failures == 0:
		print("TEST_PASS test_event_bus")
	else:
		print("TEST_FAIL test_event_bus failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
