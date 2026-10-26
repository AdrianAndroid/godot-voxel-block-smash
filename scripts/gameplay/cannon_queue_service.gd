extends RefCounted

# CQ-20261026/S03：五列可变长守恒队列（替代旧 3×3 池）。
# 生成：每色 V0[c] 整数拆分为普通炮 30~80 发（末门余数允许 1~29，不丢余数、不四舍五入），
# 再把这些固定炮台分配到五列（每列至少一门，长度随机差异）；专用 RNG + seed 完全可复现。
# 守恒：生成后 sum(Q[c]) == V0[c] 逐色成立；本服务不凭空造弹。
# 所有权：炮台只存在于 session.turrets；queue_columns 只存 turret_id 引用。

const COLUMN_COUNT := 5
const AMMO_MIN := 30
const AMMO_MAX := 80

# CannonState.state 取值（QUEUED/LOADING/READY/WAITING_TARGET/FIRING/RETURN_PENDING/DRAINING）
const STATE_QUEUED := "QUEUED"
const STATE_LOADING := "LOADING"
const STATE_READY := "READY"
const STATE_WAITING_TARGET := "WAITING_TARGET"
const STATE_FIRING := "FIRING"
const STATE_RETURN_PENDING := "RETURN_PENDING"
const STATE_DRAINING := "DRAINING"


# 单色拆分：返回弹数数组，总和 == total。total<=0 返回空；total<=80 单炮（<30 视为余数炮）。
static func split_color_ammo(total: int, rng: RandomNumberGenerator) -> Array[int]:
	var parts: Array[int] = []
	var rest := total
	while rest > AMMO_MAX:
		var c := -1
		# 拒绝采样：要求余下 rest-c ∈ [1,29]∪[30,80]（不含 0：rest>80 时 c<rest 恒成立）
		for _try in 16:
			var cand := rng.randi_range(AMMO_MIN, AMMO_MAX)
			var left := rest - cand
			if (left >= 1 and left <= 29) or (left >= AMMO_MIN and left <= AMMO_MAX):
				c = cand
				break
		if c < 0:
			# 确定性兜底：c=clamp(rest-80,30,80) 恒合法（rest>=81 时 rest-c ∈ [30,80]）
			c = clampi(rest - AMMO_MAX, AMMO_MIN, AMMO_MAX)
		parts.append(c)
		rest -= c
	if rest > 0:
		parts.append(rest)  # 末门：1~29 余数或 30~80 正常
	return parts


# 生成五列队列。color_counts: {color_id: V0}。填充 session.turrets / session.queue_columns。
# 分配：全部炮台洗牌后前 5 门每列一门，其余随机落列（总炮数<5 时有多少放多少列）。
static func generate(session: RefCounted, color_counts: Dictionary, rng: RandomNumberGenerator) -> void:
	session.turrets.clear()
	session.queue_columns.clear()
	for i in COLUMN_COUNT:
		session.queue_columns.append([])
	var ids: Array = color_counts.keys()
	ids.sort()  # 固定遍历顺序，保证同 seed 复现
	var all: Array[int] = []  # turret_id 创建顺序
	for cid in ids:
		for ammo in split_color_ammo(int(color_counts[cid]), rng):
			var tid := int(session.next_turret_id)
			session.next_turret_id += 1
			session.turrets[tid] = {
				"turret_id": tid, "color_id": int(cid), "ammo_remaining": ammo,
				"origin_column": -1, "state": STATE_QUEUED, "has_fired": false,
			}
			all.append(tid)
	# Fisher-Yates（专用 rng）
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := all[i]
		all[i] = all[j]
		all[j] = tmp
	for k in all.size():
		var col := k if k < COLUMN_COUNT else rng.randi_range(0, COLUMN_COUNT - 1)
		var tid := all[k]
		session.queue_columns[col].append(tid)
		session.turrets[tid].origin_column = col


# 逐色守恒审计：{color_id: {queue, expect, ok}}，全部一致才 ok
static func conservation_report(session: RefCounted, color_counts: Dictionary) -> Dictionary:
	var q := {}
	for tid in session.turrets:
		var t: Dictionary = session.turrets[tid]
		q[t.color_id] = int(q.get(t.color_id, 0)) + int(t.ammo_remaining)
	var ok := true
	var per := {}
	for cid in color_counts:
		var have := int(q.get(cid, 0))
		var want := int(color_counts[cid])
		per[cid] = {"queue": have, "expect": want, "ok": have == want}
		if have != want:
			ok = false
	for cid in q:  # 队列里出现模型外的颜色也算失败
		if not color_counts.has(cid):
			per[cid] = {"queue": q[cid], "expect": 0, "ok": false}
			ok = false
	return {"ok": ok, "per_color": per}


static func front_of(session: RefCounted, column: int) -> int:
	if column < 0 or column >= session.queue_columns.size():
		return -1
	var col: Array = session.queue_columns[column]
	return int(col[0]) if not col.is_empty() else -1


static func pop_front(session: RefCounted, column: int) -> int:
	var tid := front_of(session, column)
	if tid >= 0:
		session.queue_columns[column].remove_at(0)
	return tid


# 取回：放回来源列队首（CQ §2.1）。turret 当前不得在队列中。
static func push_front(session: RefCounted, turret_id: int) -> void:
	var t: Dictionary = session.turrets.get(turret_id, {})
	if t.is_empty():
		return
	session.queue_columns[int(t.origin_column)].push_front(turret_id)


static func column_lengths(session: RefCounted) -> Array[int]:
	var out: Array[int] = []
	for col in session.queue_columns:
		out.append((col as Array).size())
	return out


# 随机排（CQ §2.4）：只重排五列中的现有 turret_id，保留 ID/颜色/弹量；无变化余地则不执行
static func shuffle_columns(session: RefCounted, rng: RandomNumberGenerator) -> bool:
	var total := 0
	for col in session.queue_columns:
		total += (col as Array).size()
	if total < 2:
		return false
	for col in session.queue_columns:
		var a: Array = col
		for i in range(a.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = a[i]
			a[i] = a[j]
			a[j] = tmp
	return true
