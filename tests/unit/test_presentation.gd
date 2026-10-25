extends SceneTree

# P5-01~05 表现层自测：HUD 绑定/道具用尽隐藏/选中高亮、音效一事件一播放、粒子上限、关卡列表
# 运行：godot --headless --path . -s tests/unit/test_presentation.gd

var _failures := 0

const GameControllerScript := preload("res://scripts/app/game_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gc: Node = GameControllerScript.new()
	root.add_child(gc)
	gc.start_level("res://assets/levels/level_01.json")

	# --- HUD 绑定与同步（T02/T24） ---
	var hud: Control = preload("res://scripts/presentation/hud_presenter.gd").new()
	root.add_child(hud)
	hud.bind(gc)
	_check(hud._remain_label.text.contains("367"), "剩余数同步=367", hud._remain_label.text)
	var destroyed: Dictionary = gc.voxel_manager.destroy(0)
	_check(destroyed.ok, "删除块0", "")
	hud.refresh()
	_check(hud._remain_label.text.contains("366"), "删除后剩余数=366", hud._remain_label.text)
	_check(hud._pool_buttons.size() == 9 and hud._slot_buttons.size() == 5, "池9槽5按钮", "")
	gc.session.pool[3] = {}
	hud.refresh()
	_check(hud._pool_buttons[3].disabled, "空池格按钮禁用", "")
	hud.selected_pool = 0
	hud.refresh()
	_check(not hud._pool_buttons[0].disabled, "选中态不崩溃", "")
	gc.session.prop_counts.shuffle = 0
	hud.refresh()
	_check(not hud._prop_buttons["shuffle"].visible, "道具用尽隐藏（G13）", "")
	_check(hud._prop_buttons["speed_x2"].visible, "有次数道具可见", "")

	# 槽可见性随解锁数
	gc.session.unlocked_slots = 3
	hud.refresh()
	_check(hud._slot_buttons[2].visible and not hud._slot_buttons[3].visible, "槽按解锁数显示", "")

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
	_check(fx.get_child_count() == 4, "粒子节点一次性生成", "%d" % fx.get_child_count())

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
