extends Control
class_name HudPresenter

## P5-01/02/04 HUD：顶部关卡号+剩余数、连击、槽行、九宫格池、四道具按钮。
## 全部为屏幕空间 Control，固定布局，不随模型旋转（G01）。UI 只读会话状态 + 调用控制器命令。

const PALETTE_FALLBACK := {
	1: Color("#4CAF50"), 2: Color("#F44336"), 3: Color("#2196F3"), 4: Color("#FFEB3B"),
	5: Color("#9C27B0"), 6: Color("#FAFAFA"), 7: Color("#212121"),
}
const PROP_LABELS := {"speed_x2": "速度×2", "add_slot": "加槽", "any_color": "任意指", "shuffle": "随机排"}

var controller: Node = null
var selected_pool := -1

var _level_label: Label
var _remain_label: Label
var _combo_label: Label
var _result_label: Label
var _pool_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _prop_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size  # CanvasLayer 父级不提供 Control 尺寸，显式取视口
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()


func bind(p_controller: Node) -> void:
	controller = p_controller
	selected_pool = -1
	for e in ["voxel_destroyed", "combo_update", "turret_fire", "turret_merged",
			"item_activated", "level_win", "level_lose"]:
		controller.bus.subscribe(e, func(_a: Array, _m: Dictionary) -> void: refresh(), controller.session.level_id)
	refresh()


# --- UI 构建（程序化 StyleBoxFlat，无外部美术资源） ---

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(PRESET_TOP_WIDE, false)
	top.offset_top = 12
	top.offset_left = 16
	top.offset_right = -16
	add_child(top)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 36)
	top.add_child(_level_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(spacer)
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 36)
	top.add_child(_combo_label)
	_remain_label = Label.new()
	_remain_label.add_theme_font_size_override("font_size", 36)
	top.add_child(_remain_label)

	_result_label = Label.new()
	_result_label.set_anchors_preset(PRESET_CENTER, false)
	_result_label.offset_left = -300
	_result_label.offset_right = 300
	_result_label.add_theme_font_size_override("font_size", 96)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_result_label)

	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -16
	bottom.offset_top = -640
	bottom.add_theme_constant_override("separation", 12)
	add_child(bottom)

	var props_row := HBoxContainer.new()
	props_row.alignment = BoxContainer.ALIGNMENT_CENTER
	props_row.add_theme_constant_override("separation", 12)
	bottom.add_child(props_row)
	for prop in ["speed_x2", "add_slot", "any_color", "shuffle"]:
		var b := _make_button(PROP_LABELS[prop], Color(0.25, 0.25, 0.3))
		b.pressed.connect(_on_prop_pressed.bind(prop))
		props_row.add_child(b)
		_prop_buttons[prop] = b

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 12)
	bottom.add_child(slot_row)
	for i in 5:
		var b := _make_button("槽%d" % (i + 1), Color(0.2, 0.2, 0.24))
		b.pressed.connect(_on_slot_pressed.bind(i))
		slot_row.add_child(b)
		_slot_buttons.append(b)

	var pool_grid := GridContainer.new()
	pool_grid.columns = 3
	pool_grid.add_theme_constant_override("h_separation", 10)
	pool_grid.add_theme_constant_override("v_separation", 10)
	pool_grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	bottom.add_child(pool_grid)
	for i in 9:
		var b := _make_button("", Color(0.3, 0.3, 0.3))
		b.custom_minimum_size = Vector2(180, 120)
		b.pressed.connect(_on_pool_pressed.bind(i))
		pool_grid.add_child(b)
		_pool_buttons.append(b)


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 84)
	b.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = color.lightened(0.2)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = color.darkened(0.2)
	b.add_theme_stylebox_override("pressed", sbp)
	return b


# --- 刷新（状态 → 视图，单向） ---

func refresh() -> void:
	if controller == null or controller.session == null:
		return
	var s: RefCounted = controller.session
	_level_label.text = "关卡 %s" % s.level_id
	_remain_label.text = "  剩余 %d" % controller.voxel_manager.alive_count()
	_result_label.text = {"WON": "通关！", "LOST": "失败"}.get(s.outcome, "")
	_combo_label.text = ""

	for i in 9:
		_refresh_pool_button(i, s.pool[i] if i < s.pool.size() else {})
	for i in 5:
		var t: Dictionary = s.slots[i] if i < s.slots.size() else {}
		var b := _slot_buttons[i]
		var unlocked: bool = i < s.unlocked_slots
		b.visible = unlocked
		if t.is_empty():
			b.text = "放置"
			_set_button_color(b, Color(0.2, 0.2, 0.24))
		else:
			b.text = "%d" % int(t.ammo_count)
			_set_button_color(b, _color_of(t.color_id))
	for prop in _prop_buttons:
		var count := int(s.prop_counts.get(prop, 0))
		var b: Button = _prop_buttons[prop]
		b.text = "%s×%d" % [PROP_LABELS[prop], count]
		b.visible = count > 0  # 用尽消失（G13）


func _refresh_pool_button(i: int, t: Dictionary) -> void:
	var b := _pool_buttons[i]
	if t.is_empty():
		b.text = ""
		b.disabled = true
		_set_button_color(b, Color(0.12, 0.12, 0.14))
		return
	b.disabled = false
	b.text = "%d" % int(t.ammo_count)
	var c := _color_of(t.color_id)
	if i == selected_pool:
		c = c.lightened(0.35)  # 选中高亮（T02）
	_set_button_color(b, c)


func _color_of(color_id: int) -> Color:
	if controller.voxel_manager != null and controller.voxel_manager.data != null:
		var p: Dictionary = controller.voxel_manager.data.palette
		if p.has(color_id):
			return p[color_id]
	return PALETTE_FALLBACK.get(color_id, Color.GRAY)


func _set_button_color(b: Button, c: Color) -> void:
	var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
	sb.bg_color = c
	b.add_theme_stylebox_override("normal", sb)


# --- 交互（视图 → 控制器命令） ---

func _on_pool_pressed(i: int) -> void:
	if controller == null or controller.session == null:
		return
	if selected_pool >= 0 and selected_pool != i:
		var res: Dictionary = controller.merge_turrets(selected_pool, i)
		if res.ok:
			selected_pool = -1
			refresh()
			return
	selected_pool = i if selected_pool != i else -1
	refresh()


func _on_slot_pressed(i: int) -> void:
	if controller == null or controller.session == null:
		return
	var s: RefCounted = controller.session
	if i < s.slots.size() and not s.slots[i].is_empty():
		_fire_slot(i)
	elif selected_pool >= 0:
		controller.place_turret(selected_pool)
		selected_pool = -1
	refresh()


func _fire_slot(i: int) -> void:
	var center: Vector3 = controller.ball_physics.system.boundary_center
	var half: float = controller.ball_physics.system.boundary_half
	var origin := center + Vector3((i - 2) * 2.0, -half * 0.8, 0)
	controller.fire(i, origin, (center - origin).normalized())


func _on_prop_pressed(prop: String) -> void:
	if controller != null:
		controller.use_prop(prop)
		refresh()
