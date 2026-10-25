extends RefCounted

# 局部网格空间索引（架构 v6：Vector3i格 -> voxel_id；已删块不再被候选查询返回）
# 阶段：阶段3。坐标为模型局部格坐标（voxel_size=1 的格空间）

var _cell: Dictionary = {}  # Vector3i -> voxel_id


func build(data: RefCounted) -> void:
	_cell.clear()
	for i in data.count:
		_cell[Vector3i(data.positions[i])] = i


func remove_at(pos: Vector3i) -> void:
	_cell.erase(pos)


func at(pos: Vector3i) -> int:
	return _cell.get(pos, -1)


func candidates_along_segment(p0: Vector3, p1: Vector3, radius: float) -> Array:
	# 宽相：线段 DDA 经过的格 + 半径邻域内的已占用格，返回 voxel_id 数组（去重）
	var found := {}
	var cells := _dda_cells(p0, p1)
	var grow := int(ceil(radius))
	for c in cells:
		for dx in range(-grow, grow + 1):
			for dy in range(-grow, grow + 1):
				for dz in range(-grow, grow + 1):
					var id: int = _cell.get(c + Vector3i(dx, dy, dz), -1)
					if id >= 0:
						found[id] = true
	return found.keys()


func _dda_cells(p0: Vector3, p1: Vector3) -> Array:
	var cells: Array = []
	var pos := Vector3i(floori(p0.x), floori(p0.y), floori(p0.z))
	var endp := Vector3i(floori(p1.x), floori(p1.y), floori(p1.z))
	cells.append(pos)
	if pos == endp:
		return cells
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
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			pos.x += step.x
			t_max.x += t_delta.x
		elif t_max.y <= t_max.z:
			pos.y += step.y
			t_max.y += t_delta.y
		else:
			pos.z += step.z
			t_max.z += t_delta.z
		cells.append(pos)
	return cells
