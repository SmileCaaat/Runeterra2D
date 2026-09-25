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
	var red_outline_ok := _has_target_highlight(source_red)

	var blue_target: CharacterBody3D = blue.get("target")
	var red_target: CharacterBody3D = source_red.get("target")
	var target_ok := blue_target == source_red and red_target == blue
	var red_garen_root_start := source_red.global_position
	source_red.call("apply_root", 1.0)
	await physics_frame
	var red_garen_root_stops_movement := bool(source_red.call("is_rooted")) \
		and Vector2(source_red.global_position.x - red_garen_root_start.x, source_red.global_position.z - red_garen_root_start.z).length() < 0.01

	var blue_hp_before := float(blue.get("current_health"))
	source_red.call("receive_hit", blue.global_position, &"attack1", 80.0)
	var red_hp_after_hit := float(source_red.get("current_health"))
	var red_took_aa := red_hp_after_hit < float(source_red.get("max_health"))
	var red_hit_feedback := _hit_feedback_count(source_red) == 1

	blue.call("receive_skill_damage", 120.0, "测试", false, source_red.global_position, &"physical", &"basic_melee")
	var blue_hp_after := float(blue.get("current_health"))
	var blue_took_skill := blue_hp_after < blue_hp_before
	var blue_hit_feedback := _hit_feedback_count(blue) == 1

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
	var ryze_hit_feedback := _hit_feedback_count(red_ryze) == 1
	var ryze_root_start := red_ryze.global_position
	red_ryze.call("apply_root", 1.0)
	await physics_frame
	var ryze_root_stops_movement := bool(red_ryze.call("is_rooted")) \
		and Vector2(red_ryze.global_position.x - ryze_root_start.x, red_ryze.global_position.z - ryze_root_start.z).length() < 0.01
	red_ryze.call("receive_skill_damage", 99999.0, "处决", false, blue.global_position, &"true", &"judgment_hit")
	var ryze_dies := bool(red_ryze.get("is_dead")) and not red_ryze.is_in_group(&"combat_target")

	print("HERO_VS_HERO target=%s target_highlight=%s root=%s/%s aa=%s skill=%s hit=%s/%s/%s ryze_hp=%s ryze_death=%s blue_hp=%.1f->%.1f red_hp=%.1f" % [
		target_ok, red_outline_ok, red_garen_root_stops_movement, ryze_root_stops_movement, red_took_aa, blue_took_skill, red_hit_feedback, blue_hit_feedback, ryze_hit_feedback, ryze_takes_damage, ryze_dies, blue_hp_before, blue_hp_after, red_hp_after_hit
	])
	var passed := target_ok and red_outline_ok and red_garen_root_stops_movement and ryze_root_stops_movement and red_took_aa and blue_took_skill and red_hit_feedback and blue_hit_feedback and ryze_hit_feedback and ryze_takes_damage and ryze_dies
	if not passed:
		push_error("Hero versus hero verification failed")
		stage.queue_free()
		await process_frame
		quit(1)
		return
	stage.queue_free()
	await process_frame
	quit(0)


func _has_target_highlight(actor: Node) -> bool:
	var controller := actor.get_node_or_null("OutlineHighlight")
	if controller == null:
		return false
	var pairs: Array = controller.get("_pairs")
	if pairs.is_empty() or pairs.size() != _generated_outline_count(actor) or not bool(controller.call("is_targeted")):
		return false
	for pair: Dictionary in pairs:
		var outline := pair.get("outline") as MeshInstance3D
		if outline == null or not is_instance_valid(outline):
			return false
		var material := outline.material_override as ShaderMaterial
		var color := material.get_shader_parameter(&"outline_color") as Color if material != null else Color.BLACK
		if not color.is_equal_approx(controller.get("targeted_color")):
			return false
	return true


func _hit_feedback_count(actor: Node) -> int:
	var feedback := actor.get_node_or_null("HeroHitFeedback3D")
	return int(feedback.get("hit_count")) if feedback != null else 0


func _generated_outline_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and node.name.begins_with("OutlineHighlight_") else 0
	for child in node.get_children():
		count += _generated_outline_count(child)
	return count
