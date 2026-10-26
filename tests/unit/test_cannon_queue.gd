extends SceneTree

# CQ-20261026/S03：五列守恒队列生成器自测。
# 拆分合法（普通炮 30~80、末炮余数 1~29、无零弹、不丢余数）、100 样本逐色守恒、
# ID 唯一、五列合法（每列≥1）、固定 seed 完全复现、shuffle 只重排不造弹。
# 运行：godot --headless --path . -s tests/unit/test_cannon_queue.gd

const CannonQueue := preload("res://scripts/gameplay/cannon_queue_service.gd")
const SessionScript := preload("res://scripts/level/level_session.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_split()
	_test_generate_100_samples()
	_test_reproducible()
	_test_shuffle()
	if _failures == 0:
		print("TEST_PASS test_cannon_queue")
	else:
		print("TEST_FAIL test_cannon_queue failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_split() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for total in [1, 5, 29, 30, 31, 79, 80, 81, 100, 109, 110, 111, 160, 161, 218, 311, 3167]:
		var parts := CannonQueue.split_color_ammo(total, rng)
		var sum := 0
		for p in parts:
			sum += p
		_check(sum == total, "拆分总和=%d" % total, "got %d parts=%s" % [sum, str(parts)])
		for i in parts.size():
			var p := int(parts[i])
			_check(p >= 1, "拆分无零弹 total=%d" % total, str(parts))
			var is_last: bool = i == parts.size() - 1
			if is_last:
				_check(p <= CannonQueue.AMMO_MAX, "末炮≤80 total=%d" % total, str(parts))
			else:
				_check(p >= CannonQueue.AMMO_MIN and p <= CannonQueue.AMMO_MAX,
					"普通炮30~80 total=%d" % total, str(parts))
	# 末炮余数允许 1~29 仅在 total%某拆分下出现；81=52+29 之类合法，上面范围断言已覆盖


func _test_generate_100_samples() -> void:
	# frog_02 真实颜色统计
	var counts := {1: 3167, 4: 311, 6: 218, 7: 30, 8: 299, 9: 80}
	var total_voxels := 0
	for c in counts:
		total_voxels += int(counts[c])
	for sample in 100:
		var session := SessionScript.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + sample
		CannonQueue.generate(session, counts, rng)
		# 五列合法：每列至少一门
		_check(session.queue_columns.size() == 5, "五列 sample=%d" % sample, "")
		var lens := CannonQueue.column_lengths(session)
		for li in 5:
			if int(lens[li]) < 1:
				_check(false, "每列≥1门 sample=%d" % sample, str(lens))
				break
		# ID 唯一且队列引用一致
		var seen := {}
		var id_ok := true
		for col in session.queue_columns:
			for tid in col:
				if seen.has(tid) or not session.turrets.has(tid):
					id_ok = false
				seen[tid] = true
		_check(id_ok and seen.size() == session.turrets.size(),
			"ID唯一且全在队列 sample=%d" % sample, "seen=%d turrets=%d" % [seen.size(), session.turrets.size()])
		# 逐色守恒
		var cons := CannonQueue.conservation_report(session, counts)
		_check(bool(cons.ok), "逐色守恒 sample=%d" % sample, str(cons.per_color))
		# 总数
		var q_total := 0
		for tid in session.turrets:
			q_total += int(session.turrets[tid].ammo_remaining)
		_check(q_total == total_voxels, "总弹数=总块数 sample=%d" % sample,
			"%d vs %d" % [q_total, total_voxels])
	print("  100 样本生成校验完成")


func _test_reproducible() -> void:
	var counts := {1: 3167, 4: 311, 6: 218, 7: 30, 8: 299, 9: 80}
	var a := SessionScript.new()
	var b := SessionScript.new()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 777
	rng_b.seed = 777
	CannonQueue.generate(a, counts, rng_a)
	CannonQueue.generate(b, counts, rng_b)
	_check(a.queue_columns == b.queue_columns, "同seed队列一致", "")
	_check(str(a.turrets) == str(b.turrets), "同seed炮台一致", "")
	var c := SessionScript.new()
	var rng_c := RandomNumberGenerator.new()
	rng_c.seed = 778
	CannonQueue.generate(c, counts, rng_c)
	_check(str(c.queue_columns) != str(a.queue_columns), "异seed队列不同", "")


func _test_shuffle() -> void:
	# FM/F4：可洗前提收紧为"至少一列≥2 门"，用足量炮台保证抽屉原理必有一列≥2
	var counts := {1: 300, 4: 270}
	var session := SessionScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	CannonQueue.generate(session, counts, rng)
	var before := str(session.turrets)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 9
	var ok := CannonQueue.shuffle_columns(session, rng2)
	_check(ok, "shuffle 可执行", "")
	_check(str(session.turrets) == before, "shuffle 不改炮台数据", "")
	var flat := 0
	for col in session.queue_columns:
		flat += (col as Array).size()
	_check(flat == session.turrets.size(), "shuffle 不丢炮", "")
	# 空队列不可 shuffle（不扣次数）
	var empty := SessionScript.new()
	empty.queue_columns = [[], [], [], [], []]
	_check(not CannonQueue.shuffle_columns(empty, rng2), "空队列 shuffle 拒绝", "")


func _check(cond: bool, name: String, detail: String) -> void:
	if cond:
		pass  # 100 样本量太大，只报失败
	else:
		_failures += 1
		print("  FAIL: " + name + " " + detail)
