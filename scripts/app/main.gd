extends Node3D

## 主场景：关卡列表 → 关卡游玩。装配控制器、HUD、音效、命中表现、弹珠表现与手势旋转。
## 【新增代码】可玩性补齐（playability-architecture §2.2/§3/§10）：
## §3 固定生命周期（禁用输入→保存/停止→清表现→清手势→新会话→绑定→启用输入）；
## 发射原点由槽位屏幕坐标经相机射线与边界 AABB 求交投影；_input 释放兜底；退后台冻结调度。

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const GestureRouterScript := preload("res://scripts/input/gesture_router.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")
const FireGeometry := preload("res://scripts/gameplay/fire_geometry.gd")

var controller: Node
var hud: Control
var level_list: Control
var audio: Node
var effects: Node3D
var marbles: Node3D  # MarblePresenter
var router: RefCounted
var camera: Camera3D

var _current_level_id := ""
var _input_enabled := false  # §3：会话切换期间禁用输入
var _press_pos := Vector2.ZERO   # CQ/S08：点击/拖拽判别（指定目标点选 vs 旋转，12px 阈值）
var _press_moved := false


func _ready() -> void:
	# iOS 适配（CQ 输入互斥）：引擎默认 emulate_mouse_from_touch=true 会让一次触摸
	# 同时产生 InputEventMouseButton/Motion 与 InputEventScreenTouch/Drag（headless 实测），
	# 导致旋转量翻倍、CannonView/ColumnClip 一次点按触发两次。本工程所有处理器均已
	# 原生处理触摸事件，iOS 上关闭鼠标模拟；其他平台不受影响（桌面 emulate_touch_from_mouse 默认 false）。
	if OS.has_feature("ios"):
		Input.emulate_mouse_from_touch = false
	router = GestureRouterScript.new()
	controller = GameControllerScript.new()
	add_child(controller)
	effects = preload("res://scripts/presentation/hit_effects.gd").new()
	add_child(effects)
	marbles = preload("res://scripts/presentation/marble_presenter.gd").new()
	add_child(marbles)
	audio = preload("res://scripts/presentation/audio_presenter.gd").new()
	add_child(audio)
	camera = $Camera3D

	var ui := CanvasLayer.new()
	ui.name = "UILayer"
	add_child(ui)
	hud = preload("res://scripts/presentation/hud_presenter.gd").new()
	hud.visible = false
	ui.add_child(hud)
	hud.connect("restart_requested", restart_current_level)
	hud.connect("back_requested", return_to_list)
	level_list = preload("res://scripts/presentation/level_list_presenter.gd").new()
	level_list.on_level_chosen = _on_level_chosen
	ui.add_child(level_list)
	var pm: Node = preload("res://scripts/diagnostics/perf_monitor.gd").new()
	# FM/F2：perf_log.jsonl 每行携带发射统计快照（FM05/13 证据）
	pm.stats_provider = func() -> Dictionary:
		return controller.fire_stats.snapshot() if controller != null \
			and controller.fire_stats != null else {}
	# FM/F0：测试隔离目录时 perf 日志同样隔离，避免并发测试清掉真机采样
	if LevelRepository.is_isolated():
		pm.path = LevelRepository.save_dir.path_join("perf_log.jsonl")
	add_child(pm)
	# FM/F5：CLI 带 --replay=<解路径> 时进入实时回放模式（公开 API 驱动，自动连发+自动旋转）
	var replay := preload("res://scripts/app/replay_runner.gd").new()
	add_child(replay)
	replay.arm(self)


# --- §3 会话生命周期 ---

func enter_level(level_id: String, restore: Dictionary = {}) -> void:
	# 固定顺序：禁用输入 → 旧会话收尾 → 开记录 → 新会话 → 绑定表现 → 启用输入
	_input_enabled = false
	_cleanup_session(false)
	_current_level_id = level_id
	controller.recorder.open()
	var res: Dictionary = controller.start_level("res://assets/levels/%s.json" % level_id, restore)
	if not res.ok:
		# CQ/S09 §4：旧档不兼容/坏档 → 原子写保留可恢复副本（备份），明确提示后重开，
		# 不静默迁移弹量或覆盖原档
		var err := str(res.get("error", ""))
		if not restore.is_empty():
			var bak: String = LevelRepository.backup_save(level_id)
			print("[save] 存档不可用（%s），已备份 %s，本关重新开始" % [err, bak])
			enter_level(level_id)  # 全新会话重开
			return
		push_error("关卡启动失败: " + err)
		level_list.show_notice("关卡启动失败，请重试")
		level_list.visible = true
		hud.visible = false
		return
	controller.origin_resolver = _resolve_fire_origin  # §2.2 表现层注入发射原点
	_frame_model()  # CQ-20261026/S02：按包围球拟合相机距离 + 模型视觉中心移至内容区 y≈33%
	level_list.visible = false
	hud.visible = true
	hud.bind(controller)
	hud.camera = camera  # CQ/S06：炮管瞄准需要把目标世界坐标投影到屏幕
	audio.attach(controller.bus, level_id)
	effects.attach(controller.bus, level_id, _palette_color)
	marbles.bind(controller)
	controller.bus.subscribe("level_win", _on_level_end, level_id)
	controller.bus.subscribe("level_lose", _on_level_end, level_id)
	controller.bus.subscribe("integrity_error", _on_level_end, level_id)  # CQ/S08
	_input_enabled = true


