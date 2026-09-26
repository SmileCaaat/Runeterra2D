extends SceneTree

class FixedKit:
	extends HeroKitEvaluator
	var scores: Dictionary = {}

	func build_candidates(ctx: HeroAIContext, output: Array[HeroAIDecision]) -> void:
		for action: StringName in scores:
			var decision := HeroAIDecision.make(action, float(scores[action]), "fixed test score")
			decision.target = ctx.target
			output.append(decision)


func _initialize() -> void:
	var target := CharacterBody3D.new()
	root.add_child(target)
	var battlemage := AIArchetypeDefinition.new()
	battlemage.preferred_distance = 3.0
	battlemage.engage_distance = 5.0
	battlemage.disengage_distance = 1.5
	battlemage.aoe_min_targets = 2
	var ryze_ctx := _context(target, battlemage, 12.0)
	ryze_ctx.r_ready = true
	ryze_ctx.t_ready = true
	ryze_ctx.q_ready = true
	ryze_ctx.w_ready = true
	ryze_ctx.e_ready = true
	ryze_ctx.extras[&"warp_range"] = 25.0
	ryze_ctx.extras[&"engage_destination"] = Vector3(7.0, 0.0, 0.0)
	ryze_ctx.extras[&"escape_destination"] = Vector3(-7.0, 0.0, 0.0)
	var ryze_brain := HeroBrain.new()
	ryze_brain.configure(BattlemageZoneEvaluator.new(), RyzeAIKit.new())
	var distant := ryze_brain.think(ryze_ctx)
	var distant_ok := distant.action_id != &"skill_t" and _has(ryze_brain.last_candidates, &"ryze_r_engage")
	var warp_slot_ok := false
	for candidate: HeroAIDecision in ryze_brain.last_candidates:
		if candidate.action_id == &"ryze_r_engage":
			warp_slot_ok = candidate.skill_slot == &"r"
			break
	ryze_ctx.target_distance = 1.2
	ryze_ctx.target_closing_speed = 3.0
	ryze_ctx.now_seconds = 1.0
	ryze_brain.clear_intent()
	ryze_brain.think(ryze_ctx)
	var close_ok := _has(ryze_brain.last_candidates, &"skill_w") and _has(ryze_brain.last_candidates, &"retreat")
	ryze_ctx.target_distance = 4.0
	ryze_ctx.now_seconds = 2.0
	ryze_brain.clear_intent()
	var ideal := ryze_brain.think(ryze_ctx)
	var ideal_ok := _has(ryze_brain.last_candidates, &"skill_q") and _has(ryze_brain.last_candidates, &"skill_w") and _has(ryze_brain.last_candidates, &"skill_e") and ideal.action_id != &"retreat"

	var juggernaut := AIArchetypeDefinition.new()
	juggernaut.engage_distance = 2.4
	var garen_ctx := _context(target, juggernaut, 1.2)
	garen_ctx.attack_range = 1.5
	garen_ctx.r_ready = true
	garen_ctx.e_ready = true
	garen_ctx.extras[&"r_range"] = 2.4
	garen_ctx.extras[&"e_range"] = 3.8
	garen_ctx.extras[&"target_health"] = 100.0
	garen_ctx.extras[&"projected_execute_damage"] = 200.0
	garen_ctx.extras[&"attack_damage"] = 69.0
	garen_ctx.target_health_ratio = 0.2
	garen_ctx.target_is_hero = true
	var garen_brain := HeroBrain.new()
	garen_brain.configure(JuggernautPressureEvaluator.new(), GarenAIKit.new())
	var execute := garen_brain.think(garen_ctx)
	var execute_ok := execute.action_id == &"skill_r"
	garen_ctx.extras[&"breaker_empowered"] = true
	garen_ctx.r_ready = false
	garen_ctx.now_seconds = 1.0
	garen_brain.clear_intent()
	var empowered := garen_brain.think(garen_ctx)
	var empowered_ok := empowered.action_id == &"basic_attack"

	var fixed := FixedKit.new()
	fixed.scores = {&"skill_r": 70.0, &"skill_w": 60.0}
	var intent := HeroBrain.new()
	intent.configure(AIArchetypeEvaluator.new(), fixed)
	var intent_ctx := _context(target, juggernaut, 1.0)
	intent_ctx.r_ready = true
	intent_ctx.w_ready = true
	var first := intent.think(intent_ctx)
	var generic_slot_probe := HeroAIDecision.make(&"unfamiliar_action", 1.0)
	generic_slot_probe.target = target
	generic_slot_probe.skill_slot = &"r"
	intent_ctx.r_ready = false
	var slot_gate_ok := not bool(intent.call("_decision_still_valid", intent_ctx, generic_slot_probe))
	intent_ctx.r_ready = true
	slot_gate_ok = slot_gate_ok and bool(intent.call("_decision_still_valid", intent_ctx, generic_slot_probe)) \
		and HeroAIDecision.make(&"skill_q", 1.0).skill_slot == &"q"
	fixed.scores = {&"skill_r": 68.0, &"skill_w": 72.0}
	intent_ctx.now_seconds = 0.1
	var kept := intent.think(intent_ctx)
	fixed.scores = {&"skill_r": 60.0, &"skill_w": 90.0}
	intent_ctx.now_seconds = 0.2
	var switched := intent.think(intent_ctx)
	var hysteresis_ok := first.action_id == &"skill_r" and kept.action_id == &"skill_r" and kept.generation == first.generation and switched.action_id == &"skill_w" and switched.generation != first.generation
	fixed.scores = {&"skill_r": 100.0, &"skill_w": 60.0}
	intent_ctx.now_seconds = 0.5
	intent_ctx.block_action(&"skill_r", "casting")
	var filtered := intent.think(intent_ctx)
	var filter_ok := filtered.action_id == &"skill_w" and not _has(intent.last_candidates, &"skill_r")
	var e_ctx := _context(target, juggernaut, 1.2)
	e_ctx.attack_range = 1.5
	e_ctx.r_ready = true
	e_ctx.w_ready = true
	e_ctx.self_health_ratio = 0.25
	e_ctx.extras[&"r_range"] = 2.4
	e_ctx.extras[&"target_health"] = 50.0
	e_ctx.extras[&"projected_execute_damage"] = 200.0
	e_ctx.target_is_hero = true
	e_ctx.block_action(&"skill_r", "ocean storm active")
	e_ctx.block_action(&"basic_attack", "ocean storm active")
	e_ctx.block_action(&"approach", "ocean storm active")
	var e_brain := HeroBrain.new()
	e_brain.configure(JuggernautPressureEvaluator.new(), GarenAIKit.new())
	var during_e := e_brain.think(e_ctx)
	var e_w_ok := during_e.action_id == &"skill_w" and not _has(e_brain.last_candidates, &"skill_r")

	var dive_ctx := _context(target, battlemage, 1.2)
	dive_ctx.self_position = Vector3.ZERO
	dive_ctx.target_position = Vector3(1.2, 0.0, 0.0)
	dive_ctx.target_closing_speed = 4.0
	dive_ctx.nearby_enemy_count = 1
	dive_ctx.q_ready = true
	dive_ctx.w_ready = true
	dive_ctx.e_ready = true
	dive_ctx.r_ready = true
	dive_ctx.recent_damage_ratio = 0.12
	dive_ctx.extras[&"r_channel_duration"] = 0.9
	dive_ctx.extras[&"warp_range"] = 25.0
	dive_ctx.extras[&"escape_destination"] = Vector3(-8.0, 0.0, 0.0)
	var dive_brain := HeroBrain.new()
	dive_brain.configure(BattlemageZoneEvaluator.new(), RyzeAIKit.new())
	var dive_decision := dive_brain.think(dive_ctx)
	var dive_w_score := _score(dive_brain.last_candidates, &"skill_w")
	var dive_retreat_score := _score(dive_brain.last_candidates, &"retreat")
	var dive_escape_score := _score(dive_brain.last_candidates, &"ryze_r_escape")
	var anti_dive_ok := dive_decision.action_id == &"skill_w" and dive_w_score > dive_retreat_score and dive_w_score > dive_escape_score

	dive_brain.clear_intent()
	dive_ctx.now_seconds = 1.0
	dive_ctx.target_rooted = true
	dive_ctx.target_closing_speed = 0.0
	dive_ctx.w_ready = false
	var rooted_solo_decision := dive_brain.think(dive_ctx)
	var rooted_solo_escape_score := _score(dive_brain.last_candidates, &"ryze_r_escape")
	var root_reassess_ok := rooted_solo_escape_score > dive_escape_score and rooted_solo_decision.action_id not in [&"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition"]

	dive_ctx.nearby_enemy_count = 4
	dive_ctx.now_seconds = 1.5
	dive_brain.clear_intent()
	var crowded_root_decision := dive_brain.think(dive_ctx)
	var rooted_escape_ok := crowded_root_decision.action_id == &"ryze_r_escape"

	var ryze_kit := RyzeAIKit.new()
	var slight_position_ctx := _context(target, battlemage, 3.0)
	slight_position_ctx.self_position = Vector3(-14.0, 0.0, 0.0)
	slight_position_ctx.target_position = Vector3(-11.0, 0.0, 0.0)
	var slight_reposition: Dictionary = ryze_kit.call("_best_reposition", slight_position_ctx, 25.0)
	var strong_position_ctx := _context(target, battlemage, 1.2)
	strong_position_ctx.self_position = Vector3.ZERO
	strong_position_ctx.target_position = Vector3(1.2, 0.0, 0.0)
	var strong_reposition: Dictionary = ryze_kit.call("_best_reposition", strong_position_ctx, 25.0)
	var reposition_threshold_ok := slight_reposition.is_empty() and not strong_reposition.is_empty() and float(strong_reposition.get("improvement", 0.0)) >= 18.0

	var outcome_brain := HeroBrain.new()
	var outcome_archetype := BattlemageZoneEvaluator.new()
	var outcome_kit := RyzeAIKit.new()
	outcome_brain.configure(outcome_archetype, outcome_kit)
	var closing_ctx := _context(target, battlemage, 9.5)
	closing_ctx.archetype_evaluator = outcome_archetype
	closing_ctx.self_position = Vector3.ZERO
	closing_ctx.target_position = Vector3(9.5, 0.0, 0.0)
	closing_ctx.target_velocity = Vector3(-5.0, 0.0, 0.0)
	closing_ctx.target_health_ratio = 1.0
	closing_ctx.output_range = 5.5
	closing_ctx.control_range = 5.5
	closing_ctx.control_available = true
	closing_ctx.r_ready = true
	closing_ctx.w_ready = true
	closing_ctx.q_ready = true
	closing_ctx.move_speed = 4.0
	closing_ctx.extras[&"warp_range"] = 25.0
	closing_ctx.extras[&"r_channel_duration"] = 0.9
	closing_ctx.extras[&"r_cooldown_duration"] = 180.0
	closing_ctx.nearby_enemy_count = 1
	var closing_outcome := ShortHorizonOutcomeEvaluator.new().evaluate_action(closing_ctx, outcome_kit, &"ryze_r_engage", 0.9)
	var closing_decision := outcome_brain.think(closing_ctx)
	var closing_reject_ok := not bool(closing_outcome.get(&"accepted", true)) and not _has(outcome_brain.last_candidates, &"ryze_r_engage") and closing_decision.action_id != &"ryze_r_engage"
	var debug_values_ok := closing_outcome.has(&"baseline_state_value") and closing_outcome.has(&"warp_state_value") and closing_outcome.has(&"channel_risk") and closing_outcome.has(&"cooldown_cost") and closing_outcome.has(&"net_gain")

	var fleeing_ctx := _context(target, battlemage, 18.0)
	fleeing_ctx.archetype_evaluator = outcome_archetype
	fleeing_ctx.self_position = Vector3.ZERO
	fleeing_ctx.target_position = Vector3(18.0, 0.0, 0.0)
	fleeing_ctx.target_velocity = Vector3(5.0, 0.0, 0.0)
	fleeing_ctx.target_health_ratio = 0.15
	fleeing_ctx.output_range = 5.5
	fleeing_ctx.control_range = 5.5
	fleeing_ctx.control_available = true
	fleeing_ctx.r_ready = true
	fleeing_ctx.q_ready = true
	fleeing_ctx.move_speed = 4.0
	fleeing_ctx.extras[&"warp_range"] = 25.0
	fleeing_ctx.extras[&"r_channel_duration"] = 0.9
	fleeing_ctx.extras[&"r_cooldown_duration"] = 180.0
	fleeing_ctx.nearby_enemy_count = 1
	outcome_brain.clear_intent()
	var fleeing_decision := outcome_brain.think(fleeing_ctx)
	var fleeing_outcome: Dictionary = fleeing_ctx.outcome_evaluations.get(&"ryze_r_engage", {})
	var fleeing_allow_ok := bool(fleeing_outcome.get(&"accepted", false)) and _has(outcome_brain.last_candidates, &"ryze_r_engage") and fleeing_outcome.has(&"net_gain")

	var passed := distant_ok and close_ok and ideal_ok and execute_ok and empowered_ok and hysteresis_ok and filter_ok and e_w_ok and warp_slot_ok and slot_gate_ok
	passed = passed and anti_dive_ok and root_reassess_ok and rooted_escape_ok and reposition_threshold_ok and closing_reject_ok and debug_values_ok and fleeing_allow_ok
	print("HERO_AI_FOUNDATION far=%s close=%s ideal=%s execute=%s empowered=%s hysteresis=%s filter=%s e_w=%s slot=%s/%s fast_chase_w=%s rooted_reassess=%s rooted_escape=%s reposition_threshold=%s closing_r_rejected=%s fleeing_r_allowed=%s metrics=%s" % [distant_ok, close_ok, ideal_ok, execute_ok, empowered_ok, hysteresis_ok, filter_ok, e_w_ok, warp_slot_ok, slot_gate_ok, anti_dive_ok, root_reassess_ok, rooted_escape_ok, reposition_threshold_ok, closing_reject_ok, fleeing_allow_ok, debug_values_ok])
	target.queue_free()
	quit(0 if passed else 1)


func _context(target: CharacterBody3D, archetype: AIArchetypeDefinition, distance: float) -> HeroAIContext:
	var ctx := HeroAIContext.new()
	ctx.target = target
	ctx.archetype = archetype
	ctx.target_distance = distance
	ctx.preferred_distance = archetype.preferred_distance
	ctx.engage_distance = archetype.engage_distance
	ctx.disengage_distance = archetype.disengage_distance
	ctx.cast_range = 5.5
	ctx.attack_range = 5.5
	ctx.output_range = 5.5
	ctx.arena_min = Vector2(-14.5, -3.4)
	ctx.arena_max = Vector2(14.5, 3.4)
	return ctx


func _has(candidates: Array[HeroAIDecision], action: StringName) -> bool:
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == action:
			return true
	return false


func _score(candidates: Array[HeroAIDecision], action: StringName) -> float:
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == action:
			return candidate.score
	return -INF
