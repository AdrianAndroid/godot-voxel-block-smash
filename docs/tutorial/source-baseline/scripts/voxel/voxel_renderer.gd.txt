extends RefCounted
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

# 单 MultiMesh 体素渲染（阶段3完整版：整量构建 + 尾交换删除 + voxel_id↔slot 双向映射）
# 观测契约：显示实例数等于存活数；交换删除后两向映射一致；无逐块 Node
# 注意：MultiMesh 缓冲在 headless dummy 渲染器下不可回读，逻辑断言以 CPU 镜像为准

var _mesh_instance: MultiMeshInstance3D
var mirror_transforms: Array = []   # slot -> Transform3D
var mirror_colors: Array = []       # slot -> Color
var slot_of: Dictionary = {}        # voxel_id -> slot
var voxel_of: Array = []            # slot -> voxel_id
var _visible_count: int = 0


func build(data: RefCounted) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	# CQ-20261026/S01：块缝=格距 3%（任务要求 2%~4%）；碰撞仍按逻辑格定义，视觉缝隙不是穿透通道
	box.size = Vector3.ONE * data.voxel_size * 0.97
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = data.count
	mirror_transforms.clear()
	mirror_colors.clear()
	slot_of.clear()
	voxel_of.clear()
	for i in data.count:
		var t := Transform3D(Basis.IDENTITY, data.grid_to_local(i))
		var c: Color = data.palette[data.color_ids[i]]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
		mirror_transforms.append(t)
		mirror_colors.append(c)
		slot_of[i] = i
		voxel_of.append(i)
	_visible_count = data.count
	_mesh_instance = MultiMeshInstance3D.new()
	_mesh_instance.name = "VoxelMultiMesh"
	_mesh_instance.multimesh = mm
	return _mesh_instance


func remove_voxel(voxel_id: int) -> bool:
	var _pt := PerfProbe.t0()
	# 尾交换删除：把最后一个可见实例搬到被删 slot，收缩可见数
	if not slot_of.has(voxel_id):
		return false
	var slot: int = slot_of[voxel_id]
	var last := _visible_count - 1
	var mm: MultiMesh = _mesh_instance.multimesh
	if slot != last:
		var last_id: int = voxel_of[last]
		mirror_transforms[slot] = mirror_transforms[last]
		mirror_colors[slot] = mirror_colors[last]
		mm.set_instance_transform(slot, mirror_transforms[last])
		mm.set_instance_color(slot, mirror_colors[last])
		voxel_of[slot] = last_id
		slot_of[last_id] = slot
	mirror_transforms.resize(last)
	mirror_colors.resize(last)
	voxel_of.resize(last)
	slot_of.erase(voxel_id)
	_visible_count = last
	mm.visible_instance_count = _visible_count
	PerfProbe.add("mm_remove", _pt)
	return true


func instance_count() -> int:
	return _visible_count


func instance_of(voxel_id: int) -> int:
	return slot_of.get(voxel_id, -1)
