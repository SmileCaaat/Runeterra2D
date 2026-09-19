extends SceneTree

## Verifies red/blue hero combat contracts: hostile retarget, AA damage, and HP.

func _initialize() -> void:
	var stage := load("res://DNF_Style_Prototype.tscn").instantiate() as Node
	root.add_child(stage)
	await process_frame
	await process_frame

	var characters := stage.get_node("Characters") as Node3D
	var blue := characters.get_node("Player") as CharacterBody3D
	var source_red := blue.duplicate() as CharacterBody3D
	source_red.name = "RosterGarenRed"
	source_red.set("team", "enemy")
	source_red.set("target_path", NodePath())
	source_red.set("target", null)
	characters.add_child(source_red)
	source_red.global_position = Vector3(5.5, 0.0, -1.9)
	source_red.remove_from_group(&"player_actor")
	source_red.call("_configure_team_groups")
	source_red.call("force_retarget_hostile")
	blue.set("target", null)
	blue.call("force_retarget_hostile")
	await process_frame

	var blue_target: CharacterBody3D = blue.get("target")
	var red_target: CharacterBody3D = source_red.get("target")
	var target_ok := blue_target == source_red and red_target == blue

	var blue_hp_before := float(blue.get("current_health"))
	source_red.call("receive_hit", blue.global_position, &"attack1", 80.0)
	var red_hp_after_hit := float(source_red.get("current_health"))
	var red_took_aa := red_hp_after_hit < float(source_red.get("max_health"))

	blue.call("receive_skill_damage", 120.0, "测试", false, source_red.global_position, &"physical", &"basic_melee")
	var blue_hp_after := float(blue.get("current_health"))
	var blue_took_skill := blue_hp_after < blue_hp_before

	var ryze_scene := load("res://scenes/units/ryze.tscn") as PackedScene
	var red_ryze := ryze_scene.instantiate() as CharacterBody3D
	red_ryze.name = "RosterRyzeRed"
	red_ryze.set("team", "enemy")
	red_ryze.set("enabled", true)
	characters.add_child(red_ryze)
	red_ryze.global_position = Vector3(6.0, 0.0, 1.5)
	red_ryze.call("_configure_team_groups")
	await process_frame
	var ryze_hp_before := float(red_ryze.get("current_health"))
	red_ryze.call("receive_skill_damage", 150.0, "测试", false, blue.global_position, &"physical", &"basic_melee")
	var ryze_hp_after := float(red_ryze.get("current_health"))
	var ryze_takes_damage := ryze_hp_after < ryze_hp_before and ryze_hp_after > 0.0
	red_ryze.call("receive_skill_damage", 99999.0, "处决", false, blue.global_position, &"true", &"judgment_hit")
	var ryze_dies := bool(red_ryze.get("is_dead")) and not red_ryze.is_in_group(&"combat_target")

	print("HERO_VS_HERO target=%s aa=%s skill=%s ryze_hp=%s ryze_death=%s blue_hp=%.1f->%.1f red_hp=%.1f" % [
		target_ok, red_took_aa, blue_took_skill, ryze_takes_damage, ryze_dies, blue_hp_before, blue_hp_after, red_hp_after_hit
	])
	var passed := target_ok and red_took_aa and blue_took_skill and ryze_takes_damage and ryze_dies
	if not passed:
		push_error("Hero versus hero verification failed")
		quit(1)
		return
	quit(0)
