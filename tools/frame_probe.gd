extends SceneTree

# CQ-20261026/S02：多分辨率构图探针——包围球采样点投影应落在模型区（纵向 10%~56%，横向不裁切）
# 运行：godot --headless --path . --resolution 1080x2400 -s tools/frame_probe.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# headless 下 --resolution 不生效，显式设置窗口尺寸模拟不同长宽比
	var wh: PackedStringArray = OS.get_cmdline_user_args()  # -- WxH
	var w := 1080
	var h := 2400
	if wh.size() >= 1:
		var p: PackedStringArray = wh[0].split("x")
		if p.size() == 2:
			w = int(p[0])
			h = int(p[1])
	root.size = Vector2i(w, h)
	var size: Vector2 = root.get_visible_rect().size
	var main: Node = preload("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.enter_level("level_01", {})
	var cam: Camera3D = main.camera
	var vm: Node3D = main.controller.voxel_model
	var data: RefCounted = vm.voxel_data
	var center: Vector3 = vm.global_transform.origin
	var r: float = ((data.bounds_max - data.bounds_min) * 0.5 * data.voxel_size).length()
	# 包围球 26 方向采样
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for dx in [-1.0, 0.0, 1.0]:
		for dy in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				var dir := Vector3(dx, dy, dz)
				if dir.length() < 0.5:
					continue
				var p: Vector3 = center + dir.normalized() * r
				if cam.is_position_behind(p):
					continue
				var s: Vector2 = cam.unproject_position(p)
				mn = mn.min(s)
				mx = mx.max(s)
	print("viewport=%dx%d sphere_r=%.2f" % [int(size.x), int(size.y), r])
	print("project x: %.1f%%~%.1f%%  y: %.1f%%~%.1f%%" % [
		mn.x / size.x * 100, mx.x / size.x * 100, mn.y / size.y * 100, mx.y / size.y * 100])
	var ok: bool = mn.x >= 0 and mx.x <= size.x and mn.y >= size.y * 0.09 and mx.y <= size.y * 0.57
	print("FRAME_OK" if ok else "FRAME_CLIP")
	quit(0 if ok else 1)
