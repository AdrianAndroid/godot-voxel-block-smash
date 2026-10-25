extends SceneTree

# 主场景探针：加载 main.tscn → 程序选择 level_01 → 40 帧后截图（诊断用，非测试）

var _frames := 0
var _main: Node


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main._on_level_chosen("level_01")
	print("level chosen")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		var cam := _main.get_node("Camera3D") as Camera3D
		var vp := root.get_viewport().get_visible_rect().size
		print("cam_transform=", cam.global_transform)
		print("viewport=", vp)
		print("origin_screen=", cam.unproject_position(Vector3.ZERO))
		var model: Node3D = _main.controller.voxel_model
		print("model_global=", model.global_transform)
		var mm: Node = model.get_child(0)
		print("render_child_global=", (mm as Node3D).global_transform)
		var hud: Control = _main.hud
		print("hud_visible=", hud.visible, " hud_size=", hud.size, " anchors=", hud.anchor_left, ",", hud.anchor_top, ",", hud.anchor_right, ",", hud.anchor_bottom)
		for c in hud.get_children():
			var cc := c as Control
			print("child ", c.name, " anchors=", cc.anchor_top, "..", cc.anchor_bottom, " offsets=", cc.offset_top, "..", cc.offset_bottom, " pos=", cc.position)
		for i in 3:
			var b: Button = hud._pool_buttons[i]
			print("pool_btn", i, " pos=", b.global_position, " size=", b.size, " visible=", b.visible, " text=", b.text)
		var sb: Button = hud._slot_buttons[0]
		print("slot_btn0 pos=", sb.global_position, " size=", sb.size, " visible=", sb.visible)
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("user://scene_probe.png")
		print("saved ", img.get_size())
		return true
	return false
