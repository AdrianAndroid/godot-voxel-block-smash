extends Node
class_name GameController

## 游戏主控：装配事件总线、关卡装载、体素管理、弹珠系统与玩法服务。
## 阶段4：发射事务/合成/同色消除/连击/道具/胜负/关卡切换编排。

const LevelLoaderScript := preload("res://scripts/data/level_loader.gd")
const GameRulesScript := preload("res://scripts/data/game_rules.gd")
const VoxelManagerScript := preload("res://scripts/voxel/voxel_manager.gd")
const BallPhysicsScript := preload("res://scripts/projectile/ball_physics.gd")
const EventBusScript := preload("res://scripts/app/event_bus.gd")
const EventRecorderScript := preload("res://scripts/diagnostics/event_recorder.gd")
const LevelSessionScript := preload("res://scripts/level/level_session.gd")
const PoolService := preload("res://scripts/gameplay/pool_service.gd")
const SlotService := preload("res://scripts/gameplay/slot_service.gd")
const MergeService := preload("res://scripts/gameplay/merge_service.gd")
const ComboStateScript := preload("res://scripts/gameplay/combo_state.gd")
const PropServiceScript := preload("res://scripts/gameplay/prop_service.gd")
const HitResolverScript := preload("res://scripts/gameplay/hit_resolver.gd")
const OutcomeStateScript := preload("res://scripts/gameplay/outcome_state.gd")
const LevelRepositoryScript := preload("res://scripts/level/level_repository.gd")

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

var _level_loader: RefCounted
var _hit_resolver: RefCounted
var _rng := RandomNumberGenerator.new()
var _generation := 0
var _event_id := 0
var _tick := 0
var _shot_seq := 0


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
	session = LevelSessionScript.new()
	session.level_id = result.config.level_id
	session.session_generation = _generation
	rules = GameRulesScript.from_rules(result.config.rules)
	bus.set_generation(session.level_id, _generation)
	recorder.attach(bus, session.level_id)

	voxel_manager = VoxelManagerScript.new()
	if voxel_model != null:
		voxel_model.queue_free()
	voxel_model = preload("res://scenes/voxel/voxel_model.tscn").instantiate()
	voxel_model.attach(voxel_manager, result.voxel_data)
	add_child(voxel_model)

	ball_physics = BallPhysicsScript.new()
	ball_physics.set_level(session.level_id)
	var data: RefCounted = result.voxel_data
	var extent: Vector3 = (data.bounds_max - data.bounds_min) * 0.5
	var half: float = maxf(extent.x, maxf(extent.y, extent.z)) + rules.boundary_margin
	var center_world: Vector3 = voxel_model.world_from_grid() * data.center_offset()
	ball_physics.setup(bus, voxel_manager, center_world, half)

	combo = ComboStateScript.new()
	combo.setup(bus, session.level_id)
	props = PropServiceScript.new()
	props.setup(bus)
	outcome_state = OutcomeStateScript.new()
	outcome_state.setup(bus)
	_hit_resolver = HitResolverScript.new()
	_hit_resolver.setup(bus, session, voxel_manager, combo, session.level_id, _next_event_id)
	bus.subscribe("ball_out_of_bounds", _on_ball_out_of_bounds, session.level_id)

	if not restore_snapshot.is_empty():
		if not session.restore(restore_snapshot):
			return {"ok": false, "error": "snapshot_rejected"}
		# 恢复存活集：删除不在快照中的体素
		var keep := {}
		for id in session.alive_voxel_ids:
			keep[int(id)] = true
		for id in range(data.count):
			if not keep.has(id):
				voxel_manager.destroy(id)
	else:
		_rng.randomize()
		session.rng_seed = _rng.seed
		PoolService.generate_pool(session, rules, _rng)
		session.alive_voxel_ids = range(data.count).duplicate()

	bus.publish("level_loaded", [session.level_id], _meta())
	return {"ok": true}


# --- P4-01/P4-02 池与槽操作 ---

