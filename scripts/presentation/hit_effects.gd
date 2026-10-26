extends Node3D
class_name HitEffects
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

## P5-03 命中表现：受限碎裂粒子（一次性、不参与碰撞、总量/寿命受 D 阈值约束）+ 连击飘字。
## 订阅 voxel_destroyed / combo_update；表现层只读事件，绝不反写业务状态。
## 【新增代码】碎块使用 BoxMesh + 被消块体素颜色材质（§2.3）；位置取碰撞点（世界坐标）；
## 定时回收带 generation token，clear 后旧 timer 回调不会减掉新会话计数；飘字移至命中点上方。

var particle_per_hit := 16
var particle_lifetime := 0.8
var particle_max_total := 512

var active_particles := 0
var dropped_bursts := 0                 # 超上限丢弃计数（验收用）

var _level_id := ""
var _palette := Callable()            # func(color_id: int) -> Color（§2.3 注入）
var _materials: Dictionary = {}       # color_id -> StandardMaterial3D（逐色只读缓存）
var _box_mesh: BoxMesh = null
var _token := 0                       # 跨局隔离：clear/attach 递增，旧 timer 回调按 token 失效
var _last_hit_point := Vector3.ZERO


func attach(bus: RefCounted, level_id: String, palette: Callable = Callable()) -> void:
	_level_id = level_id
	_palette = palette
	_token += 1
	active_particles = 0
	dropped_bursts = 0
	bus.subscribe("voxel_destroyed", _on_voxel_destroyed, level_id)
	bus.subscribe("combo_update", _on_combo_update, level_id)


# 重开/返回/结算时回收全部表现粒子与飘字，旧 timer 不再影响计数（§2.3）
func clear() -> void:
	_token += 1
	active_particles = 0
	for c in get_children():
		c.queue_free()


func _on_voxel_destroyed(args: Array, _meta: Dictionary) -> void:
	var block: Dictionary = args[0]
	var ball: Dictionary = args[1] if args.size() > 1 else {}
	var pos: Vector3 = ball.get("point", Vector3.ZERO)
	_last_hit_point = pos
	spawn_burst(pos, particle_per_hit, int(block.get("color_id", 0)))


# CQ-20261026 §2.2：combo_update [streak] 全局连击（无 ball_id 维度）
func _on_combo_update(args: Array, _meta: Dictionary) -> void:
	var streak: int = int(args[0])
	if streak >= 2:
		spawn_floater(_last_hit_point, streak)  # 命中点上方（§9 P1）


func spawn_burst(pos: Vector3, count: int, color_id: int = 0) -> bool:
	var _pt := PerfProbe.t0()
	if active_particles + count > particle_max_total:
		dropped_bursts += 1
		return false  # 超批准总量阈值：丢弃本次效果，不影响玩法（G07）
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = particle_lifetime
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	# CQ/S06：碎块棱长 0.08~0.18 体素（BoxMesh 0.13 × scale 0.62~1.38）
	p.scale_amount_min = 0.62
	p.scale_amount_max = 1.38
	p.mesh = _box()                      # 立方体碎块（§2.3）
	p.material_override = _material_of(color_id)
	p.position = pos
	add_child(p)
	p.emitting = true
	active_particles += count
	spawn_ring(pos, color_id)            # CQ/S06：同色光圈反馈
	PerfProbe.add("spawn_burst", _pt)
	var token := _token
	var timer := get_tree().create_timer(particle_lifetime)
	timer.timeout.connect(func() -> void:
		if token != _token:
			return  # 旧会话 timer：不再扣新会话计数（§2.3 generation 隔离）
		active_particles -= count
		if is_instance_valid(p):
			p.queue_free())
	return true


# CQ/S06：同色光圈——命中点扩散淡出的发光圆环（0.3s，一次性，不计入粒子上限）
func spawn_ring(pos: Vector3, color_id: int = 0) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.36
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var c := Color.WHITE
	if _palette.is_valid():
		c = _palette.call(color_id)
	m.albedo_color = c.lightened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = pos
	ring.scale = Vector3.ONE * 0.4
	add_child(ring)
	var token := _token
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.6, 0.3)
	tween.parallel().tween_property(m, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		if token == _token and is_instance_valid(ring):
			ring.queue_free())


func spawn_floater(pos: Vector3, combo_count: int) -> void:
	var label := Label3D.new()
	label.text = "x%d" % combo_count
	label.font_size = 64
	label.position = pos + Vector3(0, 1.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var token := _token
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.5, particle_lifetime)
	tween.parallel().tween_property(label, "modulate:a", 0.0, particle_lifetime)
	tween.tween_callback(func() -> void:
		if token == _token and is_instance_valid(label):
			label.queue_free())


func _box() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3.ONE * 0.13  # × scale 0.62~1.38 → 棱长 0.08~0.18 体素（CQ/S06）
	return _box_mesh


func _material_of(color_id: int) -> StandardMaterial3D:
	if _materials.has(color_id):
		return _materials[color_id]
	var c := Color.WHITE
	if _palette.is_valid():
		c = _palette.call(color_id)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	_materials[color_id] = m
	return m
