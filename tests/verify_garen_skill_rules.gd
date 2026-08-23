extends SceneTree


func _initialize() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	if packed == null:
		push_error("Could not load prototype scene")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("Characters/Player") as CharacterBody3D
	var dummy := scene.get_node("Characters/EnemyPlaceholder") as CharacterBody3D
	var skills := player.get_node("SkillController")
	skills.set("automatic_demo", false)

	skills.set("breaker_timer", 4.5)
	var breaker_ok := is_equal_approx(float(skills.call("get_move_speed_multiplier")), 1.35)
	breaker_ok = breaker_ok and StringName(skills.call("get_run_animation")) == &"run_spell"
	var passive_ok := is_equal_approx(float(skills.call("get_passive_armor_multiplier")), 1.2)

	skills.set("current_health", 1000.0)
	skills.set("rum_timer", 0.0)
	skills.set("black_sail_timer", 1.0)
	skills.call("receive_incoming_damage", 100.0)
	var reduction_ok := is_equal_approx(float(skills.get("current_health")), 930.0)

	skills.set("current_health", 1000.0)
	skills.set("black_sail_timer", 0.0)
	skills.set("rum_timer", 10.0)
	skills.set("delayed_damage_pool", 0.0)
	skills.call("receive_incoming_damage", 100.0)
	var rum_ok := is_equal_approx(float(skills.get("current_health")), 1000.0)
	rum_ok = rum_ok and is_equal_approx(float(skills.get("delayed_damage_pool")), 100.0)
	skills.call("activate_black_sail_defenses")
	var cleanse_ok := is_equal_approx(float(skills.get("delayed_damage_pool")), 70.0)

	skills.set("current_health", 5.0)
	skills.set("rum_timer", 1.0)
	skills.set("delayed_damage_pool", 1000.0)
	skills.call("_update_rum_damage", 1.0)
	var nonlethal_ok := is_equal_approx(float(skills.get("current_health")), 1.0)
	var judgment_ok := is_equal_approx(float(skills.call("calculate_judgment_damage", 0.5)), 260.0)

	skills.set("black_sail_timer", 1.0)
	skills.call("_update_timers", 0.25)
	var jolly_duration_ok := (skills.get_node("JollyRoger") as AnimatedSprite3D).visible
	skills.set("black_sail_timer", 0.1)
	skills.call("_update_timers", 0.2)
	jolly_duration_ok = jolly_duration_ok and not (skills.get_node("JollyRoger") as AnimatedSprite3D).visible

	var anchor := skills.get_node("Anchor") as AnimatedSprite3D
	anchor.visible = true
	dummy.global_position = Vector3(2.0, 0.0, -1.0)
	skills.call("_process", 0.0)
	var anchor_follow_ok := anchor.global_position.is_equal_approx(dummy.global_position)
	var ghost := skills.get_node("Ghostship") as AnimatedSprite3D
	skills.call("prepare_ghostship_direction", player.global_position + Vector3.LEFT * 4.0)
	var ghost_flip_ok := ghost.flip_h
	skills.call("prepare_ghostship_direction", player.global_position + Vector3.RIGHT * 4.0)
	ghost_flip_ok = ghost_flip_ok and not ghost.flip_h
	var vfx_anchor_ok := true
	for effect_name: StringName in [&"JollyRoger", &"OceanStorm", &"Anchor", &"Ghostship"]:
		var effect := skills.get_node(NodePath(effect_name)) as AnimatedSprite3D
		var expected_offset := _read_vfx_anchor(effect.animation)
		vfx_anchor_ok = vfx_anchor_ok and effect.offset.is_equal_approx(expected_offset)

	player.set_physics_process(false)
	dummy.set_physics_process(false)
	var ghost_area_center := dummy.global_position
	await skills.call("_cast_seven_seas")
	var ghost_area_ok := ghost.global_position.is_equal_approx(ghost_area_center)

	var ocean := skills.get_node("OceanStorm") as AnimatedSprite3D
	skills.set("is_casting", true)
	skills.set("current_skill", 3)
	var moving_storm_ok := bool(skills.call("allows_movement_while_casting"))
	skills.set("current_skill", 4)
	moving_storm_ok = moving_storm_ok and not bool(skills.call("allows_movement_while_casting"))
	skills.set("is_casting", false)
	var layering_ok := ocean.scale.is_equal_approx(Vector3.ONE * 1.4)
	layering_ok = layering_ok and ocean.render_priority > 0 and anchor.render_priority > 0
	layering_ok = layering_ok and anchor.no_depth_test
	layering_ok = layering_ok and (skills.get_node("JollyRoger") as AnimatedSprite3D).render_priority < 0
	layering_ok = layering_ok and ghost.scale.is_equal_approx(Vector3.ONE * 1.5)
	var filter_clip_ok := true
	var vfx_frames := ocean.sprite_frames
	for animation_name: StringName in vfx_frames.get_animation_names():
		var frame_texture := vfx_frames.get_frame_texture(animation_name, 0) as AtlasTexture
		filter_clip_ok = filter_clip_ok and frame_texture != null and frame_texture.filter_clip
	var shader_ok := true
	var canvas_fade_ok := true
	var ground_occlusion_ok := true
	for effect_name: StringName in [&"JollyRoger", &"OceanStorm", &"Anchor", &"Ghostship"]:
		(skills.get_node(NodePath(effect_name)) as AnimatedSprite3D).visible = true
	skills.call("_sync_vfx_frame_textures")
	for effect_name: StringName in [&"JollyRoger", &"OceanStorm", &"Anchor", &"Ghostship"]:
		var effect := skills.get_node(NodePath(effect_name)) as AnimatedSprite3D
		shader_ok = shader_ok and effect.material_override is ShaderMaterial
		if effect.material_override is ShaderMaterial:
			var material := effect.material_override as ShaderMaterial
			shader_ok = shader_ok and material.shader != null
			var canvas_fade_value: Variant = material.get_shader_parameter(&"canvas_edge_fade")
			var frame_uv_rect_value: Variant = material.get_shader_parameter(&"frame_uv_rect")
			var ground_height_value: Variant = material.get_shader_parameter(&"ground_height")
			var ground_alpha_value: Variant = material.get_shader_parameter(&"ground_occluded_alpha")
			var ground_depth_fade_value: Variant = material.get_shader_parameter(&"ground_depth_fade")
			var show_over_models_value: Variant = material.get_shader_parameter(&"show_over_models")
			canvas_fade_ok = canvas_fade_ok and canvas_fade_value is float
			if canvas_fade_value is float:
				canvas_fade_ok = canvas_fade_ok and is_equal_approx(float(canvas_fade_value), 0.15)
			var frame_texture := effect.sprite_frames.get_frame_texture(effect.animation, effect.frame) as AtlasTexture
			canvas_fade_ok = canvas_fade_ok and frame_texture != null and frame_uv_rect_value is Vector4
			if frame_texture != null and frame_uv_rect_value is Vector4:
				var atlas_size := Vector2(frame_texture.atlas.get_size())
				var region := frame_texture.region
				var expected_uv_rect := Vector4(
					region.position.x / atlas_size.x,
					region.position.y / atlas_size.y,
					region.size.x / atlas_size.x,
					region.size.y / atlas_size.y
				)
				canvas_fade_ok = canvas_fade_ok and (frame_uv_rect_value as Vector4).is_equal_approx(expected_uv_rect)
			ground_occlusion_ok = ground_occlusion_ok and ground_height_value is float
			if ground_height_value is float:
				ground_occlusion_ok = ground_occlusion_ok and is_equal_approx(float(ground_height_value), 0.0)
			ground_occlusion_ok = ground_occlusion_ok and ground_alpha_value is float
			if ground_alpha_value is float:
				ground_occlusion_ok = ground_occlusion_ok and is_equal_approx(float(ground_alpha_value), 0.32)
			ground_occlusion_ok = ground_occlusion_ok and ground_depth_fade_value is float
			if ground_depth_fade_value is float:
				ground_occlusion_ok = ground_occlusion_ok and is_equal_approx(float(ground_depth_fade_value), 0.9)
			ground_occlusion_ok = ground_occlusion_ok and show_over_models_value is bool
			if show_over_models_value is bool:
				ground_occlusion_ok = ground_occlusion_ok and bool(show_over_models_value) == effect.no_depth_test

	print("SKILL_RULES breaker=%s passive=%s reduction=%s rum=%s cleanse=%s nonlethal=%s judgment=%s jolly=%s anchor=%s ghost=%s vfx_anchor=%s ghost_area=%s moving_storm=%s layering=%s filter=%s shader=%s canvas_fade=%s ground_occlusion=%s" % [
		breaker_ok, passive_ok, reduction_ok, rum_ok, cleanse_ok, nonlethal_ok, judgment_ok,
		jolly_duration_ok, anchor_follow_ok, ghost_flip_ok, vfx_anchor_ok, ghost_area_ok,
		moving_storm_ok, layering_ok, filter_clip_ok, shader_ok, canvas_fade_ok, ground_occlusion_ok,
	])
	var passed := breaker_ok and passive_ok and reduction_ok and rum_ok
	passed = passed and cleanse_ok and nonlethal_ok and judgment_ok
	passed = passed and jolly_duration_ok and anchor_follow_ok and ghost_flip_ok
	passed = passed and vfx_anchor_ok and ghost_area_ok
	passed = passed and moving_storm_ok and layering_ok and filter_clip_ok and shader_ok and canvas_fade_ok
	passed = passed and ground_occlusion_ok
	if not passed:
		push_error("Garen skill rule verification failed")
	quit(0 if passed else 2)


func _read_vfx_anchor(animation_name: StringName) -> Vector2:
	var json_path := "res://assets/vfx/garen_skills".path_join(String(animation_name)).path_join("spritesheet.json")
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return Vector2.INF
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return Vector2.INF
	var meta: Dictionary = (parsed as Dictionary).get("meta", {})
	var canvas: Dictionary = meta.get("canvas", {})
	var width := float(canvas.get("width", 0.0))
	var height := float(canvas.get("height", 0.0))
	var origin_x := float(canvas.get("originPixelX", width * 0.5))
	var origin_y := float(canvas.get("originPixelY", height))
	return Vector2(width * 0.5 - origin_x, origin_y - height * 0.5)
