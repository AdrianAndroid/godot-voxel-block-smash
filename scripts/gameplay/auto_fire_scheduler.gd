extends RefCounted
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

# 【新增代码】入槽自动连发调度器（GDD v6 §10 / G02 2026-10-26 用户规则：
# 炮台在炮位即连续发射，弹数0消失；多炮台独立冷却同时工作；点击槽不额外发射）。
# 只调用控制器既有 fire 原子接口，不改碰撞/消除核心。冷却按物理步时钟，不随渲染帧率。

var interval := 0.25          # 发射间隔秒数（执行默认值，可进 rules.auto_fire_interval）
var fire_by_slot := Callable()  # func(slot_index: int) -> Dictionary（控制器注入）
var slot_index_of := Callable() # func(turret_id: int) -> int（控制器注入，找不到返回 -1）

var _cooldowns: Dictionary = {}  # turret_id -> 剩余冷却秒
var _fail_streak: Dictionary = {}  # turret_id -> 连续失败次数（限频日志）


func setup(p_interval: float, p_fire: Callable, p_slot_index_of: Callable) -> void:
	interval = p_interval
	fire_by_slot = p_fire
	slot_index_of = p_slot_index_of


func register(turret_id: int) -> void:
	_cooldowns[turret_id] = 0.0  # 首发在下一物理步（§10）


func unregister(turret_id: int) -> void:
	_cooldowns.erase(turret_id)
	_fail_streak.erase(turret_id)


func clear() -> void:
	_cooldowns.clear()
	_fail_streak.clear()


func registered_count() -> int:
	return _cooldowns.size()


# 每物理步推进；同一轮到期的多个炮台按稳定 turret_id 顺序发射（下一发道具只被首个成功者消费）
func tick(dt: float) -> void:
	var _pt := PerfProbe.t0()
	if fire_by_slot.is_null() or slot_index_of.is_null():
		return
	var ids: Array = _cooldowns.keys()
	ids.sort()
	for id in ids:
		if not _cooldowns.has(id):
			continue  # 本轮发射导致的移除不追补
		_cooldowns[id] = float(_cooldowns[id]) - dt
		if float(_cooldowns[id]) > 0.0:
			continue
		var slot_index: int = slot_index_of.call(int(id))
		if slot_index < 0:
			_cooldowns.erase(id)  # 炮台已归零/取回
			_fail_streak.erase(id)
			continue
		var res: Dictionary = fire_by_slot.call(slot_index)
		if res.get("ok", false):
			_fail_streak.erase(id)
			if int(res.get("ammo_left", 1)) <= 0:
				_cooldowns.erase(id)  # 归零移除，已发射球继续飞行（G05）
			else:
				_cooldowns[id] = interval
		else:
			# 失败不扣弹、按冷却重试。CQ §2.3：等待同色目标/在途/弹尽结算中是正常等待，
			# 不算失败、不刷日志；其余原因限频告警（§10）
			var reason := str(res.get("reason", ""))
			if reason in ["waiting_target", "in_flight", "no_ammo", "scan_pending"]:
				_fail_streak.erase(id)
				_cooldowns[id] = interval
				continue
			var n := int(_fail_streak.get(id, 0)) + 1
			_fail_streak[id] = n
			_cooldowns[id] = interval
			if n <= 3 or n % 20 == 0:
				push_warning("auto_fire retry turret=%d n=%d reason=%s" % [id, n, reason])
	PerfProbe.add("scheduler_tick", _pt)
