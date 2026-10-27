extends RefCounted

# CQ-20261026/S05：目标选择器——按 color_id 查询"真实可达"同色目标。
# 可达 = 以真实发射起点、弹珠半径、当前模型变换扫掠，目标为第一个命中的体素
# （与离线验证器 tools/cq_verify.gd 同一规则：FireGeometry.first_hit_is + collision_solver）。
# 性能：逐色表面前沿缓存（全 6 邻被占的内部块不可能首中，不检测）+ DDA 纯格走查预过滤，
# 幸存者才做完整扫掠确认；体素删除时增量维护前沿。

const Solver := preload("res://scripts/projectile/collision_solver.gd")
const FireGeom := preload("res://scripts/gameplay/fire_geometry.gd")

var _voxels: RefCounted      # VoxelManager
var _data: RefCounted        # VoxelData
var _radius := 0.35
var _frontier: Dictionary = {}  # color_id -> Array[voxel_id]（表面候选，可能含已删，查询时惰性剔除）
var _frontier_set: Dictionary = {}  # color_id -> Dictionary{voxel_id:true}（去重，防前沿无限膨胀）

# 结果缓存（S10 性能）：key="%d|%d,%d,%d" % [color, origin*0.5]（粗量化：
# 炮口随瞄准摆动，精确原点每发都变；粗 key 只决定命中哪条缓存，正确性由
# 实时 DDA+扫掠复核保证）。
# 热点 _last_target：上次确认目标——发射沿弹道啃进同一点是常态，目标被消后
# 其 6 邻大概率仍在同一射线上（体素只减不增、可达性单调），逐个复核即可。
# 负缓存 _target_cache：无目标结果随体素删除（gen 推进）可能翻正，按 gen 失效；
# 模型旋转改变格空间原点 → 换 key。
var _target_cache: Dictionary = {}
var _last_target: Dictionary = {}
var _scan_state: Dictionary = {}  # ckey -> {start, k, ii, gen, tver0, skipped_reserved}（时间片断点）
var _rr_cursor: Dictionary = {}   # FM/F2：color_id -> 下次全扫起始桶（持续旋转下有界轮转，防饥饿）
var _tver := 0                    # FM/F2：模型变换版本（控制器每步注入；负缓存随 gen+tver 双匹配失效）
var _sim_now := 0.0               # 2026-10-27 P4：模拟时钟（控制器每步注入；独立使用时恒 0
                                  # → TTL 永不超时，退化为 FM/F5 gen+ckey 语义，时钟域不混用）
var _step_budget_left := 6000     # P4 §6.2.6：全局每步选靶预算（覆盖所有炮/点/候选构建）
var _budget_armed := false        # begin_step() 调用后才启用全局预算（独立测试保持按次预算）
# 共享扫描几何（S10 性能）：buckets 只依赖 (color, gen)——按到模型中心距离分桶，
# 与炮口原点无关 → 同色 4 炮塔每 gen 只付一次压缩+分桶，不再每原点重建（真机
# 每原点冷建 ~10-20ms × 4 同帧叠加曾致 100ms+ 帧尖刺）。原点相关的可达性仍由
# 逐候选 DDA+扫掠实时复核保证，桶序只影响早退速度。
var _scan_geo: Dictionary = {}    # color_id -> {gen, buckets}
var _destroy_gen := 0

const NBUCKET := 24  # 距离分桶数（替代 lambda 排序：近者优先只影响早退速度）

var scan_budget_us := 3000  # 单次 find_target 时间片预算（测试可注入小值验证断点续扫）
var step_budget_us := 6000  # P4：每物理步全部炮台共享的选靶预算（begin_step 重置）
var dbg_neg_served := 0     # 测试观测：负缓存命中次数

# 2026-10-27 P4 §6.3：负缓存有界失效——几何（gen+tver）精确匹配长期服务；
# 旋转中（tver 每步变）只做 TTL≤100ms 的短暂退避，原点格驻留期内也不永久封锁。
const NEG_TTL_SEC := 0.1

