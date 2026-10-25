extends RefCounted

# 体素管理门面：组合 VoxelState/SpatialIndex/Renderer，统一查询与删除入口（架构 v6）
# 阶段：阶段3。不逐块创建节点；删除为事务性三步（状态→索引→渲染）

var data: RefCounted            # VoxelData
var state: RefCounted           # VoxelState
var index: RefCounted           # VoxelSpatialIndex
var renderer: RefCounted        # VoxelRenderer


func build(p_data: RefCounted) -> MultiMeshInstance3D:
	data = p_data
	state = preload("res://scripts/voxel/voxel_state.gd").new()
	state.setup(data.count)
	index = preload("res://scripts/voxel/voxel_spatial_index.gd").new()
	index.build(data)
	renderer = preload("res://scripts/voxel/voxel_renderer.gd").new()
	return renderer.build(data)


func alive_count() -> int:
	return state.count


func is_alive(voxel_id: int) -> bool:
	return state.is_alive(voxel_id)


func block_snapshot(voxel_id: int) -> Dictionary:
	# 只读快照（事件载荷用，不是节点引用）
	if not state.is_alive(voxel_id):
		return {}
	return {
		"voxel_id": voxel_id,
		"grid": Vector3i(data.positions[voxel_id]),
		"color_id": data.color_ids[voxel_id],
	}


func destroy(voxel_id: int) -> Dictionary:
	# 返回 {ok, block};重复删除拒绝且不产生副作用
	if not state.is_alive(voxel_id):
		return {"ok": false, "block": {}}
	var snap := block_snapshot(voxel_id)
	state.remove(voxel_id)
	index.remove_at(snap.grid)
	renderer.remove_voxel(voxel_id)
	return {"ok": true, "block": snap}


func sweep_candidates(local_p0: Vector3, local_p1: Vector3, radius: float) -> Array:
	return index.candidates_along_segment(local_p0, local_p1, radius)


func grid_position(voxel_id: int) -> Vector3:
	return data.positions[voxel_id]


func color_of(voxel_id: int) -> int:
	return data.color_ids[voxel_id]
