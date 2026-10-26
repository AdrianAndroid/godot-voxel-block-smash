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
var rules_version := 2    # CQ/S09：规则版本（CQ 五列守恒规则=2；取回流程保留，版本维持 2）

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
		"rng_seed": str(rng_seed),    # FM/F4：uint64 按十进制字符串往返（JSON number 是 double 会丢精度）
		"rng_state": str(rng_state),
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
	rng_seed = _u64_from_json(snap.get("rng_seed", 0))
	rng_state = _u64_from_json(snap.get("rng_state", 0))
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


# FM/F4：uint64 与 JSON 往返——新档是十进制字符串；兼容旧档的 number（double 精度内安全值）
static func _u64_from_json(v: Variant) -> int:
	if v is String:
		return int(v)  # 十进制字符串无精度损失
	return int(v)  # 旧档 number（可能已被 double 截断，仅兼容路径）


# FM/F4：纯校验（不落任何状态）——start_level 先校验后 mutate，坏档不产生半步状态。
# 参数：level_id 归属、model_count 体素总数（alive 范围）、color_of 查色（守恒重算）、
# palette_color_ids 合法色、valid_states 状态白名单、max_slots 槽位数。
static func validate_snapshot(snap: Dictionary, level_id: String, model_count: int,
		color_of: Callable, palette_color_ids: Array, valid_states: Array, max_slots: int) -> Dictionary:
	if snap.get("version") != SNAPSHOT_VERSION:
		return {"ok": false, "error": "bad_version:%s" % str(snap.get("version"))}
	if str(snap.get("level_id", "")) != level_id:
		return {"ok": false, "error": "level_mismatch"}
	var turrets: Dictionary = snap.get("turrets", {})
	var queue_columns: Array = snap.get("queue_columns", [])
	var slots: Array = snap.get("slots", [])
	var alive: Array = snap.get("alive_voxel_ids", [])
	var unlocked := int(snap.get("unlocked_slots", 0))
	# alive 去重 + 范围
	var seen_v := {}
	for vid in alive:
		var id := int(vid)
		if id < 0 or id >= model_count:
			return {"ok": false, "error": "alive_out_of_range:%d" % id}
		if seen_v.has(id):
			return {"ok": false, "error": "alive_duplicate:%d" % id}
		seen_v[id] = true
	# 炮台字段 + 状态白名单 + 归属列 + 颜色
	var max_tid := 0
	for k in turrets:
		var t: Dictionary = turrets[k]
		var tid := int(t.get("turret_id", -1))
		if tid != int(k) or tid < 0:
			return {"ok": false, "error": "turret_id_mismatch:%s" % str(k)}
		max_tid = maxi(max_tid, tid)
		if not valid_states.has(str(t.get("state", ""))):
			return {"ok": false, "error": "invalid_state:%s:%d" % [str(t.get("state", "")), tid]}
		var oc := int(t.get("origin_column", -1))
		if oc < 0 or oc >= 5:
			return {"ok": false, "error": "bad_origin_column:%d" % tid}
		if not palette_color_ids.has(int(t.get("color_id", -1))):
			return {"ok": false, "error": "invalid_color:%d" % tid}
	if int(snap.get("next_turret_id", 0)) <= max_tid:
		return {"ok": false, "error": "next_turret_id_not_ahead:%d" % max_tid}
	# 引用存在且全局唯一（队列+槽）
	var seen := {}
	for col in queue_columns:
		for tid in (col as Array):
			var id := int(tid)
			if not turrets.has(id):
				return {"ok": false, "error": "queue_refs_missing_turret:%d" % id}
			if seen.has(id):
				return {"ok": false, "error": "duplicate_turret_ref:%d" % id}
			seen[id] = true
	for si in slots.size():
		var id := int(slots[si])
		# 锁定槽（未解锁位）必须为空 -1
		if si >= unlocked and id != -1:
			return {"ok": false, "error": "locked_slot_occupied:%d" % si}
		if id < 0:
			continue
		if si >= max_slots:
			return {"ok": false, "error": "slot_out_of_range:%d" % si}
		if not turrets.has(id):
			return {"ok": false, "error": "slot_refs_missing_turret:%d" % id}
		if seen.has(id):
			return {"ok": false, "error": "duplicate_turret_ref:%d" % id}
		seen[id] = true
	# 每色守恒重算：Q[c]+S[c]==V[c]（保存时已结算在途，F=0）
	var ammo_by_color := {}
	for k in turrets:
		var t: Dictionary = turrets[k]
		var cid := int(t.color_id)
		ammo_by_color[cid] = int(ammo_by_color.get(cid, 0)) + int(t.ammo_remaining)
	var alive_by_color := {}
	for vid in alive:
		var cid: int = int(color_of.call(int(vid)))
		alive_by_color[cid] = int(alive_by_color.get(cid, 0)) + 1
	for cid in alive_by_color:
		if int(ammo_by_color.get(cid, 0)) != int(alive_by_color[cid]):
			return {"ok": false, "error": "conservation_broken:color=%s" % str(cid)}
	for cid in ammo_by_color:
		if not alive_by_color.has(cid):
			return {"ok": false, "error": "ammo_without_voxels:color=%s" % str(cid)}
	return {"ok": true}
