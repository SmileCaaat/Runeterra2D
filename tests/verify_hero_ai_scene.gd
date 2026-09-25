extends SceneTree


func _initialize() -> void:
	var stage := load("res://DNF_Style_Prototype.tscn").instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage
	await process_frame
	await process_frame
	var roster := stage.get_node("BattleHUD/HUDRoot/DebugDrawer/TrainingToolsPanel/VBox/Body/TrainingRosterPanel") as TrainingRosterPanel
	roster.set_training_units({&"friendly_dummy": false, &"enemy_dummy": false, &"scuttle": false})
	roster.set_roster(&"friendly", [&"garen", &"ryze"])
	roster.set_roster(&"enemy", [&"garen", &"ryze"])
	await process_frame
	var characters := stage.get_node("Characters") as Node3D
	var blue_garen := characters.get_node("Player") as CharacterBody3D
	var red_garen := characters.get_node("RosterGarenRed") as CharacterBody3D
	var blue_ryze := characters.get_node("RosterRyzeBlue") as CharacterBody3D
	var red_ryze := characters.get_node("RosterRyzeRed") as CharacterBody3D
	blue_garen.global_position = Vector3(-2.5, 0.0, -1.0)
	red_garen.global_position = Vector3(2.5, 0.0, -1.0)
	blue_ryze.global_position = Vector3(-3.5, 0.0, 1.0)
	red_ryze.global_position = Vector3(3.5, 0.0, 1.0)
	var heroes: Array[CharacterBody3D] = [blue_garen, red_garen, blue_ryze, red_ryze]
	for hero: CharacterBody3D in heroes:
		hero.call("force_retarget_hostile")
	var initial_health := 0.0
	for hero: CharacterBody3D in heroes:
		initial_health += float(hero.get("current_health"))
	await create_timer(4.0).timeout
	var ending_health := 0.0
	var brains_ok := true
	for hero: CharacterBody3D in heroes:
		ending_health += float(hero.get("current_health"))
		brains_ok = brains_ok and hero.get("ai_brain") != null
	var combat_progress := ending_health < initial_health - 1.0
	var demo_off := not bool(blue_garen.get_node("SkillController").get("automatic_demo")) and not bool(red_garen.get_node("SkillController").get("automatic_demo"))
	var passed := brains_ok and combat_progress and demo_off
	print("HERO_AI_SCENE brains=%s combat=%s demo_off=%s hp=%.1f->%.1f" % [brains_ok, combat_progress, demo_off, initial_health, ending_health])
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
