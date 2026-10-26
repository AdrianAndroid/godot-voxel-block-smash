extends Node
class_name GameController
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

## 游戏主控：装配事件总线、关卡装载、体素管理、弹珠系统与玩法服务。
## CQ-20261026：五列守恒队列（S03）、一键上位/取回事务（S04）、
## 目标选择+射击账本+一发一块（S05：同色可达才发射，取消/失效返还，逐色守恒 Q+S+F=V）。

const LevelLoaderScript := preload("res://scripts/data/level_loader.gd")
const GameRulesScript := preload("res://scripts/data/game_rules.gd")
const VoxelManagerScript := preload("res://scripts/voxel/voxel_manager.gd")
const BallPhysicsScript := preload("res://scripts/projectile/ball_physics.gd")
const EventBusScript := preload("res://scripts/app/event_bus.gd")
const EventRecorderScript := preload("res://scripts/diagnostics/event_recorder.gd")
const LevelSessionScript := preload("res://scripts/level/level_session.gd")
const PoolService := preload("res://scripts/gameplay/cannon_queue_service.gd")  # CQ-20261026：队列服务替代旧池
const SlotService := preload("res://scripts/gameplay/slot_service.gd")
const MergeService := preload("res://scripts/gameplay/merge_service.gd")
const ComboStateScript := preload("res://scripts/gameplay/combo_state.gd")
const PropServiceScript := preload("res://scripts/gameplay/prop_service.gd")
const OutcomeStateScript := preload("res://scripts/gameplay/outcome_state.gd")
const LevelRepositoryScript := preload("res://scripts/level/level_repository.gd")
const AutoFireSchedulerScript := preload("res://scripts/gameplay/auto_fire_scheduler.gd")
const TargetSelectorScript := preload("res://scripts/gameplay/target_selector.gd")
const ShotLedgerScript := preload("res://scripts/gameplay/shot_ledger.gd")

const SHOT_TIMEOUT_SEC := 3.0  # CQ §2.3：在途弹超时取消返还（设计默认 3s）

var bus: RefCounted
var recorder: RefCounted
var session: RefCounted
var rules: RefCounted
var voxel_manager: RefCounted
var ball_physics: RefCounted
var voxel_model: Node3D  # VoxelModelNode
var combo: RefCounted
var props: RefCounted
var outcome_state: RefCounted
var auto_fire: RefCounted       # AutoFireScheduler
var target_selector: RefCounted  # CQ-20261026/S05
var shot_ledger: RefCounted      # CQ-20261026/S05
var origin_resolver := Callable()  # func(slot_index) -> {ok,origin,origin_grid|reason}，表现层注入

var _level_loader: RefCounted
var _rng := RandomNumberGenerator.new()
var _generation := 0
var _event_id := 0
var _tick := 0
var _shot_seq := 0
var _stopped := true   # 无活跃会话/已停止时不推进
var _paused := false   # 退后台暂停调度与物理推进


func _ready() -> void:
	bus = EventBusScript.new()
	recorder = EventRecorderScript.new()
	_level_loader = LevelLoaderScript.new()


