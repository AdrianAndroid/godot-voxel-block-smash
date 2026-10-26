extends RefCounted
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

# 弹珠物理门面：组合 ProjectileSystem/CollisionSolver，推进并发布命中/出界事实（架构 v6）
# 阶段：阶段3物理，阶段4业务接入。颜色消除业务归 HitResolver，本模块只报告碰撞事实
# FM §4.2：物理层产出格空间局部事件点/法线；世界投影统一用【本步】world_from_grid 在此完成。

var system: RefCounted          # ProjectileSystem
var _bus: RefCounted            # EventBus
var _voxels: RefCounted         # VoxelManager（只读查询：候选/格坐标/快照）
var _level_id := ""
var _event_seq := 0
var _gen := 0                   # 【新增代码】当前会话代，混入 event_id 防重开后撞去重表（§3）


func setup(bus: RefCounted, voxel_manager: RefCounted, boundary_center: Vector3, boundary_half: float) -> void:
	_bus = bus
	_voxels = voxel_manager
	system = preload("res://scripts/projectile/projectile_system.gd").new()
	system.boundary_center = boundary_center
	system.boundary_half = boundary_half


func set_level(level_id: String) -> void:
	_level_id = level_id


# FM §4：局部格空间生成（local_pos 格坐标、local_dir 单位向量、speed 格/秒）
func spawn_ball(local_pos: Vector3, local_dir: Vector3, speed_grid_per_sec: float, shot_id: int,
		color_id: int = 0, stop_on_hit: bool = false) -> int:
	return system.spawn_local(local_pos, local_dir, speed_grid_per_sec, shot_id, color_id, stop_on_hit)


func physics_step(dt: float, world_from_grid: Transform3D, generation: int, tick: int) -> void:
	if system == null:
		return
	_gen = generation
	var _pt := PerfProbe.t0()
	var result: RefCounted = system.step(dt, world_from_grid,
		func(p0: Vector3, p1: Vector3, r: float) -> Array: return _voxels.sweep_candidates(p0, p1, r),
		func(voxel_id: int) -> Vector3: return _voxels.grid_position(voxel_id))
	PerfProbe.add("ball_step", _pt)
	var wfg := world_from_grid
	for h in result.hits:
		_event_seq += 1
		var block: Dictionary = _voxels.block_snapshot(h.voxel_id)
		var ball: Dictionary = system.ball_snapshot(h.ball_id)
		if ball.is_empty():
			continue
		# 事件点/法线/速度：本步当前变换投影到世界（§4.2 不混用发射时变换）
		ball["point"] = wfg * (h.point as Vector3)
		ball["normal"] = (wfg.basis * (h.normal as Vector3)).normalized()
		ball["vel_before"] = wfg.basis * (h.vel_before as Vector3)
		ball["vel_after"] = wfg.basis * (h.vel_after as Vector3)
		# 碰撞事实事件（未决定删除），由控制器/HitResolver 处理
		_bus.publish("ball_hit_voxel", [ball, block],
			{"event_id": _next_event_id(), "level_id": _level_id, "session_generation": generation, "physics_tick": tick})
	for e in result.ended:
		var ball_e: Dictionary = system.ball_snapshot(e.ball_id)
		if ball_e.is_empty():
			ball_e = {"ball_id": e.ball_id, "shot_id": e.get("shot_id", -1),
				"color_id": e.get("color_id", 0), "active": false}
		ball_e["reason"] = e.reason
		ball_e["pos"] = wfg * (e.local_pos as Vector3)
		ball_e["local_pos"] = e.local_pos
		_bus.publish("ball_out_of_bounds", [ball_e],
			{"event_id": _next_event_id(), "level_id": _level_id, "session_generation": generation, "physics_tick": tick})
	# R04：事件快照派发完成后回收结束球（重复结束安全：erase 幂等）
	for e in result.ended:
		system.erase_ball(e.ball_id)
	for diag in result.diagnostics:
		push_warning("projectile diagnostic: %s" % str(diag))


func _next_event_id() -> int:
	_event_seq += 1
	return hash("%s:%d:%d" % [_level_id, _gen, _event_seq]) & 0x7FFFFFFF
