class_name HeroKitEvaluator
extends RefCounted


func build_candidates(_ctx: HeroAIContext, _output: Array[HeroAIDecision]) -> void:
	pass


func modify_candidate(_ctx: HeroAIContext, _decision: HeroAIDecision) -> void:
	pass


func describe_action_transition(
	_ctx: HeroAIContext,
	_action_id: StringName,
	_predicted_target_position: Vector3,
	_horizon: float
) -> Dictionary:
	return {}