func start_level(level_config_path: String, restore_snapshot: Dictionary = {}) -> Dictionary:
	var result: Dictionary = _level_loader.load_level(level_config_path)
	if not result.ok:
		return result
	_generation += 1
	_tick = 0
	_shot_seq = 0
	_stopped = false
	_paused = false
	_designated_slot = -1  # CQ/S08：选择模式 UI 态不跨局
	session = LevelSessionScript.new()
	session.level_id = result.config.level_id
	rules = GameRulesScript.from_rules(result.config.rules)

	# 每局全新总线，杜绝跨局订阅累积与 event_id 去重碰撞
	bus = EventBusScript.new()
	recorder.attach(bus, session.level_id)

	voxel_manager = VoxelManagerScript.new()
	if voxel_model != null:
		voxel_model.queue_free()
	voxel_model = preload("res://scenes/voxel/voxel_model.tscn").instantiate()
	voxel_model.attach(voxel_manager, result.voxel_data)
	add_child(voxel_model)

	# 有效色候选集 = 模型实际 color_ids 去重；V0[c]=开局该色体素数（守恒基准）
	var valid := {}
	var weights := {}
	for id in range(result.voxel_data.count):
		var cid: int = voxel_manager.color_of(id)
		valid[cid] = true
		weights[cid] = int(weights.get(cid, 0)) + 1
	if valid.is_empty():
		return {"ok": false, "error": "model_has_no_colors"}
	rules.palette_color_ids = valid.keys()
	rules.palette_color_ids.sort()
	rules.palette_weights = weights
	session.v0_counts = weights.duplicate()

	ball_physics = BallPhysicsScript.new()
	ball_physics.set_level(session.level_id)
	var data: RefCounted = result.voxel_data
	var extent: Vector3 = (data.bounds_max - data.bounds_min) * 0.5
	var half: float = maxf(extent.x, maxf(extent.y, extent.z)) + rules.boundary_margin
	# 出界判定在格空间进行，必须传格空间中心
	ball_physics.setup(bus, voxel_manager, data.center_offset(), half)

	combo = ComboStateScript.new()
	combo.setup(bus, session.level_id)
	props = PropServiceScript.new()
	props.setup(bus)
	outcome_state = OutcomeStateScript.new()
	outcome_state.setup(bus)
	shot_ledger = ShotLedgerScript.new()
	# CQ-20261026/S05：命中/取消统一由控制器按票据结算（替代旧 HitResolver 异色反弹）
	bus.subscribe("ball_hit_voxel", _on_ball_hit, session.level_id)
	bus.subscribe("ball_out_of_bounds", _on_ball_out_of_bounds, session.level_id)

	# CQ §2.3：只在有可达同色目标时发射（等待目标不扣弹不刷错误）
	auto_fire = AutoFireSchedulerScript.new()
	auto_fire.setup(rules.auto_fire_interval, try_auto_fire, _slot_index_of_turret)

	# CQ/S09：模型内容哈希（位置+颜色），存档与恢复一致性校验用
	var model_hash := _hash_model(data)
	if not restore_snapshot.is_empty():
		if not session.restore(restore_snapshot):
			return {"ok": false, "error": "snapshot_rejected"}
		# CQ/S09 §4：模型/规则版本变更 → 不静默迁移，由调用方备份旧档并重开
		if session.model_hash != model_hash:
			return {"ok": false, "error": "model_changed"}
		if session.rules_version != 2:
			return {"ok": false, "error": "rules_version_changed"}
		# 恢复后保留本次运行代号，不被历史存档代号覆盖
		session.session_generation = _generation
		# CQ/S09 §1：加载校验——ID 归属/颜色/每色守恒（无效色=坏档，拒绝而不静默迁移）
		var validation := _validate_restored()
		if not validation.get("ok", false):
			return {"ok": false, "error": "snapshot_invalid: %s" % str(validation.get("error", ""))}
		# 恢复 RNG 完整状态：同一随机序列继续（不重置为种子起点）
		_rng = RandomNumberGenerator.new()
		_rng.seed = session.rng_seed
		_rng.state = session.rng_state
		# 恢复存活集：删除不在快照中的体素
		var keep := {}
		for id in session.alive_voxel_ids:
			keep[int(id)] = true
		for id in range(data.count):
			if not keep.has(id):
				voxel_manager.destroy(id)
		# CQ-20261026/S05：恢复的有弹炮台重新注册调度，不补发离线期间弹药；
		# 快照前已结算/返还在途弹（save_session），恢复后在途恒为 0
		for si in session.slots.size():
			var tid := int(session.slots[si])
			if tid >= 0 and int(session.turrets.get(tid, {}).get("ammo_remaining", 0)) > 0:
				session.turrets[tid].state = PoolService.STATE_READY
				auto_fire.register(tid)
	else:
		# CQ-20261026/S03：队列 seed 来自关卡配置（经离线验证），专用 RNG 完全可复现
		_rng = RandomNumberGenerator.new()
		_rng.seed = int(result.config.get("queue_seed", 1))
		session.rng_seed = _rng.seed
		session.model_hash = model_hash
		session.session_generation = _generation
		session.prop_counts = rules.initial_props.duplicate()
		SlotService.init_slots(session)  # CQ-20261026/S04：固定五槽 -1 空位
		PoolService.generate(session, weights, _rng)  # CQ 五列守恒队列
		session.alive_voxel_ids = range(data.count).duplicate()

	# 目标选择器在存活集确定后初始化（表面前沿缓存）
	target_selector = TargetSelectorScript.new()
	target_selector.setup(voxel_manager, rules.ball_radius)

	bus.set_generation(session.level_id, session.session_generation)
	bus.publish("level_loaded", [session.level_id], _meta())
	return {"ok": true}