# 暴露面位掩码（S10 性能预过滤）：bit i = DIRS6[i] 方向面暴露（邻格空）。
# 首中必经暴露面 ⇒ 原点必须在该面外侧半空间（dot(origin-center, n) > 阈值），
# 否则便宜剔除（把 DDA 留给少数朝向原点的候选）。删除体素时邻居增量补面。
var _face_mask := PackedByteArray()

const DIRS6 := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const DIRV6 := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
	Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_PLANE_MARGIN := 0.4  # 面半空间阈值（留 0.1 余量，宁多勿漏，扫掠兜底）


func setup(voxel_manager: RefCounted, ball_radius: float = 0.35) -> void:
	_voxels = voxel_manager
	_data = voxel_manager.data
	_radius = ball_radius
	_rebuild_frontier()


# FM/F2：控制器每物理步注入模型变换版本——持续旋转期间负缓存永不服务，
# 扫描实时复核；同一 tver 内完整扫完才允许写负缓存（见 find_target 尾部）。
func set_transform_version(tver: int) -> void:
	_tver = tver


# 2026-10-27 P4 §6.3：模拟时钟注入（负缓存 TTL 用模拟秒，headless 快进不受墙钟影响）
func set_clock(sim_now: float) -> void:
	_sim_now = sim_now


func _now() -> float:
	return _sim_now


# P4 §6.2.6：全局预算——每物理步一次（控制器 step 顶部调用），覆盖本步所有炮台的
# 扫描切片；独立使用（单元测试不调用）时按次预算、行为与旧版一致。
func begin_step() -> void:
	_step_budget_left = step_budget_us
	_budget_armed = true


func _rebuild_frontier() -> void:
	_frontier.clear()
	_frontier_set.clear()
	_face_mask = PackedByteArray()
	_face_mask.resize(_data.count)
	for i in _data.count:
		if not _voxels.is_alive(i):
			continue
		var g := Vector3i(_data.positions[i])
		var mask := 0
		for fi in 6:
			if _voxels.index.at(g + DIRS6[fi]) < 0:
				mask |= 1 << fi
		_face_mask[i] = mask
		if mask != 0:
			var cid := int(_data.color_ids[i])
			if not _frontier.has(cid):
				_frontier[cid] = []
				_frontier_set[cid] = {}
			_frontier[cid].append(i)
			_frontier_set[cid][i] = true


func _is_surface(voxel_id: int) -> bool:
	var g := Vector3i(_data.positions[voxel_id])
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _voxels.index.at(g + d) < 0:
			return true
	return false


# 体素删除后增量维护：新暴露的 6 邻补面并进入各自颜色前沿（去重防膨胀）
func on_voxel_destroyed(voxel_id: int) -> void:
	_destroy_gen += 1
	var g := Vector3i(_data.positions[voxel_id])
	for fi in 6:
		var nid: int = _voxels.index.at(g + DIRS6[fi])
		if nid < 0:
			continue
		_face_mask[nid] = _face_mask[nid] | (1 << (fi ^ 1))  # 邻居朝本格的面暴露
		var ncolor := int(_data.color_ids[nid])
		if not _frontier.has(ncolor):
			_frontier[ncolor] = []
			_frontier_set[ncolor] = {}
		if not _frontier_set[ncolor].has(nid):
			_frontier_set[ncolor][nid] = true
			_frontier[ncolor].append(nid)


