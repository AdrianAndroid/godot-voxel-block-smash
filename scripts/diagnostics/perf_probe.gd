extends RefCounted

# S10 真机定位用：子系统耗时累计探针。ENABLED=false 时全部调用内联为空（零开销）。
# perf_monitor 每 5s 取 snapshot_and_reset() 写入 perf_log.jsonl。

const ENABLED := true

static var _acc: Dictionary = {}


static func t0() -> int:
	return (Time.get_ticks_usec() if ENABLED else 0) as int


static func add(name: String, t_start: int) -> void:
	if not ENABLED:
		return
	var us := Time.get_ticks_usec() - t_start
	var e: Dictionary = _acc.get(name, {"n": 0, "ms": 0.0, "max_ms": 0.0})
	e.n += 1
	var ms := us / 1000.0
	e.ms += ms
	if ms > e.max_ms:
		e.max_ms = ms
	_acc[name] = e


static func count(name: String) -> void:
	if not ENABLED:
		return
	var e: Dictionary = _acc.get(name, {"n": 0, "ms": 0.0, "max_ms": 0.0})
	e.n += 1
	_acc[name] = e


static func snapshot_and_reset() -> Dictionary:
	var out := _acc
	_acc = {}
	return out
