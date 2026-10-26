extends SceneTree

# P3-03 弹珠物理自测：反射公式/连续扫掠防穿透/出界一次/旋转模型碰撞
# 运行：godot --headless --path . -s tests/integration/test_ball.gd

var _failures := 0


func _initialize() -> void:
	var solver := preload("res://scripts/projectile/collision_solver.gd")

	# 无损反射公式夹具
	var v := solver.reflect(Vector3(-12, 0, 0), Vector3(1, 0, 0))
	_check(v == Vector3(12, 0, 0), "反射 v-2(v·n)n", str(v))
	var v2 := solver.reflect(Vector3(1, -1, 0), Vector3(0, 1, 0))
	_check(v2.is_equal_approx(Vector3(1, 1, 0)), "斜入射反射", str(v2))

	# 构造 10x10 竖墙（x=0 平面），格坐标 (0, y, z)
	var wall := {}
	for y in 10:
		for z in 10:
			wall[y * 100 + z] = Vector3(0, y, z)
	var grid_pos_of := func(id: int) -> Vector3: return wall[id]
	var index_script := preload("res://scripts/voxel/voxel_spatial_index.gd")
	var idx := index_script.new()
	# 手工喂索引：利用 manager 过重，直接构造 candidates 用 DDA
	var data := {"count": wall.size()}
	var cells := {}
	for id in wall:
		cells[index_script.pack_v(Vector3i(wall[id]))] = id  # CQ/S10：索引键为打包 int
	idx._cell = cells

	var candidates_of := func(p0: Vector3, p1: Vector3, r: float) -> Array:
		return idx.candidates_along_segment(p0, p1, r)

	# 命中与法线：从 (5,5,5) 朝 -x 射向墙
	var hit: Dictionary = solver.sweep(Vector3(5, 5.5, 5.5), Vector3(-5, 5.5, 5.5), 0.35,
		candidates_of.call(Vector3(5, 5.5, 5.5), Vector3(-5, 5.5, 5.5), 0.35), grid_pos_of)
	_check(hit.hit and is_equal_approx(hit.point.x, 1.35) and hit.normal == Vector3(1, 0, 0),
		"墙面命中点/法线", str(hit))

	# 防穿透：大步长（速度12*步长0.5s=6单位）跨过墙仍命中
	var ps := preload("res://scripts/projectile/projectile_system.gd").new()
	ps.radius = 0.35
	ps.boundary_center = Vector3(5, 5, 5)
	ps.boundary_half = 100.0
	var bid: int = ps.spawn_local(Vector3(5, 5.5, 5.5), Vector3(-1, 0, 0), 12.0, 1)
	var res: RefCounted = ps.step(0.5, Transform3D.IDENTITY, candidates_of, grid_pos_of)
	_check(res.hits.size() == 1, "大步长不穿透(命中1次)", str(res.hits))
	var b: Dictionary = ps.ball_snapshot(bid)
	_check(b.vel.x > 0, "反弹后速度反向", str(b.vel))

	# 出界只结束一次
	var ps2 := preload("res://scripts/projectile/projectile_system.gd").new()
	ps2.radius = 0.35
	ps2.boundary_center = Vector3.ZERO
	ps2.boundary_half = 5.0
	var bid2: int = ps2.spawn_local(Vector3(0, 0, 0), Vector3(1, 0, 0), 60.0, 2)
	var ended_total := 0
	for i in 10:
		var r2: RefCounted = ps2.step(0.1, Transform3D.IDENTITY, candidates_of, grid_pos_of)
		ended_total += r2.ended.size()
	_check(ended_total == 1, "出界只提交一次", "ended=%d" % ended_total)

	# FM §4 局部锁定弹道：飞行途中模型变换改变（旋转90°），球仍沿局部轨迹命中同一面墙；
	# 事件点/法线为格空间，世界投影由门面按本步变换完成。
	var rot := Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	var ps3 := preload("res://scripts/projectile/projectile_system.gd").new()
	ps3.radius = 0.35
	ps3.boundary_center = Vector3(5, 5, 5)
	ps3.boundary_half = 100.0
	var bid3: int = ps3.spawn_local(Vector3(5, 5.5, 5.5), Vector3(-1, 0, 0), 12.0, 3)
	ps3.step(0.1, Transform3D.IDENTITY, candidates_of, grid_pos_of)  # 先以 Identity 飞一段
	var res3: RefCounted = ps3.step(0.5, rot, candidates_of, grid_pos_of)  # 中途换成旋转90°变换
	_check(res3.hits.size() == 1, "飞行中变换切换仍命中（局部锁定）", str(res3.hits))
	if res3.hits.size() == 1:
		_check(res3.hits[0].normal == Vector3(1, 0, 0), "命中法线为格空间（+x墙法线）",
			str(res3.hits[0].normal))
		# 快照世界投影用本步变换：反弹点在格空间 x≈1.35+ε
		var snap3: Dictionary = ps3.ball_snapshot(bid3)
		var expect_w: Vector3 = rot * (snap3.local_pos as Vector3)
		_check((snap3.pos as Vector3).is_equal_approx(expect_w), "快照世界位置=本步变换×局部坐标",
			"%s vs %s" % [str(snap3.pos), str(expect_w)])

	# FM/F1 回归：DDA signi 浮点截断缺陷——步长分量全 <1 时 step=(0,0,0) 空转，
	# 候选只剩起点格邻域，球进入目标格扩张盒却漏扫（mismatch 退款风暴根源）。
	# 夹具：起点贴近格边界、步长 0.667（speed40×1/60）、目标在终点格上方邻格。
	var idx2 := index_script.new()
	idx2._cell[index_script.pack_v(Vector3i(10, 4, 8))] = 1180
	idx2._cell[index_script.pack_v(Vector3i(10, 2, 8))] = 2000  # 起点格占位（无关体素）
	var seg_p0 := Vector3(10.81827, 2.999588, 8.5)
	var seg_p1 := Vector3(10.67993, 3.651744, 8.5)  # 终点已进入 (10,4,8) 半径0.35扩张盒
	var cands2: Array = idx2.candidates_along_segment(seg_p0, seg_p1, 0.35)
	_check(cands2.has(1180), "亚单位步长候选含终点邻格体素", str(cands2))
	var hit2: Dictionary = solver.sweep(seg_p0, seg_p1, 0.35, cands2,
		func(id: int) -> Vector3: return Vector3(10, 4, 8) if id == 1180 else Vector3(10, 2, 8))
	_check(hit2.hit and int(hit2.voxel_id) == 1180, "进入扩张盒的那一步即命中", str(hit2))

	if _failures == 0:
		print("TEST_PASS test_ball")
	else:
		print("TEST_FAIL test_ball failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
