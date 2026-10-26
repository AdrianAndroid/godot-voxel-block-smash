extends SceneTree

# CQ-20261026/S03：离线可解性验证器（headless）。
# 用与运行时相同的可达目标规则（fire_geometry.first_hit_is + collision_solver 扫掠、真实槽口起点、
# 弹珠半径、当前模型变换）、3 炮位、列首规则与允许旋转视角，贪心回放一条可清空方案。
# 成功种子写入关卡配置 queue_seed；操作序列写 reports/desktop/cq/s03-solution.json。
# 运行：godot --headless --path . -s tools/cq_verify.gd -- [起始seed] [最多尝试]

const CannonQueue := preload("res://scripts/gameplay/cannon_queue_service.gd")
const FireGeom := preload("res://scripts/gameplay/fire_geometry.gd")
const Solver := preload("res://scripts/projectile/collision_solver.gd")
const SpatialIndex := preload("res://scripts/voxel/voxel_spatial_index.gd")
const VoxelLoader := preload("res://scripts/data/voxel_loader.gd")

const VIEWPORT := Vector2(1080, 2400)  # Pixel 7a 逻辑分辨率（20:9）
const CAMERA_FOV := 75.0
const BALL_RADIUS := 0.35
const SLOT_CAPACITY := 3
const BOUNDARY_MARGIN := 8.0
const MODEL_PATH := "res://assets/models/json/frog_02.json"

var _data: RefCounted
var _index: RefCounted
var _camera: Camera3D
var _boundary_center: Vector3
var _boundary_half := 0.0
var _color_sets: Dictionary = {}  # color_id -> {voxel_id: true}
var _frontier: Dictionary = {}    # color_id -> Array[voxel_id]：最近被暴露的邻块（优先检测）
var _alive_count := 0
var _orientations: Array[Basis] = []
var _orient_names: Array[String] = []
var _actions: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_start := 1
	var max_tries := 200
	if args.size() >= 1:
		seed_start = int(args[0])
	if args.size() >= 2:
		max_tries = int(args[1])

	var loaded: Dictionary = VoxelLoader.load_from_json(MODEL_PATH)
	if not loaded.get("ok", false):
		print("VERIFY_ERROR model load: %s" % loaded.get("error", ""))
		quit(1)
		return
	root.size = Vector2i(int(VIEWPORT.x), int(VIEWPORT.y))  # headless 下显式设定视口，相机投影依赖它
	_data = loaded.data
	_setup_camera()
	_setup_orientations()
	var color_counts := {}
	for i in _data.count:
		var cid := int(_data.color_ids[i])
		color_counts[cid] = int(color_counts.get(cid, 0)) + 1
	print("model voxels=%d colors=%s" % [_data.count, str(color_counts)])

	var found_seed := -1
	for attempt in max_tries:
		var seed := seed_start + attempt
		if _verify_seed(seed, color_counts):
			found_seed = seed
			break
		if attempt % 10 == 9:
			print("  ... tried %d seeds, none verified yet" % [attempt + 1])
	if found_seed < 0:
		print("VERIFY_FAIL no solvable seed in [%d, %d)" % [seed_start, seed_start + max_tries])
		quit(1)
		return
	var out_path := ProjectSettings.globalize_path("res://reports/desktop/cq/s03-solution.json")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"seed": found_seed, "model": MODEL_PATH, "color_counts": color_counts,
		"slots": SLOT_CAPACITY, "actions": _actions,
	}, "  "))
	f.close()
	print("VERIFY_PASS seed=%d actions=%d solution=%s" % [found_seed, _actions.size(), out_path])
	quit(0)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	root.add_child(_camera)
	var half: Vector3 = (_data.bounds_max - _data.bounds_min) * 0.5 * _data.voxel_size
	var r: float = half.length() * 1.08
	var vfov := deg_to_rad(CAMERA_FOV)
	var aspect := VIEWPORT.x / VIEWPORT.y
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var d := maxf(r / (0.44 * tan(vfov * 0.5)), r / (0.90 * tan(hfov * 0.5)))
	var up_shift := 0.16 * 2.0 * d * tan(vfov * 0.5)
	_camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, -up_shift, d))
	_boundary_center = _data.center_offset()
	_boundary_half = maxf(half.x, maxf(half.y, half.z)) + BOUNDARY_MARGIN


