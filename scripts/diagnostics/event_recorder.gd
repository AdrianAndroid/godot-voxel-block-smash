extends RefCounted

# 结构化事件记录器（架构 v6：JSONL；run/build/gdd 标识；可开关与采样；发布构建关闭高频日志）
# 阶段：阶段3

var enabled := OS.is_debug_build()  # iOS 适配：发布构建默认关（每事件 flush 高频写盘仅限 debug/编辑器）
var sample_every := 1           # 高频事件采样率（1=全量）
var path := "user://event_log.jsonl"
var run_id := ""
var build_id := "dev"
var gdd_version := "v6"

var _file: FileAccess
var _dropped := 0
var _counters: Dictionary = {}
const SAMPLED_EVENTS := ["ball_hit_voxel"]  # 高频事件采样写


func open(p_path: String = "") -> void:
	if not enabled:
		return  # 发布构建不落盘、不建文件
	if p_path != "":
		path = p_path
	run_id = "%d" % Time.get_unix_time_from_system()
	_file = FileAccess.open(path, FileAccess.WRITE)
	_write({"event": "_run_start", "run_id": run_id, "build_id": build_id, "gdd_version": gdd_version})


func attach(bus: RefCounted, level_id: String) -> void:
	for e in bus.EVENTS:
		bus.subscribe(e, _on_event, level_id)


func _on_event(args: Array, meta: Dictionary) -> void:
	if not enabled or _file == null:
		return
	var ev: String = str(meta.get("event", ""))
	_counters[ev] = int(_counters.get(ev, 0)) + 1
	if ev in SAMPLED_EVENTS and _counters[ev] % sample_every != 0:
		_dropped += 1
		return
	_write({"event": ev, "args": _to_jsonable(args), "meta": meta, "run_id": run_id})


func close() -> Dictionary:
	if _file != null:
		_write({"event": "_run_end", "dropped": _dropped, "counters": _counters})
		_file.close()
		_file = null
	return {"dropped": _dropped, "counters": _counters}


func _write(row: Dictionary) -> void:
	if _file != null:
		_file.store_line(JSON.stringify(row))
		_file.flush()  # Android 上 close() 前缓冲不落盘，每行强制 flush（诊断日志，量小）


static func _to_jsonable(v: Variant) -> Variant:
	if v is Array:
		return v.map(_to_jsonable)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = _to_jsonable(v[k])
		return out
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Vector3i:
		return [v.x, v.y, v.z]
	if v is Vector2:
		return [v.x, v.y]
	if v is Color:
		return [v.r, v.g, v.b, v.a]
	if v is float or v is int or v is String or v is bool or v == null:
		return v
	return str(v)
