extends SceneTree

# 调试：OFF27 偏移加法正确性（含负坐标，球从界外起飞经过负格）+ 几何暴力候选校验
const VoxelLoader := preload("res://scripts/data/voxel_loader.gd")
const SpatialIndex := preload("res://scripts/voxel/voxel_spatial_index.gd")

func _seg_hits_aabb(a: Vector3, b: Vector3, g: Vector3, r: float) -> bool:
	var n := 64
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var c := Vector3(clampf(p.x, g.x, g.x + 1.0), clampf(p.y, g.y, g.y + 1.0),
			clampf(p.z, g.z, g.z + 1.0))
		if p.distance_to(c) < r - 0.01:
			return true
	return false

func _init() -> void:
	var res: Dictionary = VoxelLoader.load_from_json("res://assets/models/json/frog_02.json")
	var data: RefCounted = res.data
	var idx: RefCounted = SpatialIndex.new()
	idx.build(data)

	# 1) OFF27：坐标范围 [-40, 40] 全量验证
	var off27: Array = SpatialIndex.OFF27
	var bad := 0
	var k := 0
	for dz in [-1, 0, 1]:  # OFF27 表序：dz 外层、dy 中层、dx 内层
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var off: int = off27[k]
				k += 1
				for gx in range(-40, 41):
					for gy in range(-40, 41):
						for gz in range(-40, 41):
							var want: int = SpatialIndex.pack(gx + dx, gy + dy, gz + dz)
							var got: int = SpatialIndex.pack(gx, gy, gz) + off
							if want != got:
								bad += 1
								if bad <= 5:
									print("OFF_BAD g=(%d,%d,%d) d=(%d,%d,%d)" % [gx, gy, gz, dx, dy, dz])
	print("off_bad=%d" % bad)

	# 2) at() 全命中
	var miss := 0
	for i in data.count:
		if idx.at(Vector3i(data.positions[i])) != i:
			miss += 1
	print("at_miss=%d" % miss)

	# 3) 几何暴力：从界外（含负坐标原点）射向体素中心
	var radius := 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cmiss := 0
	var total_expected := 0
	for t in 300:
		var b: Vector3 = data.positions[rng.randi_range(0, data.count - 1)] + Vector3(0.5, 0.5, 0.5)
		var a := b + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1),
			rng.randf_range(-1, 1)).normalized() * 30.0  # 界外起点
		var got: Array = idx.candidates_along_segment(a, b, radius)
		var got_set := {}
		for id in got:
			got_set[id] = true
		for i in data.count:
			var gp: Vector3 = data.positions[i]
			if absf(gp.x - (a.x + b.x) * 0.5) > absf(b.x - a.x) * 0.5 + 3.0:
				continue
			if _seg_hits_aabb(a, b, gp, radius):
				total_expected += 1
				if not got_set.has(i):
					cmiss += 1
					if cmiss <= 5:
						print("CAND_MISS seg=%s->%s voxel=%d pos=%s" % [str(a), str(b), i, str(gp)])
	print("expected=%d cand_missing=%d" % [total_expected, cmiss])
	quit(0 if bad == 0 and miss == 0 and cmiss == 0 else 1)
