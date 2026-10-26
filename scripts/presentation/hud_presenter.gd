extends Control
class_name HudPresenter
const PerfProbe := preload("res://scripts/diagnostics/perf_probe.gd")

## CQ-20261026 HUD：顶部信息、固定五槽位、五列可变长队列（仅列首可点）、道具行、结算遮罩。
## 分区（S02 §4）：信息 0~10%、模型 10~56%、炮位 57~65%、队列 66~91%、道具 92~100%。
## 槽位按钮屏幕中心 = FireGeometry.slot_screen_center（发射原点投影契约，运行时/验证器共用）。
## UI 只读会话状态 + 调用控制器命令；炮台数据唯一容器是 session.turrets。

signal restart_requested
signal back_requested

const FireGeom := preload("res://scripts/gameplay/fire_geometry.gd")

const PALETTE_FALLBACK := {
	1: Color("#4CAF50"), 2: Color("#F44336"), 3: Color("#2196F3"), 4: Color("#FFEB3B"),
	5: Color("#9C27B0"), 6: Color("#FAFAFA"), 7: Color("#212121"), 8: Color("#8BC34A"),
	9: Color("#FF9800"),
}
const PROP_LABELS := {"speed_x2": "速度×2", "add_slot": "加槽", "designated_target": "指定目标", "shuffle": "随机排"}  # CQ/S08：任意指→指定目标
const PROP_PENDING := {"speed_x2": "speed_x2", "designated_target": "designated_selecting"}  # 有"待发"态的道具

var controller: Node = null
var camera: Camera3D = null   # main 注入：炮管瞄准屏幕投影用（CQ/S06）

var _level_label: Label
var _remain_label: Label
var _combo_label: Label
var _toast_label: Label
var _result_overlay: Control
var _pause_overlay: Control       # FM/F4：运行中暂停遮罩（继续/重开/返回）
var _result_title: Label
var _column_views: Array[CannonView] = []   # 5 列列首炮台视图（= 池[0]，CQ/S06 与炮位共用 CannonView）
var _column_pools: Array = []               # 5 列 × 3 门可见窗口（CQ/S07 视图复用池）
var _column_clips: Array = []               # 5 列裁切/滚动容器
var _col_offset := [0, 0, 0, 0, 0]          # 每列滚动偏移（0=列首在顶；只有 offset=0 可操作）
var _col_shift := [0.0, 0.0, 0.0, 0.0, 0.0] # 上位/滚动动画位移（px，纯表现）
var _column_depths: Array[Label] = []       # 5 列深度标签
var _slot_views: Array[CannonView] = []     # 固定五槽炮台视图
var _prop_buttons: Dictionary = {}
var _return_button: Button
var _return_mode := false          # 取回模式
var _merge_button: Button = null   # CQ/S08：合成模式开关
var _merge_mode := false
var _merge_first := -1             # 合成模式已选的第一列
var _idle_time := 0.0              # CQ/S08 §5：无进展计时（5s 提示）
var _refresh_dirty := false        # FM/F4：事件驱动的刷新按帧合并（用户直接操作仍即时 refresh）
var _toast_token := 0
var _debug_button: Button = null   # CQ/S07：守恒调试面板开关（仅 debug 构建）
var _debug_panel: Label = null

const COLUMN_WINDOW := 3           # 每列可见窗口（S07：至少展示前三门）
const SCROLL_THRESHOLD_PX := 12.0  # 点击/滚动移动阈值（S07 §6）


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size = get_viewport_rect().size  # CanvasLayer 父级不提供 Control 尺寸，显式取视口
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()


