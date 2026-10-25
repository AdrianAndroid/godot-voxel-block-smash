extends Control
class_name LevelListPresenter

## P5-01 关卡列表：从 LevelCatalog 读取，按 display_number 排序，选择回调给 main。

const LevelCatalog := preload("res://scripts/level/level_catalog.gd")

var on_level_chosen: Callable = Callable()

var _container: VBoxContainer


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size  # CanvasLayer 父级不提供 Control 尺寸，显式取视口
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.size = size
	add_child(bg)
	_container = VBoxContainer.new()
	_container.anchor_left = 0.5
	_container.anchor_right = 0.5
	_container.anchor_top = 0.5
	_container.anchor_bottom = 0.5
	_container.offset_left = -260
	_container.offset_right = 260
	_container.offset_top = -300
	_container.add_theme_constant_override("separation", 20)
	add_child(_container)
	refresh()


func refresh() -> void:
	for c in _container.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "选择关卡"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(title)
	for config in LevelCatalog.list_levels():
		var b := Button.new()
		b.text = "第 %d 关" % int(config.display_number)
		b.custom_minimum_size = Vector2(400, 120)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(_on_chosen.bind(str(config.level_id)))
		_container.add_child(b)


func levels() -> Array:
	return LevelCatalog.list_levels()


func choose(level_id: String) -> void:
	_on_chosen(level_id)


func _on_chosen(level_id: String) -> void:
	if on_level_chosen.is_valid():
		on_level_chosen.call(level_id)
