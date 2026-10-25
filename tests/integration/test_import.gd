extends SceneTree

# T01 导入分支自测（阶段2 P2-03）：合法/非法模型加载、单 MultiMesh、颜色映射、轴向夹具
# 运行：godot --headless --path . -s tests/integration/test_import.gd

var _failures := 0


func _initialize() -> void:
	var loader := preload("res://scripts/data/voxel_loader.gd")
	var renderer_script := preload("res://scripts/voxel/voxel_renderer.gd")

	# 合法模型
	var r300: Dictionary = loader.load_from_json("res://tests/fixtures/model_300.json")
	_check(r300.ok, "model_300 加载成功", "model_300 拒绝: " + str(r300.error))
	if r300.ok:
		_check(r300.data.count == 300, "model_300 存活数=300", "实际 %d" % r300.data.count)
	var r1200: Dictionary = loader.load_from_json("res://tests/fixtures/model_1200.json")
	_check(r1200.ok and r1200.data.count == 1200, "model_1200 存活数=1200", str(r1200))

	# 非法模型拒绝且定位字段
	var r_dup: Dictionary = loader.load_from_json("res://tests/fixtures/bad_dup.json")
	_check(not r_dup.ok and "重复坐标" in r_dup.error and "voxels[" in r_dup.error,
		"重复坐标拒绝并定位字段", str(r_dup))
	var r_color: Dictionary = loader.load_from_json("res://tests/fixtures/bad_color.json")
	_check(not r_color.ok and "color_id" in r_color.error, "非法色拒绝: " + str(r_color.error), "")
	var r_count: Dictionary = loader.load_from_json("res://tests/fixtures/bad_count.json")
	_check(not r_count.ok and "数量" in r_count.error, "非法数量拒绝: " + str(r_count.error), "")
	var r_schema: Dictionary = loader.load_from_json("res://tests/fixtures/bad_schema.json")
	_check(not r_schema.ok and "schema_version" in r_schema.error, "非法schema拒绝: " + str(r_schema.error), "")

	# 正式青蛙模型
	var r_frog: Dictionary = loader.load_from_json("res://assets/models/json/frog_01.json")
	_check(r_frog.ok and r_frog.data.count == 367, "frog_01 存活数=367", str(r_frog))

	# 渲染：单 MultiMesh、实例数=存活数、颜色一致、无逐块节点
	if r_frog.ok:
		var renderer: RefCounted = renderer_script.new()
		var node: MultiMeshInstance3D = renderer.build(r_frog.data)
		_check(node is MultiMeshInstance3D, "单 MultiMeshInstance3D", "")
		_check(renderer.instance_count() == 367, "实例数=存活数", "实际 %d" % renderer.instance_count())
		_check(node.get_child_count() == 0, "无逐块子节点", "子节点 %d" % node.get_child_count())
		var mm: MultiMesh = node.multimesh
		var mm_ok := true
		for i in 367:
			var expect: Color = r_frog.data.palette[r_frog.data.color_ids[i]]
			# headless dummy 渲染器不回读 MultiMesh 缓冲，以渲染器 CPU 镜像为断言对象；
			# GPU 缓冲一致性在桌面/模拟器轮次验证（记录于 test-report）
			if renderer.mirror_colors[i] != expect or renderer.mirror_transforms[i].origin != r_frog.data.grid_to_local(i):
				mm_ok = false
				break
		_check(mm_ok, "逐实例颜色/位置镜像与 palette 一致", "")
		node.free()

	# 轴向夹具：vox(x,y,z) -> godot(x,z,-y)，居中后验证
	var r_axis: Dictionary = loader.load_from_json("res://tests/fixtures/axis_fixture.json", false)
	var axis_ok := false
	if r_axis.ok:
		# 夹具 godot 格坐标: 绿(0,0,0) 红(3,0,0) 蓝(0,0,-4)+归一=(0,0,0) 黄(0,5,0)
		# 归一(min->0)后: 绿(0,0,4) 红(3,0,4) 蓝(0,0,0) 黄(0,5,4)
		var want := {Vector3i(0, 0, 4): 1, Vector3i(3, 0, 4): 2, Vector3i(0, 0, 0): 3, Vector3i(0, 5, 4): 4}
		axis_ok = r_axis.data.count == 4
		for i in 4:
			var p := Vector3i(r_axis.data.positions[i])
			if not want.has(p) or want[p] != r_axis.data.color_ids[i]:
				axis_ok = false
	_check(axis_ok, "轴向夹具映射 godot=(vox.x, vox.z, -vox.y) 且颜色正确", str(r_axis))

	if _failures == 0:
		print("TEST_PASS test_import")
	else:
		print("TEST_FAIL test_import failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