# 找 color_id 的可达目标（排除已预订）。返回 {ok, voxel_id, target_grid_center} 或 {ok:false, reason}
# S10 性能：负缓存 O(1) → 热点邻域复核（≤7 次 DDA+扫掠）→ 全扫描兜底。
func find_target(color_id: int, origin_grid: Vector3, is_available: Callable) -> Dictionary:
	# FM/F2：ckey 用 floori（截断对负坐标不对称，会错位缓存桶）
	var ckey := "%d|%d,%d,%d" % [color_id, floori(origin_grid.x * 0.5),
		floori(origin_grid.y * 0.5), floori(origin_grid.z * 0.5)]
	var cached: Dictionary = _target_cache.get(ckey, {})
	# FM/F5 节奏 + P4 §6.3 有界失效：负缓存要求 gen 匹配，且（tver 精确匹配＝几何未变，
	# 长期服务）或（TTL≤100ms 短暂退避——持续旋转下同原点格内目标变可达不永久封锁，UX11）。
	# ckey 把世界固定原点量化到 2 格网格，原点跨格自然换新 key 重扫；错发不可能
	# （任何肯定结论都由实时 DDA+扫掠复核产出），滞后仅表现为短暂等待。
	if bool(cached.get("neg", false)) and int(cached.get("gen", -1)) == _destroy_gen:
		var age := _now() - float(cached.get("sim_t", -1.0e9))
		if int(cached.get("tver", -1)) == _tver \
				or (age >= 0.0 and age <= NEG_TTL_SEC):
			dbg_neg_served += 1
			return {"ok": false, "reason": "no_reachable_target"}  # 缓存的否定结果
	# 热点复核：上次目标（可能已被自己打掉）+ 其 6 邻同色存活块（多点确认，P4 §6.2）
	var hot := int(_last_target.get(ckey, -1))
	if hot >= 0 and hot < _data.count:
		var tries: Array = [hot]
		var g := Vector3i(_data.positions[hot])
		for d in DIRS6:
			var nid: int = _voxels.index.at(g + d)
			if nid >= 0 and int(_data.color_ids[nid]) == color_id:
				tries.append(nid)
		for vid in tries:
			if not is_available.call(vid):
				continue
			var hc: Dictionary = confirm_reachable_mp(vid, origin_grid)
			if hc.get("ok", false):
				_last_target[ckey] = vid
				return {"ok": true, "voxel_id": vid,
					"target_grid_center": _data.positions[vid] + Vector3(0.5, 0.5, 0.5),
					"aim_grid_point": hc.aim_grid_point, "face_id": int(hc.face_id),
					"origin_used": origin_grid, "geometry_version": _destroy_gen}
	var cand_list: Array = _frontier.get(color_id, [])
	if cand_list.is_empty():
		_target_cache[ckey] = {"neg": true, "gen": _destroy_gen, "tver": _tver, "sim_t": _now()}
		return {"ok": false, "reason": "no_alive_color"}
	# 全扫描兜底：时间片 ≤3ms/次（S10：单帧预算保护）。断点续扫状态按 (key,gen) 保存，
	# 体素删除推进 gen 后作废重扫；预订变化不推进 gen，恢复扫描时实时复查。
	# FM/F2 §5.3：scan_pending = 本次未扫完，调度器下一物理步立即续扫（冷却 0）。
	# FM/F2 §11.3：起始桶按色轮转（_rr_cursor），持续旋转下不全从桶0重扫、防饥饿。
	var st: Dictionary = _scan_state.get(ckey, {})
	if st.is_empty() or int(st.get("gen", -1)) != _destroy_gen:
		# FM/F5：续扫状态锚定开扫原点（origin0/ckey0）——旋转中逐片换原点会产生
		# "各片只测过当片原点"的混合否定，缓存后成真否定封锁（实测吞吐反降）。
		st = {"start": int(_rr_cursor.get(color_id, 0)), "k": 0, "ii": 0,
			"gen": _destroy_gen, "tver0": _tver, "skipped_reserved": false,
			"origin0": origin_grid, "ckey0": ckey}
	# 共享几何：按 (color, gen) 懒重建一次，同色多炮塔复用
	var geo: Dictionary = _scan_geo.get(color_id, {})
	if geo.is_empty() or int(geo.get("gen", -1)) != _destroy_gen:
		# 压缩前沿：剔除已删除，重建去重集合；到模型中心距离²分桶（顺序只影响早退速度）
		var center: Vector3 = (_data.bounds_min + _data.bounds_max) * 0.5
		var alive_frontier: Array = []
		var rebuilt_set := {}
		var max_d2 := 0.0
		for vid in cand_list:
			if _voxels.is_alive(int(vid)):
				alive_frontier.append(vid)
				rebuilt_set[vid] = true
				var d2: float = _data.positions[vid].distance_squared_to(center)
				if d2 > max_d2:
					max_d2 = d2
		_frontier[color_id] = alive_frontier
		_frontier_set[color_id] = rebuilt_set
		var bucket_w := maxf(max_d2 / float(NBUCKET), 0.001)
		var buckets_new: Array = []
		buckets_new.resize(NBUCKET)
		for vid in alive_frontier:
			var b := mini(int(_data.positions[vid].distance_squared_to(center) / bucket_w),
				NBUCKET - 1)
			if buckets_new[b] == null:
				buckets_new[b] = []
			(buckets_new[b] as Array).append(vid)
		geo = {"gen": _destroy_gen, "buckets": buckets_new}
		_scan_geo[color_id] = geo
	var _slice_t0 := Time.get_ticks_usec()
	var scan_origin: Vector3 = st.origin0  # FM/F5：整次扫描锚定开扫原点（跨片不漂）
	var buckets: Array = geo.buckets
	# FM/F2 断点语义：{start=轮转起始桶, k=已扫桶数, ii=当前桶内下一索引}——
	# 整桶扫完才推 k（旧实现预增 bi，续扫时跳过半扫桶的剩余候选 = §2.1 漏扫）
	while st.k < NBUCKET:
		var bi: int = (int(st.start) + int(st.k)) % NBUCKET
		var bucket = buckets[bi]
		if bucket == null:
			st.k = int(st.k) + 1
			st.ii = 0
			continue
		var ii: int = st.ii
		var n: int = (bucket as Array).size()
		while ii < n:
			# FM/F2：预算检查在内层每次迭代顶部——三条 continue 路径与扫掠都受控
			# P4 §6.2.6：全局步预算（begin_step 重置）——所有炮台共享，防每炮 3ms 叠加
			if Time.get_ticks_usec() - _slice_t0 > scan_budget_us \
					or (_budget_armed and _step_budget_left <= 0):
				st.ii = ii
				_scan_state[ckey] = st
				_step_budget_left -= int(Time.get_ticks_usec() - _slice_t0)
				_prune_caches()
				return {"ok": false, "reason": "scan_pending"}
			var vid: int = bucket[ii]
			ii += 1
			if not is_available.call(vid):
				st.skipped_reserved = true
				continue  # 已预订，跳过（防重复命中）
			var center: Vector3 = _data.positions[vid] + Vector3(0.5, 0.5, 0.5)
			# 首中必经暴露面 ⇒ 原点须在某一暴露面外侧半空间，否则便宜剔除
			var rel := scan_origin - center
			var mask := int(_face_mask[vid])
			var facing := false
			for fi in 6:
				if mask & (1 << fi) and rel.dot(DIRV6[fi]) > FACE_PLANE_MARGIN:
					facing = true
					break
			if not facing:
				continue
			# P4 §6.2：先试中心（DDA 预过滤+完整扫掠）；失败再对朝向原点的暴露面
			# 采样 5 点（面中心+0.2/0.8 内缩角）——面点射线落格与中心不同，但瞄点
			# 在目标块内（向块内偏 0.06），DDA 终点=目标格不会误伤自身/邻格，仍有效。
			var aim := Vector3.ZERO
			var face_id := -1
			var confirmed := false
			if not _los_blocked(scan_origin, center):
				var cands0: Array = _voxels.sweep_candidates(scan_origin, center, _radius)
				var hit0: Dictionary = Solver.sweep(scan_origin, center, _radius, cands0,
					func(id: int) -> Vector3: return _data.positions[id])
				if bool(hit0.get("hit", false)) and int(hit0.get("voxel_id", -1)) == vid:
					aim = center
					confirmed = true
			if not confirmed:
				var mp: Dictionary = _confirm_face_points(vid, scan_origin)
				if mp.get("ok", false):
					aim = mp.aim_grid_point
					face_id = int(mp.face_id)
					confirmed = true
			if confirmed:
				_last_target[ckey] = vid
				_scan_state.erase(ckey)
				_rr_cursor[color_id] = (bi + 1) % NBUCKET  # 下次从本桶之后开始
				_step_budget_left -= int(Time.get_ticks_usec() - _slice_t0)
				_prune_caches()
				return {"ok": true, "voxel_id": vid, "target_grid_center": center,
					"aim_grid_point": aim, "face_id": face_id,
					"origin_used": scan_origin, "geometry_version": _destroy_gen}
		st.k = int(st.k) + 1
		st.ii = 0
	# 扫完无目标：有候选因预订被跳过时不缓存否定（预订释放可能翻正，预订不推进 gen）。
	# 否定结论带 gen+tver+写入时刻：几何不变（tver 匹配）长期服务；旋转中 TTL≤100ms
	# 短暂退避（P4 §6.3），同原点格内目标变可达不永久封锁。
	_scan_state.erase(ckey)
	_rr_cursor[color_id] = (int(st.start) + 1) % NBUCKET
	if not bool(st.skipped_reserved):
		_target_cache[st.ckey0] = {"neg": true, "gen": _destroy_gen, "tver": _tver, "sim_t": _now()}
	_step_budget_left -= int(Time.get_ticks_usec() - _slice_t0)
	_prune_caches()
	return {"ok": false, "reason": "no_reachable_target"}


