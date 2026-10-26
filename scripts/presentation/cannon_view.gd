extends Control
class_name CannonView

## CQ-20261026/S06：统一炮台视图（队列列首与炮位共用）。
## 分层素材（tools/cannon_gen.py 自制 CC0）：底座 + 炮身（白色→palette 染色）+ 炮管（绕枢轴旋转）
## + 炮口闪光；弹药数字白字粗描边（1~160）。炮管朝向目标屏幕投影；muzzle_screen_center()
## 提供可见炮口的屏幕坐标（发射起点契约）。
## 状态：empty/locked/queued/back/front/waiting/draining + recoil/flash 瞬时效果。

signal pressed

const TEX_BASE := preload("res://assets/cannons/cannon_base.png")
const TEX_BODY := preload("res://assets/cannons/cannon_body.png")
const TEX_BARREL := preload("res://assets/cannons/cannon_barrel.png")
const TEX_FLASH := preload("res://assets/cannons/cannon_flash.png")

# 素材内几何（256² 画布）：炮身圆心/炮管枢轴=(128,150)，炮口≈(128,26)，枢轴→炮口 124px
const PIVOT_UV := Vector2(128.0 / 256.0, 150.0 / 256.0)
const MUZZLE_DIST_UV := 124.0 / 256.0

var disabled := false
var state := "empty"         # empty/locked/queued/back/front/waiting/draining
var ammo := 0
var tint := Color.WHITE      # 炮身染色（palette color_id）

var _base: TextureRect
var _body: TextureRect
var _barrel: TextureRect
var _flash: TextureRect
var _label: Label
var _state_label: Label      # 锁/空 等覆盖文字
var _aim_dir := Vector2(0, -1)  # 屏幕空间瞄准方向（默认朝上）
var _recoil_tween: Tween = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	_base = _layer(TEX_BASE)
	_body = _layer(TEX_BODY)
	_barrel = _layer(TEX_BARREL)
	_flash = TextureRect.new()
	_flash.texture = TEX_FLASH
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flash.visible = false
	_flash.modulate = Color(1, 1, 1, 0.9)
	add_child(_flash)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.1
	_label.anchor_right = 0.9
	_label.anchor_top = 0.48   # 数字在炮身下半，炮管（上半）不遮挡
	_label.anchor_bottom = 0.78
	var ls := LabelSettings.new()
	ls.font_color = Color.WHITE
	ls.outline_color = Color(0.12, 0.12, 0.15)
	ls.outline_size = 10
	ls.font_size = 44
	_label.label_settings = ls
	add_child(_label)
	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.set_anchors_preset(PRESET_FULL_RECT)
	var sls := LabelSettings.new()
	sls.font_color = Color(0.85, 0.85, 0.9)
	sls.outline_color = Color(0.1, 0.1, 0.12)
	sls.outline_size = 8
	sls.font_size = 40
	_state_label.label_settings = sls
	add_child(_state_label)
	resized.connect(_layout)
	_layout()
	_apply_state()


func _layer(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(PRESET_FULL_RECT)
	t.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(t)
	return t


# 三层纹理同矩形居中，素材内对齐即控件内对齐；炮管绕枢轴旋转
func _layout() -> void:
	var s := minf(size.x, size.y)
	var ox := (size.x - s) * 0.5
	var oy := (size.y - s) * 0.5
	var pivot := Vector2(ox, oy) + PIVOT_UV * s
	_barrel.pivot_offset = pivot
	_barrel.rotation = atan2(_aim_dir.x, -_aim_dir.y)
	var muzzle := pivot + _aim_dir * (MUZZLE_DIST_UV * s)
	var fs := s * 0.30
	_flash.position = muzzle - Vector2(fs, fs) * 0.5
	_flash.size = Vector2(fs, fs)


# --- 公共 API ---

# 设置炮台内容；ammo<=0 时显示 0（配合 draining 态）
func set_cannon(color: Color, p_ammo: int) -> void:
	tint = color
	ammo = p_ammo
	_apply_state()


func set_visual_state(p_state: String) -> void:
	state = p_state
	_apply_state()


# 瞄准：屏幕空间方向（会归一化）；0 向量保持原方向
func set_aim_dir(dir: Vector2) -> void:
	if dir.length_squared() < 1e-6:
		return
	_aim_dir = dir.normalized()
	_layout()


# 可见炮口的屏幕坐标（发射起点契约：origin 射线从这里发出）
func muzzle_screen_center() -> Vector2:
	var s := minf(size.x, size.y)
	var pivot := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5) + PIVOT_UV * s
	return get_global_rect().position + pivot + _aim_dir * (MUZZLE_DIST_UV * s)


# CQ/S07：上位落位弹跳（0.08s 放大 + 0.12s 回弹，纯表现可被打断）
func place_feedback() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


# 成功发射后的后坐 + 炮口闪光（0.12s 后座、0.1s 闪光）
func fire_feedback() -> void:
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	var s := minf(size.x, size.y)
	var back := -_aim_dir * s * 0.06
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_barrel, "position", back, 0.05)
	_recoil_tween.tween_property(_barrel, "position", Vector2.ZERO, 0.09)
	_flash.visible = true
	_flash.modulate.a = 0.95
	var ft := create_tween()
	ft.tween_property(_flash, "modulate:a", 0.0, 0.1)
	ft.tween_callback(func() -> void: _flash.visible = false)


func _apply_state() -> void:
	if _label == null:
		return
	var show_cannon := state not in ["empty", "locked"]
	_body.visible = show_cannon
	_barrel.visible = show_cannon
	_base.visible = true  # 底座常驻（炮位存在感）
	_label.visible = show_cannon and state != "back"
	match state:
		"empty":
			_state_label.text = "空"
			_base.modulate = Color(1, 1, 1, 0.25)
		"locked":
			_state_label.text = "锁"
			_base.modulate = Color(0.4, 0.4, 0.45, 0.6)
		_:
			_state_label.text = ""
			_base.modulate = Color.WHITE
	if show_cannon:
		_body.modulate = tint
		_label.text = str(maxi(ammo, 0))
		match state:
			"back":  # 队列后排：整体压暗
				_body.modulate = tint.darkened(0.45)
				_barrel.modulate = Color(0.55, 0.55, 0.6)
				_base.modulate = Color(0.55, 0.55, 0.6)
			"waiting":  # 等待目标：略降饱和提示
				_body.modulate = tint.lerp(Color(0.7, 0.7, 0.75), 0.35)
				_barrel.modulate = Color(0.85, 0.85, 0.9)
			"draining":  # 归零结算中：灰化
				_body.modulate = tint.lerp(Color(0.4, 0.4, 0.45), 0.6)
				_barrel.modulate = Color(0.5, 0.5, 0.55)
			_:  # queued/front
				_barrel.modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		pressed.emit()
	elif event is InputEventScreenTouch and not event.pressed:
		pressed.emit()