func restart_current_level() -> void:
	if _current_level_id.is_empty():
		return
	enter_level(_current_level_id)  # 重开 = 全新会话，不恢复旧档


func return_to_list() -> void:
	_input_enabled = false
	_cleanup_session(true)  # 返回列表：保存会话（G15）
	_current_level_id = ""
	hud.visible = false
	level_list.visible = true


func _cleanup_session(save: bool) -> void:
	router.cancel_all()
	_set_rot_hold(false)
	if controller.session != null:
		if save:
			controller.save_session()
		controller.stop_session()  # 停止调度与物理推进
	effects.clear()
	marbles.clear()
	audio.stop_all()
	controller.recorder.close()


func _on_level_chosen(level_id: String) -> void:
	var snap: Dictionary = LevelRepository.load_snapshot(level_id)
	var restore: Dictionary = {}
	if snap.get("ok", false) and snap.get("exists", false):
		var s: Dictionary = snap.snapshot
		if int(s.get("version", 0)) != 2:
			# CQ-20261026/S09：v1 旧档备份后本关重新开始，明确提示不静默迁移
			var bak: String = LevelRepository.backup_save(level_id)
			print("[save] v1 存档已备份 %s，本关重新开始" % bak)
			level_list.show_notice("关卡内容已更新，本关重新开始（旧档已备份）")
		elif s.get("outcome", "") == "RUNNING":
			restore = s  # 跨进程恢复进行中的本局（G15/D09）；已终局则重开
	enter_level(level_id, restore)


func _on_level_end(_args: Array, _meta: Dictionary) -> void:
	controller.save_session()


# CQ-20261026/S05+S06：发射原点契约收敛到 FireGeometry（运行时与离线验证器同一实现）。
# S06：起点 = 可见炮口屏幕坐标（HUD CannonView.muzzle_screen_center，无 HUD 时回退槽位契约点）
# → 相机射线 → 格空间边界 AABB 求交内移 0.1；方向由控制器按预订目标计算。
func _resolve_fire_origin(slot_index: int) -> Dictionary:
	if camera == null or controller.ball_physics == null or controller.voxel_model == null:
		return {"ok": false, "reason": "no_camera"}
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen := FireGeometry.muzzle_screen_point(slot_index, viewport_size)
	if hud != null and hud.visible:
		var muzzle: Vector2 = hud.slot_muzzle_screen_center(slot_index)
		if muzzle.x >= 0.0:
			screen = muzzle
	var wfg: Transform3D = controller.voxel_model.world_from_grid()
	var res: Dictionary = FireGeometry.screen_point_origin_world(camera, screen,
		wfg.affine_inverse(),
		controller.ball_physics.system.boundary_center,
		controller.ball_physics.system.boundary_half)
	if not res.get("ok", false):
		return res
	var center_world: Vector3 = wfg * controller.ball_physics.system.boundary_center
	res["dir"] = (center_world - res.origin).normalized()  # 兼容旧调用；目标化发射不使用
	return res


func _palette_color(color_id: int) -> Color:
	if controller.voxel_manager != null and controller.voxel_manager.data != null:
		var p: Dictionary = controller.voxel_manager.data.palette
		if p.has(color_id):
			return p[color_id]
	return Color.WHITE


# --- 输入 ---

