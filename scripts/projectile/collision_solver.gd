extends RefCounted

# 碰撞求解（架构 v6：局部网格候选/窄相分离、球体连续扫掠、最早命中、稳定ID破平局）
# 阶段：阶段3。全部在模型局部格空间计算（voxel_size=1），方块=单位盒

# 扫掠线段 p0->p1（局部格空间），球半径 radius，候选 voxel_id 列表
# 返回 {hit:bool, voxel_id:int, t:float(0..1), point:Vector3, normal:Vector3}
static func sweep(p0: Vector3, p1: Vector3, radius: float, candidate_ids: Array, grid_pos_of: Callable) -> Dictionary:
	var best := {"hit": false, "voxel_id": -1, "t": 1.0, "point": p1, "normal": Vector3.ZERO}
	var d := p1 - p0
	for id in candidate_ids:
		var gp: Vector3 = grid_pos_of.call(id)
		var bmin := gp - Vector3.ONE * radius
		var bmax := gp + Vector3.ONE + Vector3.ONE * radius
		var hit := _ray_aabb(p0, d, bmin, bmax)
		if hit.hit and (hit.t < best.t or (hit.t == best.t and id < best.voxel_id)):
			best = {"hit": true, "voxel_id": id, "t": hit.t, "point": p0 + d * hit.t, "normal": hit.normal}
	return best


# 射线 vs AABB（slab 法），返回进入点 t 与法线；起点在盒内视为 t=0 不命中（防零时间反复碰撞）
static func _ray_aabb(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> Dictionary:
	if bmin.x < o.x and o.x < bmax.x and bmin.y < o.y and o.y < bmax.y and bmin.z < o.z and o.z < bmax.z:
		return {"hit": false}
	var t_near := 0.0
	var t_far := 1.0
	var axis := -1
	var sign_axis := 0.0
	for ai in 3:
		if absf(d[ai]) < 1e-9:
			if o[ai] < bmin[ai] or o[ai] > bmax[ai]:
				return {"hit": false}
		else:
			var t1 := (bmin[ai] - o[ai]) / d[ai]
			var t2 := (bmax[ai] - o[ai]) / d[ai]
			var s := -1.0
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
				s = 1.0
			if t1 > t_near:
				t_near = t1
				axis = ai
				sign_axis = s
			t_far = minf(t_far, t2)
			if t_near > t_far:
				return {"hit": false}
	if axis < 0:
		return {"hit": false}
	var n := Vector3.ZERO
	n[axis] = sign_axis
	return {"hit": true, "t": t_near, "normal": n}


# 无损反射（架构 v6 公式夹具）：v_out = v_in - 2(v_in·n)n
static func reflect(v: Vector3, n: Vector3) -> Vector3:
	return v - 2.0 * v.dot(n) * n
