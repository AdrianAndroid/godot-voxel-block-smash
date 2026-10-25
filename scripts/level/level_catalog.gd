extends RefCounted

# 关卡目录（架构 v6 关卡配置 JSON 契约最小版本）
# 校验：schema_version=1、必填字段、model_path 限 res://assets/models/json/ 且禁路径穿越、未知字段拒绝

const SUPPORTED_SCHEMA := 1
const MODEL_PREFIX := "res://assets/models/json/"
const ALLOWED_KEYS := ["schema_version", "level_id", "display_number", "model_path", "model_revision", "rules"]


static func load_config(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _err("关卡配置不存在: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _err("关卡配置 JSON 解析失败: " + path)
	var doc: Dictionary = parsed
	for key in doc.keys():
		if key not in ALLOWED_KEYS:
			return _err("未知字段: " + str(key))
	if doc.get("schema_version") != SUPPORTED_SCHEMA:
		return _err("schema_version 不支持: " + str(doc.get("schema_version")))
	var level_id: Variant = doc.get("level_id")
	if not (level_id is String) or level_id.is_empty():
		return _err("level_id 缺失或为空")
	var num: Variant = doc.get("display_number")
	if not (num is float or num is int) or num < 1:
		return _err("display_number 非正整数")
	var model_path: Variant = doc.get("model_path")
	if not (model_path is String) or not model_path.begins_with(MODEL_PREFIX) or model_path.contains(".."):
		return _err("model_path 越界: " + str(model_path))
	var rev: Variant = doc.get("model_revision")
	if not (rev is String) or rev.is_empty():
		return _err("model_revision 缺失")
	if not (doc.get("rules") is Dictionary):
		return _err("rules 缺失或非对象")
	return {"ok": true, "config": doc, "error": ""}


static func list_levels(dir_path: String = "res://assets/levels") -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".json"):
			var r := load_config(dir_path.path_join(f))
			if r.ok:
				out.append(r.config)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.display_number < b.display_number)
	return out


static func _err(msg: String) -> Dictionary:
	return {"ok": false, "config": {}, "error": msg}
