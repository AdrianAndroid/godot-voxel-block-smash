extends RefCounted

# 不可变模型数据（schema_version=2，架构 v6 数据契约）
# 阶段：阶段2最小实现，阶段3完善。格坐标已归一为非负整数，加载展示时按包围盒中心居中。

var voxel_size: float = 1.0
var palette: Dictionary = {}          # color_id(int) -> Color
var positions: PackedVector3Array     # 格坐标（整数存入 float 分量）
var color_ids: PackedInt32Array
var count: int = 0
var bounds_min: Vector3 = Vector3.ZERO
var bounds_max: Vector3 = Vector3.ZERO


func center_offset() -> Vector3:
	# 加载时减包围盒中心，ModelPivot 放在该中心（架构 v6 数据契约）
	return (bounds_min + bounds_max) * 0.5


func grid_to_local(i: int) -> Vector3:
	return (positions[i] - center_offset()) * voxel_size