func place_turret(pool_index: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var t: Dictionary = PoolService.turret_at(session, pool_index)
	if t.is_empty():
		return {"ok": false, "reason": "empty_slot"}  # 空位不可选（G03）
	if session.slots.size() >= SlotService.capacity(session, rules):
		return {"ok": false, "reason": "slots_full"}  # 满槽拒绝（G02）
	PoolService.take(session, pool_index)
	SlotService.place(session, rules, t, pool_index)
	_evaluate_outcome()
	return {"ok": true, "turret_id": t.turret_id}


func return_turret(slot_index: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var res: Dictionary = SlotService.take_back(session, slot_index)
	if not res.ok:
		return res
	if not PoolService.put_at(session, res.origin_index, res.turret):
		return {"ok": false, "reason": "pool_slot_occupied"}  # 理论不发生：来源格已空
	_evaluate_outcome()
	return {"ok": true, "turret_id": res.turret.turret_id}


# --- P4-03 发射事务：生成失败不扣弹；成功才扣 1；归零移除 ---

func fire(slot_index: int, world_origin: Vector3, world_dir: Vector3) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var s: Dictionary = SlotService.slot_at(session, slot_index)
	if s.is_empty():
		return {"ok": false, "reason": "empty_slot"}
	var dir := world_dir.normalized()
	if dir.length_squared() < 0.5:
		return {"ok": false, "reason": "bad_direction"}
	var speed: float = rules.ball_speed * (2.0 if session.pending_effects.speed_x2 else 1.0)
	var any_color: bool = session.pending_effects.any_color
	_shot_seq += 1
	var ball_id: int = ball_physics.spawn_ball(world_origin, dir * speed, _shot_seq,
		s.color_id, any_color)
	if ball_id <= 0:
		return {"ok": false, "reason": "spawn_failed"}  # 不扣弹（G05）
	s.ammo_count -= 1
	s.has_fired = true
	session.pending_effects.speed_x2 = false   # 下一发一次（D04）
	session.pending_effects.any_color = false  # 效果绑定该弹珠（G10）
	bus.publish("turret_fire", [s.duplicate(true), ball_id], _meta())
	if s.ammo_count <= 0:
		SlotService.remove_at(session, slot_index)  # 归零消失；已发射球不受影响（G05）
	_evaluate_outcome()
	return {"ok": true, "ball_id": ball_id, "ammo_left": s.ammo_count}


# --- P4-04 合成 ---

func merge_turrets(idx_a: int, idx_b: int) -> Dictionary:
	if session.outcome != "RUNNING":
		return {"ok": false, "reason": "not_running"}
	var res: Dictionary = MergeService.merge(session, rules, idx_a, idx_b)
	if res.ok:
		bus.publish("turret_merged", [res.turret, res.merged_id], _meta())
	return res


# --- P4-07 道具 ---

func use_prop(prop: String) -> Dictionary:
	var res: Dictionary = props.use(session, rules, prop, _rng, _meta())
	if res.get("ok", false):
		_evaluate_outcome()
	return res


# --- 帧驱动：物理步进 + 命中/出界/胜负 ---

func step(dt: float) -> void:
	if session == null or session.outcome != "RUNNING":
		return
	_tick += 1
	ball_physics.physics_step(dt, voxel_model.world_from_grid(),
		session.session_generation, _tick)
	_evaluate_outcome()


func _physics_process(delta: float) -> void:
	step(delta)


func _on_ball_out_of_bounds(args: Array, meta: Dictionary) -> void:
	var ball: Dictionary = args[0]
	combo.on_ball_end(int(ball.ball_id),
		{"event_id": _next_event_id.call(), "level_id": session.level_id,
			"session_generation": meta.get("session_generation", 0),
			"physics_tick": meta.get("physics_tick", 0)})
	ball_physics.system.end_ball(int(ball.ball_id))


func _evaluate_outcome() -> void:
	if session == null:
		return
	outcome_state.evaluate(session, voxel_manager.alive_count(),
		ball_physics.system.active_count(), session.level_id, _meta())


func save_session() -> Dictionary:
	session.alive_voxel_ids = voxel_manager.state.alive_ids()
	return LevelRepositoryScript.save(session.to_snapshot())


func _meta() -> Dictionary:
	return {"event_id": _next_event_id.call(), "level_id": session.level_id,
		"session_generation": session.session_generation, "physics_tick": _tick}


func _next_event_id() -> int:
	_event_id += 1
	return _event_id
