extends Node

# FM/F5 实时回放器（FM12/FM13/FM20 证据）：
# 按 s03-solution.json 的 place/park 列序驱动【公开控制器 API】（place_front），
# 发射交给自动连发、旋转交给自动旋转（解的全部朝向 pitch0，连续 yaw 扫掠全覆盖），
# 不直接删块、不改计数、不跳过冷却。实时 pacing：每帧最多执行一个上位操作，
# 槽满即等待（炮台耗尽自动退槽后推进）。产出 JSON 报告 + JSONL 进度流。
# 用法：VoxelBlockSmash.app/Contents/MacOS/... -- --replay=<solution.json 绝对路径>
#       [--replay-report=<报告输出绝对路径>] [--replay-max-sec=360]

var _main: Node = null
var _gc: Node = null
var _ops: Array = []           # 非 fire 操作（place/park），按解序
var _op_idx := 0
var _armed := false
var _started := false
var _report_path := ""
var _max_sec := 360.0
var _t_wall := 0.0
var _last_progress := -999.0
var _progress_lines: Array = []
var _op_mismatches: Array = []
var _solution_meta := {}


# main._ready 调用；CLI 无 --replay= 返回 false（正常游戏不受影响）
func arm(main_node: Node) -> bool:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replay="):
			path = arg.trim_prefix("--replay=")
		elif arg.begins_with("--replay-report="):
			_report_path = arg.trim_prefix("--replay-report=")
		elif arg.begins_with("--replay-max-sec="):
			_max_sec = float(arg.trim_prefix("--replay-max-sec="))
	if path.is_empty():
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[replay] 无法读取解文件: " + path)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("actions"):
		push_error("[replay] 解文件格式错误")
		return false
	_main = main_node
	var data: Dictionary = parsed
	_solution_meta = {"seed": data.get("seed"), "slots": data.get("slots"),
		"model": data.get("model"), "color_counts": data.get("color_counts"),
		"actions_total": (data["actions"] as Array).size()}
	var fires := 0
	for a in data["actions"]:
		match str(a.get("op", "")):
			"fire":
				fires += 1  # 发射交给自动连发，仅计数校验终局消除数
			"place", "park":
				_ops.append(a)  # place/park 均为 place_front（park=驻停占位）
			"rotate":
				pass  # 自动旋转连续扫掠全覆盖（解全部 pitch0）
	_solution_meta["fire_ops"] = fires
	_solution_meta["drive_ops"] = _ops.size()
	if _report_path.is_empty():
		_report_path = "user://replay_report.json"
	_armed = true
	return true


func _process(delta: float) -> void:
	if not _armed:
		return
	if not _started:
		_started = true
		_main.enter_level("level_01")  # 全新会话（不回放存档）
		_gc = _main.controller
		# 正常玩家操作：开局用唯一一枚加槽道具（3→4 槽并行，节奏验收前提）
		var slot_res: Dictionary = _gc.use_prop("add_slot")
		_solution_meta["add_slot_used"] = slot_res.get("ok", false)
		print("[replay] 开始：%s" % str(_solution_meta))
		return
	_t_wall += delta
	if _gc == null or _gc.session == null:
		return
	var outcome: String = _gc.session.outcome
	if outcome != "RUNNING":
		_finish(outcome)
		return
	if _t_wall > _max_sec:
		_finish("TIMEOUT")
		return
	# 每帧至多推进一个上位操作（实时 pacing）
	if _op_idx < _ops.size():
		var op: Dictionary = _ops[_op_idx]
		var res: Dictionary = _gc.place_front(int(op.column))
		if res.ok:
			if int(res.turret_id) != int(op.turret):
				_op_mismatches.append({"op": _op_idx, "expect": op.turret, "got": res.turret_id})
			_op_idx += 1
		elif str(res.get("reason", "")) != "slots_full":
			# empty_column/not_running 等 = 解与实跑分叉（列序应确定性一致）
			_op_mismatches.append({"op": _op_idx, "error": str(res)})
			_op_idx += 1
	# 5s 进度流
	if _t_wall - _last_progress >= 5.0:
		_last_progress = _t_wall
		var fs: Dictionary = _gc.fire_stats.snapshot()
		var line := {"t_wall": snappedf(_t_wall, 0.1), "t_eff": fs.get("effective_clock_sec"),
			"alive": _gc.voxel_manager.alive_count(), "ops_done": _op_idx,
			"fires": fs.get("fire_success"), "hits": fs.get("hit"),
			"cancels": fs.get("cancel_total"), "dps_10s": fs.get("destroys_per_sec")}
		_progress_lines.append(line)
		print("[replay] %s" % str(line))


func _finish(outcome: String) -> void:
	if not _armed:
		return
	_armed = false
	var fs: Dictionary = _gc.fire_stats.snapshot()
	var audit: Dictionary = _gc.conservation_audit()
	var eff := float(fs.get("effective_clock_sec", 0.0))
	var report := {
		"result": outcome,
		"pacing": "PASS" if outcome == "WON" and eff <= 300.0 else "FAIL",
		"pacing_target_210_240": eff >= 0.0 and eff <= 240.0,
		"wall_sec": snappedf(_t_wall, 0.01),
		"effective_sec": snappedf(eff, 0.01),
		"alive_remaining": _gc.voxel_manager.alive_count(),
		"renderer_instances": _gc.voxel_manager.renderer.instance_count(),
		"drive_ops_done": _op_idx, "drive_ops_total": _ops.size(),
		"op_mismatches": _op_mismatches,
		"auto_rot_deg_per_sec": _gc.rules.auto_rot_deg_per_sec,
		"fire_stats": fs,
		"conservation_ok": audit.get("ok", false),
		"solution": _solution_meta,
	}
	var f := FileAccess.open(_report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	var pl := FileAccess.open(_report_path + ".progress.jsonl", FileAccess.WRITE)
	if pl != null:
		for line in _progress_lines:
			pl.store_line(JSON.stringify(line))
		pl.close()
	print("[replay] 结束 result=%s eff=%.1fs wall=%.1fs report=%s" % [outcome, eff, _t_wall, _report_path])
	# 结算屏停留 5s（关键帧/人工核验证据）后退出；退出码 0=胜 1=其他
	await _main.get_tree().create_timer(5.0).timeout
	_main.get_tree().quit(0 if outcome == "WON" else 1)