func bind(p_controller: Node) -> void:
	controller = p_controller
	_return_mode = false
	for c in 5:
		_col_offset[c] = 0
		_col_shift[c] = 0.0
	if _return_button != null:
		_return_button.button_pressed = false
		_return_button.text = "取回"
	if _debug_panel != null:
		_debug_panel.visible = false
	_result_overlay.visible = false
	if _pause_overlay != null:
		_pause_overlay.visible = false  # FM/F4：换局/重开时收起暂停遮罩
	for e in ["voxel_destroyed", "turret_fire", "turret_merged", "item_activated",
			"queue_changed", "slots_changed", "turret_state_changed", "shot_resolved"]:
		# FM/F4：事件刷新只置脏标，_process 每帧最多合并执行一次（10-30 发/秒事件洪流不重建 N 次）
		controller.bus.subscribe(e, func(_a: Array, _m: Dictionary) -> void: _refresh_dirty = true,
			controller.session.level_id)
	# 发射反馈（后坐+炮口闪光，仅成功发射后触发）
	controller.bus.subscribe("turret_fire", _on_fire_feedback, controller.session.level_id)
	# 连击专属订阅：不被 refresh 清掉
	controller.bus.subscribe("combo_update", _on_combo_update, controller.session.level_id)
	controller.bus.subscribe("level_win", _on_outcome.bind("WON"), controller.session.level_id)
	controller.bus.subscribe("level_lose", _on_outcome.bind("LOST"), controller.session.level_id)
	# CQ/S08：完整性错误（守恒破坏，不包装成正常失败）+ 指定目标失效提示
	controller.bus.subscribe("integrity_error", _on_outcome.bind("ERROR"), controller.session.level_id)
	controller.bus.subscribe("designated_expired",
		func(_a: Array, _m: Dictionary) -> void: show_action_result("指定目标已失效，恢复自动选靶"),
		controller.session.level_id)
	# 无进展计时：消除/上位/发射/合成都算进展
	for e2 in ["voxel_destroyed", "turret_fire", "queue_changed", "slots_changed"]:
		controller.bus.subscribe(e2, func(_a: Array, _m: Dictionary) -> void: _idle_time = 0.0,
			controller.session.level_id)
	_merge_mode = false
	_merge_first = -1
	if _merge_button != null:
		_merge_button.button_pressed = false
		_merge_button.text = "合成"
	_idle_time = 0.0
	_refresh_dirty = false
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
	_combo_label.add_theme_font_size_override("font_size", 48)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	top.add_child(_combo_label)
	_remain_label = Label.new()
	_remain_label.add_theme_font_size_override("font_size", 36)
	top.add_child(_remain_label)
	# FM/F4：运行中暂停按钮（继续/重开/返回，走控制器 _paused 门）
	var pause_btn := _make_button("暂停", Color(0.25, 0.28, 0.35))
	pause_btn.custom_minimum_size = Vector2(120, 60)
	pause_btn.pressed.connect(_on_pause_pressed)
	top.add_child(pause_btn)
	# CQ/S07 §5：守恒调试面板（仅 debug 构建，正式 HUD 不堆实现细节）
	if OS.is_debug_build():
		_debug_button = _make_button("守恒", Color(0.2, 0.2, 0.25))
		_debug_button.custom_minimum_size = Vector2(120, 60)
		_debug_button.pressed.connect(_toggle_debug_panel)
		top.add_child(_debug_button)
		_debug_panel = Label.new()
		_debug_panel.anchor_left = 0.0
		_debug_panel.anchor_right = 1.0
		_debug_panel.anchor_top = 0.08
		_debug_panel.anchor_bottom = 0.30
		_debug_panel.add_theme_font_size_override("font_size", 22)
		_debug_panel.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		_debug_panel.visible = false
		add_child(_debug_panel)

	_toast_label = Label.new()
	_toast_label.anchor_left = 0.0
	_toast_label.anchor_right = 1.0
	_toast_label.anchor_top = 0.52
	_toast_label.anchor_bottom = 0.56
	_toast_label.add_theme_font_size_override("font_size", 32)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast_label)

	# 炮位区 57%~65%：固定五槽等宽（发射原点投影契约），右侧窄条放取回开关
	var slot_row := HBoxContainer.new()
	slot_row.anchor_left = 0.0
	slot_row.anchor_right = 1.0
	slot_row.anchor_top = 0.57
	slot_row.anchor_bottom = 0.65
	slot_row.add_theme_constant_override("separation", 0)
	add_child(slot_row)
	for i in 5:
		var cv := CannonView.new()
		cv.size_flags_horizontal = SIZE_EXPAND_FILL
		cv.size_flags_vertical = SIZE_EXPAND_FILL
		cv.custom_minimum_size = Vector2(0, 0)
		cv.pressed.connect(_on_slot_pressed.bind(i))
		slot_row.add_child(cv)
		_slot_views.append(cv)

	# 队列区 66%~91%：五列。CQ/S07：每列 = 可滚动裁切窗（3 门可见窗口，视图复用池，
	# 只有 offset=0 的实际列首可操作，滚动不能把后排变列首）+ 深度标签。
	var queue_row := HBoxContainer.new()
	queue_row.anchor_left = 0.0
	queue_row.anchor_right = 1.0
	queue_row.anchor_top = 0.66
	queue_row.anchor_bottom = 0.91
	queue_row.add_theme_constant_override("separation", 6)
	add_child(queue_row)
	for c in 5:
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		queue_row.add_child(vbox)
		var clip := ColumnClip.new()
		clip.hud = self
		clip.column = c
		clip.clip_contents = true
		clip.mouse_filter = MOUSE_FILTER_STOP  # 消费拖拽：拖队列不转模型（S07 输入优先级）
		clip.size_flags_vertical = SIZE_EXPAND_FILL
		vbox.add_child(clip)
		_column_clips.append(clip)
		var pool: Array[CannonView] = []
		for i in COLUMN_WINDOW:
			var w := CannonView.new()
			clip.add_child(w)
			# 必须在 add_child 之后设置：CannonView._ready 会重置为 STOP（槽位需要）。
			# 队列表图 IGNORE，输入统一由裁切窗分发（12px 阈值区分点/滚）。
			w.mouse_filter = MOUSE_FILTER_IGNORE
			pool.append(w)
		_column_pools.append(pool)
		_column_views.append(pool[0])  # 兼容引用：列首视图 = 池[0]
		clip.resized.connect(_layout_column.bind(c))
		var dl := Label.new()
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", 24)
		dl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		vbox.add_child(dl)
		_column_depths.append(dl)

	# 道具区 92%~100%
	var props_row := HBoxContainer.new()
	props_row.anchor_left = 0.0
	props_row.anchor_right = 1.0
	props_row.anchor_top = 0.92
	props_row.anchor_bottom = 1.0
	props_row.alignment = BoxContainer.ALIGNMENT_CENTER
	props_row.add_theme_constant_override("separation", 8)
	add_child(props_row)
	for prop in ["speed_x2", "add_slot", "designated_target", "shuffle"]:
		var b := _make_button(PROP_LABELS[prop], Color(0.25, 0.25, 0.3))
		b.custom_minimum_size = Vector2(190, 0)
		b.size_flags_vertical = SIZE_EXPAND_FILL
		b.pressed.connect(_on_prop_pressed.bind(prop))
		props_row.add_child(b)
		_prop_buttons[prop] = b
	_return_button = _make_button("取回", Color(0.3, 0.22, 0.16))
	_return_button.custom_minimum_size = Vector2(150, 0)
	_return_button.size_flags_vertical = SIZE_EXPAND_FILL
	_return_button.toggle_mode = true
	_return_button.toggled.connect(_on_return_toggled)
	props_row.add_child(_return_button)
	# CQ/S08 §2.4：合成是独立模式（非消耗道具），未启用时点击只负责上位
	_merge_button = _make_button("合成", Color(0.22, 0.3, 0.2))
	_merge_button.custom_minimum_size = Vector2(150, 0)
	_merge_button.size_flags_vertical = SIZE_EXPAND_FILL
	_merge_button.toggle_mode = true
	_merge_button.toggled.connect(_on_merge_toggled)
	props_row.add_child(_merge_button)

	# 结算全屏遮罩：阻断底层输入，重开/返回按钮
	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_result_overlay.color = Color(0, 0, 0, 0.7)
	_result_overlay.mouse_filter = MOUSE_FILTER_STOP
	_result_overlay.visible = false
	add_child(_result_overlay)
	var center_box := VBoxContainer.new()
	center_box.set_anchors_preset(PRESET_CENTER, false)
	center_box.offset_left = -260
	center_box.offset_right = 260
	center_box.offset_top = -200
	center_box.offset_bottom = 200
	center_box.add_theme_constant_override("separation", 40)
	_result_overlay.add_child(center_box)
	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 96)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(_result_title)
	var restart_btn := _make_button("重开本关", Color(0.2, 0.45, 0.25))
	restart_btn.custom_minimum_size = Vector2(480, 120)
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	center_box.add_child(restart_btn)
	var back_btn := _make_button("返回列表", Color(0.3, 0.3, 0.36))
	back_btn.custom_minimum_size = Vector2(480, 120)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	center_box.add_child(back_btn)

	# FM/F4：暂停全屏遮罩（继续/重开/返回；暂停期 _paused 门冻结调度/物理/自动旋转/无进展计时）
	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_pause_overlay.color = Color(0, 0, 0, 0.6)
	_pause_overlay.mouse_filter = MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	add_child(_pause_overlay)
	var pause_box := VBoxContainer.new()
	pause_box.set_anchors_preset(PRESET_CENTER, false)
	pause_box.offset_left = -260
	pause_box.offset_right = 260
	pause_box.offset_top = -260
	pause_box.offset_bottom = 260
	pause_box.add_theme_constant_override("separation", 40)
	_pause_overlay.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "已暂停"
	pause_title.add_theme_font_size_override("font_size", 96)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	var resume_btn := _make_button("继续", Color(0.2, 0.45, 0.25))
	resume_btn.custom_minimum_size = Vector2(480, 120)
	resume_btn.pressed.connect(_on_resume_pressed)
	pause_box.add_child(resume_btn)
	var pause_restart := _make_button("重开本关", Color(0.35, 0.3, 0.2))
	pause_restart.custom_minimum_size = Vector2(480, 120)
	pause_restart.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		if controller != null:
			controller.set_paused(false)
		restart_requested.emit())
	pause_box.add_child(pause_restart)
	var pause_back := _make_button("返回列表", Color(0.3, 0.3, 0.36))
	pause_back.custom_minimum_size = Vector2(480, 120)
	pause_back.pressed.connect(func() -> void:
		_pause_overlay.visible = false
		if controller != null:
			controller.set_paused(false)
		back_requested.emit())
	pause_box.add_child(pause_back)


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
	var _pt := PerfProbe.t0()
	var s: RefCounted = controller.session
	_level_label.text = "关卡 %s" % s.level_id
	_remain_label.text = "  剩余 %d" % controller.voxel_manager.alive_count()
	# 连击标签由 combo_update 专属订阅维护，这里不清空

	for c in 5:
		_refresh_column(c, s)
	for i in 5:
		var cv := _slot_views[i]
		var unlocked: bool = i < s.unlocked_slots
		var tid: int = int(s.slots[i]) if i < s.slots.size() else -1
		if not unlocked:
			cv.set_visual_state("locked")
			cv.disabled = true
			continue
		if tid < 0:
			cv.set_visual_state("empty")
			cv.disabled = true  # 空槽不可点（上位走列首）
			continue
		cv.disabled = false
		var t: Dictionary = s.turrets.get(tid, {})
		cv.set_cannon(_color_of(int(t.get("color_id", 0))), int(t.get("ammo_remaining", 0)))
		# CQ §2.2 状态映射：归零结算中 / 待取回 / 等待目标 / 正常
		if int(t.get("ammo_remaining", 0)) <= 0 or t.get("state", "") == "DRAINING":
			cv.set_visual_state("draining")
		elif t.get("state", "") == "RETURN_PENDING" or t.get("state", "") == "WAITING_TARGET":
			cv.set_visual_state("waiting")
		else:
			cv.set_visual_state("front")
	for prop in _prop_buttons:
		var count := int(s.prop_counts.get(prop, 0))
		var b: Button = _prop_buttons[prop]
		# 待发标记：已使用、等待下一发生效
		var pending: bool = PROP_PENDING.has(prop) and bool(s.pending_effects.get(PROP_PENDING[prop], false))
		b.text = "%s×%d%s" % [PROP_LABELS[prop], count, " 待发" if pending else ""]
		b.visible = count > 0 or pending
	PerfProbe.add("hud_refresh", _pt)


