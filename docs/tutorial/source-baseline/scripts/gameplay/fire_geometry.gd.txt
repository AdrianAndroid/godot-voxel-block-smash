extends RefCounted
class_name FireGeometry

# CQ-20261026：发射几何契约（运行时 main.gd 与离线验证器 tools/cq_verify.gd 共用）。
# 槽口屏幕中心 → 相机射线 → 格空间边界 AABB 求交，交点内移 0.1 作为发射原点；
# 可达性 = 从真实原点向目标体素中心扫掠，目标必须是第一个命中的体素（半径=弹珠半径）。

# 五槽屏幕中心（CQ §S02 分区：槽位区纵向 57%~65%，五列等宽）
static func slot_screen_center(slot_index: int, viewport_size: Vector2) -> Vector2:
	return Vector2((float(slot_index) + 0.5) * viewport_size.x / 5.0, viewport_size.y * 0.61)


# CQ/S06：炮口屏幕点 = 槽中心 + 朝模型中心方向 × 炮管长（素材几何 124/256 × min(槽宽,槽高)）。
# 与 CannonView 的可见炮口同一契约；model_center_screen <0 时默认 (0.5w, 0.32h)（S02 构图中心）。
const MUZZLE_LEN_UV := 124.0 / 256.0

static func muzzle_screen_point(slot_index: int, viewport_size: Vector2,
		model_center_screen: Vector2 = Vector2(-1, -1)) -> Vector2:
	var c := slot_screen_center(slot_index, viewport_size)
	if model_center_screen.x < 0.0:
		model_center_screen = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.32)
	var dir := model_center_screen - c
	if dir.length_squared() < 1e-6:
		dir = Vector2(0, -1)
	var cell := minf(viewport_size.x / 5.0, viewport_size.y * 0.08)
	return c + dir.normalized() * (MUZZLE_LEN_UV * cell)


# 任意屏幕点 → 发射原点（世界坐标）。boundary_center/boundary_half 为格空间
static func screen_point_origin_world(camera: Camera3D, screen: Vector2,
		grid_from_world: Transform3D, boundary_center: Vector3, boundary_half: float) -> Dictionary:
	if camera == null:
		return {"ok": false, "reason": "no_camera"}
	var from: Vector3 = camera.project_ray_origin(screen)
	var ray_dir: Vector3 = camera.project_ray_normal(screen)
	var g_from: Vector3 = grid_from_world * from
	var g_dir: Vector3 = (grid_from_world.basis * ray_dir).normalized()
	var box := AABB(boundary_center - Vector3.ONE * boundary_half, Vector3.ONE * boundary_half * 2.0)
	var g_hit: Variant = box.intersects_ray(g_from, g_dir)
	if g_hit == null:
		return {"ok": false, "reason": "ray_miss"}
	var origin_grid: Vector3 = g_hit + g_dir * 0.1  # 入界内一点，避免首帧即判出界
	return {"ok": true, "origin": grid_from_world.affine_inverse() * origin_grid,
		"origin_grid": origin_grid}


# 发射原点（世界坐标）：炮口屏幕点（朝模型中心）→ 相机射线 ∩ 边界 AABB 内移 0.1
static func muzzle_origin_world(camera: Camera3D, slot_index: int, viewport_size: Vector2,
		grid_from_world: Transform3D, boundary_center: Vector3, boundary_half: float) -> Dictionary:
	var model_screen := Vector2(-1, -1)
	if camera != null:
		model_screen = camera.unproject_position(
			grid_from_world.affine_inverse() * boundary_center)
	return screen_point_origin_world(camera,
		muzzle_screen_point(slot_index, viewport_size, model_screen),
		grid_from_world, boundary_center, boundary_half)


# 可达性（格空间）：从 origin_grid 扫掠到目标体素中心，目标须为首个命中（CQ §2.3 真实起点+半径验证）
# sweep_fn: Callable(p0, p1, radius) -> {hit, voxel_id,...}（运行时=碰撞求解器，验证器同）
static func first_hit_is(sweep_fn: Callable, origin_grid: Vector3, target_grid_center: Vector3,
		radius: float, target_voxel_id: int) -> bool:
	var hit: Dictionary = sweep_fn.call(origin_grid, target_grid_center, radius)
	return bool(hit.get("hit", false)) and int(hit.get("voxel_id", -1)) == target_voxel_id
