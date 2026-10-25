extends RefCounted

# 关卡 JSON 入口（架构 v6：调用 VoxelLoader/Data 解析与 Renderer 批量生成；不维护第二份体素状态）
# 阶段：阶段2最小导入、阶段3完善

var catalog := preload("res://scripts/level/level_catalog.gd")
var loader := preload("res://scripts/data/voxel_loader.gd")


# 返回 {ok, level_id, config, voxel_data, error}
func load_level(config_path: String) -> Dictionary:
	var c: Dictionary = catalog.load_config(config_path)
	if not c.ok:
		return {"ok": false, "error": c.error}
	var v: Dictionary = loader.load_from_json(c.config.model_path)
	if not v.ok:
		return {"ok": false, "error": "模型加载失败: " + v.error}
	return {"ok": true, "level_id": c.config.level_id, "config": c.config, "voxel_data": v.data, "error": ""}
