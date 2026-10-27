extends SceneTree

# 表现层自测（CQ-20261026）：五列 HUD 绑定/列首按钮/槽位显示/道具用尽隐藏/结算遮罩/
# 全局连击标签、音效一事件一播放、粒子上限、关卡列表
# 运行：godot --headless --path . -s tests/unit/test_presentation.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	gc.start_level("res://assets/levels/level_01.json")

	# --- HUD 绑定与同步 ---
	var hud: Control = preload("res://scripts/presentation/hud_presenter.gd").new()
	root.add_child(hud)
	hud.bind(gc)
	_check(hud._remain_label.text.contains("4105"), "剩余数同步=4105（frog_02）", hud._remain_label.text)
	var destroyed: Dictionary = gc.voxel_manager.destroy(0)
	_check(destroyed.ok, "删除块0", "")
	hud.refresh()
	_check(hud._remain_label.text.contains("4104"), "删除后剩余数=4104", hud._remain_label.text)
	_check(hud._column_views.size() == 5 and hud._slot_views.size() == 5
		and hud._column_depths.size() == 5, "五列CannonView+深度标签+五槽", "")
	# 列首炮台：非空列可点、显示列首弹数；空列禁用
	hud.refresh()
	var any_enabled := false
	for c in 5:
		if gc.session.queue_columns[c].is_empty():
			_check(hud._column_views[c].disabled and hud._column_views[c].state == "empty",
				"空列列首禁用", "col=%d" % c)
		else:
			any_enabled = any_enabled or not hud._column_views[c].disabled
	_check(any_enabled, "非空列列首可点击", "")
	# 槽位：未解锁显示"锁"禁用；空槽显示"空"
	gc.session.unlocked_slots = 3
	hud.refresh()
	_check(hud._slot_views[3].disabled and hud._slot_views[3].state == "locked"
		and hud._slot_views[3]._state_label.text == "锁", "未解锁槽显示锁", "")
	_check(hud._slot_views[0].state == "empty"
		and hud._slot_views[0]._state_label.text == "空", "空槽显示空", "")
	# 道具用尽隐藏（G13）
	gc.session.prop_counts.shuffle = 0
	hud.refresh()
	_check(not hud._prop_buttons["shuffle"].visible, "道具用尽隐藏（G13）", "")
	_check(hud._prop_buttons["speed_x2"].visible, "有次数道具可见", "")

	# --- 音效：一事件一播放（T23） ---
	var audio: Node = preload("res://scripts/presentation/audio_presenter.gd").new()
	audio.muted = true  # headless 无声卡，仅计数请求
	root.add_child(audio)
	audio.attach(gc.bus, "level_01")
	var meta := func(id: int) -> Dictionary:
		return {"event_id": id, "level_id": "level_01", "session_generation": gc.session.session_generation, "physics_tick": 0}
	gc.bus.publish("turret_fire", [{}, 1], meta.call(10001))
	gc.bus.publish("turret_fire", [{}, 2], meta.call(10002))
	gc.bus.publish("voxel_destroyed", [{"voxel_id": 1}, {}], meta.call(10003))
	gc.bus.publish("turret_merged", [{}, 0], meta.call(10004))
	_check(int(audio.play_counts.get("fire", 0)) == 2, "两次发射两次音效", str(audio.play_counts))
	_check(int(audio.play_counts.get("shatter", 0)) == 1, "一次击碎一次音效", str(audio.play_counts))
	_check(int(audio.play_counts.get("merge", 0)) == 1, "一次合成一次音效", str(audio.play_counts))
	# 重复 event_id 不重复播放
	gc.bus.publish("turret_fire", [{}, 3], meta.call(10001))
	_check(int(audio.play_counts.get("fire", 0)) == 2, "重复 event_id 不重复播放", str(audio.play_counts))
	for sfx in ["fire", "shatter", "merge", "win", "lose"]:
		_check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % sfx), "音效文件存在 %s" % sfx, "")

	# --- 粒子上限（T13/T22） ---
	var fx: Node3D = preload("res://scripts/presentation/hit_effects.gd").new()
	fx.particle_max_total = 64
	root.add_child(fx)
	var spawned := 0
	for i in 5:
		if fx.spawn_burst(Vector3.ZERO, 16):
			spawned += 1
	_check(spawned == 4 and fx.dropped_bursts == 1, "粒子总量上限 64：4 次放行 1 次丢弃",
		"spawned=%d dropped=%d" % [spawned, fx.dropped_bursts])
	# CQ/S06：每次 burst 附带 1 个同色光圈节点 → 4 粒子 + 4 光圈
	_check(fx.get_child_count() == 8, "粒子+光圈节点一次性生成", "%d" % fx.get_child_count())
	# CQ/S06：碎块棱长 0.08~0.18 体素（mesh 0.13 × scale 0.62~1.38）
	var burst_node: Node = fx.get_child(0)
	var e_min: float = burst_node.scale_amount_min * 0.13
	var e_max: float = burst_node.scale_amount_max * 0.13
	_check(e_min >= 0.08 and e_min < 0.09 and e_max <= 0.18 and e_max > 0.17,
		"碎块棱长 0.08~0.18 体素", "%f~%f" % [e_min, e_max])

	# --- CQ HUD 交互：点列首一键上位/点槽不发射/取回模式/结算遮罩/全局连击/待发标记 ---
	var gc2: Node = GameControllerScript.new()
	root.add_child(gc2)
	gc2.start_level("res://assets/levels/level_01.json")
	var hud2: Control = preload("res://scripts/presentation/hud_presenter.gd").new()
	root.add_child(hud2)
	hud2.bind(gc2)
	# 找一个非空列
	var col := -1
	for c in 5:
		if not gc2.session.queue_columns[c].is_empty():
			col = c
			break
	var front_before: int = gc2.session.queue_columns[col].size()
	hud2._on_column_pressed(col)
	_check(gc2.session.queue_columns[col].size() == front_before - 1
		and int(gc2.session.slots[0]) >= 0, "点列首一键上位到最左空槽", "")
	# 点击已占位槽位不发射（入槽自动连发），仅提示
	var fires2 := {"n": 0}
	gc2.bus.subscribe("turret_fire", func(_a: Array, _m: Dictionary) -> void: fires2.n += 1, "level_01")
	hud2._on_slot_pressed(0)
	_check(fires2.n == 0 and hud2._toast_label.text.contains("自动连发"), "点击已占位槽位不发射仅提示",
		"fires=%d toast=%s" % [fires2.n, hud2._toast_label.text])
	# P2：走完 LOADING 上位时钟（本测试无 origin_resolver，落地后也不会开火）
	for i in 20:
		gc2.step(1.0 / 60.0)
	# 取回模式：点击槽位调用 return_turret（无在途弹立即回来源列队首）
	var tid0 := int(gc2.session.slots[0])
	var origin_col := int(gc2.session.turrets[tid0].origin_column)
	hud2._on_return_toggled(true)
	_check(hud2._return_mode, "取回模式开启", "")
	hud2._on_slot_pressed(0)
	_check(int(gc2.session.slots[0]) == -1 and int(gc2.session.queue_columns[origin_col][0]) == tid0,
		"取回模式取回炮台回来源列队首", "")
	hud2._on_return_toggled(false)
	# 结算遮罩：level_win 后显示，阻断输入
	gc2.bus.publish("level_win", ["level_01"],
		{"event_id": 20001, "level_id": "level_01", "session_generation": gc2.session.session_generation, "physics_tick": 0})
	_check(hud2._result_overlay.visible and hud2._result_overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
		"结算全屏遮罩显示且阻断输入", "")
	var got_restart := {"n": 0}
	hud2.connect("restart_requested", func() -> void: got_restart.n += 1)
	hud2.restart_requested.emit()
	_check(got_restart.n == 1, "重开信号可订阅", "")
	# 连击标签（CQ §2.2 全局 streak）：combo_update [streak]，refresh 不清空
	hud2._result_overlay.visible = false
	gc2.bus.publish("combo_update", [3],
		{"event_id": 20002, "level_id": "level_01", "session_generation": gc2.session.session_generation, "physics_tick": 0})
	_check(hud2._combo_label.text == "x3", "连击标签显示 x3", hud2._combo_label.text)
	hud2.refresh()
	_check(hud2._combo_label.text == "x3", "refresh 不清连击标签", hud2._combo_label.text)
	gc2.bus.publish("combo_update", [0],
		{"event_id": 20003, "level_id": "level_01", "session_generation": gc2.session.session_generation, "physics_tick": 0})
	_check(hud2._combo_label.text == "", "连击归零隐藏", hud2._combo_label.text)
	# 待发标记：速度×2 使用后按钮显示"待发"
	gc2.use_prop("speed_x2")
	hud2.refresh()
	_check(hud2._prop_buttons["speed_x2"].text.contains("待发"), "待发道具标记", hud2._prop_buttons["speed_x2"].text)
	# slot_screen_center 供发射原点投影
	var c2: Vector2 = hud2.slot_screen_center(0)
	_check(c2.x >= 0.0 and hud2.slot_screen_center(9) == Vector2(-1, -1), "槽位屏幕中心/越界兜底", str(c2))

	# --- CQ/S07：五列滚动窗口/12px 阈值/后排禁用/上位动画 ---
	# 找最深的列（>3 门）
	var deep := -1
	for c in 5:
		if gc2.session.queue_columns[c].size() > 3:
			deep = c
			break
	_check(deep >= 0, "存在深列（>3 门）", "")
	var clip: Control = hud2._column_clips[deep]
	clip.size = Vector2(200, 300)  # headless 下显式给尺寸：行高 100
	hud2._layout_column(deep)
	# 窗口映射：前 3 门可见，仅列首 front/可用，其余 back/禁用
	hud2.refresh()
	_check(hud2._column_pools[deep][0].visible and hud2._column_pools[deep][0].state == "front"
		and not hud2._column_pools[deep][0].disabled, "窗口[0]=列首可用", "")
	_check(hud2._column_pools[deep][1].state == "back" and hud2._column_pools[deep][1].disabled
		and hud2._column_pools[deep][2].state == "back" and hud2._column_pools[deep][2].disabled,
		"窗口[1,2]=后排禁用", "")
	_check(hud2._column_depths[deep].text.contains("还有"), "深度提示'还有 N 门'",
		hud2._column_depths[deep].text)
	# 12px 阈值：5px 拖动不滚动，再拖 10px 进入滚动
	clip._begin()
	clip._drag(Vector2(0, -5))
	_check(not clip._scrolling, "5px 拖动不触发滚动（阈值内）", "")
	clip._drag(Vector2(0, -10))
	_check(clip._scrolling, "累计 15px 触发滚动", "")
	clip._release(Vector2(10, 50))
	_check(int(hud2._col_offset[deep]) == 0, "不足一行不吸附", "off=%d" % hud2._col_offset[deep])
	# 上推一整行 → offset=1，列首滚走，池[0] 变 back/禁用
	var rem: float = hud2.scroll_column_by_px(deep, -100.0)
	_check(int(hud2._col_offset[deep]) == 1 and absf(rem) < 1.0, "滚动一行吸附 offset=1",
		"off=%d rem=%f" % [hud2._col_offset[deep], rem])
	_check(hud2._column_pools[deep][0].disabled and hud2._column_pools[deep][0].state == "back",
		"上翻后窗口[0]禁用（滚动不能把后排变列首）", "")
	_check(hud2._column_depths[deep].text.contains("上翻"), "深度提示'上翻 N'",
		hud2._column_depths[deep].text)
	# 上翻状态点击：不上位，仅提示
	var n_before: int = gc2.session.queue_columns[deep].size()
	hud2._on_column_tap(deep, Vector2(10, 50))
	_check(gc2.session.queue_columns[deep].size() == n_before
		and hud2._toast_label.text.contains("上翻"), "上翻状态点击列首不上位", "")
	# 点击窗口后排（y>行高）不操作
	hud2.scroll_column_by_px(deep, 100.0)  # 回顶部
	_check(int(hud2._col_offset[deep]) == 0, "滚回顶部", "")
	hud2._on_column_tap(deep, Vector2(10, 150))
	_check(gc2.session.queue_columns[deep].size() == n_before, "点击后排窗口不操作", "")
	# 上位过渡（P2）：数据事务先完成，完整炮台在过渡层飞行+整体上移为纯表现
	await create_timer(0.4).timeout  # 先让本用例早前那次上位的过渡炮落地回收，再取基线
	var children_before: int = hud2._transition_layer.get_child_count()
	hud2._on_column_tap(deep, Vector2(10, 50))
	_check(gc2.session.queue_columns[deep].size() == n_before - 1, "上位数据事务完成", "")
	_check(hud2._transition_layer.get_child_count() == children_before + 1,
		"上位过渡炮节点生成（完整炮台飞行，非残影）",
		"%d→%d" % [children_before, hud2._transition_layer.get_child_count()])
	await create_timer(0.6).timeout  # LOADING 0.28s 落地后回收（真实帧驱动控制器时钟）
	_check(hud2._transition_layer.get_child_count() == children_before, "过渡炮落地后回收", "")
	_check(absf(float(hud2._col_shift[deep])) < 1.0, "整体上移动画收敛", "shift=%f" % hud2._col_shift[deep])

	# --- 关卡列表（T20） ---
	var ll: Control = preload("res://scripts/presentation/level_list_presenter.gd").new()
	root.add_child(ll)
	_check(ll.levels().size() >= 1 and ll.levels()[0].level_id == "level_01", "列表含 level_01", "")
	var chosen := {"id": ""}
	ll.on_level_chosen = func(level_id: String) -> void: chosen.id = level_id
	ll.choose("level_01")
	_check(chosen.id == "level_01", "选择回调", chosen.id)

	if _failures == 0:
		print("TEST_PASS test_presentation")
	else:
		print("TEST_FAIL test_presentation failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		print("  PASS: " + name)
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
