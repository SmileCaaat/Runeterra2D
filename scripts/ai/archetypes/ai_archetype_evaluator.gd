class_name AIArchetypeEvaluator
extends RefCounted


func build_candidates(_ctx: HeroAIContext, _output: Array[HeroAIDecision]) -> void:
	pass


func modify_candidate(_ctx: HeroAIContext, _decision: HeroAIDecision) -> void:
	pass


func short_horizon_weights(_ctx: HeroAIContext) -> Dictionary:
	return {
		&"position_value": 0.25,
		&"output_opportunity": 0.35,
		&"threat": 0.20,
		&"control_opportunity": 0.20,
		&"commitment_risk": 0.30,
		&"resource_cost": 0.25,
	}
