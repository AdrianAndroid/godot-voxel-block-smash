extends RefCounted

# FM/F2 §7：发射统计——验收证据（FM05/FM13）用的只读计数器。
# 控制器在发射/结算路径打点；perf_monitor 经 stats_provider 合入 perf_log.jsonl。
# 只增计数，不影响玩法。

var fire_attempt := 0        # try_auto_fire 调用次数
var fire_success := 0        # 真实出膛次数（== turret_fire 事件数）
var hit := 0                 # HIT 结算（真实删块）
var cancel_reasons := {}     # reason -> count（mismatch/timeout/out_of_bounds/...）
var waiting_target := 0      # 等待同色目标次数（按发射尝试计）
var scan_pending := 0        # 时间片未扫完次数
var revalidate_failed := 0   # P4 §6.3：分片结果当前原点终核失败次数（等待原因可审计）
var flight_times: Array[float] = []  # 有界（256）：每发飞行时长秒（出膛→结算）
var destroyed_total := 0
var _destroy_marks: Array[float] = []  # 最近 10s 消除时间戳（滚动窗口，clock 注入）
var clock_ms := 0.0          # 由控制器用局内有效时钟驱动（秒）


func on_attempt() -> void:
	fire_attempt += 1


func on_fire() -> void:
	fire_success += 1


func on_wait(reason: String) -> void:
	if reason == "waiting_target":
		waiting_target += 1
	elif reason == "scan_pending":
		scan_pending += 1
	elif reason == "revalidate_failed":
		revalidate_failed += 1


func on_hit(flight_sec: float) -> void:
	hit += 1
	destroyed_total += 1
	_destroy_marks.append(clock_ms)
	_trim_marks()
	if flight_sec >= 0.0:
		flight_times.append(flight_sec)
		if flight_times.size() > 256:
			flight_times.pop_front()


func on_cancel(reason: String, flight_sec: float) -> void:
	cancel_reasons[reason] = int(cancel_reasons.get(reason, 0)) + 1
	if flight_sec >= 0.0:
		flight_times.append(flight_sec)
		if flight_times.size() > 256:
			flight_times.pop_front()


func advance(dt: float) -> void:
	clock_ms += dt
	_trim_marks()


func _trim_marks() -> void:
	while not _destroy_marks.is_empty() and clock_ms - _destroy_marks[0] > 10.0:
		_destroy_marks.pop_front()


# 近 10 秒每秒消除速率
func destroys_per_sec() -> float:
	if clock_ms <= 0.0:
		return 0.0
	var w := minf(clock_ms, 10.0)
	return _destroy_marks.size() / w


func avg_flight_sec() -> float:
	if flight_times.is_empty():
		return 0.0
	var s := 0.0
	for f in flight_times:
		s += f
	return s / flight_times.size()


func snapshot() -> Dictionary:
	var cancels := 0
	for k in cancel_reasons:
		cancels += int(cancel_reasons[k])
	return {
		"fire_attempt": fire_attempt,
		"fire_success": fire_success,
		"hit": hit,
		"cancel_total": cancels,
		"cancel_reasons": cancel_reasons.duplicate(),
		"waiting_target": waiting_target,
		"scan_pending": scan_pending,
		"revalidate_failed": revalidate_failed,
		"destroyed_total": destroyed_total,
		"destroys_per_sec": snappedf(destroys_per_sec(), 0.01),
		"avg_flight_ms": int(avg_flight_sec() * 1000.0),
		"effective_clock_sec": snappedf(clock_ms, 0.1),
		# 等待占比 = 等待类尝试 / 总尝试（节奏验收指标）
		"wait_ratio": snappedf(float(waiting_target + scan_pending) / maxf(fire_attempt, 1), 0.001),
	}
