extends Node3D
class_name MarblePresenter

## 【新增代码】弹珠表现层（playability-architecture §2.1）：
## turret_fire 事件生成可见球（颜色跟随炮台 palette），每帧只读 ball_snapshot 同步位置；
## 出界/快照失效幂等回收进 idle 池复用；clear 在重开/返回/结算时回收全部表现球。
## 只读物理状态，绝不反写；不推进物理。

var controller: Node = null
var debug_logging := false   # S10：默认关（每发两条 logcat 影响真机性能采样），排查时手动开
var idle_max := 32            # 原型可配置值（§2.1，需性能验证）

var _active: Dictionary = {}  # ball_id -> Node3D
var _idle: Array[Node3D] = []
var _materials: Dictionary = {}  # color_id -> StandardMaterial3D（逐色只读缓存，不共改）
var _level_id := ""


func bind(p_controller: Node) -> void:
	controller = p_controller
	_level_id = controller.session.level_id
	controller.bus.subscribe("turret_fire", _on_fire, _level_id)
	controller.bus.subscribe("ball_out_of_bounds", _on_ball_end, _level_id)


func clear() -> void:
	for id in _active.keys():
		_recycle(int(id))
	_active.clear()
	controller = null


func active_count() -> int:
	return _active.size()


func idle_count() -> int:
	return _idle.size()


func ball_node(ball_id: int) -> Node3D:
	return _active.get(ball_id, null)


func _on_fire(args: Array, _meta: Dictionary) -> void:
	var turret: Dictionary = args[0]
	var ball_id: int = int(args[1])
	var node := _acquire()
	node.visible = true
	(node.get_node("Mesh") as MeshInstance3D).set_surface_override_material(
		0, _material_of(int(turret.get("color_id", 0))))
	_active[ball_id] = node
	if debug_logging:
		print("[marble] acquire ball=%d color=%d gen=%d active=%d idle=%d" % [
			ball_id, int(turret.get("color_id", 0)),
			int(_meta.get("session_generation", 0)), _active.size(), _idle.size()])


func _on_ball_end(args: Array, _meta: Dictionary) -> void:
	_recycle(int(args[0].get("ball_id", -1)))


func _process(_delta: float) -> void:
	if controller == null or controller.ball_physics == null:
		return
	var stale: Array = []
	for id in _active:
		var snap: Dictionary = controller.ball_physics.system.ball_snapshot(int(id))
		if snap.is_empty() or not snap.get("active", false):
			stale.append(id)  # 出界/结束但事件未到：幂等回收（§2.1）
			continue
		(_active[id] as Node3D).global_position = snap.pos
	for id in stale:
		_recycle(int(id))


func _acquire() -> Node3D:
	if not _idle.is_empty():
		return _idle.pop_back()
	var node: Node3D = preload("res://scenes/projectile/marble.tscn").instantiate()
	add_child(node)
	return node


func _recycle(ball_id: int) -> void:
	var node: Node3D = _active.get(ball_id, null)
	if node == null:
		return  # 幂等：重复出界事件/未知 id 不报错
	_active.erase(ball_id)
	node.visible = false
	if _idle.size() < idle_max:
		_idle.append(node)
	else:
		node.queue_free()  # 池满才释放（§2.1）
	if debug_logging:
		print("[marble] recycle ball=%d active=%d idle=%d" % [ball_id, _active.size(), _idle.size()])


func _material_of(color_id: int) -> StandardMaterial3D:
	if _materials.has(color_id):
		return _materials[color_id]
	var c := Color.WHITE
	if controller != null and controller.voxel_manager != null \
			and controller.voxel_manager.data != null:
		var p: Dictionary = controller.voxel_manager.data.palette
		if p.has(color_id):
			c = p[color_id]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.2  # 高光提高可读性（§9：球色跟随炮台，可加高光）
	# CQ/S06：同色自发光提亮，飞行中在各种光照下可辨色
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	_materials[color_id] = m
	return m