# FM/F2：缓存有界裁剪——原点量化 key 随旋转漂移会无限累积，超限整体清空重建
const CACHE_MAX := 256


func _prune_caches() -> void:
	if _target_cache.size() > CACHE_MAX:
		_target_cache.clear()
	if _last_target.size() > CACHE_MAX:
		_last_target.clear()
	if _scan_state.size() > CACHE_MAX:
		_scan_state.clear()


# CQ/S08：屏幕点选体素（指定目标 UI）——格空间射线小半径扫掠首个存活体素
func pick_voxel(from_grid: Vector3, dir_grid: Vector3, max_dist: float) -> int:
	var p1 := from_grid + dir_grid * max_dist
	var cands: Array = _voxels.sweep_candidates(from_grid, p1, 0.1)
	var hit: Dictionary = Solver.sweep(from_grid, p1, 0.1, cands,
		func(id: int) -> Vector3: return _data.positions[id])
	return int(hit.get("voxel_id", -1)) if bool(hit.get("hit", false)) else -1


# CQ/S08 §2.4：指定目标可达性确认——与正常选靶同一扫掠契约（目标必须首个命中）
func confirm_reachable(voxel_id: int, origin_grid: Vector3) -> bool:
	return confirm_reachable_mp(voxel_id, origin_grid).get("ok", false)


