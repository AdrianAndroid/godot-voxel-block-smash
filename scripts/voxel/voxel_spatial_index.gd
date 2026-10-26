extends RefCounted

# 局部网格空间索引（架构 v6：格 -> voxel_id；已删块不再被候选查询返回）
# 阶段：阶段3。坐标为模型局部格坐标（voxel_size=1 的格空间）
# CQ-20261026/S10 性能：键从 Vector3i 改为打包 int（21bit/轴，|坐标|<2^20），
# 消除每格 27 次 Vector3i 构造+对象哈希；移动端候选查询 ~2ms → ~0.2ms。

const AXIS_BITS := 21
const AXIS_MASK := 0x1FFFFF
const Y_SHIFT := 21
const X_SHIFT := 42
# 坐标偏置：球从模型界外（负格坐标，如底面下方边界）起飞，DDA 格含负数；
# 打包键用位掩码表示坐标，邻域偏移按字段加减运算——负数会以掩码回绕、
# 正偏移再加会溢出 int64 符号位，导致邻域查找漏真实体素（球穿模）。
# 统一加 2^10 偏置，使 [-1024, 2^21-1-1024] 内坐标全部非负，加减不借位。
const BIAS := 1 << 10

# 27 邻域打包偏移（(dx<<42)|(dy<<21)|dz 的位移量，中心格=0 含自身）
const OFF27 := [
	-1 - (1 << Y_SHIFT) - (1 << X_SHIFT), -1 - (1 << Y_SHIFT), -1 - (1 << Y_SHIFT) + (1 << X_SHIFT),
	-1 - (1 << X_SHIFT), -1, -1 + (1 << X_SHIFT),
	-1 + (1 << Y_SHIFT) - (1 << X_SHIFT), -1 + (1 << Y_SHIFT), -1 + (1 << Y_SHIFT) + (1 << X_SHIFT),
	-(1 << Y_SHIFT) - (1 << X_SHIFT), -(1 << Y_SHIFT), -(1 << Y_SHIFT) + (1 << X_SHIFT),
	-(1 << X_SHIFT), 0, (1 << X_SHIFT),
	(1 << Y_SHIFT) - (1 << X_SHIFT), (1 << Y_SHIFT), (1 << Y_SHIFT) + (1 << X_SHIFT),
	1 - (1 << Y_SHIFT) - (1 << X_SHIFT), 1 - (1 << Y_SHIFT), 1 - (1 << Y_SHIFT) + (1 << X_SHIFT),
	1 - (1 << X_SHIFT), 1, 1 + (1 << X_SHIFT),
	1 + (1 << Y_SHIFT) - (1 << X_SHIFT), 1 + (1 << Y_SHIFT), 1 + (1 << Y_SHIFT) + (1 << X_SHIFT),
]

var _cell: Dictionary = {}  # packed int -> voxel_id


static func pack(x: int, y: int, z: int) -> int:
	return (((x + BIAS) & AXIS_MASK) << X_SHIFT) | (((y + BIAS) & AXIS_MASK) << Y_SHIFT) \
		| ((z + BIAS) & AXIS_MASK)


static func pack_v(pos: Vector3i) -> int:
	return (((pos.x + BIAS) & AXIS_MASK) << X_SHIFT) | (((pos.y + BIAS) & AXIS_MASK) << Y_SHIFT) \
		| ((pos.z + BIAS) & AXIS_MASK)


func build(data: RefCounted) -> void:
	_cell.clear()
	for i in data.count:
		_cell[pack_v(Vector3i(data.positions[i]))] = i  # Vector3i 转换语义与原实现一致（四舍五入）


func remove_at(pos: Vector3i) -> void:
	_cell.erase(pack_v(pos))


func at(pos: Vector3i) -> int:
	return _cell.get(pack_v(pos), -1)


func candidates_along_segment(p0: Vector3, p1: Vector3, radius: float) -> Array:
	# 宽相：线段 DDA 经过的格 + 半径邻域内的已占用格，返回 voxel_id 数组（去重）
	var found := {}
	var cells := _dda_cells(p0, p1)
	var grow := int(ceil(radius))
	if grow == 1:
		# 快路径（radius<1：固定 27 邻域，打包偏移免 Vector3i 构造）
		for c in cells:
			var base := pack_v(c)
			for off in OFF27:
				var id: int = _cell.get(base + off, -1)
				if id >= 0:
					found[id] = true
	else:
		for c in cells:
			for dx in range(-grow, grow + 1):
				for dy in range(-grow, grow + 1):
					for dz in range(-grow, grow + 1):
						var id: int = _cell.get(pack(c.x + dx, c.y + dy, c.z + dz), -1)
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
	# signf 先取浮点符号：signi 会先把 float 截断成 int，|d|<1 的分量全变 0，
	# 导致 step=(0,0,0) 空转到 4096 守卫、候选只剩起点格邻域（高速短步长漏扫根源）
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
