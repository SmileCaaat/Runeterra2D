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
	var enemy_two := scene.get_node("Characters/EnemyTargetDummy2") as CharacterBody3D
	var friendly_dummy := scene.get_node("Characters/FriendlyTargetDummy1") as CharacterBody3D
	var skills := player.get_node("SkillController")
	skills.set("automatic_demo", false)

	skills.set("breaker_timer", 4.5)
	var breaker_ok := is_equal_approx(float(skills.call("get_move_speed_multiplier")), 1.35)
	breaker_ok = breaker_ok and StringName(skills.call("get_run_animation")) == &"run_spell"
	var character_frames := player.get_node("CharacterFrames") as AnimatedSprite3D
	var breaker_afterimages: Array = skills.get("breaker_afterimages")
	var afterimage_ok := breaker_afterimages.size() == 3
	var configured_afterimage_color := skills.get("breaker_afterimage_color") as Color
	skills.set("breaker_afterimage_capture_count", 0)
	character_frames.animation = &"run_spell"
	character_frames.frame = mini(1, character_frames.sprite_frames.get_frame_count(&"run_spell") - 1)
	skills.call("_capture_breaker_afterimage")
	var run_capture_count := int(skills.get("breaker_afterimage_capture_count"))
	afterimage_ok = afterimage_ok and run_capture_count > 0
	var visible_afterimages := 0
	for afterimage_variant: Variant in breaker_afterimages:
		var afterimage := afterimage_variant as Sprite3D
		afterimage_ok = afterimage_ok and afterimage != null
		if afterimage != null and afterimage.visible:
			visible_afterimages += 1
			afterimage_ok = afterimage_ok and afterimage.texture != null and afterimage.top_level
			var afterimage_material := afterimage.material_override as ShaderMaterial
			afterimage_ok = afterimage_ok and afterimage_material != null
			if afterimage_material != null:
				var ocean_tint: Variant = afterimage_material.get_shader_parameter(&"ocean_tint")
				afterimage_ok = afterimage_ok and ocean_tint is Color
				if ocean_tint is Color:
					var tint := ocean_tint as Color
					afterimage_ok = afterimage_ok and is_equal_approx(tint.r, configured_afterimage_color.r)
					afterimage_ok = afterimage_ok and is_equal_approx(tint.g, configured_afterimage_color.g)
					afterimage_ok = afterimage_ok and is_equal_approx(tint.b, configured_afterimage_color.b)
	afterimage_ok = afterimage_ok and visible_afterimages > 0
	character_frames.animation = &"spell1"
	character_frames.frame = 0
	skills.call("_capture_breaker_afterimage")
	var attack_capture_count := int(skills.get("breaker_afterimage_capture_count"))
	afterimage_ok = afterimage_ok and attack_capture_count > run_capture_count
	character_frames.flip_h = true
	skills.call("_capture_breaker_afterimage")
	var captured_index := wrapi(int(skills.get("breaker_afterimage_cursor")) - 1, 0, breaker_afterimages.size())
	var flipped_afterimage := breaker_afterimages[captured_index] as Sprite3D
	afterimage_ok = afterimage_ok and flipped_afterimage != null and flipped_afterimage.flip_h
	afterimage_ok = afterimage_ok and flipped_afterimage.offset.is_equal_approx(character_frames.offset)
	character_frames.flip_h = false
	attack_capture_count = int(skills.get("breaker_afterimage_capture_count"))
	character_frames.animation = &"run"
	skills.call("_capture_breaker_afterimage")
	afterimage_ok = afterimage_ok and int(skills.get("breaker_afterimage_capture_count")) == attack_capture_count
	skills.call("_update_breaker_afterimages", 1.0)
	for afterimage_variant: Variant in breaker_afterimages:
		var afterimage := afterimage_variant as Sprite3D
		afterimage_ok = afterimage_ok and afterimage != null and not afterimage.visible
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
	var impact_shockwaves: Array = skills.get("impact_shockwaves")
	var impact_shockwave_ok := impact_shockwaves.size() == 2
	skills.set("impact_shockwave_emit_count", 0)
	skills.set("anchor_last_impact_frame", -1)
	anchor.frame = 7
	skills.call("_handle_impact_vfx_frame", anchor)
	var anchor_impact_count := int(skills.get("impact_shockwave_emit_count"))
	impact_shockwave_ok = impact_shockwave_ok and anchor_impact_count > 0
	var impact_debris := skills.get("impact_debris") as CPUParticles3D
	impact_shockwave_ok = impact_shockwave_ok and impact_debris != null
	impact_shockwave_ok = impact_shockwave_ok and int(skills.get("impact_debris_burst_count")) > 0
	var water_vapor_burst := skills.get("water_vapor_burst") as MeshInstance3D
	var water_vapor_mist := skills.get("water_vapor_mist") as CPUParticles3D
	impact_shockwave_ok = impact_shockwave_ok and water_vapor_burst != null and water_vapor_burst.visible
	impact_shockwave_ok = impact_shockwave_ok and water_vapor_mist != null and water_vapor_mist.emitting
	impact_shockwave_ok = impact_shockwave_ok and int(skills.get("water_vapor_burst_count")) > 0
	var vapor_duration := float(skills.get("judgment_vapor_burst_duration"))
	impact_shockwave_ok = impact_shockwave_ok and vapor_duration <= 0.30 and water_vapor_mist.lifetime <= 0.35
	skills.set("water_vapor_burst_elapsed", vapor_duration * 0.25)
	skills.call("_update_water_vapor_burst", 0.0)
	var vapor_overshoot_scale := water_vapor_burst.scale.x
	skills.set("water_vapor_burst_elapsed", vapor_duration * 0.55)
	skills.call("_update_water_vapor_burst", 0.0)
	var vapor_recoil_scale := water_vapor_burst.scale.x
	skills.set("water_vapor_burst_elapsed", vapor_duration * 0.80)
	skills.call("_update_water_vapor_burst", 0.0)
	var vapor_secondary_scale := water_vapor_burst.scale.x
	impact_shockwave_ok = impact_shockwave_ok and vapor_overshoot_scale > vapor_recoil_scale
	impact_shockwave_ok = impact_shockwave_ok and vapor_secondary_scale > vapor_recoil_scale
	anchor.frame = 6
	skills.call("_handle_impact_vfx_frame", anchor)
	impact_shockwave_ok = impact_shockwave_ok and int(skills.get("impact_shockwave_emit_count")) == anchor_impact_count
	ghost.visible = true
	skills.set("ghostship_last_impact_frame", -1)
	ghost.frame = 9
	skills.call("_handle_impact_vfx_frame", ghost)
	impact_shockwave_ok = impact_shockwave_ok and int(skills.get("impact_shockwave_emit_count")) > anchor_impact_count
	var visible_shockwaves := 0
	for shockwave_variant: Variant in impact_shockwaves:
		var shockwave := shockwave_variant as MeshInstance3D
		impact_shockwave_ok = impact_shockwave_ok and shockwave != null and shockwave.top_level
		if shockwave != null and shockwave.visible:
			visible_shockwaves += 1
			var shock_material := shockwave.material_override as ShaderMaterial
			impact_shockwave_ok = impact_shockwave_ok and shock_material != null
			if shock_material != null:
				impact_shockwave_ok = impact_shockwave_ok and shock_material.shader != null
				impact_shockwave_ok = impact_shockwave_ok and float(shock_material.get_shader_parameter(&"distortion_strength")) > 0.0
	impact_shockwave_ok = impact_shockwave_ok and visible_shockwaves >= 2
	skills.call("_update_impact_shockwaves", 1.0)
	skills.call("_update_impact_camera_shake", 1.0)
	skills.call("_update_water_vapor_burst", 1.0)
	impact_shockwave_ok = impact_shockwave_ok and not water_vapor_burst.visible
	for shockwave_variant: Variant in impact_shockwaves:
		impact_shockwave_ok = impact_shockwave_ok and not (shockwave_variant as MeshInstance3D).visible
	anchor.visible = true
	skills.call("_on_anchor_animation_finished")
	impact_shockwave_ok = impact_shockwave_ok and anchor.visible and bool(skills.get("anchor_tail_active"))
	skills.call("_update_anchor_tail_dissolve", 0.28)
	var anchor_tail_material := anchor.material_override as ShaderMaterial
	impact_shockwave_ok = impact_shockwave_ok and anchor_tail_material != null
	if anchor_tail_material != null:
		impact_shockwave_ok = impact_shockwave_ok and float(anchor_tail_material.get_shader_parameter(&"tail_dissolve")) > 0.0
	impact_shockwave_ok = impact_shockwave_ok and anchor.visible
	skills.call("_update_anchor_tail_dissolve", 1.0)
	impact_shockwave_ok = impact_shockwave_ok and not anchor.visible and is_equal_approx(anchor.speed_scale, 1.0)
	ghost.visible = false
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
	enemy_two.set_physics_process(false)
	friendly_dummy.set_physics_process(false)
	var saved_player_position := player.global_position
	var saved_dummy_position := dummy.global_position
	var saved_enemy_two_position := enemy_two.global_position
	var saved_friendly_position := friendly_dummy.global_position
	player.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0.8, 0.0, 0.0)
	enemy_two.global_position = Vector3(1.7, 0.0, 0.4)
	friendly_dummy.global_position = Vector3(1.0, 0.0, -0.5)
	var dummy_skill_hits_before := int(dummy.get("skill_damage_count"))
	var enemy_two_skill_hits_before := int(enemy_two.get("skill_damage_count"))
	var friendly_skill_hits_before := int(friendly_dummy.get("skill_damage_count"))
	var ocean_hit_targets := int(skills.call("resolve_ocean_storm_tick"))
	var aoe_ok := ocean_hit_targets == 2
	aoe_ok = aoe_ok and int(dummy.get("skill_damage_count")) == dummy_skill_hits_before + 1
	aoe_ok = aoe_ok and int(enemy_two.get("skill_damage_count")) == enemy_two_skill_hits_before + 1
	aoe_ok = aoe_ok and int(friendly_dummy.get("skill_damage_count")) == friendly_skill_hits_before

	var ghost_test_center := Vector3(4.0, 0.0, 0.0)
	dummy.global_position = ghost_test_center + Vector3.LEFT
	enemy_two.global_position = ghost_test_center + Vector3.RIGHT
	friendly_dummy.global_position = ghost_test_center
	dummy_skill_hits_before = int(dummy.get("skill_damage_count"))
	enemy_two_skill_hits_before = int(enemy_two.get("skill_damage_count"))
	friendly_skill_hits_before = int(friendly_dummy.get("skill_damage_count"))
	var ghost_hit_targets := int(skills.call("resolve_ghostship_impact", ghost_test_center))
	aoe_ok = aoe_ok and ghost_hit_targets == 2
	aoe_ok = aoe_ok and int(dummy.get("skill_damage_count")) == dummy_skill_hits_before + 1
	aoe_ok = aoe_ok and int(enemy_two.get("skill_damage_count")) == enemy_two_skill_hits_before + 1
	aoe_ok = aoe_ok and float(dummy.get("stun_timer")) > 0.0 and float(enemy_two.get("stun_timer")) > 0.0
	aoe_ok = aoe_ok and int(friendly_dummy.get("skill_damage_count")) == friendly_skill_hits_before
	# Match the radial gameplay boundary to the roughly 10.5 m wide Ghostship canvas.
	dummy.global_position = ghost_test_center + Vector3(5.1, 0.0, 0.0)
	enemy_two.global_position = ghost_test_center + Vector3(5.3, 0.0, 0.0)
	dummy_skill_hits_before = int(dummy.get("skill_damage_count"))
	enemy_two_skill_hits_before = int(enemy_two.get("skill_damage_count"))
	ghost_hit_targets = int(skills.call("resolve_ghostship_impact", ghost_test_center))
	aoe_ok = aoe_ok and is_equal_approx(float(skills.get("ghostship_radius")), 5.2)
	aoe_ok = aoe_ok and ghost_hit_targets == 1
	aoe_ok = aoe_ok and int(dummy.get("skill_damage_count")) == dummy_skill_hits_before + 1
	aoe_ok = aoe_ok and int(enemy_two.get("skill_damage_count")) == enemy_two_skill_hits_before
	dummy.call("_reset_training_session", true)
	enemy_two.call("_reset_training_session", true)
	player.global_position = saved_player_position
	dummy.global_position = saved_dummy_position
	enemy_two.global_position = saved_enemy_two_position
	friendly_dummy.global_position = saved_friendly_position
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
	var inward_edge_ok := true
	var ground_occlusion_ok := true
	for effect_name: StringName in [&"JollyRoger", &"OceanStorm", &"Anchor", &"Ghostship"]:
		var effect := skills.get_node(NodePath(effect_name)) as AnimatedSprite3D
		effect.visible = true
		var frame_count := effect.sprite_frames.get_frame_count(effect.animation)
		for frame_index: int in range(frame_count):
			effect.frame = frame_index
			var frame_texture := effect.sprite_frames.get_frame_texture(effect.animation, frame_index) as AtlasTexture
			var material := effect.material_override as ShaderMaterial
			canvas_fade_ok = canvas_fade_ok and frame_texture != null and material != null
			if frame_texture != null and material != null:
				var atlas_size := Vector2(frame_texture.atlas.get_size())
				var region := frame_texture.region
				var expected_uv_rect := Vector4(
					region.position.x / atlas_size.x,
					region.position.y / atlas_size.y,
					region.size.x / atlas_size.x,
					region.size.y / atlas_size.y
				)
				var actual_uv_rect: Variant = material.get_shader_parameter(&"frame_uv_rect")
				canvas_fade_ok = canvas_fade_ok and actual_uv_rect is Vector4
				if actual_uv_rect is Vector4:
					canvas_fade_ok = canvas_fade_ok and (actual_uv_rect as Vector4).is_equal_approx(expected_uv_rect)
	for effect_name: StringName in [&"JollyRoger", &"OceanStorm", &"Anchor", &"Ghostship"]:
		var effect := skills.get_node(NodePath(effect_name)) as AnimatedSprite3D
		shader_ok = shader_ok and effect.material_override is ShaderMaterial
		if effect.material_override is ShaderMaterial:
			var material := effect.material_override as ShaderMaterial
			shader_ok = shader_ok and material.shader != null
			var canvas_clear_value: Variant = material.get_shader_parameter(&"canvas_edge_clear")
			var canvas_fade_value: Variant = material.get_shader_parameter(&"canvas_edge_fade")
			var inward_base_value: Variant = material.get_shader_parameter(&"canvas_inward_base")
			var inward_warp_value: Variant = material.get_shader_parameter(&"canvas_inward_warp")
			var inward_softness_value: Variant = material.get_shader_parameter(&"canvas_inward_softness")
			var inward_frequency_value: Variant = material.get_shader_parameter(&"canvas_inward_frequency")
			var frame_uv_rect_value: Variant = material.get_shader_parameter(&"frame_uv_rect")
			var ground_height_value: Variant = material.get_shader_parameter(&"ground_height")
			var ground_alpha_value: Variant = material.get_shader_parameter(&"ground_occluded_alpha")
			var ground_depth_fade_value: Variant = material.get_shader_parameter(&"ground_depth_fade")
			var show_over_models_value: Variant = material.get_shader_parameter(&"show_over_models")
			canvas_fade_ok = canvas_fade_ok and canvas_clear_value is float and canvas_fade_value is float
			if canvas_clear_value is float:
				canvas_fade_ok = canvas_fade_ok and is_equal_approx(float(canvas_clear_value), 0.08)
			if canvas_fade_value is float:
				canvas_fade_ok = canvas_fade_ok and is_equal_approx(float(canvas_fade_value), 0.28)
			inward_edge_ok = inward_edge_ok and inward_base_value is float and inward_warp_value is float
			inward_edge_ok = inward_edge_ok and inward_softness_value is float and inward_frequency_value is float
			if inward_base_value is float and inward_warp_value is float:
				if effect_name == &"Anchor":
					inward_edge_ok = inward_edge_ok and is_equal_approx(float(inward_base_value), 0.025)
					inward_edge_ok = inward_edge_ok and is_equal_approx(float(inward_warp_value), 0.055)
				elif effect_name == &"Ghostship":
					inward_edge_ok = inward_edge_ok and is_equal_approx(float(inward_base_value), 0.04)
					inward_edge_ok = inward_edge_ok and is_equal_approx(float(inward_warp_value), 0.085)
				else:
					inward_edge_ok = inward_edge_ok and is_zero_approx(float(inward_base_value))
					inward_edge_ok = inward_edge_ok and is_zero_approx(float(inward_warp_value))
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

	print("SKILL_RULES breaker=%s afterimage=%s impact_shockwave=%s passive=%s reduction=%s rum=%s cleanse=%s nonlethal=%s judgment=%s jolly=%s anchor=%s ghost=%s vfx_anchor=%s ghost_area=%s aoe=%s moving_storm=%s layering=%s filter=%s shader=%s canvas_fade=%s inward_edge=%s ground_occlusion=%s" % [
		breaker_ok, afterimage_ok, impact_shockwave_ok, passive_ok, reduction_ok, rum_ok, cleanse_ok, nonlethal_ok, judgment_ok,
		jolly_duration_ok, anchor_follow_ok, ghost_flip_ok, vfx_anchor_ok, ghost_area_ok, aoe_ok,
		moving_storm_ok, layering_ok, filter_clip_ok, shader_ok, canvas_fade_ok, inward_edge_ok, ground_occlusion_ok,
	])
	var passed := breaker_ok and afterimage_ok and impact_shockwave_ok and passive_ok and reduction_ok and rum_ok
	passed = passed and cleanse_ok and nonlethal_ok and judgment_ok
	passed = passed and jolly_duration_ok and anchor_follow_ok and ghost_flip_ok
	passed = passed and vfx_anchor_ok and ghost_area_ok and aoe_ok
	passed = passed and moving_storm_ok and layering_ok and filter_clip_ok and shader_ok and canvas_fade_ok
	passed = passed and inward_edge_ok
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
