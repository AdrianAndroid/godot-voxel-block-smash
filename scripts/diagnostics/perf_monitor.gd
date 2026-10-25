extends Node

## D07 性能采样：帧时间窗口统计（avg/p95/FPS）+ 内存，周期写 user://perf_log.jsonl。
## 只读测量，不影响玩法。

var interval_sec := 5.0
var path := "user://perf_log.jsonl"
var enabled := true

var _frames: Array[float] = []
var _elapsed := 0.0
var _file: FileAccess


func _ready() -> void:
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
	}
	_file.store_line(JSON.stringify(row))
	_file.flush()
	_frames.clear()
