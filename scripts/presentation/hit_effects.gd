extends Node3D
class_name HitEffects

## P5-03 命中表现：受限碎裂粒子（一次性、不参与碰撞、总量/寿命受 D 阈值约束）+ 连击飘字。
## 订阅 voxel_destroyed / combo_update；表现层只读事件，绝不反写业务状态。

var particle_per_hit := 16
var particle_lifetime := 0.8
var particle_max_total := 512

var active_particles := 0
var dropped_bursts := 0                 # 超上限丢弃计数（验收用）
var _level_id := ""


func attach(bus: RefCounted, level_id: String) -> void:
	_level_id = level_id
	bus.subscribe("voxel_destroyed", _on_voxel_destroyed, level_id)
	bus.subscribe("combo_update", _on_combo_update, level_id)


func _on_voxel_destroyed(args: Array, _meta: Dictionary) -> void:
	var block: Dictionary = args[0]
	var ball: Dictionary = args[1] if args.size() > 1 else {}
	var pos: Vector3 = ball.get("point", Vector3.ZERO)
	spawn_burst(pos, particle_per_hit)


func _on_combo_update(args: Array, _meta: Dictionary) -> void:
	var combo_count: int = int(args[1])
	if combo_count >= 2:
		spawn_floater(Vector3.ZERO, combo_count)


func spawn_burst(pos: Vector3, count: int) -> bool:
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
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.position = pos
	add_child(p)
	p.emitting = true
	active_particles += count
	var timer := get_tree().create_timer(particle_lifetime)
	timer.timeout.connect(func() -> void:
		active_particles -= count
		if is_instance_valid(p):
			p.queue_free())
	return true


func spawn_floater(pos: Vector3, combo_count: int) -> void:
	var label := Label3D.new()
	label.text = "x%d" % combo_count
	label.font_size = 64
	label.position = pos + Vector3(0, 1.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.5, particle_lifetime)
	tween.parallel().tween_property(label, "modulate:a", 0.0, particle_lifetime)
	tween.tween_callback(label.queue_free)
