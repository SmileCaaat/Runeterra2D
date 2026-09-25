class_name JuggernautPressureEvaluator
extends AIArchetypeEvaluator


func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
	if ctx.target == null:
		output.append(HeroAIDecision.make(&"hold", 10.0, "no target"))
		return
	var outside_melee := AIUtilityScore.remap01(ctx.target_distance, ctx.attack_range * 0.9, maxf(ctx.engage_distance, ctx.attack_range + 0.1))
	var connected := 1.0 - AIUtilityScore.remap01(ctx.target_distance, ctx.attack_range * 0.85, ctx.engage_distance)
	var approach := HeroAIDecision.make(&"approach", 25.0 + outside_melee * 65.0, "juggernaut pressure")
	var hold := HeroAIDecision.make(&"hold", 15.0 + connected * 25.0, "maintain melee")
	approach.target = ctx.target
	hold.target = ctx.target
	output.append(approach)
	output.append(hold)
