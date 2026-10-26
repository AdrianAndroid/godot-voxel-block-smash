extends Node3D
class_name VoxelModelNode

## 体素模型节点：承载 VoxelManager 构建的 MultiMesh 渲染子节点，
## 对外提供 world_from_grid 变换（含中心偏移与手势旋转）。

var manager: RefCounted  # VoxelManager
var voxel_data: RefCounted  # VoxelData

## FM §11：模型朝向唯一写入口计数。选靶负缓存/扫描断点据此失效；
## 所有姿态修改必须走 set_orientation，禁止外部直写 global_transform.basis。
var transform_version := 0


func set_orientation(b: Basis) -> void:
	var t := global_transform
	t.basis = b
	global_transform = t
	transform_version += 1


func attach(p_manager: RefCounted, p_data: RefCounted) -> void:
	manager = p_manager
	voxel_data = p_data
	var render_node: Node3D = manager.build(p_data)
	# 实例变换已含 -center_offset（grid_to_local），渲染子节点不再二次偏移，
	# 枢轴即本节点原点（= 模型包围盒中心），旋转绕中心（G01）
	add_child(render_node)


func grid_to_world(grid_pos: Vector3) -> Vector3:
	return world_from_grid() * grid_pos


func world_from_grid() -> Transform3D:
	# 格坐标 → 世界：先减中心偏移（渲染子节点已平移），再应用本节点变换
	return global_transform * Transform3D(Basis.IDENTITY, -voxel_data.center_offset())
