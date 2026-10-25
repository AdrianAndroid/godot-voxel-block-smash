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
		cells[Vector3i(wall[id])] = id
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
	var bid: int = ps.spawn(Vector3(5, 5.5, 5.5), Vector3(-12, 0, 0), 1)
	var res: RefCounted = ps.step(0.5, Transform3D.IDENTITY, candidates_of, grid_pos_of)
	_check(res.hits.size() == 1, "大步长不穿透(命中1次)", str(res.hits))
	var b: Dictionary = ps.ball_snapshot(bid)
	_check(b.vel.x > 0, "反弹后速度反向", str(b.vel))

	# 出界只结束一次
	var ps2 := preload("res://scripts/projectile/projectile_system.gd").new()
	ps2.radius = 0.35
	ps2.boundary_center = Vector3.ZERO
	ps2.boundary_half = 5.0
	var bid2: int = ps2.spawn(Vector3(0, 0, 0), Vector3(60, 0, 0), 2)
	var ended_total := 0
	for i in 10:
		var r2: RefCounted = ps2.step(0.1, Transform3D.IDENTITY, candidates_of, grid_pos_of)
		ended_total += r2.ended.size()
	_check(ended_total == 1, "出界只提交一次", "ended=%d" % ended_total)

	# 旋转模型：格空间绕Y转90°，世界球朝 -z 飞（对应格空间 -x 方向墙）
	var rot := Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
	var ps3 := preload("res://scripts/projectile/projectile_system.gd").new()
	ps3.radius = 0.35
	ps3.boundary_center = Vector3(5, 5, 5)
	ps3.boundary_half = 100.0
	var world_pos: Vector3 = rot * Vector3(5, 5.5, 5.5)
	var world_vel: Vector3 = rot.basis * Vector3(-12, 0, 0)
	var bid3: int = ps3.spawn(world_pos, world_vel, 3)
	var res3: RefCounted = ps3.step(0.5, rot, candidates_of, grid_pos_of)
	_check(res3.hits.size() == 1, "旋转模型下命中", str(res3.hits))
	if res3.hits.size() == 1:
		var wn: Vector3 = res3.hits[0].normal
		_check(wn.is_equal_approx((rot.basis * Vector3(1, 0, 0)).normalized()), "旋转后世界法线正确", str(wn))

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
