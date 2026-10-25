extends SceneTree

# P3-01 体素管理自测：存活集/重复删除/索引剔除/尾交换映射一致性
# 运行：godot --headless --path . -s tests/unit/test_voxel.gd

var _failures := 0


func _initialize() -> void:
	var loader := preload("res://scripts/data/voxel_loader.gd")
	var manager_script := preload("res://scripts/voxel/voxel_manager.gd")
	var r: Dictionary = loader.load_from_json("res://tests/fixtures/axis_fixture.json", false)
	_check(r.ok, "夹具加载", str(r))
	var m: RefCounted = manager_script.new()
	var node: Node3D = m.build(r.data)
	_check(m.alive_count() == 4, "存活=4", "%d" % m.alive_count())

	# 重复删除拒绝
	_check(m.destroy(1).ok, "首次删除 voxel 1", "")
	_check(not m.destroy(1).ok, "重复删除拒绝", "")
	_check(m.alive_count() == 3, "存活=3", "%d" % m.alive_count())
	_check(m.renderer.instance_count() == 3, "渲染实例数=存活数", "%d" % m.renderer.instance_count())

	# 已删块不再被候选查询返回
	var grid: Vector3i = r.data.positions[1]
	_check(m.index.at(grid) == -1, "索引已剔除", "")

	# 尾交换映射一致：每个存活 id 双向映射吻合，且位置/颜色与数据一致
	var map_ok := true
	for id in m.state.alive_ids():
		var slot: int = m.renderer.slot_of.get(id, -1)
		if slot < 0 or m.renderer.voxel_of[slot] != id:
			map_ok = false
		if m.renderer.mirror_transforms[slot].origin != r.data.grid_to_local(id):
			map_ok = false
	_check(map_ok, "交换删除后 voxel_id↔slot 双向映射与位置一致", "")

	# 候选查询包含命中路径上的存活块、排除已删块
	var cands: Array = m.sweep_candidates(Vector3(0.5, 5.5, 4.5), Vector3(3.5, 5.5, 4.5), 0.3)
	_check(1 not in cands, "候选不含已删块", str(cands))

	if _failures == 0:
		print("TEST_PASS test_voxel")
	else:
		print("TEST_FAIL test_voxel failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
