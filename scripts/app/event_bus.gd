extends RefCounted

# 唯一跨模块通知通道（架构 v6 固定事件清单）
# 串行派发 + 防重入队列；event_id 去重；session_generation 陈旧拒绝；切关按 level_id 解绑
# meta 契约：{event_id:int, level_id:String, session_generation:int, physics_tick:int}；sequence 由总线注入

const EVENTS := [
	"level_loaded", "voxel_destroyed", "ball_hit_voxel", "ball_out_of_bounds",
	"turret_fire", "turret_merged", "combo_update", "level_win", "level_lose",
	"item_activated",
]

var _subs: Dictionary = {}        # event -> Array[Dictionary{callable, level_id}]
var _queue: Array = []            # 防重入：派发中发布的事件排队
var _dispatching := false
var _sequence := 0
var _seen_event_ids: Dictionary = {}
var _generation: Dictionary = {}  # level_id -> 当前 session_generation


func _init() -> void:
	for e in EVENTS:
		_subs[e] = []


func set_generation(level_id: String, generation: int) -> void:
	_generation[level_id] = generation


func subscribe(event: String, callable: Callable, level_id: String) -> bool:
	if not _subs.has(event):
		return false
	_subs[event].append({"callable": callable, "level_id": level_id})
	return true


func unsubscribe_level(level_id: String) -> void:
	for e in EVENTS:
		_subs[e] = _subs[e].filter(func(s: Dictionary) -> bool: return s.level_id != level_id)


func publish(event: String, args: Array, meta: Dictionary) -> bool:
	if not _subs.has(event):
		return false
	if not meta.has("event_id") or not meta.has("level_id") or not meta.has("session_generation"):
		return false
	if _seen_event_ids.has(meta.event_id):
		return false  # 同 event_id 只处理一次
	if _generation.get(meta.level_id, meta.session_generation) != meta.session_generation:
		return false  # 旧代事件拒绝
	_seen_event_ids[meta.event_id] = true
	_queue.append({"event": event, "args": args, "meta": meta})
	if _dispatching:
		return true  # 防重入：排队，由外层循环串行派发
	_dispatching = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		_sequence += 1
		item.meta["sequence"] = _sequence
		item.meta["event"] = item.event
		for s in _subs[item.event]:
			# 监听方只读消费，不得修改权威状态
			s.callable.callv([item.args, item.meta])
	_dispatching = false
	return true


func published_sequence() -> int:
	return _sequence