# CQ/S07：列刷新 = 3 门可见窗口映射（视图复用池，不为整列建节点）；
# 只有 offset=0 的实际列首是 front/可操作，窗口其余为 back/禁用。
func _refresh_column(c: int, s: RefCounted) -> void:
	var pool: Array = _column_pools[c]
	var dl := _column_depths[c]
	var col: Array = s.queue_columns[c] if c < s.queue_columns.size() else []
	var n := col.size()
	_col_offset[c] = clampi(int(_col_offset[c]), 0, maxi(n - 1, 0))
	var off: int = _col_offset[c]
	if n == 0:
		pool[0].visible = true
		pool[0].set_visual_state("empty")
		pool[0].disabled = true
		for i in range(1, COLUMN_WINDOW):
			pool[i].visible = false
		dl.text = ""
		return
	for i in COLUMN_WINDOW:
		var cv: CannonView = pool[i]
		var idx := off + i
		if idx >= n:
			cv.visible = false
			continue
		cv.visible = true
		var t: Dictionary = s.turrets.get(int(col[idx]), {})
		cv.set_cannon(_color_of(int(t.get("color_id", 0))), int(t.get("ammo_remaining", 0)))
		if idx == 0:
			cv.set_visual_state("front")
			cv.disabled = false
		else:
			cv.set_visual_state("back")
			cv.disabled = true  # 后排正确禁用（S07 通过条件）
	var parts: Array = []
	if off > 0:
		parts.append("上翻 %d" % off)
	var rest := n - off - 1
	parts.append("还有 %d 门" % rest if rest > 0 else "末门")
	dl.text = " · ".join(parts)
	if _debug_panel != null and _debug_panel.visible:
		_update_debug_panel()


