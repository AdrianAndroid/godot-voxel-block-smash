extends RefCounted

# P4-05 同色消除（G04/G07）：订阅 ball_hit_voxel；同色（或任意指弹珠）删除一次并发布
# voxel_destroyed；异色仅反弹（物理层已完成反射，此处不改弹道）。粒子由渲染层订阅
# voxel_destroyed 自行播放，不参与碰撞。

var _bus: RefCounted
var _session: RefCounted
var _voxels: RefCounted          # VoxelManager
var _combo: RefCounted           # ComboState
var _level_id := ""
var _next_event_id: Callable     # 由控制器提供，保证 event_id 全局唯一


func setup(bus: RefCounted, session: RefCounted, voxel_manager: RefCounted,
		combo: RefCounted, level_id: String, event_id_source: Callable) -> void:
	_bus = bus
	_session = session
	_voxels = voxel_manager
	_combo = combo
	_level_id = level_id
	_next_event_id = event_id_source
	bus.subscribe("ball_hit_voxel", _on_hit, level_id)


func _on_hit(args: Array, meta: Dictionary) -> void:
	if _session.outcome != "RUNNING":
		return
	var ball: Dictionary = args[0]
	var block: Dictionary = args[1]
	var color_match: bool = bool(ball.get("any_color", false)) \
		or int(ball.get("color_id", -1)) == int(block.get("color_id", -2))
	if not color_match:
		return  # 异色：不删除、不计连击（G04/G07）
	var res: Dictionary = _voxels.destroy(int(block.voxel_id))
	if not res.get("ok", false):
		return  # 已被同帧其他弹珠删除，只删一次（G04）
	var destroy_meta := {"event_id": _next_event_id.call(), "level_id": _level_id,
		"session_generation": meta.get("session_generation", 0),
		"physics_tick": meta.get("physics_tick", 0)}
	_bus.publish("voxel_destroyed", [res.block, ball], destroy_meta)
	var combo_meta := destroy_meta.duplicate()
	combo_meta["event_id"] = _next_event_id.call()  # event_id 全局唯一，不可复用
	_combo.on_destroy(int(ball.ball_id), combo_meta)
