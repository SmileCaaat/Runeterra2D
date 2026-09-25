class_name BattlemageZoneEvaluator
extends AIArchetypeEvaluator


func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
	if ctx.target == null:
		output.append(HeroAIDecision.make(&"hold", 10.0, "no target"))
		return
	var cast_limit := maxf(ctx.cast_range, ctx.engage_distance)
	var preferred := maxf(ctx.preferred_distance, 0.1)
	var too_far := AIUtilityScore.remap01(ctx.target_distance, cast_limit * 0.85, cast_limit + 3.0)
	var too_close := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.disengage_distance, preferred)
	var ideal_center := preferred + (cast_limit - preferred) * 0.35
	var ideal := AIUtilityScore.peak(ctx.target_distance, ideal_center, maxf((cast_limit - preferred) * 0.85, 0.5))
	var approach := HeroAIDecision.make(&"approach", 15.0 + too_far * 75.0, "battlemage distance")
	var retreat_score := 10.0 + too_close * 70.0
	if ctx.target_closing_speed > 0.0:
		retreat_score += AIUtilityScore.saturate(ctx.target_closing_speed / 4.0) * 15.0
	retreat_score += minf(float(ctx.extras.get(&"recent_damage_ratio", 0.0)) * 80.0, 20.0)
	var retreat := HeroAIDecision.make(&"retreat", retreat_score, "battlemage spacing")
	var hold := HeroAIDecision.make(&"hold", 15.0 + ideal * 45.0, "battlemage casting zone")
	for decision: HeroAIDecision in [approach, retreat, hold]:
		decision.target = ctx.target
		output.append(decision)
