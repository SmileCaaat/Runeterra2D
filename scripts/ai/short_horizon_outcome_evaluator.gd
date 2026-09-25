class_name ShortHorizonOutcomeEvaluator
extends RefCounted

const DEFAULT_MIN_NET_GAIN := 12.0


func evaluate_action(
	ctx: HeroAIContext,
	kit: HeroKitEvaluator,
	action_id: StringName,
	horizon: float,
	min_net_gain: float = DEFAULT_MIN_NET_GAIN
) -> Dictionary:
	if ctx == null or kit == null or ctx.target == null or not is_instance_valid(ctx.target):
		return {}
	horizon = maxf(horizon, 0.01)
	var target_future := _clamp_to_arena(ctx, ctx.target_position + _planar(ctx.target_velocity) * horizon)
	var baseline_positions := _baseline_positions(ctx, target_future, horizon)
	var baseline_value := -INF
	var baseline_mode := &"hold"
	for mode: StringName in baseline_positions:
		var features := _state_features(ctx, baseline_positions[mode], target_future, horizon)
		var value := _weighted_state_value(ctx, features)
		if value > baseline_value:
			baseline_value = value
			baseline_mode = mode
	var transition := kit.describe_action_transition(ctx, action_id, target_future, horizon)
	if transition.is_empty():
		return {}
	var warp_position: Vector3 = transition.get(&"actor_position", transition.get(&"destination", ctx.self_position))
	warp_position = _clamp_to_arena(ctx, warp_position)
	var warp_features := _state_features(ctx, warp_position, target_future, horizon)
	var resource_feature := clampf(float(transition.get(&"resource_cost", 0.0)), 0.0, 100.0)
	warp_features[&"resource_cost"] = resource_feature
	var warp_value := _weighted_state_value(ctx, warp_features)
	var weights := _weights(ctx)
	var commitment_feature := _commitment_feature(ctx, horizon)
	var channel_risk := commitment_feature * float(weights.get(&"commitment_risk", 0.30))
	var cooldown_cost := resource_feature * float(weights.get(&"resource_cost", 0.25))
	var net_gain := warp_value - baseline_value - channel_risk - cooldown_cost
	var movement_score := _baseline_movement_score(ctx, baseline_mode)
	var result := {
		&"action_id": action_id,
		&"baseline_state_value": baseline_value,
		&"warp_state_value": warp_value,
		&"channel_risk": channel_risk,
		&"cooldown_cost": cooldown_cost,
		&"net_gain": net_gain,
		&"min_net_gain": min_net_gain,
		&"baseline_mode": baseline_mode,
		&"target_future_position": target_future,
		&"destination": warp_position,
		&"features": warp_features,
		&"baseline_features": _state_features(ctx, baseline_positions[baseline_mode], target_future, horizon),
		&"resource_feature": resource_feature,
		&"commitment_feature": commitment_feature,
		&"candidate_score": movement_score + net_gain,
		&"accepted": net_gain >= min_net_gain,
	}
	ctx.outcome_evaluations[action_id] = result
	return result


func _baseline_positions(ctx: HeroAIContext, predicted_target: Vector3, horizon: float) -> Dictionary:
	var speed := maxf(float(ctx.extras.get(&"move_speed", 0.0)), 0.0)
	var preferred := maxf(ctx.preferred_distance, 0.1)
	var away := _planar(ctx.self_position - predicted_target)
	if away.length_squared() < 0.0001:
		away = Vector3.BACK
	else:
		away = away.normalized()
	var toward := -away
	var predicted_distance := ctx.self_position.distance_to(predicted_target)
	var approach_distance := minf(maxf(predicted_distance - preferred, 0.0), speed * horizon)
	var retreat_distance := minf(maxf(preferred - predicted_distance, 0.0) + speed * horizon, speed * horizon)
	var hold_target := predicted_target + away * clampf(predicted_distance, preferred * 0.75, preferred * 1.25)
	return {
		&"approach": _clamp_to_arena(ctx, ctx.self_position + toward * approach_distance),
		&"hold": _clamp_to_arena(ctx, ctx.self_position.move_toward(hold_target, speed * horizon)),
		&"retreat": _clamp_to_arena(ctx, ctx.self_position + away * retreat_distance),
	}