# 列行高（可见窗口均分裁切区高度）
func _row_height(c: int) -> float:
	if c < 0 or c >= _column_clips.size():
		return 0.0
	return (_column_clips[c] as Control).size.y / float(COLUMN_WINDOW)


# 窗口定位：i 号池视图放在第 i 行 + 动画位移（上位整体上移/滚动吸附）
func _layout_column(c: int) -> void:
	if c < 0 or c >= _column_pools.size():
		return
	var clip: Control = _column_clips[c]
	var row_h := clip.size.y / float(COLUMN_WINDOW)
	var pool: Array = _column_pools[c]
	for i in pool.size():
		(pool[i] as Control).position = Vector2(0, i * row_h + _col_shift[c])
		(pool[i] as Control).size = Vector2(clip.size.x, row_h)


# CQ/S07 §2：队列纵向滚动（整行吸附）。dy>0 下拉=回看前排；返回未消费的像素余量。
func scroll_column_by_px(c: int, dy: float) -> float:
	var row_h := _row_height(c)
	if row_h <= 1.0 or controller == null or controller.session == null:
		return dy
	var col: Array = controller.session.queue_columns[c]
	var max_off: int = maxi(col.size() - 1, 0)
	var rows := int(dy / row_h)
	if rows == 0:
		return dy
	var new_off: int = clampi(int(_col_offset[c]) - rows, 0, max_off)
	var consumed := float(int(_col_offset[c]) - new_off) * row_h
	if new_off != int(_col_offset[c]):
		_col_offset[c] = new_off
		refresh()
	return dy - consumed  # 余量留给下一行吸附


