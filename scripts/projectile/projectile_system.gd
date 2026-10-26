extends RefCounted

const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

# 弹珠推进系统（架构 v6：固定物理步、最早命中推进剩余时间、防穿透、出界只结束一次）
# 阶段：阶段3物理，阶段4业务接入
# FM §4：球以【模型局部格空间】为权威物理坐标（local_pos/local_dir，速度单位格/秒）。
# 模型旋转/平移只影响显示投影（world = 本步 world_from_grid * local_pos），
# 不改变已锁定弹道——旋转中已发射弹仍命中预订目标。
# R04：结束球在事件快照派发后由 erase_ball 真正回收，容器规模≈活跃数。

const MAX_ITERATIONS := 16      # 单步最大碰撞迭代（达上限记诊断，不静默丢弃位移）
const EPSILON := 1e-4           # 接触容差：反弹后沿法线推出，防零时间反复碰撞
const ENDED_LOG_MAX := 64       # 有界诊断历史

var radius := 0.35              # 球半径（格单位；D03 默认 0.35*voxel_size，voxel_size=1）
var boundary_center := Vector3.ZERO   # 有效边界中心（格空间，模型包围盒中心）
var boundary_half := 0.0              # 有效边界半边长（D03：模型最大半宽+8）
var max_bounces := 64                 # 防卡死逃逸上限（D03 附加执行默认）
var solver  # CollisionSolver

var _balls: Dictionary = {}     # ball_id -> {local_pos,local_dir,speed,active,shot_id,bounces,...}
var _next_ball_id := 1
var _ended_log: Array = []      # 有界已结束球诊断快照（最新在后）
var _last_wfg := Transform3D.IDENTITY  # 本步世界<-格变换（事件/快照世界投影用）


class StepResult:
	var hits: Array = []        # {ball_id, voxel_id, point(格), normal(格), vel_before(格), vel_after(格)}
	var ended: Array = []       # {ball_id, reason, local_pos, shot_id, color_id}
	var diagnostics: Array = [] # {ball_id, reason}


func _init() -> void:
	solver = preload("res://scripts/projectile/collision_solver.gd")


# CQ-20261026/S05：stop_on_hit=true 时首个命中即停球（一发消一块即回收，不再反弹续消）
# FM §4.2：局部格空间生成。local_dir 为单位向量（格空间），speed 单位格/秒。
func spawn_local(local_pos: Vector3, local_dir: Vector3, speed_grid_per_sec: float,
		shot_id: int, color_id: int = 0, stop_on_hit: bool = false) -> int:
	if not is_finite(local_pos.x) or not is_finite(local_pos.y) or not is_finite(local_pos.z):
		return -1
	if local_dir.length_squared() < 0.5 or speed_grid_per_sec <= 0.0:
		return -1
	var id := _next_ball_id
	_next_ball_id += 1
	_balls[id] = {"local_pos": local_pos, "local_dir": local_dir.normalized(),
		"speed": speed_grid_per_sec, "active": true, "shot_id": shot_id, "bounces": 0,
		"color_id": color_id, "stop_on_hit": stop_on_hit, "age": 0.0}
	return id


func ball_snapshot(ball_id: int) -> Dictionary:
	var b: Dictionary = _balls.get(ball_id, {})
	if b.is_empty():
		return {}
	# 过渡兼容：同时给局部坐标与按本步变换投影的世界 pos/vel
	return {"ball_id": ball_id, "shot_id": b.shot_id,
		"local_pos": b.local_pos, "local_dir": b.local_dir, "speed": b.speed,
		"pos": _last_wfg * b.local_pos, "vel": _last_wfg.basis * b.local_dir * b.speed,
		"active": b.active, "color_id": b.get("color_id", 0), "age": b.get("age", 0.0)}


func active_count() -> int:
	# R04 修复后 _balls 只含活跃球（结束即回收）
	return _balls.size()


func end_ball(ball_id: int) -> void:
	# 外部结束路径（无事件派发）：立即回收
	erase_ball(ball_id)


func erase_ball(ball_id: int) -> void:
	var b: Dictionary = _balls.get(ball_id, {})
	if b.is_empty():
		return
	_ended_log.append({"ball_id": ball_id, "shot_id": b.get("shot_id", -1),
		"age": b.get("age", 0.0), "bounces": b.get("bounces", 0)})
	if _ended_log.size() > ENDED_LOG_MAX:
		_ended_log.pop_front()
	_balls.erase(ball_id)


