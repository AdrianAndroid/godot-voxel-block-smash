extends RefCounted

# 已批准规则参数（架构 v6：仅批准参数、带 GDD 版本；数值来源 GDD"执行默认值决策"）
# 阶段：阶段3。关卡 rules 可覆盖默认值；空 rules 仅用于阶段2导入验证

const GDD_VERSION := "v6"

var initial_slots := 3
var max_slots := 5
var merge_max := 160  # CQ-20261026 §2.4：合成上限 160（替代旧 99）
var ball_speed := 40.0
var ball_radius := 0.35
var boundary_margin := 8.0
var initial_props := {"speed_x2": 3, "add_slot": 1, "designated_target": 2, "shuffle": 2}
var turret_ammo_min := 30  # CQ-20261026/S03：普通炮 30~80 发，末炮余数 1~29
var turret_ammo_max := 80
var palette_color_ids: Array = [1, 2, 3, 4, 5, 6, 7]  # D05 七色离散 id
var palette_weights: Dictionary = {}  # 【新增代码】color_id -> 模型块数（D05 加权随机；空=均匀兜底）
var rotate_sensitivity := 0.01
var particle_max_total := 512
var particle_per_hit := 16
var particle_lifetime := 0.8
var auto_fire_interval := 0.25  # 【新增代码】入槽自动连发间隔秒数（GDD §10 执行默认，非用户指定数值）


static func from_rules(rules: Dictionary) -> RefCounted:
	var r := preload("res://scripts/data/game_rules.gd").new()
	if rules.has("initial_slots"):
		r.initial_slots = int(rules.initial_slots)
	if rules.has("merge_max"):
		r.merge_max = int(rules.merge_max)
	if rules.has("ball_speed"):
		r.ball_speed = float(rules.ball_speed)
	if rules.has("initial_props"):
		for k in rules.initial_props:
			if r.initial_props.has(k):
				r.initial_props[k] = int(rules.initial_props[k])
	if rules.has("auto_fire_interval"):
		r.auto_fire_interval = float(rules.auto_fire_interval)
	return r