# 裁切窗点击分发（12px 阈值由 ColumnClip 判定后到达这里 = 纯点击）
func _on_column_tap(c: int, local_pos: Vector2) -> void:
	if controller == null or controller.session == null:
		return
	if int(_col_offset[c]) != 0:
		show_action_result("已上翻浏览，拖回顶部操作列首")
		return
	if local_pos.y > _row_height(c):
		return  # 点击窗口内后排：禁用，不操作（S07：不能把后排变列首）
	# CQ/S08 §2.4：合成独立模式——只对两列列首同色炮台操作，未启用时点击只负责上位
	if _merge_mode:
		if _merge_first < 0:
			if controller.session.queue_columns[c].is_empty():
				show_action_result("空列不能合成")
				return
			_merge_first = c
			show_action_result("再点另一列同色列首完成合成")
			return
		if c == _merge_first:
			show_action_result("已选该列，点另一列合成")
			return
		var res: Dictionary = controller.merge_columns(_merge_first, c)
		show_action_result("合成成功" if res.get("ok", false)
			else "合成失败：%s" % str(res.get("reason", "")))
		_merge_mode = false
		_merge_first = -1
		_merge_button.button_pressed = false
		_merge_button.text = "合成"
		refresh()
		return
	_on_column_pressed(c)


