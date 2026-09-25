class_name RyzeAIKit
extends HeroKitEvaluator


func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
	if ctx.target == null or not is_instance_valid(ctx.target):
		return
	var in_cast_range := ctx.target_distance <= ctx.cast_range
	var supercharged := bool(ctx.extras.get(&"supercharged", false))
	var desperate := bool(ctx.extras.get(&"desperate_active", false))
	var ready_count := int(ctx.q_ready) + int(ctx.w_ready) + int(ctx.e_ready)
	if in_cast_range and not ctx.silenced:
		if ctx.q_ready:
			var q_score := 42.0
			if supercharged: q_score += 18.0
			if desperate: q_score += 10.0
			if not ctx.w_ready and not ctx.e_ready: q_score += 12.0
			q_score += 10.0 * AIUtilityScore.peak(ctx.target_distance, ctx.preferred_distance + 0.7, 2.0)
			if float(ctx.extras.get(&"supercharged_timer", 0.0)) < 0.8 and int(ctx.extras.get(&"supercharged_casts", 0)) > 0: q_score += 8.0
			if ctx.target_distance < ctx.disengage_distance and ctx.w_ready: q_score -= 25.0
			_add(output, ctx, &"skill_q", q_score, "overload")
		if ctx.w_ready:
			var closeness := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance, ctx.preferred_distance + 1.0)
			var w_score := 38.0 + closeness * 35.0 + AIUtilityScore.saturate(ctx.target_closing_speed / 4.0) * 18.0
			if supercharged: w_score += 10.0
			if desperate: w_score += 8.0
			_add(output, ctx, &"skill_w", w_score, "rune prison")
		if ctx.e_ready:
			var e_score := 45.0 + float(mini(maxi(ctx.nearby_enemy_count - 1, 0), 2)) * 8.0
			if ctx.q_ready: e_score += 12.0
			if ctx.w_ready: e_score += 15.0
			e_score += 12.0 * AIUtilityScore.peak(ctx.target_distance, ctx.preferred_distance + 0.7, 2.0)
			if supercharged: e_score += 10.0
			_add(output, ctx, &"skill_e", e_score, "spell flux")
	if in_cast_range:
		var basic_score := 24.0
		if ready_count == 0: basic_score += 32.0
		if ready_count >= 2: basic_score -= 12.0
		_add(output, ctx, &"basic_attack", basic_score, "filler attack")
	if ctx.t_ready and not desperate and not ctx.silenced:
		var t_score := 12.0 + float(ready_count) * 11.0
		t_score += minf(float(ctx.extras.get(&"arcane_stacks", 0)) / 5.0, 1.0) * 18.0
		if supercharged: t_score += 14.0
		var distance_factor := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.cast_range, ctx.cast_range + 6.0)
		t_score *= lerpf(0.30, 1.0, distance_factor)
		if ctx.target_health_ratio < 0.12: t_score -= 25.0
		if not in_cast_range and ctx.r_ready: t_score -= 18.0
		if in_cast_range and ready_count >= 2: t_score += 18.0
		_add(output, ctx, &"skill_t", t_score, "desperate power")
	if ctx.r_ready and not ctx.silenced:
		_add_warp_candidates(ctx, output, ready_count, supercharged)


func _add_warp_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision], ready_count: int, supercharged: bool) -> void:
	var warp_range := float(ctx.extras.get(&"warp_range", 25.0))
	if ctx.target_distance <= ctx.preferred_distance or ctx.nearby_enemy_count >= int(ctx.archetype.aoe_min_targets) + 1:
		var danger := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance, ctx.preferred_distance)
		var score := 20.0 + danger * 55.0 + float(mini(maxi(ctx.nearby_enemy_count - 1, 0), 2)) * 15.0
		if ctx.w_ready: score -= 12.0
		_add_warp(output, ctx, &"ryze_r_escape", score, ctx.extras.get(&"escape_destination", Vector3.ZERO))
	if ctx.target_distance > ctx.cast_range and ctx.target_distance <= warp_range and (ready_count > 0 or ctx.t_ready or supercharged):
		var excess := AIUtilityScore.remap01(ctx.target_distance, ctx.cast_range, warp_range)
		var engage_score := 30.0 + excess * 35.0 + float(ready_count) * 8.0
		if ctx.t_ready: engage_score += 12.0
		if supercharged: engage_score += 10.0
		if ctx.target_health_ratio < 0.15: engage_score -= 15.0
		_add_warp(output, ctx, &"ryze_r_engage", engage_score, ctx.extras.get(&"engage_destination", Vector3.ZERO))
	if ctx.target_distance <= ctx.cast_range and (ctx.target_distance < ctx.disengage_distance or _near_edge(ctx)):
		var reposition := _best_reposition(ctx, warp_range)
		if not reposition.is_empty():
			_add_warp(output, ctx, &"ryze_r_reposition", float(reposition["score"]), reposition["point"])


func _best_reposition(ctx: HeroAIContext, warp_range: float) -> Dictionary:
	var best := {}
	var best_score := -INF
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var point := ctx.target_position + Vector3(cos(angle), 0.0, sin(angle)) * ctx.preferred_distance
		point.x = clampf(point.x, ctx.arena_min.x, ctx.arena_max.x)
		point.z = clampf(point.z, ctx.arena_min.y, ctx.arena_max.y)
		point.y = ctx.self_position.y
		if point.distance_to(ctx.self_position) > warp_range:
			continue
		var enemy_clearance := INF
		for enemy: CharacterBody3D in ctx.enemies:
			if not is_instance_valid(enemy): continue
			enemy_clearance = minf(enemy_clearance, point.distance_to(enemy.global_position))
		if enemy_clearance < ctx.disengage_distance:
			continue
		var edge_clearance := minf(minf(point.x - ctx.arena_min.x, ctx.arena_max.x - point.x), minf(point.z - ctx.arena_min.y, ctx.arena_max.y - point.z))
		var score := 45.0 + AIUtilityScore.saturate(enemy_clearance / 5.0) * 25.0 + AIUtilityScore.saturate(edge_clearance / 3.0) * 15.0
		if score > best_score:
			best_score = score
			best = {"point": point, "score": score}
	return best


func _near_edge(ctx: HeroAIContext) -> bool:
	return minf(minf(ctx.self_position.x - ctx.arena_min.x, ctx.arena_max.x - ctx.self_position.x), minf(ctx.self_position.z - ctx.arena_min.y, ctx.arena_max.y - ctx.self_position.z)) < 1.5


func _add(output: Array[HeroAIDecision], ctx: HeroAIContext, id: StringName, score: float, reason: String) -> void:
	var decision := HeroAIDecision.make(id, score, reason)
	decision.target = ctx.target
	output.append(decision)


func _add_warp(output: Array[HeroAIDecision], ctx: HeroAIContext, id: StringName, score: float, destination: Vector3) -> void:
	var decision := HeroAIDecision.make(id, score, "realm warp")
	decision.target = ctx.target
	decision.has_destination = true
	decision.destination = destination
	output.append(decision)
