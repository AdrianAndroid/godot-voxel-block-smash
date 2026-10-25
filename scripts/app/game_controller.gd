extends Node
class_name GameController

## 游戏主控（阶段3骨架）：装配事件总线、关卡装载、体素管理与弹珠系统。
## 阶段4 起在此接入炮塔/弹道/道具/结算编排。

const LevelLoaderScript := preload("res://scripts/data/level_loader.gd")
const VoxelManagerScript := preload("res://scripts/voxel/voxel_manager.gd")
const BallPhysicsScript := preload("res://scripts/projectile/ball_physics.gd")
const EventBusScript := preload("res://scripts/app/event_bus.gd")
const EventRecorderScript := preload("res://scripts/diagnostics/event_recorder.gd")
const LevelSessionScript := preload("res://scripts/level/level_session.gd")

var bus: RefCounted
var recorder: RefCounted
var session: RefCounted
var voxel_manager: RefCounted
var ball_physics: RefCounted
var voxel_model: Node3D  # VoxelModelNode

var _level_loader: RefCounted
var _generation := 0


func _ready() -> void:
	bus = EventBusScript.new()
	recorder = EventRecorderScript.new()
	_level_loader = LevelLoaderScript.new()


func start_level(level_config_path: String) -> Dictionary:
	var result: Dictionary = _level_loader.load_level(level_config_path)
	if not result.ok:
		return result
	_generation += 1
	session = LevelSessionScript.new()
	session.level_id = result.config.level_id
	session.session_generation = _generation
	bus.set_generation(session.level_id, _generation)
	recorder.attach(bus, session.level_id)

	voxel_manager = VoxelManagerScript.new()
	voxel_model = preload("res://scenes/voxel/voxel_model.tscn").instantiate()
	voxel_model.attach(voxel_manager, result.voxel_data)
	add_child(voxel_model)

	ball_physics = BallPhysicsScript.new()
	ball_physics.set_level(session.level_id)
	var data: RefCounted = result.voxel_data
	var extent: Vector3 = (data.bounds_max - data.bounds_min) * 0.5
	var half: float = maxf(extent.x, maxf(extent.y, extent.z)) + 8.0  # D03 边界默认
	var center_world: Vector3 = voxel_model.world_from_grid() * data.center_offset()
	ball_physics.setup(bus, voxel_manager, center_world, half)
	return {"ok": true}