# CQ/S07 §5：守恒调试面板（debug 构建）
func _toggle_debug_panel() -> void:
	if _debug_panel == null:
		return
	_debug_panel.visible = not _debug_panel.visible
	if _debug_panel.visible:
		_update_debug_panel()


func _update_debug_panel() -> void:
	if controller == null or controller.session == null:
		return
	var audit: Dictionary = controller.conservation_audit()
	var lines: Array = ["守恒 Q+S+F=V, V+D=V0：%s" % ("OK" if audit.get("ok", false) else "BROKEN")]
	for cid in audit.get("per_color", {}):
		var p: Dictionary = audit.per_color[cid]
		lines.append("色%s Q%d S%d F%d = V%d / V0 %d %s" % [
			str(cid), int(p.Q), int(p.S), int(p.F), int(p.V), int(p.V0),
			"" if p.ok else " ✗"])
	_debug_panel.text = "\n".join(lines)


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


# CQ/S06：发射起点 = 可见炮口屏幕坐标（不再是按钮中心）；空槽/越界回退槽位中心契约
func slot_muzzle_screen_center(index: int) -> Vector2:
	if index < 0 or index >= _slot_views.size():
		return Vector2(-1, -1)
	var cv := _slot_views[index]
	if cv.state in ["empty", "locked"]:
		return FireGeom.slot_screen_center(index, size)
	return cv.muzzle_screen_center()


func slot_screen_center(index: int) -> Vector2:
	if index < 0 or index >= _slot_views.size():
		return Vector2(-1, -1)
	return _slot_views[index].get_global_rect().get_center()


# 炮管瞄准（CQ/S06 §4）：有在途票据→朝目标体素屏幕投影；否则朝模型中心投影
func _process(_delta: float) -> void:
	# FM/F4：事件触发的刷新合并为每帧至多一次（绑定事件仅置脏标）
	if _refresh_dirty:
		_refresh_dirty = false
		refresh()
	# CQ/S08 §5：5 秒无进展提示（暂停/非 RUNNING 不计时，有进展即清零）
	if controller != null and controller.session != null and visible \
			and controller.session.outcome == "RUNNING" and not controller._paused:
		_idle_time += _delta
		if _idle_time >= 5.0:
			_idle_time = 0.0
			show_action_result("旋转模型或更换炮台")
	if controller == null or controller.session == null or camera == null \
			or controller.voxel_model == null or not visible:
		return
	var s: RefCounted = controller.session
	var wfg: Transform3D = controller.voxel_model.world_from_grid()
	var center_world: Vector3 = wfg * controller.ball_physics.system.boundary_center
	for i in _slot_views.size():
		var cv := _slot_views[i]
		if cv.state in ["empty", "locked"]:
			continue
		var tid: int = int(s.slots[i]) if i < s.slots.size() else -1
		if tid < 0:
			continue
		var target_world := center_world
		# FM/F2：多球在途——炮管瞄准最新一颗的目标
		var ticket: Dictionary = controller.shot_ledger.latest_ticket_by_turret(tid)
		if not ticket.is_empty():
			var vid := int(ticket.target_voxel_id)
			if controller.voxel_manager.is_alive(vid):
				target_world = wfg * (controller.voxel_manager.data.positions[vid] + Vector3(0.5, 0.5, 0.5))
		var screen := camera.unproject_position(target_world)
		cv.set_aim_dir(screen - cv.get_global_rect().get_center())


# FM/F4：暂停只在 RUNNING 局内生效（结算遮罩已覆盖终局）；恢复走 _paused 门，不补发不补转
func _on_pause_pressed() -> void:
	if controller == null or controller.session == null \
			or controller.session.outcome != "RUNNING" or controller._paused:
		return
	controller.set_paused(true)
	_pause_overlay.visible = true


func _on_resume_pressed() -> void:
	_pause_overlay.visible = false
	if controller != null:
		controller.set_paused(false)


