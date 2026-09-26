class_name HeroBrain
extends RefCounted

var archetype_evaluator: AIArchetypeEvaluator
var kit_evaluator: HeroKitEvaluator
var current_decision: HeroAIDecision
var current_intent_started_at := 0.0
var minimum_commit_seconds := 0.22
var switch_margin := 8.0
var emergency_switch_margin := 20.0
var last_candidates: Array[HeroAIDecision] = []
var _generation := 0


func configure(archetype_impl: AIArchetypeEvaluator, kit_impl: HeroKitEvaluator, database: CombatDatabase = null) -> void:
	archetype_evaluator = archetype_impl
	kit_evaluator = kit_impl
	if database != null:
		minimum_commit_seconds = float(database.get_rule(&"ai.intent.min_commit_seconds", 0.22))
		switch_margin = float(database.get_rule(&"ai.intent.switch_margin", 8.0))
		emergency_switch_margin = float(database.get_rule(&"ai.intent.emergency_switch_margin", 20.0))


func think(ctx: HeroAIContext) -> HeroAIDecision:
	var candidates: Array[HeroAIDecision] = []
	if archetype_evaluator != null:
		archetype_evaluator.build_candidates(ctx, candidates)
	if kit_evaluator != null:
		kit_evaluator.build_candidates(ctx, candidates)
	var legal_candidates: Array[HeroAIDecision] = []
	for candidate: HeroAIDecision in candidates:
		if ctx.is_action_blocked(candidate.action_id):
			continue
		if archetype_evaluator != null:
			archetype_evaluator.modify_candidate(ctx, candidate)
		if kit_evaluator != null:
			kit_evaluator.modify_candidate(ctx, candidate)
		legal_candidates.append(candidate)
	legal_candidates.sort_custom(func(a: HeroAIDecision, b: HeroAIDecision) -> bool: return a.score > b.score)
	last_candidates = legal_candidates
	if legal_candidates.is_empty():
		clear_intent()
		return _adopt(HeroAIDecision.make(&"hold", 0.0, "no legal candidate"), ctx)
	return _choose_with_hysteresis(ctx, legal_candidates)


func _choose_with_hysteresis(ctx: HeroAIContext, candidates: Array[HeroAIDecision]) -> HeroAIDecision:
	var best := candidates[0]
	if current_decision == null:
		return _adopt(best, ctx)
	var refreshed_current: HeroAIDecision
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == current_decision.action_id and candidate.target == current_decision.target:
			refreshed_current = candidate
			break
	if refreshed_current == null or not _decision_still_valid(ctx, refreshed_current):
		return _adopt(best, ctx)
	var age := ctx.now_seconds - current_intent_started_at
	var margin := emergency_switch_margin if age < maxf(minimum_commit_seconds, current_decision.commit_seconds) else switch_margin
	if best.action_id == refreshed_current.action_id or best.score < refreshed_current.score + margin:
		refreshed_current.generation = current_decision.generation
		current_decision = refreshed_current
		return current_decision
	return _adopt(best, ctx)


func _decision_still_valid(ctx: HeroAIContext, decision: HeroAIDecision) -> bool:
	if decision.action_id == &"hold":
		return true
	if ctx.target == null or not is_instance_valid(ctx.target):
		return false
	match decision.skill_slot:
		&"q": return ctx.q_ready
		&"w": return ctx.w_ready
		&"e": return ctx.e_ready
		&"r": return ctx.r_ready
		&"t": return ctx.t_ready
	if decision.action_id == &"basic_attack":
		return ctx.target_distance <= ctx.attack_range
	return true


func _adopt(decision: HeroAIDecision, ctx: HeroAIContext) -> HeroAIDecision:
	_generation += 1
	decision.generation = _generation
	current_decision = decision
	current_intent_started_at = ctx.now_seconds
	return decision


func clear_intent() -> void:
	current_decision = null
	current_intent_started_at = 0.0


func debug_top_candidates(limit: int = 3) -> Array[HeroAIDecision]:
	return last_candidates.slice(0, mini(limit, last_candidates.size()))
