class_name RyzeAIKit
extends HeroKitEvaluator


func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
	if ctx.target == null or not is_instance_valid(ctx.target):
		return
	var in_cast_range := ctx.target_distance <= ctx.cast_range
	var supercharged := bool(ctx.extras.get(&"supercharged", false))
	var desperate := bool(ctx.extras.get(&"desperate_active", false))
	var ready_count := int(ctx.q_ready) + int(ctx.w_ready) + int(ctx.e_ready)
	var close_pressure := _close_pressure(ctx)
	var closing_pressure := AIUtilityScore.saturate(ctx.target_closing_speed / 4.0)
	var recent_damage_pressure := _recent_damage_pressure(ctx)
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
			var w_score := 38.0 + close_pressure * 35.0 + closing_pressure * 18.0
			if supercharged: w_score += 10.0
			if desperate: w_score += 8.0
			var anti_dive_bonus := close_pressure * (18.0 + closing_pressure * 18.0 + recent_damage_pressure * 14.0)
			anti_dive_bonus += closing_pressure * 8.0 + recent_damage_pressure * 8.0
			if ctx.target_rooted:
				anti_dive_bonus *= 0.12
			w_score += anti_dive_bonus
			var w_decision := _add(output, ctx, &"skill_w", w_score, "anti-dive rune prison")
			w_decision.metadata[&"anti_dive_bonus"] = anti_dive_bonus
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


func describe_action_transition(ctx: HeroAIContext, action_id: StringName, predicted_target_position: Vector3, horizon: float) -> Dictionary:
	if action_id != &"ryze_r_engage":
		return {}
	var warp_range := float(ctx.extras.get(&"warp_range", 25.0))
	var preferred := maxf(ctx.preferred_distance, 0.1)
	var away := _planar(ctx.self_position - predicted_target_position)
	if away.length_squared() < 0.0001:
		away = Vector3.BACK
	else:
		away = away.normalized()
	var destination := predicted_target_position + away * preferred
	destination.x = clampf(destination.x, ctx.arena_min.x, ctx.arena_max.x)
	destination.z = clampf(destination.z, ctx.arena_min.y, ctx.arena_max.y)
	destination.y = ctx.self_position.y
	var delta := _planar(destination - ctx.self_position)
	if delta.length() > warp_range:
		destination = ctx.self_position + delta.normalized() * warp_range
		destination.x = clampf(destination.x, ctx.arena_min.x, ctx.arena_max.x)
		destination.z = clampf(destination.z, ctx.arena_min.y, ctx.arena_max.y)
		return {}
	var cooldown_seconds := maxf(float(ctx.extras.get(&"r_cooldown_duration", 180.0)), 0.0)
	var cooldown_resource := clampf(cooldown_seconds / 180.0 * 100.0, 0.0, 100.0)
	return {
		&"destination": destination,
		&"actor_position": destination,
		&"resource_cost": cooldown_resource,
		&"commitment_duration": horizon,
	}


func modify_candidate(ctx: HeroAIContext, decision: HeroAIDecision) -> void:
	if decision.action_id == &"retreat" and ctx.target_rooted:
		var root_relief := _close_pressure(ctx) * (24.0 + _recent_damage_pressure(ctx) * 12.0)
		decision.score -= root_relief
		decision.metadata[&"root_relief"] = root_relief


func _add_warp_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision], ready_count: int, supercharged: bool) -> void:
	var warp_range := float(ctx.extras.get(&"warp_range", 25.0))
	var channel_risk_penalty := _channel_risk_penalty(ctx)
	if ctx.target_distance <= ctx.preferred_distance or ctx.nearby_enemy_count >= int(ctx.archetype.aoe_min_targets) + 1:
		var danger := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance, ctx.preferred_distance)
		var score := 20.0 + danger * 55.0 + float(mini(maxi(ctx.nearby_enemy_count - 1, 0), 2)) * 15.0
		_add_warp(output, ctx, &"ryze_r_escape", score, ctx.extras.get(&"escape_destination", Vector3.ZERO), channel_risk_penalty)
	if ctx.target_distance > ctx.cast_range and ctx.target_distance <= warp_range and (ready_count > 0 or ctx.t_ready or supercharged):
		var evaluator := ShortHorizonOutcomeEvaluator.new()
		var horizon := maxf(float(ctx.extras.get(&"r_channel_duration", 0.9)), 0.01)
		var result := evaluator.evaluate_action(ctx, self, &"ryze_r_engage", horizon, 12.0)
		if not result.is_empty() and bool(result.get(&"accepted", false)):
			var decision := _add_warp(output, ctx, &"ryze_r_engage", float(result[&"candidate_score"]), result[&"destination"], 0.0)
			decision.metadata[&"channel_risk_penalty"] = float(result[&"channel_risk"])
			for key: StringName in [&"baseline_state_value", &"warp_state_value", &"channel_risk", &"cooldown_cost", &"net_gain"]:
				decision.metadata[key] = result[key]
		else:
			ctx.outcome_evaluations[&"ryze_r_engage"] = result
	if ctx.target_distance <= ctx.cast_range and (ctx.target_distance < ctx.disengage_distance or _near_edge(ctx)):
		var reposition := _best_reposition(ctx, warp_range)
		if not reposition.is_empty():
			var decision := _add_warp(output, ctx, &"ryze_r_reposition", float(reposition["score"]), reposition["point"], channel_risk_penalty)
			decision.metadata[&"position_improvement"] = float(reposition["improvement"])
			decision.metadata[&"current_position_score"] = float(reposition["current_score"])
			decision.metadata[&"destination_position_score"] = float(reposition["destination_score"])


