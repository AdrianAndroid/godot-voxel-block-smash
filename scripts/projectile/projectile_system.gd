extends RefCounted

# 弹珠推进系统（架构 v6：固定物理步、最早命中推进剩余时间、防穿透、出界只结束一次）
# 阶段：阶段3物理，阶段4业务接入
# 坐标：球存储世界坐标；每物理步经 world_from_grid 变换到模型局部格空间扫掠（旋转模型逐步处理）

const MAX_ITERATIONS := 16      # 单步最大碰撞迭代（达上限记诊断，不静默丢弃位移）
const EPSILON := 1e-4           # 接触容差：反弹后沿法线推出，防零时间反复碰撞

var radius := 0.35              # 球半径（D03 默认 0.35*voxel_size，voxel_size=1）
var boundary_center := Vector3.ZERO   # 有效边界中心（格空间，模型包围盒中心）
var boundary_half := 0.0              # 有效边界半边长（D03：模型最大半宽+8）
var max_bounces := 64                 # 防卡死逃逸上限（D03 附加执行默认）
var solver  # CollisionSolver

var _balls: Dictionary = {}     # ball_id -> {pos,vel,active,shot_id,bounces}（世界坐标）
var _next_ball_id := 1


class StepResult:
	var hits: Array = []        # {ball_id, voxel_id, point(world), normal(world), vel_before, vel_after}
	var ended: Array = []       # {ball_id, reason, pos}
	var diagnostics: Array = [] # {ball_id, reason}


func _init() -> void:
	solver = preload("res://scripts/projectile/collision_solver.gd")


func spawn(pos: Vector3, vel: Vector3, shot_id: int, color_id: int = 0, any_color: bool = false) -> int:
	var id := _next_ball_id
	_next_ball_id += 1
	_balls[id] = {"pos": pos, "vel": vel, "active": true, "shot_id": shot_id, "bounces": 0,
		"color_id": color_id, "any_color": any_color}
	return id


func ball_snapshot(ball_id: int) -> Dictionary:
	var b: Dictionary = _balls.get(ball_id, {})
	if b.is_empty():
		return {}
	return {"ball_id": ball_id, "shot_id": b.shot_id, "pos": b.pos, "vel": b.vel,
		"active": b.active, "color_id": b.get("color_id", 0), "any_color": b.get("any_color", false)}


func active_count() -> int:
	var n := 0
	for id in _balls:
		if _balls[id].active:
			n += 1
	return n


func end_ball(ball_id: int) -> void:
	if _balls.has(ball_id):
		_balls[ball_id].active = false


func ball_velocity(ball_id: int) -> Vector3:
	return _balls.get(ball_id, {}).get("vel", Vector3.ZERO)


# 推进一个物理步。candidates_of: Callable(grid_p0, grid_p1, radius) -> Array[voxel_id]
# grid_pos_of: Callable(voxel_id) -> Vector3（格坐标角点）
func step(dt: float, world_from_grid: Transform3D, candidates_of: Callable, grid_pos_of: Callable) -> StepResult:
	var result := StepResult.new()
	var grid_from_world := world_from_grid.affine_inverse()
	for id in _balls.keys():
		var b: Dictionary = _balls[id]
		if not b.active:
			continue
		# 世界 -> 格空间（本步内模型变换固定）
		var pl: Vector3 = grid_from_world * b.pos
		var vl: Vector3 = grid_from_world.basis * b.vel
		var remaining := dt
		var iter := 0
		while remaining > 1e-9 and iter < MAX_ITERATIONS and b.active:
			iter += 1
			var p1: Vector3 = pl + vl * remaining
			var cands: Array = candidates_of.call(pl, p1, radius)
			var hit: Dictionary = solver.sweep(pl, p1, radius, cands, grid_pos_of)
			if hit.hit:
				pl = hit.point + hit.normal * EPSILON
				var v_before_l: Vector3 = vl
				vl = solver.reflect(vl, hit.normal)
				b.bounces += 1
				result.hits.append({
					"ball_id": id, "voxel_id": hit.voxel_id,
					"point": world_from_grid * hit.point,
					"normal": (world_from_grid.basis * hit.normal).normalized(),
					"vel_before": world_from_grid.basis * v_before_l,
					"vel_after": world_from_grid.basis * vl,
				})
				remaining *= (1.0 - hit.t)
				if b.bounces >= max_bounces:
					b.active = false
					result.ended.append({"ball_id": id, "reason": "max_bounces", "pos": world_from_grid * pl})
					result.diagnostics.append({"ball_id": id, "reason": "max_bounces_escape"})
			else:
				pl = p1
				remaining = 0.0
			if b.active and _out_of_bounds(pl):
				b.active = false
				result.ended.append({"ball_id": id, "reason": "out_of_bounds", "pos": world_from_grid * pl})
		if iter >= MAX_ITERATIONS and remaining > 1e-9:
			result.diagnostics.append({"ball_id": id, "reason": "iteration_cap", "remaining": remaining})
		b.pos = world_from_grid * pl
		b.vel = world_from_grid.basis * vl
	return result


func _out_of_bounds(pl: Vector3) -> bool:
	# 格空间轴对齐立方体边界（随模型局部空间，旋转不影响判定）
	var d: Vector3 = pl - boundary_center
	return absf(d.x) > boundary_half or absf(d.y) > boundary_half or absf(d.z) > boundary_half