# 2026-10-27 P4 §6.2 多点确认（指定目标与普通自动选靶同一接口，标准一致）：
# 先试体素中心；中心被挡则对朝向原点的暴露面采样 5 点（面中心 + 0.2/0.8 内缩角），
# 瞄点向块内偏移 0.06 格（保证扫掠穿过目标扩张盒表面，不停在浮点边界）。
# 返回 {ok, aim_grid_point, face_id}（face_id=-1 表示中心瞄点）；所有点都以真实球半径
# 完整扫掠，只有 first_hit==目标才接受（不穿透异色/邻块，无合法点则不发射）。
func confirm_reachable_mp(voxel_id: int, origin_grid: Vector3) -> Dictionary:
	if not _voxels.is_alive(voxel_id):
		return {"ok": false}
	var center: Vector3 = _data.positions[voxel_id] + Vector3(0.5, 0.5, 0.5)
	if not _los_blocked(origin_grid, center):
		var cands: Array = _voxels.sweep_candidates(origin_grid, center, _radius)
		var hit: Dictionary = Solver.sweep(origin_grid, center, _radius, cands,
			func(id: int) -> Vector3: return _data.positions[id])
		if bool(hit.get("hit", false)) and int(hit.get("voxel_id", -1)) == voxel_id:
			return {"ok": true, "aim_grid_point": center, "face_id": -1}
	return _confirm_face_points(voxel_id, origin_grid)


