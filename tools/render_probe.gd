extends SceneTree

# 桌面渲染探针：进关 → 30 帧后截图 → user://render_probe.png（诊断用，非测试）

const GameControllerScript := preload("res://scripts/app/game_controller.gd")

var _frames := 0
var _gc: Node


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_gc = GameControllerScript.new()
	root.add_child(_gc)
	var r: Dictionary = _gc.start_level("res://assets/levels/level_01.json")
	print("start_level ok=", r.ok)
	var model: Node3D = _gc.voxel_model
	print("model pos=", model.position, " children=", model.get_child_count())
	var mm := _find_multimesh(model)
	if mm != null:
		print("multimesh instances=", mm.multimesh.instance_count, " visible=", mm.multimesh.visible_instance_count)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 5, 16), Vector3.ZERO)
	cam.current = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.1, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	root.add_child(light)


func _find_multimesh(n: Node) -> MultiMeshInstance3D:
	if n is MultiMeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_multimesh(c)
		if r != null:
			return r
	return null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("user://render_probe.png")
		print("saved user://render_probe.png ", img.get_size())
		return true  # 退出
	return false