# main 退后台恢复时避免冲掉用户手动暂停
func is_pause_overlay_visible() -> bool:
	return _pause_overlay != null and _pause_overlay.visible


func _on_fire_feedback(args: Array, _m: Dictionary) -> void:
	if controller == null or controller.session == null:
		return
	var tid := int((args[0] as Dictionary).get("turret_id", -1))
	var slot: int = controller.session.slots.find(tid)
	if slot >= 0 and slot < _slot_views.size():
		_slot_views[slot].fire_feedback()


# 操作结果 toast（失败原因/规则提示），2 秒自动消失
func show_action_result(text: String) -> void:
	_toast_label.text = text
	_toast_token += 1
	var token := _toast_token
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if token == _toast_token:
			_toast_label.text = "")


# --- 交互（视图 → 控制器命令） ---

# CQ §2.1：只有列首可点击上位；点击列即把列首送入最左空闲炮位（一键上位）。
# CQ/S07 §4：数据事务先完成（place_front 原子提交），动画纯表现——即使被 refresh 重建
# 打断，业务状态也已正确推进，动画不是唯一推进入口。
func _on_column_pressed(c: int) -> void:
	if controller == null or controller.session == null:
		return
	var res: Dictionary = controller.place_front(c)
	if not res.get("ok", false):
		var reason := str(res.get("reason", ""))
		show_action_result("炮位已满" if reason == "slots_full" else "无法上位：%s" % reason)
	else:
		_play_place_animation(c, int(res.get("slot", -1)), int(res.get("turret_id", -1)))
	refresh()


# 上位表现：列首残影飞向槽位 + 槽位落位弹跳 + 队列整体上移（全部纯表现，可被打断）
func _play_place_animation(c: int, slot: int, tid: int) -> void:
	if c < 0 or c >= _column_pools.size() or slot < 0 or slot >= _slot_views.size():
		return
	# 1) 残影飞行动画
	var from_rect: Rect2 = (_column_pools[c][0] as Control).get_global_rect()
	var to_rect: Rect2 = _slot_views[slot].get_global_rect()
	var side: float = minf(from_rect.size.x, from_rect.size.y)
	var ghost := TextureRect.new()
	ghost.texture = CannonView.TEX_BODY
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var t: Dictionary = controller.session.turrets.get(tid, {})
	ghost.modulate = _color_of(int(t.get("color_id", 0)))
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.size = Vector2(side, side)
	ghost.global_position = from_rect.get_center() - ghost.size * 0.5
	add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "global_position",
		to_rect.get_center() - ghost.size * 0.5, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ghost, "modulate:a", 0.3, 0.18)
	tw.tween_callback(ghost.queue_free)
	# 2) 槽位落位弹跳
	_slot_views[slot].place_feedback()
	# 3) 队列整体上移一行（映射已按新数据刷新，内容从低一行滑回）
	var row_h := _row_height(c)
	if row_h > 1.0:
		_col_shift[c] = row_h
		var stw := create_tween()
		stw.tween_method(func(v: float) -> void:
			_col_shift[c] = v
			_layout_column(c), row_h, 0.0, 0.15)


func _on_slot_pressed(i: int) -> void:
	if controller == null or controller.session == null:
		return
	var s: RefCounted = controller.session
	var tid: int = int(s.slots[i]) if i < s.slots.size() else -1
	# CQ/S08：指定目标选择模式优先——点炮位选炮（不发射、不取回）
	if controller.designated_state().get("selecting", false):
		var dres: Dictionary = controller.designated_select_turret(i)
		if dres.get("ok", false):
			show_action_result("点击模型上的同色方块（再次点道具可取消）")
		else:
			show_action_result("请选择有弹药的炮位")
		return
	if _return_mode:
		if tid >= 0:
			var res: Dictionary = controller.return_turret(i)
			if not res.get("ok", false):
				show_action_result("取回失败：%s" % str(res.get("reason", "")))
			elif res.get("pending", false):
				show_action_result("有在途弹，结算后取回")
		return
	if tid >= 0:
		# 点击已占位槽位不发射；入槽即自动连发
		show_action_result("炮台入槽后自动连发")
	refresh()


