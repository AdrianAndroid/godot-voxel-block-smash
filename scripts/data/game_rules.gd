extends RefCounted

# 已批准规则参数（架构 v6：仅批准参数、带 GDD 版本；数值来源 GDD"执行默认值决策"）
# 阶段：阶段3。关卡 rules 可覆盖默认值；空 rules 仅用于阶段2导入验证

const GDD_VERSION := "v6"

var initial_slots := 5  # 2026-10-27 用户要求：去掉锁，5 槽全解锁（add_slot 道具随之从默认库存移除）
var max_slots := 5
var merge_max := 160  # CQ-20261026 §2.4：合成上限 160（替代旧 99）
var ball_speed := 100.0  # FM/F2：格/秒（局部空间）；多球在途后单发飞行时长仍是射速瓶颈之一
var ball_radius := 0.35
var boundary_margin := 8.0
var initial_props := {"speed_x2": 3, "designated_target": 2, "shuffle": 2}  # 去掉锁后 add_slot 无意义，移出默认库存
var turret_ammo_min := 30  # CQ-20261026/S03：普通炮 30~80 发，末炮余数 1~29
var turret_ammo_max := 80
var palette_color_ids: Array = [1, 2, 3, 4, 5, 6, 7]  # D05 七色离散 id
var palette_weights: Dictionary = {}  # 【新增代码】color_id -> 模型块数（D05 加权随机；空=均匀兜底）
var rotate_sensitivity := 0.01
var particle_max_total := 512
var particle_per_hit := 16
var particle_lifetime := 0.8
var auto_fire_interval := 0.10  # FM/F2：多球连发间隔秒数（冷却不等上一发落地）
var max_in_flight_per_turret := 6  # FM/F2：单炮同时在途弹上限（替代 in_flight>=1 闸门）
var max_active_projectiles := 30   # FM/F2：全局在途弹上限（事件洪流/性能护栏）
var auto_rot_deg_per_sec := 8.0    # FM §11：青蛙绕模型中心 +Y 轴俯视逆时针自动旋转角速度


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
	if rules.has("max_in_flight_per_turret"):
		r.max_in_flight_per_turret = int(rules.max_in_flight_per_turret)
	if rules.has("max_active_projectiles"):
		r.max_active_projectiles = int(rules.max_active_projectiles)
	if rules.has("auto_rot_deg_per_sec"):
		r.auto_rot_deg_per_sec = float(rules.auto_rot_deg_per_sec)
	return r
