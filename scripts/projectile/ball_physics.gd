extends RefCounted

# 弹珠物理门面：组合 ProjectileSystem/CollisionSolver，推进并发布命中/出界事实（架构 v6）
# 阶段：阶段3物理，阶段4业务接入。颜色消除业务归 HitResolver，本模块只报告碰撞事实

var system: RefCounted          # ProjectileSystem
var _bus: RefCounted            # EventBus
var _voxels: RefCounted         # VoxelManager（只读查询：候选/格坐标/快照）
var _level_id := ""
var _event_seq := 0


func setup(bus: RefCounted, voxel_manager: RefCounted, boundary_center: Vector3, boundary_half: float) -> void:
	_bus = bus
	_voxels = voxel_manager
	system = preload("res://scripts/projectile/projectile_system.gd").new()
	system.boundary_center = boundary_center
	system.boundary_half = boundary_half


func set_level(level_id: String) -> void:
	_level_id = level_id


func spawn_ball(world_pos: Vector3, world_vel: Vector3, shot_id: int) -> int:
	return system.spawn(world_pos, world_vel, shot_id)


func physics_step(dt: float, world_from_grid: Transform3D, generation: int, tick: int) -> void:
	if system == null:
		return
	var result: RefCounted = system.step(dt, world_from_grid,
		func(p0: Vector3, p1: Vector3, r: float) -> Array: return _voxels.sweep_candidates(p0, p1, r),
		func(voxel_id: int) -> Vector3: return _voxels.grid_position(voxel_id))
	for h in result.hits:
		_event_seq += 1
		var block: Dictionary = _voxels.block_snapshot(h.voxel_id)
		var ball: Dictionary = system.ball_snapshot(h.ball_id)
		ball["point"] = h.point
		ball["normal"] = h.normal
		ball["vel_before"] = h.vel_before
		ball["vel_after"] = h.vel_after
		# 碰撞事实事件（未决定删除），由控制器/HitResolver 处理
		_bus.publish("ball_hit_voxel", [ball, block],
			{"event_id": _next_event_id(), "level_id": _level_id, "session_generation": generation, "physics_tick": tick})
	for e in result.ended:
		var ball_e: Dictionary = system.ball_snapshot(e.ball_id)
		ball_e["reason"] = e.reason
		_bus.publish("ball_out_of_bounds", [ball_e],
			{"event_id": _next_event_id(), "level_id": _level_id, "session_generation": generation, "physics_tick": tick})
	for diag in result.diagnostics:
		push_warning("projectile diagnostic: %s" % str(diag))


func _next_event_id() -> int:
	_event_seq += 1
	return hash("%s:%d" % [_level_id, _event_seq]) & 0x7FFFFFFF
