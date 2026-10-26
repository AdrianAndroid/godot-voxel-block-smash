extends SceneTree

# 调试：测量 find_target 冷扫描各阶段耗时（桌面，推断设备 ≈5-10x）
const VoxelLoader := preload("res://scripts/data/voxel_loader.gd")
const VoxelManager := preload("res://scripts/voxel/voxel_manager.gd")
const TargetSelector := preload("res://scripts/gameplay/target_selector.gd")

func _init() -> void:
	var res: Dictionary = VoxelLoader.load_from_json("res://assets/models/json/frog_02.json")
	var data: RefCounted = res.data
	var vm: RefCounted = VoxelManager.new()
	vm.build(data)  # headless: renderer dummy，build 可能失败则只建 index
	var sel: RefCounted = TargetSelector.new()
	sel.setup(vm, 0.35)
	var avail := func(_vid: int) -> bool: return true
	# 4 个不同原点（模拟 4 炮位），冷扫描
	for k in 4:
		var origin := Vector3(5.0 + k * 6.0, -20.0, 8.0)
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = sel.find_target(1, origin, avail)
		var us := Time.get_ticks_usec() - t0
		print("cold origin%d: %.2fms ok=%s reason=%s" % [k, us / 1000.0, str(r.get("ok")), str(r.get("reason", ""))])
	# 模拟一次删除后 gen 推进，再扫（每帧真实场景）
	vm.destroy(631) if vm.is_alive(631) else vm.destroy(0)
	sel.on_voxel_destroyed(631)
	for k in 4:
		var origin := Vector3(5.0 + k * 6.0, -20.0, 8.0)
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = sel.find_target(1, origin, avail)
		var us := Time.get_ticks_usec() - t0
		print("post-destroy origin%d: %.2fms ok=%s reason=%s" % [k, us / 1000.0, str(r.get("ok")), str(r.get("reason", ""))])
	quit(0)