# 面采样（P4 §6.2.2）：每暴露面 5 点，面内 UV 取 0.2/0.5/0.8（避开数学边缘）；
# 只试朝向原点的面（原点在该面外侧半空间），每点 DDA 预过滤 + 完整扫掠确认。
const AIM_INSET := 0.06  # 瞄点向块内偏移（格）
const FACE_UV := [0.2, 0.5, 0.8]


func _confirm_face_points(voxel_id: int, origin_grid: Vector3) -> Dictionary:
	var center: Vector3 = _data.positions[voxel_id] + Vector3(0.5, 0.5, 0.5)
	var rel := origin_grid - center
	var mask := int(_face_mask[voxel_id])
	for fi in 6:
		if not (mask & (1 << fi)):
			continue
		var n: Vector3 = DIRV6[fi]
		if rel.dot(n) <= 0.2:  # 原点须在该面外侧（宽松阈值，扫掠兜底正确性）
			continue
		# 面内两轴 = 法向为零的两轴
		var a1 := 0
		var a2 := 1
		if n.x != 0.0:
			a1 = 1
			a2 = 2
		elif n.y != 0.0:
			a1 = 0
			a2 = 2
		for u in FACE_UV:
			for v in FACE_UV:
				if (u != 0.5 or v != 0.5) and (u == 0.5 or v == 0.5):
					continue  # 面中心 + 四角内缩（跳过边中点，每面 5 点）
				var p := center + n * (0.5 - AIM_INSET)
				p[a1] += u - 0.5
				p[a2] += v - 0.5
				if _los_blocked(origin_grid, p):
					continue
				var cands: Array = _voxels.sweep_candidates(origin_grid, p, _radius)
				var hit: Dictionary = Solver.sweep(origin_grid, p, _radius, cands,
					func(id: int) -> Vector3: return _data.positions[id])
				if bool(hit.get("hit", false)) and int(hit.get("voxel_id", -1)) == voxel_id:
					return {"ok": true, "aim_grid_point": p, "face_id": fi}
	return {"ok": false}


# P4 §6.3 最终复核：分片扫描的成功候选可能锚定旧原点（origin0），发射前必须用
# 本次真实炮口对同一 aim_grid_point 复核——失败则不扣弹不发射（继续找目标）。
func confirm_aim(voxel_id: int, aim_grid_point: Vector3, origin_grid: Vector3) -> bool:
	if not _voxels.is_alive(voxel_id):
		return false
	if _los_blocked(origin_grid, aim_grid_point):
		return false
	var cands: Array = _voxels.sweep_candidates(origin_grid, aim_grid_point, _radius)
	var hit: Dictionary = Solver.sweep(origin_grid, aim_grid_point, _radius, cands,
		func(id: int) -> Vector3: return _data.positions[id])
	return bool(hit.get("hit", false)) and int(hit.get("voxel_id", -1)) == voxel_id


func alive_candidate_count(color_id: int) -> int:
	var n := 0
	for vid in _frontier.get(color_id, []):
		if _voxels.is_alive(int(vid)):
			n += 1
	return n


# 便宜否定：DDA 走过 origin→target 的格子序列，目标格之前若有任何存活占用格，则必被先命中
func _los_blocked(p0: Vector3, p1: Vector3) -> bool:
	var pos := Vector3i(floori(p0.x), floori(p0.y), floori(p0.z))
	var endp := Vector3i(floori(p1.x), floori(p1.y), floori(p1.z))
	if pos == endp:
		return false
	var d := p1 - p0
	var step := Vector3i(int(signf(d.x)), int(signf(d.y)), int(signf(d.z)))
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
		if _voxels.index.at(pos) >= 0:
			return true
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
