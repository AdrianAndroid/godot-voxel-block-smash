extends RefCounted

# 关卡会话：每关独立状态快照与隔离（架构 v6：绑定 level_id 和 session_generation）
# CQ-20261026：v2 快照 = 五列队列 + turrets 字典 + 固定五槽（turret_id/-1）。
# 飞行球/连击不保存（D09）；v1 旧档由 main 备份后弃用、本关重新开始（S09 完善模型哈希校验）。

const SNAPSHOT_VERSION := 2

var level_id := ""
var session_generation := 0
var rng_seed := 0
var rng_state := 0        # CQ/S09：RNG 完整状态（恢复后继续同一随机序列）
var model_hash := ""      # CQ/S09：模型内容哈希（模型变更→旧档作废）
var rules_version := 2    # CQ/S09：规则版本（CQ 五列守恒规则=2）

# 会话状态
var alive_voxel_ids: Array = []
var turrets: Dictionary = {}    # turret_id -> {turret_id,color_id,ammo_remaining,origin_column,state,has_fired,in_flight}
var queue_columns: Array = []   # Array[5]，每列 Array[turret_id]，索引0=列首
var slots: Array = []           # 固定5格，元素 turret_id 或 -1
var unlocked_slots := 3
var prop_counts: Dictionary = {"speed_x2": 3, "add_slot": 1, "designated_target": 2, "shuffle": 2}  # CQ/S08：任意指→指定目标
var pending_effects: Dictionary = {"speed_x2": false, "designated_selecting": false}  # CQ/S08
var outcome := "RUNNING"        # RUNNING/WON/ERROR（CQ/S08：死局判负由完整性错误取代）
var next_turret_id := 1
var v0_counts: Dictionary = {}  # CQ-20261026：开局每色体素数 V0[c]（守恒审计基准）


func to_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"level_id": level_id,
		"session_generation": session_generation,
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"model_hash": model_hash,
		"rules_version": rules_version,
		"alive_voxel_ids": alive_voxel_ids.duplicate(),
		"turrets": turrets.duplicate(true),
		"queue_columns": queue_columns.duplicate(true),
		"slots": slots.duplicate(),
		"unlocked_slots": unlocked_slots,
		"prop_counts": prop_counts.duplicate(),
		"pending_effects": pending_effects.duplicate(),
		"outcome": outcome,
		"next_turret_id": next_turret_id,
		"v0_counts": v0_counts.duplicate(),
	}


func restore(snap: Dictionary) -> bool:
	if snap.get("version") != SNAPSHOT_VERSION or snap.get("level_id") != level_id:
		return false  # 拒绝不兼容数据，不静默覆盖
	session_generation = int(snap.session_generation)
	rng_seed = int(snap.rng_seed)
	rng_state = int(snap.get("rng_state", 0))
	model_hash = str(snap.get("model_hash", ""))
	rules_version = int(snap.get("rules_version", 0))
	alive_voxel_ids = snap.alive_voxel_ids.duplicate()
	# JSON 往返后字典键/数值均为 String/float，统一归一为 int 键 + int 字段
	turrets = {}
	for k in snap.turrets:
		var t: Dictionary = (snap.turrets[k] as Dictionary).duplicate(true)
		t.turret_id = int(t.turret_id)
		t.color_id = int(t.color_id)
		t.ammo_remaining = int(t.ammo_remaining)
		t.origin_column = int(t.origin_column)
		t["in_flight"] = int(t.get("in_flight", 0))
		turrets[int(k)] = t
	queue_columns = []
	for col in snap.queue_columns:
		var ids: Array = []
		for tid in col:
			ids.append(int(tid))
		queue_columns.append(ids)
	slots = []
	for tid in snap.slots:
		slots.append(int(tid))
	unlocked_slots = int(snap.unlocked_slots)
	prop_counts = snap.prop_counts.duplicate()
	pending_effects = snap.pending_effects.duplicate()
	# CQ/S08 迁移：旧档 any_color → designated_target；选择模式不落盘（恢复后不处于选择中）
	if prop_counts.has("any_color"):
		prop_counts["designated_target"] = int(prop_counts.get("designated_target", 0)) \
			+ int(prop_counts["any_color"])
		prop_counts.erase("any_color")
	pending_effects.erase("any_color")
	pending_effects["designated_selecting"] = false
	outcome = snap.outcome
	next_turret_id = int(snap.next_turret_id)
	v0_counts = {}
	for k in snap.get("v0_counts", {}):
		v0_counts[int(k)] = int(snap.v0_counts[k])
	return true
