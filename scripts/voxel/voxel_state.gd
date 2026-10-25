extends RefCounted

# 存活体素状态（架构 v6：存活集、稳定ID、重复删除拒绝、alive_count等于存活集大小）
# 阶段：阶段3

var _alive: Dictionary = {}  # voxel_id(int) -> true
var count: int = 0


func setup(p_count: int) -> void:
	_alive.clear()
	for i in p_count:
		_alive[i] = true
	count = p_count


func is_alive(voxel_id: int) -> bool:
	return _alive.has(voxel_id)


func remove(voxel_id: int) -> bool:
	if not _alive.has(voxel_id):
		return false  # 重复删除拒绝，无副作用
	_alive.erase(voxel_id)
	count -= 1
	return true


func alive_ids() -> Array:
	return _alive.keys()