func ball_velocity(ball_id: int) -> Vector3:
	# 世界系速度（按本步变换投影）
	var b: Dictionary = _balls.get(ball_id, {})
	if b.is_empty():
		return Vector3.ZERO
	return _last_wfg.basis * (b.local_dir as Vector3) * float(b.speed)


# 推进一个物理步。candidates_of: Callable(grid_p0, grid_p1, radius) -> Array[voxel_id]
# grid_pos_of: Callable(voxel_id) -> Vector3（格坐标角点）
# world_from_grid 仅用于记录本步变换（事件世界投影由门面完成），弹道本身与变换无关。
func step(dt: float, world_from_grid: Transform3D, candidates_of: Callable, grid_pos_of: Callable) -> StepResult:
	var result := StepResult.new()
	_last_wfg = world_from_grid
	# 回收上一步遗留的结束球（正常路径门面在事件派发后已 erase；直调 step 的调用方在此兜底）
	for id in _balls.keys():
		if not _balls[id].active:
			erase_ball(id)
	PerfProbe.count("pstep_active_%d" % mini(_balls.size(), 20))
	for id in _balls.keys():
		var b: Dictionary = _balls[id]
		if not b.active:
			continue
		b.age = float(b.get("age", 0.0)) + dt
		var pl: Vector3 = b.local_pos
		var vl: Vector3 = b.local_dir * b.speed
		var remaining := dt
		var iter := 0
		while remaining > 1e-9 and iter < MAX_ITERATIONS and b.active:
			iter += 1
			var p1: Vector3 = pl + vl * remaining
			var _tc := PerfProbe.t0()
			var cands: Array = candidates_of.call(pl, p1, radius)
			PerfProbe.add("pstep_cands", _tc)
			PerfProbe.count("pstep_cands_n_%d" % mini(cands.size(), 200))
			var _ts := PerfProbe.t0()
			var hit: Dictionary = solver.sweep(pl, p1, radius, cands, grid_pos_of)
			PerfProbe.add("pstep_sweep", _ts)
			if hit.hit:
				pl = hit.point + hit.normal * EPSILON
				var v_before_l: Vector3 = vl
				vl = solver.reflect(vl, hit.normal)
				b.bounces += 1
				result.hits.append({
					"ball_id": id, "voxel_id": hit.voxel_id,
					"point": hit.point, "normal": hit.normal,
					"vel_before": v_before_l, "vel_after": vl,
				})
				remaining *= (1.0 - hit.t)
				if b.get("stop_on_hit", false):
					# CQ §2.2：一发一块——首个接触即停球，由控制器按票据结算（命中/取消）
					b.active = false
					result.ended.append({"ball_id": id, "reason": "hit_stop", "local_pos": pl,
						"shot_id": b.shot_id, "color_id": b.get("color_id", 0)})
				elif b.bounces >= max_bounces:
					b.active = false
					result.ended.append({"ball_id": id, "reason": "max_bounces", "local_pos": pl,
						"shot_id": b.shot_id, "color_id": b.get("color_id", 0)})
					result.diagnostics.append({"ball_id": id, "reason": "max_bounces_escape"})
			else:
				pl = p1
				remaining = 0.0
			if b.active and _out_of_bounds(pl):
				b.active = false
				result.ended.append({"ball_id": id, "reason": "out_of_bounds", "local_pos": pl,
					"shot_id": b.shot_id, "color_id": b.get("color_id", 0)})
		if iter >= MAX_ITERATIONS and remaining > 1e-9:
			result.diagnostics.append({"ball_id": id, "reason": "iteration_cap", "remaining": remaining})
		if b.active:
			b.local_pos = pl
			# 反弹时速度方向已变，回写方向（速率不变）
			if vl.length_squared() > 1e-12:
				b.local_dir = vl.normalized()
		# 结束球保留到门面派发完 hit/ended 事件快照后由 erase_ball 回收
	return result


func _out_of_bounds(pl: Vector3) -> bool:
	# 格空间轴对齐立方体边界（模型局部空间，旋转不影响判定）
	var d: Vector3 = pl - boundary_center
	return absf(d.x) > boundary_half or absf(d.y) > boundary_half or absf(d.z) > boundary_half
