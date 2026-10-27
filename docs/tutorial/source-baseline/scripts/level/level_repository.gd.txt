extends RefCounted

# 关卡存档仓库（架构 v6：user://、临时文件完整写入校验后替换、拒绝不兼容数据）
# 阶段：阶段3接口，D09 默认：跨进程持久化 user://saves/level_<id>.json

# FM/F0：目录可注入——测试必须 set_save_dir 到隔离目录，禁止触碰真实存档
static var save_dir := "user://saves"


static func set_save_dir(d: String) -> void:
	save_dir = d


static func is_isolated() -> bool:
	return save_dir != "user://saves"


static func save_path(level_id: String) -> String:
	return save_dir.path_join("level_%s.json" % level_id)


static func save(snapshot: Dictionary) -> Dictionary:
	var level_id: String = str(snapshot.get("level_id", ""))
	if level_id.is_empty():
		return {"ok": false, "error": "snapshot 缺 level_id"}
	DirAccess.make_dir_recursive_absolute(save_dir)
	var final_path := save_path(level_id)
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "临时文件写入失败: " + tmp_path}
	f.store_string(JSON.stringify(snapshot))
	f.close()
	# 校验临时文件可解析后再替换
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp_path))
	if not (check is Dictionary) or check.get("level_id") != level_id:
		return {"ok": false, "error": "临时文件校验失败，保留旧快照"}
	var err := DirAccess.rename_absolute(tmp_path, final_path)
	if err != OK:
		return {"ok": false, "error": "替换失败 err=%d" % err}
	return {"ok": true, "error": ""}


static func load_snapshot(level_id: String) -> Dictionary:
	var p := save_path(level_id)
	if not FileAccess.file_exists(p):
		return {"ok": false, "exists": false, "snapshot": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (parsed is Dictionary) or parsed.get("level_id") != level_id or not parsed.has("version"):
		return {"ok": false, "exists": true, "snapshot": {}, "error": "存档校验失败"}
	return {"ok": true, "exists": true, "snapshot": parsed}


# CQ-20261026/S09：v1 旧档备份（重命名 .v1.bak），由调用方决定重新开始
# 2026-10-27 §9：返回值必须反映真实结果——rename 失败时原档仍在，返回空串并告警，
# 调用方据此决定（失败时不得把原档当作已备份丢弃/覆盖处理）。
static func backup_save(level_id: String) -> String:
	var p := save_path(level_id)
	if not FileAccess.file_exists(p):
		return ""
	var bak := p + ".v1.bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)  # 旧备份可弃：本次要备份的是当前坏档
	var err := DirAccess.rename_absolute(p, bak)
	if err != OK:
		push_warning("[LevelRepository] 备份失败 err=%d（保留原档）: %s" % [err, p])
		return ""
	return bak


static func delete_save(level_id: String) -> void:
	var p := save_path(level_id)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