func _setup_orientations() -> void:
	# 初始姿态 yaw=PI（正面朝相机）；候选 = 偏航 18 档 × 俯仰 5 档（±50° 内）
	var initial := Basis(Quaternion(Vector3.UP, PI))
	for pitch_deg in [0, -25, 25, -50, 50]:
		for yaw_deg in range(0, 360, 20):
			_orientations.append(Basis(Quaternion(Vector3.UP, deg_to_rad(yaw_deg)))
				* Basis(Quaternion(Vector3.RIGHT, deg_to_rad(pitch_deg))) * initial)
			_orient_names.append("yaw%d_pitch%d" % [yaw_deg, pitch_deg])


func _wfg(basis: Basis) -> Transform3D:
	return Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -_data.center_offset())


# 当前朝向下 slot_index 的格空间发射原点
func _origin_grid(basis: Basis, slot_index: int) -> Dictionary:
	var gfw := _wfg(basis).affine_inverse()
	return FireGeom.muzzle_origin_world(_camera, slot_index, VIEWPORT, gfw,
		_boundary_center, _boundary_half)


func _verify_seed(seed: int, color_counts: Dictionary) -> bool:
	# 生成队列（与运行时同一服务、同一 seed）
	var session := preload("res://scripts/level/level_session.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	CannonQueue.generate(session, color_counts, rng)
	var cons: Dictionary = CannonQueue.conservation_report(session, color_counts)
	if not cons.ok:
		print("VERIFY_ERROR seed=%d conservation broken: %s" % [seed, str(cons)])
		return false

	# 初始化存活集
	_index = SpatialIndex.new()
	_index.build(_data)
	_color_sets.clear()
	_frontier.clear()
	for i in _data.count:
		var cid := int(_data.color_ids[i])
		if not _color_sets.has(cid):
			_color_sets[cid] = {}
		_color_sets[cid][i] = true
	# 初始前沿=全部表面块（有 6 邻空位）；内部块必被邻块先命中，无需检测
	for i in _data.count:
		if _is_surface(i):
			var cid := int(_data.color_ids[i])
			if not _frontier.has(cid):
				_frontier[cid] = []
			_frontier[cid].append(i)
	_alive_count = _data.count
	_actions = []

	# 槽位：固定 3 格，元素 turret_id 或 -1
	var slots: Array[int] = [-1, -1, -1]
	var orient_idx := 0
	var since_progress := 0  # 连续无进展的朝向尝试数
	var iterations := 0
	while _alive_count > 0:
		iterations += 1
		if iterations > 300000:
			print("  seed=%d ITER_CAP" % seed)
			return false
		var basis: Basis = _orientations[orient_idx]
		var progressed := false

		# 1) 已上位炮台：有可达同色目标即打一发
		for si in SLOT_CAPACITY:
			var tid := slots[si]
			if tid < 0:
				continue
			var t: Dictionary = session.turrets[tid]
			var org: Dictionary = _origin_grid(basis, si)
			if not org.get("ok", false):
				continue
			var target := _find_reachable(int(t.color_id), org.origin_grid)
			if target < 0:
				continue  # WAITING_TARGET：不扣弹、不发射
			# 发射成功：S-- 命中提交 V-- D++（F 过账在 S05 账本验证）
			t.ammo_remaining = int(t.ammo_remaining) - 1
			_destroy(target)
			_actions.append({"op": "fire", "turret": tid, "slot": si, "target": target,
				"color": t.color_id, "ammo_left": t.ammo_remaining,
				"orient": _orient_names[orient_idx]})
			if int(t.ammo_remaining) <= 0:
				slots[si] = -1  # 归零移除
			progressed = true
			break  # 一次一动作，目标缓存随删除失效
		if progressed:
			since_progress = 0
			continue

		# 2) 有空槽：把某列列首（颜色可达）上位
		var free_slot := -1
		var free_count := 0
		for si in SLOT_CAPACITY:
			if slots[si] < 0:
				free_count += 1
				if free_slot < 0:
					free_slot = si
		if free_slot >= 0:
			var org: Dictionary = _origin_grid(basis, free_slot)
			if org.get("ok", false):
				for col in CannonQueue.COLUMN_COUNT:
					var tid := CannonQueue.front_of(session, col)
					if tid < 0:
						continue
					var t: Dictionary = session.turrets[tid]
					if _find_reachable(int(t.color_id), org.origin_grid) >= 0:
						CannonQueue.pop_front(session, col)
						t.state = "READY"
						slots[free_slot] = tid
						_actions.append({"op": "place", "turret": tid, "column": col,
							"slot": free_slot, "ammo": t.ammo_remaining,
							"orient": _orient_names[orient_idx]})
						progressed = true
						break
		if progressed:
			since_progress = 0
			continue

		# 3) 驻停推进：还剩 ≥2 空槽时，把"颜色被埋"的列首停入炮位推进该列（只占一个槽，保留机动槽）
		if free_count >= 2:
			var best_col := -1
			var best_alive := 0
			for col in CannonQueue.COLUMN_COUNT:
				var tid := CannonQueue.front_of(session, col)
				if tid < 0:
					continue
				var cid := int(session.turrets[tid].color_id)
				var n: int = (_color_sets.get(cid, {}) as Dictionary).size()
				if n > best_alive:
					best_alive = n
					best_col = col
			if best_col >= 0:
				var tid := CannonQueue.pop_front(session, best_col)
				session.turrets[tid].state = "WAITING_TARGET"
				slots[free_slot] = tid
				_actions.append({"op": "park", "turret": tid, "column": best_col,
					"slot": free_slot, "ammo": session.turrets[tid].ammo_remaining,
					"orient": _orient_names[orient_idx]})
				continue  # 驻停不计消除进展，但列有限保证终止

		# 4) 槽满且都射不出：取回一门当前无可达目标的炮台，腾出机动槽
		if free_slot < 0:
			var returned := false
			for si in SLOT_CAPACITY:
				var tid := slots[si]
				var t: Dictionary = session.turrets[tid]
				var org: Dictionary = _origin_grid(basis, si)
				if org.get("ok", false) \
						and _find_reachable(int(t.color_id), org.origin_grid) >= 0:
					continue  # 能射的不取回
				slots[si] = -1
				t.state = "QUEUED"
				CannonQueue.push_front(session, tid)  # 回来源列队首
				_actions.append({"op": "return", "turret": tid, "slot": si,
					"orient": _orient_names[orient_idx]})
				returned = true
				break
			if returned:
				continue

		# 3) 无进展：旋转到下一候选朝向
		orient_idx = (orient_idx + 1) % _orientations.size()
		since_progress += 1
		_actions.append({"op": "rotate", "orient": _orient_names[orient_idx]})
		if since_progress >= _orientations.size():
			return false  # 全朝向无进展：该种子未证明可解

	# 胜利还要求队列/槽位随守恒自然清空（V=0 ⟺ Q+S=0）
	for col in session.queue_columns:
		if not (col as Array).is_empty():
			print("  seed=%d WIN_BUT_QUEUE_LEFT" % seed)
			return false
	for si in SLOT_CAPACITY:
		if slots[si] >= 0:
			print("  seed=%d WIN_BUT_SLOT_LEFT" % seed)
			return false
	return true


# 在 color_id 存活体素中找第一个从 origin_grid 可达（首个命中=自身）的体素；无返回 -1。
# 只检测前沿（表面）块：全 6 邻被占的内部块，其扩张盒必被邻块扩张盒先命中，不可能首中。
# 两级过滤：先 DDA 纯格走查（线段穿过的格子若有存活块则必被挡，便宜否定），幸存者再做完整扫掠确认。
func _find_reachable(color_id: int, origin_grid: Vector3) -> int:
	var set: Dictionary = _color_sets.get(color_id, {})
	if set.is_empty():
		return -1
	var cand_list: Array = _frontier.get(color_id, [])
	# 压缩前沿：剔除已删除，避免列表无限增长
	var alive_frontier: Array = []
	for vid in cand_list:
		if set.has(vid):
			alive_frontier.append(vid)
	_frontier[color_id] = alive_frontier
	var survivors: Array = []
	for vid in alive_frontier:
		var center: Vector3 = _data.positions[vid] + Vector3(0.5, 0.5, 0.5)
		if not _los_blocked(origin_grid, center):
			survivors.append(vid)
	for vid in survivors:
		var center: Vector3 = _data.positions[vid] + Vector3(0.5, 0.5, 0.5)
		var cands: Array = _index.candidates_along_segment(origin_grid, center, BALL_RADIUS)
		var hit: Dictionary = Solver.sweep(origin_grid, center, BALL_RADIUS, cands,
			func(id: int) -> Vector3: return _data.positions[id])
		if bool(hit.get("hit", false)) and int(hit.get("voxel_id", -1)) == int(vid):
			return int(vid)
	return -1


# 便宜否定：DDA 走过 origin→target 的格子序列，目标格之前若有任何存活占用格，则必被先命中。
# 注意反向不成立（邻格扩张盒也可能挡），所以这只是预过滤，最终仍由完整扫掠确认。
func _los_blocked(p0: Vector3, p1: Vector3) -> bool:
	var pos := Vector3i(floori(p0.x), floori(p0.y), floori(p0.z))
	var endp := Vector3i(floori(p1.x), floori(p1.y), floori(p1.z))
	if pos == endp:
		return false
	var d := p1 - p0
	var step := Vector3i(signi(d.x), signi(d.y), signi(d.z))
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for ai in 3:
		if d[ai] != 0.0:
			var next_boundary: float = float(pos[ai] + (1 if d[ai] > 0.0 else 0))
			t_max[ai] = (next_boundary - p0[ai]) / d[ai]
			t_delta[ai] = absf(1.0 / d[ai])
	var guard := 0
	while pos != endp and guard < 4096:
		guard += 1
		if _index.at(pos) >= 0:
			return true  # 路径中先碰到占用格（起点格外，起点在界内空腔）
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			pos.x += step.x
			t_max.x += t_delta.x
		elif t_max.y <= t_max.z:
			pos.y += step.y
			t_max.y += t_delta.y
		else:
			pos.z += step.z
			t_max.z += t_delta.z
	return false


func _is_surface(voxel_id: int) -> bool:
	var g := Vector3i(_data.positions[voxel_id])
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _index.at(g + d) < 0:
			return true
	return false


func _destroy(voxel_id: int) -> void:
	var grid := Vector3i(_data.positions[voxel_id])
	_index.remove_at(grid)
	var cid := int(_data.color_ids[voxel_id])
	_color_sets[cid].erase(voxel_id)
	_alive_count -= 1
	# 新暴露的 6 邻进入各自颜色前沿
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var nid: int = _index.at(grid + d)
		if nid >= 0:
			var ncolor := int(_data.color_ids[nid])
			if not _frontier.has(ncolor):
				_frontier[ncolor] = []
			_frontier[ncolor].append(nid)
	if _alive_count % 500 == 0:
		print("  alive=%d" % _alive_count)