func _state_features(ctx: HeroAIContext, actor_position: Vector3, target_position: Vector3, horizon: float) -> Dictionary:
	var distance := actor_position.distance_to(target_position)
	var preferred := maxf(ctx.preferred_distance, 0.1)
	var position_value := AIUtilityScore.peak(distance, preferred, maxf(preferred, 1.0)) * 80.0
	var edge_clearance := minf(minf(actor_position.x - ctx.arena_min.x, ctx.arena_max.x - actor_position.x), minf(actor_position.z - ctx.arena_min.y, ctx.arena_max.y - actor_position.z))
	position_value += AIUtilityScore.saturate(edge_clearance / 3.0) * 20.0
	var output_range := maxf(ctx.output_range, ctx.cast_range)
	var output_opportunity := 100.0 * (1.0 - AIUtilityScore.remap01(distance, output_range * 0.72, output_range + 2.0))
	output_opportunity *= lerpf(0.75, 1.0, 1.0 - AIUtilityScore.saturate(ctx.target_health_ratio))
	var threat := _threat_at(ctx, actor_position, target_position, horizon)
	var control_opportunity := 0.0
	if ctx.control_available and not ctx.target_rooted and distance <= maxf(ctx.control_range, 0.0):
		control_opportunity = 100.0 * (1.0 - AIUtilityScore.remap01(distance, ctx.control_range * 0.75, ctx.control_range))
	return {
		&"position_value": position_value,
		&"output_opportunity": output_opportunity,
		&"threat": threat,
		&"control_opportunity": control_opportunity,
		&"commitment_risk": _commitment_feature(ctx, horizon),
		&"resource_cost": 0.0,
	}


func _threat_at(ctx: HeroAIContext, actor_position: Vector3, predicted_target: Vector3, horizon: float) -> float:
	var target_distance := actor_position.distance_to(predicted_target)
	var total := 100.0 * (1.0 - AIUtilityScore.remap01(target_distance, ctx.disengage_distance + 1.0, maxf(ctx.cast_range, ctx.disengage_distance + 2.0)))
	for enemy: CharacterBody3D in ctx.enemies:
		if not is_instance_valid(enemy):
			continue
		var future_enemy := _clamp_to_arena(ctx, enemy.global_position + _planar(enemy.velocity) * horizon)
		var enemy_distance := actor_position.distance_to(future_enemy)
		total += 100.0 * (1.0 - AIUtilityScore.remap01(enemy_distance, ctx.disengage_distance + 1.0, maxf(ctx.cast_range, ctx.disengage_distance + 2.0)))
	return clampf(total / float(maxi(ctx.nearby_enemy_count, 1)), 0.0, 100.0)


func _commitment_feature(ctx: HeroAIContext, horizon: float) -> float:
	var pressure := 100.0 * (1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance + 1.0, maxf(ctx.cast_range, ctx.disengage_distance + 2.0)))
	var other_enemy_pressure := minf(float(maxi(ctx.nearby_enemy_count - 1, 0)) * 28.0, 60.0)
	var recent_damage := clampf(float(ctx.extras.get(&"recent_damage_ratio", 0.0)) / 0.20, 0.0, 1.0) * 30.0
	var chase_pressure := AIUtilityScore.saturate(ctx.target_closing_speed / 4.0) * 22.0
	var cheaper_defense_pressure := 18.0 if ctx.control_available and not ctx.target_rooted else 0.0
	var root_relief := 0.65 if ctx.target_rooted else 1.0
	return clampf((pressure + other_enemy_pressure + recent_damage + chase_pressure + cheaper_defense_pressure) * minf(horizon / 0.9, 1.5) * root_relief, 0.0, 100.0)


func _weighted_state_value(ctx: HeroAIContext, features: Dictionary) -> float:
	var weights := _weights(ctx)
	var total_weight := 0.0
	var value := 0.0
	for feature: StringName in [&"position_value", &"output_opportunity", &"threat", &"control_opportunity"]:
		var weight := float(weights.get(feature, 0.0))
		total_weight += weight
		var sign := -1.0 if feature == &"threat" else 1.0
		value += float(features.get(feature, 0.0)) * weight * sign
	return value / maxf(total_weight, 0.001) * 100.0


func _weights(ctx: HeroAIContext) -> Dictionary:
	if ctx.archetype_evaluator != null:
		return ctx.archetype_evaluator.short_horizon_weights(ctx)
	return AIArchetypeEvaluator.new().short_horizon_weights(ctx)


func _baseline_movement_score(ctx: HeroAIContext, mode: StringName) -> float:
	if ctx.archetype_evaluator == null:
		return 0.0
	var candidates: Array[HeroAIDecision] = []
	ctx.archetype_evaluator.build_candidates(ctx, candidates)
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == mode:
			return candidate.score
	return 0.0


func _planar(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _clamp_to_arena(ctx: HeroAIContext, position: Vector3) -> Vector3:
	position.x = clampf(position.x, ctx.arena_min.x, ctx.arena_max.x)
	position.z = clampf(position.z, ctx.arena_min.y, ctx.arena_max.y)
	position.y = ctx.self_position.y
	return position
