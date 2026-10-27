extends Node
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

## D07 性能采样：帧时间窗口统计（avg/p95/FPS）+ 内存，周期写 user://perf_log.jsonl。
## 只读测量，不影响玩法。

var interval_sec := 5.0
var path := "user://perf_log.jsonl"
var enabled := OS.is_debug_build()  # iOS 适配：发布构建默认关（周期写盘仅限 debug/编辑器）
var stats_provider := Callable()  # FM/F2：() -> Dictionary（fire_stats 快照，合入每行）

var _frames: Array[float] = []
var _elapsed := 0.0
var _file: FileAccess


func _ready() -> void:
	if enabled:
		_file = FileAccess.open(path, FileAccess.WRITE)


func _process(delta: float) -> void:
	if not enabled or _file == null:
		return
	_frames.append(delta)
	_elapsed += delta
	if _elapsed >= interval_sec:
		_flush()
		_elapsed = 0.0


func _flush() -> void:
	if _frames.is_empty():
		return
	_frames.sort()
	var sum := 0.0
	for f in _frames:
		sum += f
	var avg := sum / _frames.size()
	var p95: float = _frames[mini(int(_frames.size() * 0.95), _frames.size() - 1)]
	var row := {
		"ts": Time.get_unix_time_from_system(),
		"frames": _frames.size(),
		"fps": 1.0 / avg if avg > 0 else 0.0,
		"avg_ms": avg * 1000.0,
		"p95_ms": p95 * 1000.0,
		"mem_static_mb": OS.get_static_memory_usage() / 1048576.0,
		"probe": PerfProbe.snapshot_and_reset(),
		"stats": stats_provider.call() if not stats_provider.is_null() else {},
	}
	_file.store_line(JSON.stringify(row))
	_file.flush()
	_frames.clear()