func _on_merge_toggled(pressed: bool) -> void:
	_merge_mode = pressed
	_merge_first = -1
	_merge_button.text = "合成…" if pressed else "合成"
	if pressed:
		show_action_result("合成模式：点击一列列首，再点另一列同色列首")


# CQ/S08：指定目标——是否处于"等点模型选体素"阶段（main 据此把模型点击路由到这里）
func designated_picking_voxel() -> bool:
	if controller == null or controller.session == null:
		return false
	var st: Dictionary = controller.designated_state()
	return bool(st.get("selecting", false)) and int(st.get("slot", -1)) >= 0


func designated_pick_at(screen: Vector2) -> void:
	if camera == null:
		return
	var res: Dictionary = controller.designated_select_voxel(screen, camera)
	if res.get("ok", false):
		show_action_result("已指定目标，下一发优先命中")
	else:
		match str(res.get("reason", "")):
			"wrong_color":
				show_action_result("只能选同色方块（不扣次数）")
			"unreachable":
				show_action_result("该方块被遮挡，选不中（不扣次数）")
			"reserved":
				show_action_result("该方块已被预订（不扣次数）")
			_:
				show_action_result("没选中方块（不扣次数）")
	refresh()


func _on_return_toggled(pressed: bool) -> void:
	_return_mode = pressed
	_return_button.text = "取回…" if pressed else "取回"
	if pressed:
		show_action_result("取回模式：点击已占位槽位")


func _on_prop_pressed(prop: String) -> void:
	if controller == null:
		return
	# CQ/S08：指定目标是选择模式（激活不扣次，接受合法选择才扣次）；再次点击取消
	if prop == "designated_target":
		if controller.designated_state().get("selecting", false):
			controller.designated_cancel()
			show_action_result("已取消指定目标（未扣次数）")
			refresh()
			return
		var dres: Dictionary = controller.use_prop(prop)
		if dres.get("ok", false):
			show_action_result("指定目标：点击一个炮位选择炮台")
		else:
			show_action_result("道具失败：%s" % str(dres.get("reason", "")))
		refresh()
		return
	var res: Dictionary = controller.use_prop(prop)
	if not res.get("ok", false):
		show_action_result("道具失败：%s" % str(res.get("reason", "")))
	refresh()


# CQ-20261026 §2.2：combo_update [streak] 全局连续命中序列（无 ball_id 维度）
func _on_combo_update(args: Array, _m: Dictionary) -> void:
	var streak := int(args[0])
	_combo_label.text = "x%d" % streak if streak >= 2 else ""


func _on_outcome(_a: Array, _m: Dictionary, outcome: String) -> void:
	refresh()
	match outcome:
		"WON":
			_result_title.text = "通关！"
		"ERROR":
			_result_title.text = "数据完整性错误\n请重开本关"  # CQ/S08 §6：不包装成正常失败
		_:
			_result_title.text = "失败"
	_result_overlay.visible = true


# CQ/S07：列裁切/滚动容器。12 逻辑像素阈值区分点击与滚动（§6）；
# mouse_filter=STOP 消费拖拽，拖队列不会穿透为模型旋转（输入优先级：队列 > 旋转）。
class ColumnClip extends Control:
	var hud: HudPresenter = null
	var column := 0
	var _pressed := false
	var _scrolling := false
	var _accum := 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin()
			else:
				_release(event.position)
		elif event is InputEventScreenTouch:
			if event.pressed:
				_begin()
			else:
				_release(event.position)
		elif event is InputEventMouseMotion and _pressed:
			_drag(event.relative)
		elif event is InputEventScreenDrag:
			_drag(event.relative)

	func _begin() -> void:
		_pressed = true
		_scrolling = false
		_accum = 0.0

	func _drag(rel: Vector2) -> void:
		if not _pressed:
			return
		_accum += rel.y
		if not _scrolling and absf(_accum) > HudPresenter.SCROLL_THRESHOLD_PX:
			_scrolling = true
		if _scrolling and hud != null:
			_accum = hud.scroll_column_by_px(column, _accum)

	func _release(pos: Vector2) -> void:
		if not _pressed:
			return
		_pressed = false
		if not _scrolling and hud != null:
			hud._on_column_tap(column, pos)