# 调度器按稳定 turret_id 定位固定槽位（空位不压缩）
func _slot_index_of_turret(turret_id: int) -> int:
	return SlotService.slot_index_of(session, turret_id)


# --- CQ-20261026/S04 一键上位与取回事务 ---

# 点击列首 → 原子检查空槽 → 移入最左空闲已解锁炮位 → 该列向上补位（无需再点炮位）
func place_front(column_id: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	if column_id < 0 or column_id >= PoolService.COLUMN_COUNT:
		return {"ok": false, "reason": "bad_column"}
	var tid := PoolService.front_of(session, column_id)
	if tid < 0:
		return {"ok": false, "reason": "empty_column"}
	var slot := SlotService.leftmost_free(session, rules)
	if slot < 0:
		return {"ok": false, "reason": "slots_full"}
	# 原子事务：先占槽再出列，任一步失败整体不变
	if not SlotService.place_at(session, slot, tid):
		return {"ok": false, "reason": "slots_full"}
	PoolService.pop_front(session, column_id)
	var t: Dictionary = session.turrets[tid]
	t.state = PoolService.STATE_READY  # LOADING 动画为表现层职责，逻辑即就绪
	auto_fire.register(tid)
	bus.publish("queue_changed", ["place", column_id, tid], _meta())
	bus.publish("slots_changed", [slot, tid], _meta())
	_evaluate_outcome()
	return {"ok": true, "turret_id": tid, "slot": slot}


# 取回：允许取回"没有在途弹"的炮台（即使发射过）；有在途弹先停新发射，结算后取回。
# 取回到来源列队首、保留当前弹数。
func return_turret(slot_index: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var tid := SlotService.slot_turret_id(session, slot_index)
	if tid < 0:
		return {"ok": false, "reason": "empty_slot"}
	var t: Dictionary = session.turrets.get(tid, {})
	if t.is_empty():
		return {"ok": false, "reason": "missing_turret"}
	if int(t.get("in_flight", 0)) > 0:
		# 有在途弹：停止新发射，标记待取回，结算/返还后完成（_settle_return_pending）
		if t.state != PoolService.STATE_RETURN_PENDING:
			t.state = PoolService.STATE_RETURN_PENDING
			auto_fire.unregister(tid)
			bus.publish("turret_state_changed", [tid, t.state], _meta())
		return {"ok": true, "pending": true, "turret_id": tid}
	_do_return_to_column(slot_index, tid)
	return {"ok": true, "pending": false, "turret_id": tid}


func _do_return_to_column(slot_index: int, turret_id: int) -> void:
	SlotService.remove_at(session, slot_index)
	auto_fire.unregister(turret_id)
	var t: Dictionary = session.turrets[turret_id]
	t.state = PoolService.STATE_QUEUED
	PoolService.push_front(session, turret_id)  # 回来源列队首
	bus.publish("slots_changed", [slot_index, -1], _meta())
	bus.publish("queue_changed", ["return", int(t.origin_column), turret_id], _meta())
	_evaluate_outcome()


# RETURN_PENDING 炮台的在途弹全部结算后完成取回（命中/取消路径调用）
func _settle_return_pending(turret_id: int) -> void:
	var t: Dictionary = session.turrets.get(turret_id, {})
	if t.is_empty() or t.state != PoolService.STATE_RETURN_PENDING:
		return
	if int(t.get("in_flight", 0)) > 0:
		return
	var slot := SlotService.slot_index_of(session, turret_id)
	if slot >= 0:
		_do_return_to_column(slot, turret_id)


# --- CQ-20261026/S05 目标化自动发射 ---

# 自动发射入口（调度器回调）：只有存在未预订、可到达的同色活体素时才发射；
# 未找到同色目标是正常等待（WAITING_TARGET），不扣弹、不刷错误日志、不判失败。
func try_auto_fire(slot_index: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var tid := SlotService.slot_turret_id(session, slot_index)
	if tid < 0:
		return {"ok": false, "reason": "empty_slot"}
	var t: Dictionary = session.turrets.get(tid, {})
	if t.is_empty():
		return {"ok": false, "reason": "missing_turret"}
	if int(t.ammo_remaining) <= 0:
		return {"ok": false, "reason": "no_ammo"}
	if int(t.get("in_flight", 0)) >= 1:
		return {"ok": false, "reason": "in_flight"}  # CQ §2.2：每炮最多一颗在途
	if origin_resolver.is_null():
		return {"ok": false, "reason": "no_origin_resolver"}
	var o: Dictionary = origin_resolver.call(slot_index)
	if not o.get("ok", false):
		return {"ok": false, "reason": "origin_%s" % str(o.get("reason", "failed"))}
	# CQ/S08 §2.4：指定目标优先——仍有效（存活+未预订）且可达则锁定它；
	# 失效则退出优先锁定（不退款已激活道具），恢复普通同色选靶。
	var _pt := PerfProbe.t0()
	var target: Dictionary = _designated_target_for(t, o)
	if target.is_empty():
		target = target_selector.find_target(int(t.color_id), o.origin_grid,
			shot_ledger.is_available)
	PerfProbe.add("find_target", _pt)
	if not target.get("ok", false):
		if t.state != PoolService.STATE_WAITING_TARGET:
			t.state = PoolService.STATE_WAITING_TARGET
			bus.publish("turret_state_changed", [tid, t.state], _meta())
		return {"ok": false, "reason": "waiting_target"}
	return _fire_at(slot_index, tid, t, o, target)


# 发射事务：预订目标 → 生成球（首个命中即停）→ 成功才扣弹（S-- F++）→ 失败整体不发生
func _fire_at(slot_index: int, tid: int, t: Dictionary, origin: Dictionary, target: Dictionary) -> Dictionary:
	var speed_mod := 2.0 if session.pending_effects.speed_x2 else 1.0
	_shot_seq += 1
	var booked: Dictionary = shot_ledger.create_ticket(_shot_seq, tid,
		int(target.voxel_id), int(t.color_id), session.session_generation, speed_mod)
	if not booked.get("ok", false):
		return {"ok": false, "reason": "reserve_failed"}  # 被并发预订：下周期重试，不扣弹
	var wfg: Transform3D = voxel_model.world_from_grid()
	var target_world: Vector3 = wfg * target.target_grid_center
	var dir: Vector3 = (target_world - origin.origin).normalized()
	if dir.length_squared() < 0.5:
		shot_ledger.settle_cancel(_shot_seq)
		return {"ok": false, "reason": "bad_direction"}
	var ball_id: int = ball_physics.spawn_ball(origin.origin, dir * rules.ball_speed * speed_mod,
		_shot_seq, int(t.color_id), true)  # stop_on_hit：一发一块即回收（CQ/S08 已移除异色万能弹）
	if ball_id <= 0:
		shot_ledger.settle_cancel(_shot_seq)
		return {"ok": false, "reason": "spawn_failed"}  # 不扣弹（G05）
	shot_ledger.attach_ball(_shot_seq, ball_id)
	t.ammo_remaining = int(t.ammo_remaining) - 1  # S--
	t.has_fired = true
	t["in_flight"] = int(t.get("in_flight", 0)) + 1  # F++
	session.pending_effects.speed_x2 = false  # 成功生成后按旧规则消费（CQ §2.4）
	if int(t.ammo_remaining) <= 0:
		# CQ §2.2：归零暂留原槽"结算中"，不再发射；最后一发结算后才移除
		t.state = PoolService.STATE_DRAINING
		auto_fire.unregister(tid)
	else:
		t.state = PoolService.STATE_FIRING
	var fired_snapshot: Dictionary = t.duplicate(true)
	fired_snapshot["target_voxel_id"] = int(target.voxel_id)
	bus.publish("turret_fire", [fired_snapshot, ball_id], _meta())
	_evaluate_outcome()
	return {"ok": true, "ball_id": ball_id, "ammo_left": t.ammo_remaining,
		"target_voxel_id": int(target.voxel_id)}


# --- CQ/S08 指定目标（designated_target，替代旧"任意指"异色万能弹路径） ---
# 流程：道具激活只进入选择模式（不扣次）→ 点炮位选炮 → 点模型选同色/可达/未预订体素，
# 合法选择被接受时才扣次；取消/异色/不可达不扣次；目标失效退出优先锁定、不退款（记录提示）。

var _designated_slot := -1  # 选择模式 UI 态（不落盘；恢复/重开自动为空）


func designated_state() -> Dictionary:
	if session == null:
		return {"selecting": false, "slot": -1}
	return {"selecting": bool(session.pending_effects.get("designated_selecting", false)),
		"slot": _designated_slot}


func designated_cancel() -> void:
	if session != null:
		session.pending_effects["designated_selecting"] = false
	_designated_slot = -1


func designated_select_turret(slot_index: int) -> Dictionary:
	if session == null or not bool(session.pending_effects.get("designated_selecting", false)):
		return {"ok": false, "reason": "not_selecting"}
	var tid := SlotService.slot_turret_id(session, slot_index)
	if tid < 0:
		return {"ok": false, "reason": "empty_slot"}
	var t: Dictionary = session.turrets.get(tid, {})
	if int(t.get("ammo_remaining", 0)) <= 0:
		return {"ok": false, "reason": "no_ammo"}
	_designated_slot = slot_index
	return {"ok": true, "turret_id": tid, "color_id": int(t.color_id)}


func designated_select_voxel(screen: Vector2, camera: Camera3D) -> Dictionary:
	if session == null or not bool(session.pending_effects.get("designated_selecting", false)):
		return {"ok": false, "reason": "not_selecting"}
	if _designated_slot < 0:
		return {"ok": false, "reason": "no_turret"}
	var tid := SlotService.slot_turret_id(session, _designated_slot)
	var t: Dictionary = session.turrets.get(tid, {})
	if tid < 0 or t.is_empty():
		_designated_slot = -1
		return {"ok": false, "reason": "turret_gone"}
	var vid := _pick_voxel(screen, camera)
	if vid < 0:
		return {"ok": false, "reason": "no_voxel"}
	if int(voxel_manager.color_of(vid)) != int(t.color_id):
		return {"ok": false, "reason": "wrong_color"}   # 异色不扣次
	if not shot_ledger.is_available(vid):
		return {"ok": false, "reason": "reserved"}      # 已预订不扣次
	if origin_resolver.is_null():
		return {"ok": false, "reason": "no_origin_resolver"}
	var o: Dictionary = origin_resolver.call(_designated_slot)
	if not o.get("ok", false) or not target_selector.confirm_reachable(vid, o.origin_grid):
		return {"ok": false, "reason": "unreachable"}    # 不可达不扣次
	# 合法选择被接受：此时才扣次（CQ §2.4）
	t["designated_target"] = vid
	var before := int(session.prop_counts.get("designated_target", 0))
	session.prop_counts["designated_target"] = before - 1
	session.pending_effects["designated_selecting"] = false
	_designated_slot = -1
	bus.publish("item_activated", ["designated_target", before, before - 1], _meta())
	bus.publish("turret_state_changed", [tid, str(t.get("state", ""))], _meta())
	return {"ok": true, "turret_id": tid, "voxel_id": vid}


func _pick_voxel(screen: Vector2, camera: Camera3D) -> int:
	if camera == null or voxel_model == null:
		return -1
	var gfw: Transform3D = voxel_model.world_from_grid().affine_inverse()
	var from: Vector3 = gfw * camera.project_ray_origin(screen)
	var dir: Vector3 = (gfw.basis * camera.project_ray_normal(screen)).normalized()
	return target_selector.pick_voxel(from, dir, 200.0)


# 自动发射的指定目标优先：仍有效（存活+未预订+可达）则锁定；失效清除并提示，不退款
func _designated_target_for(t: Dictionary, o: Dictionary) -> Dictionary:
	var dvid := int(t.get("designated_target", -1))
	if dvid < 0:
		return {}
	if voxel_manager.is_alive(dvid) and shot_ledger.is_available(dvid) \
			and target_selector.confirm_reachable(dvid, o.origin_grid):
		return {"ok": true, "voxel_id": dvid,
			"target_grid_center": voxel_manager.data.positions[dvid] + Vector3(0.5, 0.5, 0.5)}
	t["designated_target"] = -1
	bus.publish("designated_expired", [int(t.turret_id)], _meta())
	return {}


# 命中处理（CQ §2.2/§2.3 事务）：命中预订目标且同色 → 删除提交（F-- V-- D++）；
# 命中其他体素（异色遮挡/途中旋转改变弹道）→ 取消返还（F-- S++）。随后球已停（stop_on_hit）。
func _on_ball_hit(args: Array, meta: Dictionary) -> void:
	if session.outcome != "RUNNING":
		return
	var ball: Dictionary = args[0]
	var block: Dictionary = args[1]
	var ticket: Dictionary = shot_ledger.ticket_by_shot(int(ball.get("shot_id", 0)))
	if ticket.is_empty() or ticket.status != "PENDING":
		return  # 旧代/已结算：幂等忽略
	var vid := int(block.get("voxel_id", -1))
	if vid == int(ticket.target_voxel_id) and voxel_manager.is_alive(vid) \
			and int(block.get("color_id", -2)) == int(ticket.color_id):
		shot_ledger.settle_hit(int(ticket.shot_id))
		var res: Dictionary = voxel_manager.destroy(vid)
		if res.get("ok", false):
			target_selector.on_voxel_destroyed(vid)
			bus.publish("voxel_destroyed", [res.block, ball], _meta())
			combo.on_destroy(_meta())
			_settle_ticket(ticket, false)
			bus.publish("shot_resolved", [int(ticket.shot_id), "HIT", vid], _meta())
		else:
			# 理论不发生（目标有预订保护）；防御：删除失败按取消返还
			_refund_ticket(ticket, "destroy_failed")
	else:
		_refund_ticket(ticket, "mismatch")
	_evaluate_outcome()


func _on_ball_out_of_bounds(args: Array, meta: Dictionary) -> void:
	var ball: Dictionary = args[0]
	ball_physics.system.end_ball(int(ball.ball_id))
	var ticket: Dictionary = shot_ledger.ticket_by_shot(int(ball.get("shot_id", 0)))
	if ticket.is_empty():
		return
	if ticket.status == "PENDING":
		# 出界/超时/逃逸：取消返还（hit_stop 的票已在命中处理器结算，这里幂等）
		_refund_ticket(ticket, str(ball.get("reason", "out_of_bounds")))


# 取消返还：F-- S++（CQ §2.2）；归零炮台返还后恢复可发射
func _refund_ticket(ticket: Dictionary, reason: String) -> void:
	shot_ledger.settle_cancel(int(ticket.shot_id))
	var tid := int(ticket.turret_id)
	var t: Dictionary = session.turrets.get(tid, {})
	if not t.is_empty():
		t.ammo_remaining = int(t.ammo_remaining) + 1  # S++
		if t.state == PoolService.STATE_DRAINING:
			t.state = PoolService.STATE_READY
			auto_fire.register(tid)  # 返还恢复发射资格
	_settle_ticket(ticket, true)
	bus.publish("shot_resolved", [int(ticket.shot_id), "CANCELLED:" + reason,
		int(ticket.target_voxel_id)], _meta())


# 票据结算后的槽位收尾：F--；归零炮台最后一发结算完成才移除；RETURN_PENDING 收尾
func _settle_ticket(ticket: Dictionary, _refunded: bool) -> void:
	var tid := int(ticket.turret_id)
	if not session.turrets.has(tid):
		return
	var t: Dictionary = session.turrets[tid]
	t["in_flight"] = maxi(0, int(t.get("in_flight", 0)) - 1)  # F--
	if int(t.get("in_flight", 0)) > 0:
		return
	if t.state == PoolService.STATE_DRAINING:
		var slot := SlotService.slot_index_of(session, tid)
		if slot >= 0:
			SlotService.remove_at(session, slot)
			session.turrets.erase(tid)  # 弹药耗尽的炮台彻底离场（守恒：弹药已转移为 D）
			bus.publish("slots_changed", [slot, -1], _meta())
	elif t.state == PoolService.STATE_FIRING:
		t.state = PoolService.STATE_READY
	_settle_return_pending(tid)


# --- CQ-20261026 §2.4 合成（显式模式内两列列首，HUD 控制进入） ---

func merge_columns(col_a: int, col_b: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var res: Dictionary = MergeService.merge_columns(session, rules, col_a, col_b)
	if res.ok:
		bus.publish("turret_merged", [res.turret, res.merged_id], _meta())
		bus.publish("queue_changed", ["merge", col_a, col_b], _meta())
		_evaluate_outcome()
	return res


# --- 道具 ---

func use_prop(prop: String) -> Dictionary:
	var res: Dictionary = props.use(session, rules, prop, _rng, _meta())
	if res.get("ok", false):
		_evaluate_outcome()
	return res


# 会话边界：停止推进/调度（返回列表、结算、重开前调用）
func stop_session() -> void:
	_stopped = true
	if auto_fire != null:
		auto_fire.clear()


# 退后台暂停：调度与物理同时冻结，恢复不补发
func set_paused(paused: bool) -> void:
	_paused = paused


func is_running() -> bool:
	return not _stopped and not _paused and session != null and session.outcome == "RUNNING"


# --- 帧驱动：超时取消 → 自动连发调度 → 物理步进 → 连击计时/胜负 ---

func step(dt: float) -> void:
	if not is_running():
		return
	_tick += 1
	# CQ §2.3：在途弹超时取消返还（默认 3s）
	for ticket in shot_ledger.advance_time(dt, SHOT_TIMEOUT_SEC):
		if int(ticket.ball_id) > 0:
			ball_physics.system.end_ball(int(ticket.ball_id))
		_refund_ticket(ticket, "timeout")
	auto_fire.tick(dt)  # 先于物理步：本轮新球当步参与扫掠
	ball_physics.physics_step(dt, voxel_model.world_from_grid(),
		session.session_generation, _tick)
	combo.tick(dt, _meta())
	shot_ledger.compact()
	_evaluate_outcome()


func _physics_process(delta: float) -> void:
	step(delta)


func _evaluate_outcome() -> void:
	if session == null:
		return
	# CQ/S08 §4：胜利需无未结算票据；死局判负由完整性错误取代（§6）
	outcome_state.evaluate(session, voxel_manager.alive_count(),
		ball_physics.system.active_count(), shot_ledger.pending_count(),
		session.level_id, _meta())


# CQ §2.2 分色守恒审计：Q[c]+S[c]+F[c]==V[c]，V[c]+D[c]==V0[c]
func conservation_audit() -> Dictionary:
	var q := {}
	var s := {}
	for tid in session.turrets:
		var t: Dictionary = session.turrets[tid]
		if int(t.get("in_flight", 0)) < 0:
			return {"ok": false, "error": "negative_in_flight"}
		var in_slot := SlotService.slot_index_of(session, int(tid)) >= 0
		var dst: Dictionary = s if in_slot else q
		dst[t.color_id] = int(dst.get(t.color_id, 0)) + int(t.ammo_remaining)
	var f: Dictionary = shot_ledger.in_flight_by_color()
	var v := {}
	var alive: Array = voxel_manager.state.alive_ids()
	for vid in alive:
		var cid := int(voxel_manager.color_of(int(vid)))
		v[cid] = int(v.get(cid, 0)) + 1
	var ok := true
	var per := {}
	for cid in session.v0_counts:
		var qc := int(q.get(cid, 0))
		var sc := int(s.get(cid, 0))
		var fc := int(f.get(cid, 0))
		var vc := int(v.get(cid, 0))
		var v0 := int(session.v0_counts[cid])
		var good: bool = (qc + sc + fc == vc) and (vc <= v0)
		per[cid] = {"Q": qc, "S": sc, "F": fc, "V": vc, "V0": v0, "ok": good}
		if not good:
			ok = false
	return {"ok": ok, "per_color": per}


func save_session() -> Dictionary:
	# CQ-20261026/S09：快照前先结算/返还在途弹（PENDING 票据不落盘）
	for id in shot_ledger.tickets.keys():
		var t: Dictionary = shot_ledger.tickets[id]
		if t.status == "PENDING":
			if int(t.ball_id) > 0:
				ball_physics.system.end_ball(int(t.ball_id))
			_refund_ticket(t, "save_settle")
	session.alive_voxel_ids = voxel_manager.state.alive_ids()
	session.rng_state = _rng.state  # CQ/S09：RNG 完整状态随档
	return LevelRepositoryScript.save(session.to_snapshot())


# CQ/S09 §1：模型内容哈希（逐体素 坐标+颜色 MD5；模型变更 → 旧档作废重开）
func _hash_model(data: RefCounted) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for id in range(data.count):
		var pos: Vector3 = data.positions[id]
		ctx.update(PackedFloat32Array([pos.x, pos.y, pos.z,
			float(voxel_manager.color_of(id))]).to_byte_array())
	return ctx.finish().hex_encode()


# CQ/S09 §1：恢复校验——队列/槽引用的炮台存在且全局唯一、归属列合法、颜色合法、
# 每色守恒 Q[c]+S[c]==V[c]（保存时已结算在途，F=0）。失败即拒绝，不静默修复。
func _validate_restored() -> Dictionary:
	var seen := {}
	for c in session.queue_columns.size():
		for tid in session.queue_columns[c]:
			var id := int(tid)
			if not session.turrets.has(id):
				return {"ok": false, "error": "queue_refs_missing_turret:%d" % id}
			if seen.has(id):
				return {"ok": false, "error": "duplicate_turret_ref:%d" % id}
			seen[id] = true
	for si in session.slots.size():
		var id := int(session.slots[si])
		if id < 0:
			continue
		if not session.turrets.has(id):
			return {"ok": false, "error": "slot_refs_missing_turret:%d" % id}
		if seen.has(id):
			return {"ok": false, "error": "duplicate_turret_ref:%d" % id}
		seen[id] = true
	for tid in session.turrets:
		var t: Dictionary = session.turrets[tid]
		var oc := int(t.get("origin_column", -1))
		if oc < 0 or oc >= 5:
			return {"ok": false, "error": "bad_origin_column:%d" % int(tid)}
		if not rules.palette_color_ids.has(int(t.color_id)):
			return {"ok": false, "error": "invalid_color:%d" % int(tid)}
	# 每色守恒（迁移后的颜色计入）
	var ammo_by_color := {}
	for tid in session.turrets:
		var t: Dictionary = session.turrets[tid]
		ammo_by_color[t.color_id] = int(ammo_by_color.get(t.color_id, 0)) + int(t.ammo_remaining)
	var alive_by_color := {}
	for vid in session.alive_voxel_ids:
		var cid: int = voxel_manager.color_of(int(vid))
		alive_by_color[cid] = int(alive_by_color.get(cid, 0)) + 1
	for cid in alive_by_color:
		if int(ammo_by_color.get(cid, 0)) != int(alive_by_color[cid]):
			return {"ok": false, "error": "conservation_broken:color=%s" % str(cid)}
	for cid in ammo_by_color:
		if not alive_by_color.has(cid):
			return {"ok": false, "error": "ammo_without_voxels:color=%s" % str(cid)}
	return {"ok": true}


func _meta() -> Dictionary:
	return {"event_id": _next_event_id.call(), "level_id": session.level_id,
		"session_generation": session.session_generation, "physics_tick": _tick}


func _next_event_id() -> int:
	_event_id += 1
	return _event_id
