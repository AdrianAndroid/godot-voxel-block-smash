extends Node3D

## 主场景：关卡列表 → 关卡游玩。装配控制器、HUD、音效、命中表现与手势旋转。

const GameControllerScript := preload("res://scripts/app/game_controller.gd")
const GestureRouterScript := preload("res://scripts/input/gesture_router.gd")
const LevelRepository := preload("res://scripts/level/level_repository.gd")

var controller: Node
var hud: Control
var level_list: Control
var audio: Node
var effects: Node3D
var router: RefCounted

var _current_level_path := ""


func _ready() -> void:
	router = GestureRouterScript.new()
	controller = GameControllerScript.new()
	add_child(controller)
	effects = preload("res://scripts/presentation/hit_effects.gd").new()
	add_child(effects)
	audio = preload("res://scripts/presentation/audio_presenter.gd").new()
	add_child(audio)

	var ui := CanvasLayer.new()
	ui.name = "UILayer"
	add_child(ui)
	hud = preload("res://scripts/presentation/hud_presenter.gd").new()
	hud.visible = false
	ui.add_child(hud)
	level_list = preload("res://scripts/presentation/level_list_presenter.gd").new()
	level_list.on_level_chosen = _on_level_chosen
	ui.add_child(level_list)


func _on_level_chosen(level_id: String) -> void:
	_current_level_path = "res://assets/levels/%s.json" % level_id
	var res: Dictionary = controller.start_level(_current_level_path)
	if not res.ok:
		push_error("关卡启动失败: " + str(res.get("error", "")))
		return
	level_list.visible = false
	hud.visible = true
	hud.bind(controller)
	audio.attach(controller.bus, level_id)
	effects.attach(controller.bus, level_id)
	controller.bus.subscribe("level_win", _on_level_end, level_id)
	controller.bus.subscribe("level_lose", _on_level_end, level_id)


func _on_level_end(_args: Array, _meta: Dictionary) -> void:
	controller.save_session()


func _unhandled_input(event: InputEvent) -> void:
	if controller.session == null or not hud.visible:
		return
	if event is InputEventScreenTouch:
		router.handle_press(event.index, false)  # 到这里的触摸未被 UI 消费
	elif event is InputEventScreenDrag:
		var rot: Vector2 = router.handle_drag(event.index, event.relative)
		_apply_rotation(rot)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			router.handle_press(0, false)
		else:
			router.handle_release(0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var rot2: Vector2 = router.handle_drag(0, event.relative)
		_apply_rotation(rot2)


func _apply_rotation(rot: Vector2) -> void:
	if rot == Vector2.ZERO or controller.voxel_model == null:
		return
	controller.voxel_model.rotation.y += rot.x
	controller.voxel_model.rotation.x = clampf(controller.voxel_model.rotation.x + rot.y, -1.4, 1.4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and controller.session != null:
		controller.save_session()
