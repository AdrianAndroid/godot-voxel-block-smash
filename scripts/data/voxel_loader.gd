extends RefCounted

# 模型 JSON 解析与校验（schema_version=2）
# 非法坐标/色/数量拒绝并定位字段；返回 {ok: bool, data: RefCounted(VoxelData), error: String}

const MIN_VOXELS := 300
const MAX_VOXELS := 1200
const SUPPORTED_SCHEMA := 2


static func load_from_json(path: String, enforce_range: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _err("文件不存在: " + path)
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return _err("JSON 解析失败: " + path)
	var doc: Dictionary = parsed
	var allowed := ["schema_version", "voxel_size", "palette", "voxels"]
	for key in doc.keys():
		if key not in allowed:
			return _err("未知字段: " + str(key))
	if doc.get("schema_version") != SUPPORTED_SCHEMA:
		return _err("schema_version 不支持: " + str(doc.get("schema_version")))
	var voxel_size: Variant = doc.get("voxel_size")
	if not (voxel_size is float or voxel_size is int) or voxel_size <= 0.0 or not is_finite(voxel_size):
		return _err("voxel_size 非正有限数: " + str(voxel_size))
	var palette_raw: Variant = doc.get("palette")
	if not (palette_raw is Dictionary) or palette_raw.is_empty():
		return _err("palette 缺失或为空")
	var palette := {}
	for key in palette_raw.keys():
		var cid: int = int(key) if str(key).is_valid_int() else -1
		var rgba: Variant = palette_raw[key]
		if cid <= 0 or not (rgba is Array) or rgba.size() != 4:
			return _err("palette." + str(key) + " 格式错误")
		for c in rgba:
			if not (c is float or c is int) or c < 0.0 or c > 1.0 or not is_finite(c):
				return _err("palette." + str(key) + " 分量越界")
		palette[cid] = Color(rgba[0], rgba[1], rgba[2], rgba[3])
	var voxels_raw: Variant = doc.get("voxels")
	if not (voxels_raw is Array):
		return _err("voxels 缺失或非数组")
	if enforce_range and (voxels_raw.size() < MIN_VOXELS or voxels_raw.size() > MAX_VOXELS):
		return _err("voxels 数量 %d 超出 %d~%d" % [voxels_raw.size(), MIN_VOXELS, MAX_VOXELS])
	var data := preload("res://scripts/data/voxel_data.gd").new()
	data.voxel_size = float(voxel_size)
	data.palette = palette
	var seen := {}
	var positions := PackedVector3Array()
	var color_ids := PackedInt32Array()
	var bmin := Vector3(INF, INF, INF)
	var bmax := Vector3(-INF, -INF, -INF)
	for i in voxels_raw.size():
		var v: Variant = voxels_raw[i]
		if not (v is Dictionary):
			return _err("voxels[%d] 非对象" % i)
		var coord := Vector3.ZERO
		var axes := ["x", "y", "z"]
		for ai in 3:
			var val: Variant = v.get(axes[ai])
			if not (val is float or val is int) or not is_finite(val) or val != floor(val) or val < 0.0:
				return _err("voxels[%d].%s 非法坐标: %s" % [i, axes[ai], str(val)])
			coord[ai] = float(val)
		var key := Vector3i(coord)
		if seen.has(key):
			return _err("voxels[%d] 重复坐标 %s，首次出现于 voxels[%d]" % [i, str(key), seen[key]])
		seen[key] = i
		var cid: Variant = v.get("color_id")
		if not (cid is float or cid is int) or not palette.has(int(cid)):
			return _err("voxels[%d].color_id 未引用 palette: %s" % [i, str(cid)])
		positions.append(coord)
		color_ids.append(int(cid))
		bmin = bmin.min(coord)
		bmax = bmax.max(coord)
	data.positions = positions
	data.color_ids = color_ids
	data.count = positions.size()
	data.bounds_min = bmin
	data.bounds_max = bmax
	return {"ok": true, "data": data, "error": ""}


static func _err(msg: String) -> Dictionary:
	return {"ok": false, "data": null, "error": msg}