func _best_reposition(ctx: HeroAIContext, warp_range: float) -> Dictionary:
	var best := {}
	var best_position_score := -INF
	var current_position_score := _position_score(ctx, ctx.self_position)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var point := ctx.target_position + Vector3(cos(angle), 0.0, sin(angle)) * ctx.preferred_distance
		point.x = clampf(point.x, ctx.arena_min.x, ctx.arena_max.x)
		point.z = clampf(point.z, ctx.arena_min.y, ctx.arena_max.y)
		point.y = ctx.self_position.y
		if point.distance_to(ctx.self_position) > warp_range:
			continue
		var position_score := _position_score(ctx, point)
		if position_score > best_position_score:
			best_position_score = position_score
			best = {"point": point}
	var improvement := best_position_score - current_position_score
	if improvement < 18.0:
		return {}
	best["improvement"] = improvement
	best["current_score"] = current_position_score
	best["destination_score"] = best_position_score
	best["score"] = 35.0 + minf(improvement * 0.85, 50.0)
	return best


func _position_score(ctx: HeroAIContext, point: Vector3) -> float:
	var target_distance := point.distance_to(ctx.target_position)
	var range_quality := AIUtilityScore.peak(target_distance, ctx.preferred_distance, maxf(ctx.preferred_distance, 1.0))
	var nearest_threat_distance := target_distance
	for enemy: CharacterBody3D in ctx.enemies:
		if is_instance_valid(enemy):
			nearest_threat_distance = minf(nearest_threat_distance, point.distance_to(enemy.global_position))
	var separation_quality := AIUtilityScore.saturate(nearest_threat_distance / maxf(ctx.disengage_distance * 2.0, 3.0))
	var edge_clearance := minf(minf(point.x - ctx.arena_min.x, ctx.arena_max.x - point.x), minf(point.z - ctx.arena_min.y, ctx.arena_max.y - point.z))
	var edge_quality := AIUtilityScore.saturate(edge_clearance / 3.0)
	return range_quality * 50.0 + separation_quality * 30.0 + edge_quality * 20.0


func _planar(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _close_pressure(ctx: HeroAIContext) -> float:
	return 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance, ctx.preferred_distance + 1.0)


func _recent_damage_pressure(ctx: HeroAIContext) -> float:
	return AIUtilityScore.saturate(float(ctx.extras.get(&"recent_damage_ratio", 0.0)) / 0.2)


func _channel_risk_penalty(ctx: HeroAIContext) -> float:
	var channel_duration := maxf(float(ctx.extras.get(&"r_channel_duration", 0.9)), 0.0)
	var close_pressure := _close_pressure(ctx)
	var closing_pressure := AIUtilityScore.saturate(ctx.target_closing_speed / 4.0)
	var damage_pressure := _recent_damage_pressure(ctx)
	var other_enemy_count := maxi(ctx.nearby_enemy_count - 1 - int(ctx.target_rooted), 0)
	var crowd_pressure := AIUtilityScore.saturate(float(other_enemy_count) / 2.0)
	var cheaper_defense_pressure := close_pressure * 0.20
	if ctx.target_rooted:
		close_pressure *= 0.25
		closing_pressure *= 0.2
		cheaper_defense_pressure = close_pressure * 0.55
	elif ctx.w_ready:
		cheaper_defense_pressure = close_pressure * (0.55 + closing_pressure * 0.45)
	else:
		cheaper_defense_pressure = close_pressure * (0.20 + closing_pressure * 0.20)
	var penalty_per_second := 18.0 + close_pressure * 10.0 + closing_pressure * 8.0 + damage_pressure * 6.0 + crowd_pressure * 8.0 + cheaper_defense_pressure * 18.0
	return channel_duration * penalty_per_second


func _near_edge(ctx: HeroAIContext) -> bool:
	return minf(minf(ctx.self_position.x - ctx.arena_min.x, ctx.arena_max.x - ctx.self_position.x), minf(ctx.self_position.z - ctx.arena_min.y, ctx.arena_max.y - ctx.self_position.z)) < 1.5


func _add(output: Array[HeroAIDecision], ctx: HeroAIContext, id: StringName, score: float, reason: String) -> HeroAIDecision:
	var decision := HeroAIDecision.make(id, score, reason)
	decision.target = ctx.target
	output.append(decision)
	return decision


func _add_warp(output: Array[HeroAIDecision], ctx: HeroAIContext, id: StringName, score: float, destination: Vector3, channel_risk_penalty: float) -> HeroAIDecision:
	var decision := HeroAIDecision.make(id, score, "realm warp")
	decision.score -= channel_risk_penalty
	decision.target = ctx.target
	decision.has_destination = true
	decision.destination = destination
	decision.metadata[&"channel_risk_penalty"] = channel_risk_penalty
	output.append(decision)
	return decision
