class_name GarenAIKit
extends HeroKitEvaluator


func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
	if ctx.target == null or not is_instance_valid(ctx.target):
		return
	var empowered := bool(ctx.extras.get(&"breaker_empowered", false))
	var distance := ctx.target_distance
	var attack_range := ctx.attack_range
	var nearby := ctx.nearby_enemy_count
	var r_kills := false
	if ctx.r_ready and distance <= float(ctx.extras.get(&"r_range", attack_range)):
		var projected := float(ctx.extras.get(&"projected_execute_damage", 0.0))
		var hp := float(ctx.extras.get(&"target_health", INF))
		r_kills = projected >= hp
		var r_score := 35.0
		if r_kills: r_score += 65.0
		if ctx.target_health_ratio <= float(ctx.archetype.execute_health_ratio): r_score += 35.0
		if not ctx.target_is_hero: r_score -= 18.0
		if hp <= float(ctx.extras.get(&"attack_damage", 69.0)) * 1.2: r_score -= 25.0
		_add(output, ctx, &"skill_r", r_score, "judgment execute")
	if ctx.w_ready:
		var defensive_need := 1.0 - AIUtilityScore.remap01(ctx.self_health_ratio, 0.20, float(ctx.archetype.defend_health_ratio) + 0.20)
		var w_score := 12.0 + defensive_need * 48.0 + float(mini(nearby, 2)) * 10.0
		if distance <= ctx.engage_distance: w_score += 12.0
		if ctx.self_health_ratio > 0.90 and nearby <= 1: w_score -= 12.0
		w_score += minf(ctx.recent_damage_ratio * 90.0, 25.0)
		_add(output, ctx, &"skill_w", w_score, "black sail defense")
	if ctx.e_ready and distance <= float(ctx.extras.get(&"e_range", attack_range)):
		var connected := 1.0 - AIUtilityScore.remap01(distance, attack_range * 0.85, ctx.engage_distance)
		var e_score := 42.0 + connected * 20.0 + float(mini(maxi(nearby - 1, 0), 2)) * 12.0
		if ctx.target_health_ratio <= float(ctx.archetype.pressure_health_ratio): e_score += 15.0
		if empowered: e_score -= 25.0
		_add(output, ctx, &"skill_e", e_score, "ocean storm pressure")
	if ctx.q_ready and not empowered and distance <= maxf(ctx.engage_distance, float(ctx.extras.get(&"breaker_lunge_range", 0.0))):
		var gap := AIUtilityScore.remap01(distance, attack_range, ctx.engage_distance)
		var q_score := 35.0 + gap * 35.0
		if float(ctx.extras.get(&"move_speed_multiplier", 1.0)) < 0.95: q_score += 18.0
		if distance <= attack_range: q_score += 7.0
		_add(output, ctx, &"skill_q", q_score, "breaker gap closer")
	if ctx.t_ready and distance <= float(ctx.extras.get(&"t_range", attack_range)):
		var t_score := 16.0
		if nearby >= int(ctx.archetype.aoe_min_targets): t_score += 45.0
		t_score += float(mini(maxi(nearby - int(ctx.archetype.aoe_min_targets), 0), 2)) * 10.0
		if ctx.target_health_ratio <= float(ctx.archetype.awakening_health_ratio): t_score += 15.0
		if r_kills: t_score -= 35.0
		_add(output, ctx, &"skill_t", t_score, "seven seas aoe")
	if distance <= attack_range or (empowered and distance <= float(ctx.extras.get(&"breaker_lunge_range", attack_range))):
		var basic_score := 42.0
		if empowered: basic_score += 50.0
		if ctx.target_health_ratio < 0.25: basic_score += 10.0
		_add(output, ctx, &"basic_attack", basic_score, "melee attack")


func _add(output: Array[HeroAIDecision], ctx: HeroAIContext, id: StringName, score: float, reason: String) -> void:
	var decision := HeroAIDecision.make(id, score, reason)
	decision.target = ctx.target
	output.append(decision)
