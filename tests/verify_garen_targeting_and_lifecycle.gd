extends SceneTree

## Regression: heroes outrank optional training targets and Garen owns a full
## targetable -> death -> revive lifecycle for the skeletal-model pipeline.

func _initialize() -> void:
	var stage := load("res://DNF_Style_Prototype.tscn").instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage
	await process_frame
	await process_frame
	var characters := stage.get_node("Characters") as Node3D
	var blue := characters.get_node("Player") as CharacterBody3D
	var red := blue.duplicate() as CharacterBody3D
	red.name = "LifecycleRedGaren"
	red.set("team", "enemy")
	red.set("target_path", NodePath())
	red.set("target", null)
	characters.add_child(red)
	red.global_position = Vector3(5.5, 0.0, -1.9)
	red.remove_from_group(&"player_actor")
	red.call("_configure_team_groups")
	red.call("revive_for_training")
	blue.call("force_retarget_hostile")
	await process_frame
	var hero_priority_ok: bool = blue.get("target") == red
	var roster_panel := stage.get_node("BattleHUD/HUDRoot/DebugDrawer/TrainingToolsPanel/VBox/Body/TrainingRosterPanel") as TrainingRosterPanel
	var unit_controls_ok := roster_panel != null
	if roster_panel != null:
		roster_panel.set_training_units({&"friendly_dummy": false, &"enemy_dummy": false, &"scuttle": false})
		await process_frame
		var enemy_dummy := characters.get_node("EnemyTargetDummy1") as CharacterBody3D
		var friendly_dummy := characters.get_node("FriendlyTargetDummy1") as CharacterBody3D
		var spawner := characters.get_node("ScuttleCrabSpawner") as Node3D
		unit_controls_ok = unit_controls_ok and not enemy_dummy.is_in_group(&"combat_target") \
			and not friendly_dummy.is_in_group(&"combat_target") \
			and not bool(blue.call("_is_target_available", enemy_dummy)) \
			and String(spawner.get("scene_mode")) == "disabled"
		roster_panel.set_training_units({&"friendly_dummy": true, &"enemy_dummy": true, &"scuttle": true})
		await process_frame
		unit_controls_ok = unit_controls_ok and enemy_dummy.is_in_group(&"combat_target") \
			and friendly_dummy.is_in_group(&"combat_target") \
			and String(spawner.get("scene_mode")) == "training"

	var skills := blue.get_node("SkillController")
	var ocean_storm := skills.get_node("OceanStorm") as AnimatedSprite3D
	var model := blue.get_node("GarenModel") as GarenModelAnimator
	var cast_generation_before_death := int(skills.get("_cast_generation"))
	var e_started := bool(skills.call("begin_skill", 3))
	await process_frame
	e_started = e_started and bool(skills.get("is_casting")) \
		and bool(skills.get("ocean_storm_loop_active")) \
		and StringName(model.get("current_animation")) == &"spell3"
	blue.call("receive_skill_damage", 99999.0, "TEST", false, red.global_position, &"true", &"judgment_hit")
	await create_timer(0.55).timeout
	var death_ok := bool(blue.get("is_dead")) \
		and not blue.is_in_group(&"combat_target") \
		and not bool(blue.call("is_targetable")) \
		and is_zero_approx(float(blue.get("current_health"))) \
		and model != null and StringName(model.get("current_animation")) == &"death" \
		and not bool(skills.get("ocean_storm_loop_active")) \
		and not bool(skills.get("is_casting")) \
		and int(skills.get("_cast_generation")) == cast_generation_before_death + 2 \
		and not ocean_storm.visible and not ocean_storm.is_playing()

	blue.call("revive_for_training")
	await process_frame
	var revive_ok := not bool(blue.get("is_dead")) \
		and blue.is_in_group(&"combat_target") \
		and bool(blue.call("is_targetable")) \
		and is_equal_approx(float(blue.get("current_health")), float(blue.get("max_health")))
	print("GAREN_TARGETING_LIFECYCLE hero_priority=%s unit_controls=%s e_started=%s death=%s e_death_cancel=%s revive=%s" % [hero_priority_ok, unit_controls_ok, e_started, death_ok, not bool(skills.get("ocean_storm_loop_active")), revive_ok])
	stage.queue_free()
	quit(0 if hero_priority_ok and unit_controls_ok and e_started and death_ok and revive_ok else 1)
