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
	var passed := distant_ok and close_ok and ideal_ok and execute_ok and empowered_ok and hysteresis_ok and filter_ok and e_w_ok
	print("HERO_AI_FOUNDATION far=%s close=%s ideal=%s execute=%s empowered=%s hysteresis=%s filter=%s e_w=%s" % [distant_ok, close_ok, ideal_ok, execute_ok, empowered_ok, hysteresis_ok, filter_ok, e_w_ok])
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
	ctx.arena_min = Vector2(-14.5, -3.4)
	ctx.arena_max = Vector2(14.5, 3.4)
	return ctx


func _has(candidates: Array[HeroAIDecision], action: StringName) -> bool:
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == action:
			return true
	return false
