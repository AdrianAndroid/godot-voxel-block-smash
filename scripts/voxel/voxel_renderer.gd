extends RefCounted

# 单 MultiMesh 体素渲染（阶段2最小实现：整量构建；阶段3扩展尾交换删除映射）
# 观测契约：实例数等于体素数；单 MultiMeshInstance3D；无逐块 Node；实例颜色=调色板纯色

var _mesh_instance: MultiMeshInstance3D
# CPU 镜像：MultiMesh 缓冲在 headless dummy 渲染器下不可回读，逻辑与自测以镜像为准
var mirror_transforms: Array = []
var mirror_colors: Array = []


func build(data: RefCounted) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * data.voxel_size
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
	for i in data.count:
		var t := Transform3D(Basis.IDENTITY, data.grid_to_local(i))
		var c: Color = data.palette[data.color_ids[i]]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
		mirror_transforms.append(t)
		mirror_colors.append(c)
	_mesh_instance = MultiMeshInstance3D.new()
	_mesh_instance.name = "VoxelMultiMesh"
	_mesh_instance.multimesh = mm
	return _mesh_instance


func instance_count() -> int:
	if _mesh_instance == null or _mesh_instance.multimesh == null:
		return 0
	return _mesh_instance.multimesh.instance_count
