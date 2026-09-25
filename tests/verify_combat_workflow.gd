extends SceneTree

var player: CharacterBody3D
var dummy: CharacterBody3D
var model: GarenModelAnimator
var start_player := Vector3.ZERO
var observed := {}
var elapsed := 0.0

func _initialize() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	if packed == null:
		push_error("Prototype scene failed to load")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	player = scene.get_node("Characters/Player") as CharacterBody3D
	dummy = scene.get_node("Characters/EnemyTargetDummy1") as CharacterBody3D
	model = player.get_node_or_null("GarenModel") as GarenModelAnimator
	start_player = player.position
	if model == null:
		push_error("GarenModel node is missing from the combat scene")
		quit(1)

func _process(delta: float) -> bool:
	if model == null:
		return true
	elapsed += delta
	observed[String(model.current_animation)] = true
	if elapsed < 18.0:
		return false
	var skill_controller := player.get_node("SkillController") as Node
	var model_animations := model.animation_player.get_animation_list() if model.animation_player != null else PackedStringArray()
	var normal_attack_retiming_ok := is_equal_approx(model.get_semantic_speed(&"attack1"), 2.5) and is_equal_approx(model.get_semantic_speed(&"attack2"), 2.5) and is_equal_approx(model.get_semantic_speed(&"attack3"), 2.5)
	var outline_highlight := player.get_node_or_null("OutlineHighlight") as Node3D
	var outline_pairs := outline_highlight.get("_pairs") as Array if outline_highlight != null else []
	var outline_material: ShaderMaterial
	var toon_material: ShaderMaterial
	var default_outline_hidden := false
	if not outline_pairs.is_empty():
		outline_material = outline_pairs[0].get("outline", null).material_override as ShaderMaterial
		var source := outline_pairs[0].get("source", null) as MeshInstance3D
		toon_material = source.get_surface_override_material(0) as ShaderMaterial if source != null else null
	var highlight_ok := outline_highlight != null and outline_highlight.has_method("set_selected") and outline_highlight.has_method("set_targeted") and outline_highlight.has_method("set_highlighted")
	if outline_highlight != null and outline_material != null:
		outline_highlight.call("set_selected", false)
		outline_highlight.call("set_targeted", false)
		outline_highlight.call("set_highlighted", false)
		default_outline_hidden = outline_pairs.all(func(pair: Dictionary) -> bool: return not (pair.get("outline") as MeshInstance3D).visible)
		outline_highlight.call("set_targeted", true)
		var target_color := outline_material.get_shader_parameter(&"outline_color") as Color
		highlight_ok = highlight_ok and default_outline_hidden and target_color.is_equal_approx(outline_highlight.get("targeted_color"))
		outline_highlight.call("set_targeted", false)
	var toon_ok := toon_material != null and toon_material.shader.resource_path.ends_with("character_toon_3d.gdshader")
	toon_ok = toon_ok and toon_material.shader.code.contains("render_mode unshaded") and not toon_material.shader.code.contains("diffuse_toon")
	var hit_count := int(dummy.get("hit_count"))
	var skill_casts: Array = skill_controller.get("cast_counts") as Array
	model.set_facing(Vector3(1.0, 0.0, 8.0))
	var right_axis_ok := is_equal_approx(model.rotation.y, PI * 0.5)
	var depth_yaw_limit := deg_to_rad(model.max_visual_depth_yaw_degrees)
	var right_depth_yaw_ok := absf(model.get_visual_depth_yaw()) <= depth_yaw_limit + 0.0001
	model.set_facing(Vector3(-1.0, 0.0, 8.0))
	var left_axis_ok := is_equal_approx(model.rotation.y, -PI * 0.5)
	var left_depth_yaw_ok := absf(model.get_visual_depth_yaw()) <= depth_yaw_limit + 0.0001
	var passed := player.get_node_or_null("CharacterFrames") == null
	passed = passed and model_animations.size() == 33
	# Utility AI can spend this window casting instead of reaching the second combo swing.
	passed = passed and observed.has("run") and observed.has("attack1") and observed.has("spell1") and observed.has("spell3")
	passed = passed and hit_count >= 3 and start_player.distance_to(player.global_position) > 0.5
	passed = passed and int(skill_casts[1]) > 0 and int(skill_casts[3]) > 0
	passed = passed and right_axis_ok and left_axis_ok and right_depth_yaw_ok and left_depth_yaw_ok
	passed = passed and highlight_ok and toon_ok and normal_attack_retiming_ok
	print("COMBAT_3D animations=%d observed=%s hits=%d skills=%s player_moved=%.2f axis=%s/%s visual_yaw=%s/%s outline_hidden=%s highlight_api=%s toon=%s" % [
		model_animations.size(), observed.keys(), hit_count, skill_casts,
		start_player.distance_to(player.global_position), right_axis_ok, left_axis_ok,
		right_depth_yaw_ok, left_depth_yaw_ok, default_outline_hidden, highlight_ok, toon_ok,
	])
	if not passed:
		push_error("3D combat workflow verification failed")
	quit(0 if passed else 2)
	return true