func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	# 【新增代码】释放兜底：即使按下被 UI 消费，抬手也结束拖拽态，防手势卡死（§3）
	if event is InputEventScreenTouch and not event.pressed:
		router.handle_release(event.index)
		_set_rot_hold(false)  # FM §11：松手自动旋转从当前姿态渐入接续
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		router.handle_release(0)
		_set_rot_hold(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or controller.session == null or not hud.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_pos = event.position
			_press_moved = false
			router.handle_press(event.index, false)  # 到这里的触摸未被 UI 消费
			_set_rot_hold(true)  # FM §11：模型区按住即暂停自动旋转（手动全胜）
		elif hud.designated_picking_voxel() and not _press_moved:
			# CQ/S08：指定目标选体素（12px 内视为点击；优先级高于模型旋转）
			hud.designated_pick_at(event.position)
	elif event is InputEventScreenDrag:
		if (event.position - _press_pos).length() > 12.0:
			_press_moved = true
		var rot: Vector2 = router.handle_drag(event.index, event.relative)
		_apply_rotation(rot)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_press_moved = false
			router.handle_press(0, false)
			_set_rot_hold(true)
		elif hud.designated_picking_voxel() and not _press_moved:
			hud.designated_pick_at(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if (event.position - _press_pos).length() > 12.0:
			_press_moved = true
		var rot2: Vector2 = router.handle_drag(0, event.relative)
		_apply_rotation(rot2)


# CQ-20261026/S02：跟手旋转——相机空间增量四元数（每步绕当前相机 up/right 轴旋转），
# 替代本地欧拉角累加（后者不同朝向下轴向翻转、符号与屏幕方向相反）。
# 小增量绕屏幕轴旋转保证任意朝向下前表面随手指同向移动；俯仰限制 ±70°，越界只保留偏航分量。
func _apply_rotation(rot: Vector2) -> void:
	if rot == Vector2.ZERO or controller.voxel_model == null or camera == null:
		return
	var up: Vector3 = camera.global_transform.basis.y.normalized()
	var right: Vector3 = camera.global_transform.basis.x.normalized()
	var basis: Basis = controller.voxel_model.global_transform.basis
	var candidate := Basis(Quaternion(up, rot.x) * Quaternion(right, rot.y)) * basis
	# 俯仰角=模型前方轴（本地 -Z）相对相机竖直轴的倾角
	var tilt_now: float = asin(clampf((basis * Vector3(0, 0, -1)).normalized().dot(up), -1.0, 1.0))
	var tilt_new: float = asin(clampf((candidate * Vector3(0, 0, -1)).normalized().dot(up), -1.0, 1.0))
	const PITCH_LIMIT := 1.2217  # ±70°
	if absf(tilt_new) > PITCH_LIMIT and absf(tilt_new) > absf(tilt_now):
		candidate = Basis(Quaternion(up, rot.x)) * basis  # 越过边界：只偏航
	controller.voxel_model.set_orientation(candidate)  # FM §11：唯一写入口（transform_version++）


# CQ-20261026/S02：相机按模型包围球拟合距离（旋转包络 8% 留白），
# 直立相机置于模型下方平视，使模型视觉中心落在内容区 y≈33%（模型区 10%~56%）。
# 只动相机，模型/物理世界坐标不变；灵敏度按屏宽归一（横扫 ≈180°）。
func _frame_model() -> void:
	var data: RefCounted = controller.voxel_model.voxel_data
	var half: Vector3 = (data.bounds_max - data.bounds_min) * 0.5 * data.voxel_size
	var r: float = half.length() * 1.08
	var vfov: float = deg_to_rad(camera.fov)
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var hfov: float = 2.0 * atan(tan(vfov * 0.5) * aspect)
	# 模型区占屏高 44%、宽向占 90%，取两者较大距离
	var d: float = maxf(r / (0.44 * tan(vfov * 0.5)), r / (0.90 * tan(hfov * 0.5)))
	# 模型中心需在屏上偏移：屏高一半对应世界 d*tan(vfov/2)，上移 (50-34)%=16% 屏高
	#（透视非线性约再抬 1.7%，实测中心≈32%，包围球投影落在 10%~56% 模型区内）
	var up_shift: float = 0.16 * 2.0 * d * tan(vfov * 0.5)
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, -up_shift, d))
	camera.rotation = Vector3.ZERO  # 直立：up=+Y、right=+X
	router.sensitivity = PI / get_viewport().get_visible_rect().size.x  # 横扫全宽≈180°
	# 初始姿态：青蛙正面（模型本地 -Z）转向相机（相机在 +Z）
	controller.voxel_model.set_orientation(Basis(Quaternion(Vector3.UP, PI)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and controller.session != null:
		controller.save_session()
		controller.recorder.close()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		router.cancel_all()  # 退后台丢弃进行中的手势
		_set_rot_hold(false)
		if controller.session != null:
			controller.set_paused(true)   # 【新增代码】§10：冻结自动连发，恢复不补发
			controller.save_session()     # Android 退后台即落盘（G15）
			controller.recorder.close()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# FM/F4：用户手动暂停（暂停遮罩可见）不被后台恢复冲掉
		if not hud.is_pause_overlay_visible():
			controller.set_paused(false)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# FM §11：macOS 失焦只清理悬挂手势、不暂停（失焦时间计入 FM13 有效局时）
		router.cancel_all()
		_set_rot_hold(false)


# FM §11：模型区指针按住/释放 → 控制器自动旋转持有开关（空安全）
func _set_rot_hold(hold: bool) -> void:
	if controller != null:
		controller.set_rotation_hold(hold)
