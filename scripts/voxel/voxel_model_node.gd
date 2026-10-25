extends Node3D
class_name VoxelModelNode

## 体素模型节点：承载 VoxelManager 构建的 MultiMesh 渲染子节点，
## 对外提供 world_from_grid 变换（含中心偏移与手势旋转）。

var manager: RefCounted  # VoxelManager
var voxel_data: RefCounted  # VoxelData


func attach(p_manager: RefCounted, p_data: RefCounted) -> void:
	manager = p_manager
	voxel_data = p_data
	var render_node: Node3D = manager.build(p_data)
	add_child(render_node)
	# 以包围盒中心为枢轴，便于绕中心旋转
	render_node.position = -p_data.center_offset()


func grid_to_world(grid_pos: Vector3) -> Vector3:
	return world_from_grid() * grid_pos


func world_from_grid() -> Transform3D:
	# 格坐标 → 世界：先减中心偏移（渲染子节点已平移），再应用本节点变换
	return global_transform * Transform3D(Basis.IDENTITY, -voxel_data.center_offset())
