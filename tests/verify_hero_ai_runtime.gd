extends SceneTree


func _initialize() -> void:
	var stage := load("res://DNF_Style_Prototype.tscn").instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage
	await process_frame
	await process_frame
	var characters := stage.get_node("Characters") as Node3D
	var roster := stage.get_node("BattleHUD/HUDRoot/DebugDrawer/TrainingToolsPanel/VBox/Body/TrainingRosterPanel") as TrainingRosterPanel
	roster.set_training_units({&"friendly_dummy": false, &"enemy_dummy": false, &"scuttle": false})
	roster.set_roster(&"friendly", [&"garen", &"ryze"])
	roster.set_roster(&"enemy", [&"garen", &"ryze"])
	await process_frame
	var blue_garen := characters.get_node("Player") as CharacterBody3D
	var red_garen := characters.get_node("RosterGarenRed") as CharacterBody3D
	var blue_ryze := characters.get_node("RosterRyzeBlue") as CharacterBody3D
	var red_ryze := characters.get_node("RosterRyzeRed") as CharacterBody3D
	var blue_skills := blue_garen.get_node("SkillController")
	var red_skills := red_garen.get_node("SkillController")
	var roster_ok := not bool(blue_skills.get("automatic_demo")) and not bool(red_skills.get("automatic_demo"))
	roster.set_roster(&"enemy", [&"ryze"])
	await process_frame
	roster.set_roster(&"enemy", [&"garen", &"ryze"])
	await process_frame
	red_garen = characters.get_node("RosterGarenRed") as CharacterBody3D
	red_skills = red_garen.get_node("SkillController")
	roster_ok = roster_ok and not bool(red_skills.get("automatic_demo"))
	roster.set_roster(&"friendly", [&"ryze"])
	roster.set_roster(&"friendly", [&"garen", &"ryze"])
	roster_ok = roster_ok and not bool(blue_skills.get("automatic_demo"))

	blue_ryze.global_position = Vector3(0.0, 0.0, 0.0)
	red_garen.global_position = Vector3(3.0, 0.0, 0.0)
	blue_ryze.set("target", red_garen)
	blue_ryze.set("action_lock", 0.0)
	var cooldowns: Dictionary = blue_ryze.get("cooldowns")
	for cooldown_key: StringName in cooldowns:
		cooldowns[cooldown_key] = 0.0
	blue_ryze.set("ai_recent_damage_accumulator", 0.0)
	var scene_brain: HeroBrain = blue_ryze.get("ai_brain")
	blue_ryze.global_position = Vector3.ZERO
	red_garen.global_position = Vector3(9.5, 0.0, 0.0)
	red_garen.velocity = Vector3(-5.0, 0.0, 0.0)
	scene_brain.clear_intent()
	var closing_scene_ctx: HeroAIContext = blue_ryze.call("_build_ai_context")
	var closing_scene_decision := scene_brain.think(closing_scene_ctx)
	var closing_scene_outcome: Dictionary = closing_scene_ctx.outcome_evaluations.get(&"ryze_r_engage", {})
	var scene_closing_ok := not closing_scene_outcome.is_empty() and not bool(closing_scene_outcome.get(&"accepted", true)) and closing_scene_decision.action_id != &"ryze_r_engage"
	red_garen.global_position = Vector3(18.0, 0.0, 0.0)
	red_garen.velocity = Vector3(5.0, 0.0, 0.0)
	scene_brain.clear_intent()
	var fleeing_scene_ctx: HeroAIContext = blue_ryze.call("_build_ai_context")
	scene_brain.think(fleeing_scene_ctx)
	var fleeing_scene_outcome: Dictionary = fleeing_scene_ctx.outcome_evaluations.get(&"ryze_r_engage", {})
	var scene_fleeing_ok := not fleeing_scene_outcome.is_empty() and bool(fleeing_scene_outcome.get(&"accepted", false)) and _has_decision(scene_brain.last_candidates, &"ryze_r_engage")
	blue_ryze.global_position = Vector3.ZERO
	red_garen.global_position = Vector3(3.0, 0.0, 0.0)
	red_garen.velocity = Vector3.ZERO
	scene_brain.clear_intent()
	cooldowns[&"q"] = 0.0
	var q := HeroAIDecision.make(&"skill_q", 60.0, "runtime test")
	q.target = red_garen
	q.generation = 9001
	var first_q := bool(blue_ryze.call("_try_consume_ai_one_shot", q))
	var q_cooldown := float(cooldowns[&"q"])
	var second_q := bool(blue_ryze.call("_try_consume_ai_one_shot", q))
	var one_shot_ok := first_q and q_cooldown > 0.0 and not second_q
	blue_ryze.set("ai_decision", q)
	blue_ryze.get("ai_brain").current_decision = q
	blue_ryze.call("force_retarget_hostile")
	var retarget_ok := blue_ryze.get("ai_decision") == null and blue_ryze.get("ai_brain").current_decision == null
	blue_ryze.set("target", red_garen)

	blue_ryze.set("action_lock", 0.0)
	cooldowns[&"q"] = 5.0
	var stale_q := HeroAIDecision.make(&"skill_q", 70.0, "stale test")
	stale_q.target = red_garen
	stale_q.generation = 9002
	blue_ryze.set("ai_decision", stale_q)
	var rejected := not bool(blue_ryze.call("_try_consume_ai_one_shot", stale_q))
	var invalidate_ok := rejected and blue_ryze.get("ai_decision") == null and blue_ryze.get("ai_brain").current_decision == null and is_zero_approx(float(blue_ryze.get("ai_decision_timer")))
	blue_ryze.set("velocity", Vector3.ZERO)
	blue_ryze.call("apply_root", 1.0)
	var retreat := HeroAIDecision.make(&"retreat", 80.0, "root test")
	retreat.target = red_garen
	blue_ryze.call("_execute_ai_decision", retreat)
	var root_ok := (blue_ryze.get("velocity") as Vector3).length_squared() < 0.0001
	var stale_warp := HeroAIDecision.make(&"ryze_r_engage", 80.0, "warp test")
	stale_warp.target = red_garen
	stale_warp.has_destination = true
	stale_warp.destination = Vector3(100.0, 0.0, 0.0)
	var warp_ok := not bool(blue_ryze.call("_is_valid_ai_warp_destination", stale_warp))
	stale_warp.destination = Vector3(14.6, 0.0, 0.0)
	warp_ok = warp_ok and not bool(blue_ryze.call("_is_valid_ai_warp_destination", stale_warp))

	var probe := load("res://scenes/units/ryze.tscn").instantiate() as CharacterBody3D
	probe.name = "AIRecentDamageProbe"
	characters.add_child(probe)
	probe.remove_from_group(&"combat_target")
	probe.set("enabled", false)
	probe.call("record_ai_damage_taken", 100.0)
	probe.call("_physics_process", 0.8)
	probe.call("record_ai_damage_taken", 50.0)
	probe.call("_physics_process", 0.7)
	var hold_ok := is_equal_approx(float(probe.get("ai_recent_damage_accumulator")), 150.0)
	probe.call("_physics_process", 0.31)
	hold_ok = hold_ok and is_zero_approx(float(probe.get("ai_recent_damage_accumulator")))
	blue_skills.set("normal_shield", 0.0)
	blue_skills.set("black_sail_timer", 0.0)
	blue_skills.set("rum_timer", 0.0)
	var hp_before := float(blue_skills.get("current_health"))
	blue_skills.call("receive_incoming_damage", 40.0, &"true")
	var immediate_loss := hp_before - float(blue_skills.get("current_health"))
	var recorded_before_shield := float(blue_garen.get("ai_recent_damage_accumulator"))
	var damage_ok := is_equal_approx(immediate_loss, recorded_before_shield)
	blue_skills.set("normal_shield", 50.0)
	blue_skills.call("receive_incoming_damage", 30.0, &"true")
	damage_ok = damage_ok and is_equal_approx(float(blue_garen.get("ai_recent_damage_accumulator")), recorded_before_shield)
	blue_skills.set("normal_shield", 0.0)
	blue_skills.set("black_sail_timer", 1.0)
	var before_reduced := float(blue_garen.get("ai_recent_damage_accumulator"))
	hp_before = float(blue_skills.get("current_health"))
	blue_skills.call("receive_incoming_damage", 40.0, &"physical")
	var reduced_loss := hp_before - float(blue_skills.get("current_health"))
	damage_ok = damage_ok and reduced_loss < 40.0 and is_equal_approx(float(blue_garen.get("ai_recent_damage_accumulator")) - before_reduced, reduced_loss)
	blue_skills.set("black_sail_timer", 0.0)
	blue_skills.set("rum_timer", 0.01)
	blue_skills.set("delayed_damage_pool", 0.0)
	hp_before = float(blue_skills.get("current_health"))
	blue_skills.call("receive_incoming_damage", 40.0, &"true")
	var rum_immediate := hp_before - float(blue_skills.get("current_health"))
	damage_ok = damage_ok and is_equal_approx(rum_immediate, 20.0)
	var recorded_before_settlement := float(blue_garen.get("ai_recent_damage_accumulator"))
	hp_before = float(blue_skills.get("current_health"))
	blue_skills.call("_update_timers", 0.02)
	var rum_settlement := hp_before - float(blue_skills.get("current_health"))
	damage_ok = damage_ok and is_equal_approx(float(blue_garen.get("ai_recent_damage_accumulator")) - recorded_before_settlement, rum_settlement)
	blue_skills.set("current_health", 20.0)
	blue_skills.set("rum_timer", 0.01)
	blue_skills.set("delayed_damage_pool", 100.0)
	blue_skills.set("rum_settlement_pending", true)
	recorded_before_settlement = float(blue_garen.get("ai_recent_damage_accumulator"))
	blue_skills.call("_update_timers", 0.02)
	damage_ok = damage_ok and is_equal_approx(float(blue_skills.get("current_health")), 1.0)
	damage_ok = damage_ok and is_equal_approx(float(blue_garen.get("ai_recent_damage_accumulator")) - recorded_before_settlement, 19.0)
	blue_skills.set("current_health", blue_skills.get("max_health"))

	blue_garen.set("target", red_ryze)
	blue_skills.set("is_casting", false)
	var skill_cooldowns: Array = blue_skills.get("cooldowns") as Array
	skill_cooldowns[2] = 0.0
	skill_cooldowns[3] = 0.0
	var e_started := bool(blue_skills.call("begin_skill", 3, red_ryze))
	var w := HeroAIDecision.make(&"skill_w", 80.0, "E W test")
	w.target = red_ryze
	w.generation = 9003
	blue_garen.set("ai_decision", w)
	var w_started := bool(blue_garen.call("_try_consume_ai_one_shot", w))
	var e_w_ok := e_started and w_started and bool(blue_skills.get("is_casting")) and int(blue_skills.get("current_skill")) == 3
	blue_ryze.set("ai_debug", true)
	blue_ryze.set("ai_decision_timer", 0.0)
	blue_ryze.call("_update_ai_decision", 0.2)
	var debug_ok := String(blue_ryze.get_node("AIStateLabel").text).contains("AI ")
	blue_garen.set("ai_debug", true)
	blue_garen.set("ai_decision_timer", 0.0)
	blue_garen.call("_update_ai_decision", 0.2)
	debug_ok = debug_ok and String(blue_garen.get_node("AIStateLabel").text).contains("AI ")

	for group_name: StringName in [&"combat_target", &"friendly_actor", &"enemy_actor", &"player_actor", &"hero_actor"]:
		probe.remove_from_group(group_name)
	probe.global_position = Vector3.ZERO
	var probe_cooldowns: Dictionary = probe.get("cooldowns")
	probe_cooldowns[&"r"] = 0.0
	var r_channel_duration := float(probe.call("_rulef", &"ryze.r.channel_duration", 0.0))
	var model := probe.get_node("RyzeModel")
	var original_animation_speed := float(model.get("animation_speed_scale"))
	var spell4_original_duration := float(model.call("get_semantic_animation_length", &"spell4"))
	var warp_destination := Vector3(2.0, 0.0, 0.0)
	probe.call("cast_realm_warp", warp_destination)
	await create_timer(0.70).timeout
	var warp_still_winding_up := probe.global_position.distance_to(warp_destination) > 0.5
	var animation_speed_during_windup := float(model.get("animation_speed_scale"))
	var actual_channel_duration := 0.70
	while probe.global_position.distance_to(warp_destination) > 0.05 and actual_channel_duration < 1.3:
		await physics_frame
		actual_channel_duration += Engine.time_scale / float(Engine.physics_ticks_per_second)
	var r_timing_ok := is_equal_approx(r_channel_duration, 0.9) and warp_still_winding_up
	r_timing_ok = r_timing_ok and absf(actual_channel_duration - r_channel_duration) <= 0.12
	var expected_windup_speed := original_animation_speed * spell4_original_duration / r_channel_duration
	r_timing_ok = r_timing_ok and absf(animation_speed_during_windup - expected_windup_speed) <= 0.02
	r_timing_ok = r_timing_ok and is_equal_approx(float(model.get("animation_speed_scale")), original_animation_speed)
	r_timing_ok = r_timing_ok and is_zero_approx(float(probe.get("super_armor_timer")))

	probe.call("receive_skill_damage", 99999.0, "AI death test", false, Vector3.ZERO, &"true")
	var lifecycle_ok := bool(probe.get("is_dead")) and probe.get("ai_decision") == null and probe.get("ai_brain").current_decision == null
	probe.call("revive_for_training")
	lifecycle_ok = lifecycle_ok and not bool(probe.get("is_dead")) and probe.get("ai_brain").current_decision == null

	var passed := roster_ok and one_shot_ok and retarget_ok and invalidate_ok and root_ok and warp_ok and hold_ok and damage_ok and e_w_ok and lifecycle_ok and debug_ok and r_timing_ok and scene_closing_ok and scene_fleeing_ok
	print("HERO_AI_RUNTIME roster=%s scene_closing_r_rejected=%s scene_fleeing_r_allowed=%s one_shot=%s retarget=%s invalidate=%s root=%s warp=%s damage_hold=%s actual_damage=%s e_w=%s lifecycle=%s debug=%s r_timing=%s r_rule=%.2f r_elapsed=%.2f r_stayed=%s r_animation=%.2f/%.2f r_speed_restored=%s no_r_super_armor=%s" % [roster_ok, scene_closing_ok, scene_fleeing_ok, one_shot_ok, retarget_ok, invalidate_ok, root_ok, warp_ok, hold_ok, damage_ok, e_w_ok, lifecycle_ok, debug_ok, r_timing_ok, r_channel_duration, actual_channel_duration, warp_still_winding_up, animation_speed_during_windup, expected_windup_speed, is_equal_approx(float(model.get("animation_speed_scale")), original_animation_speed), is_zero_approx(float(probe.get("super_armor_timer")))])
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _has_decision(candidates: Array[HeroAIDecision], action_id: StringName) -> bool:
	for candidate: HeroAIDecision in candidates:
		if candidate.action_id == action_id:
			return true
	return false
