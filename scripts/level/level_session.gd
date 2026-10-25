extends RefCounted

# 关卡会话：每关独立状态快照与隔离（架构 v6：绑定 level_id 和 session_generation）
# 阶段：阶段3契约，阶段4填充业务字段。飞行球/连击不保存（D09）

const SNAPSHOT_VERSION := 1

var level_id := ""
var session_generation := 0
var rng_seed := 0

# 会话状态（阶段4填充语义，此处仅定义结构）
var alive_voxel_ids: Array = []
var pool: Array = []            # 9 格，元素为 turret 字典或 {}
var slots: Array = []           # 最多5，元素为 turret 字典或 {}
var unlocked_slots := 3
var prop_counts: Dictionary = {"speed_x2": 3, "add_slot": 1, "any_color": 2, "shuffle": 2}
var pending_effects: Dictionary = {"speed_x2": false, "any_color": false}
var outcome := "RUNNING"        # RUNNING/WON/LOST
var next_turret_id := 1


func to_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"level_id": level_id,
		"session_generation": session_generation,
		"rng_seed": rng_seed,
		"alive_voxel_ids": alive_voxel_ids.duplicate(),
		"pool": pool.duplicate(true),
		"slots": slots.duplicate(true),
		"unlocked_slots": unlocked_slots,
		"prop_counts": prop_counts.duplicate(),
		"pending_effects": pending_effects.duplicate(),
		"outcome": outcome,
		"next_turret_id": next_turret_id,
	}


func restore(snap: Dictionary) -> bool:
	if snap.get("version") != SNAPSHOT_VERSION or snap.get("level_id") != level_id:
		return false  # 拒绝不兼容数据，不静默覆盖
	session_generation = int(snap.session_generation)
	rng_seed = int(snap.rng_seed)
	alive_voxel_ids = snap.alive_voxel_ids.duplicate()
	pool = snap.pool.duplicate(true)
	slots = snap.slots.duplicate(true)
	unlocked_slots = int(snap.unlocked_slots)
	prop_counts = snap.prop_counts.duplicate()
	pending_effects = snap.pending_effects.duplicate()
	outcome = snap.outcome
	next_turret_id = int(snap.next_turret_id)
	return true
