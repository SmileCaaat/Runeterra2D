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
	var dummy := scene.get_node("Characters/EnemyTargetDummy1") as CharacterBody3D
	var enemy_two := scene.get_node("Characters/EnemyTargetDummy2") as CharacterBody3D
	var friendly_dummy := scene.get_node("Characters/FriendlyTargetDummy1") as CharacterBody3D
	var skills := player.get_node("SkillController")
	skills.set("automatic_demo", false)
	var jolly_audio := skills.get_node("JollyRogerAudio") as AudioStreamPlayer3D
	var ocean_audio := skills.get_node("OceanStormAudio") as AudioStreamPlayer3D
	var anchor_audio := skills.get_node("AnchorAudio") as AudioStreamPlayer3D
	var ghostship_audio := skills.get_node("GhostshipAudio") as AudioStreamPlayer3D
	var audio_ok := jolly_audio.stream != null and jolly_audio.stream.resource_path.ends_with("w_cast.ogg")
	audio_ok = audio_ok and ocean_audio.stream != null and ocean_audio.stream.resource_path.ends_with("e_cast.ogg")
	audio_ok = audio_ok and anchor_audio.stream != null and anchor_audio.stream.resource_path.ends_with("r_cast.ogg")
	audio_ok = audio_ok and ghostship_audio.stream != null
	audio_ok = audio_ok and is_equal_approx(ghostship_audio.volume_db, 5.0)
	audio_ok = audio_ok and ghostship_audio.max_distance >= 44.0
	audio_ok = audio_ok and CombatAudio.resolve_surface_audio(&"garen_basic_hit_wood", &"flesh", false) == &"garen_basic_hit_flesh"
	audio_ok = audio_ok and CombatAudio.resolve_surface_audio(&"garen_basic_hit_wood", &"wood", true) == &"garen_crit_hit_wood"
	var q_audio_player := skills.call("play_audio_cue", &"garen_q_cast", player.global_position, 1.0) as AudioStreamPlayer3D
	audio_ok = audio_ok and q_audio_player != null and q_audio_player.stream.resource_path.ends_with("q_cast.ogg")
	audio_ok = audio_ok and not (skills.get("audio_cue_play_counts") as Dictionary).has(&"garen_passive_recovery_activate")
	if q_audio_player != null:
		q_audio_player.stop()
		q_audio_player.queue_free()

	skills.set("breaker_timer", 4.5)
	var breaker_ok := is_equal_approx(float(skills.call("get_move_speed_multiplier")), 1.35)
	breaker_ok = breaker_ok and StringName(skills.call("get_run_animation")) == &"run_spell"
	breaker_ok = breaker_ok and int(skills.call("get_skill_rank", 1)) == 1
	breaker_ok = breaker_ok and is_equal_approx(float(skills.get("breaker_duration")), 1.4)
	breaker_ok = breaker_ok and is_equal_approx(float(skills.get("breaker_damage")), 30.0)
	breaker_ok = breaker_ok and is_equal_approx(float(skills.get("breaker_damage_coefficient")), 0.5)
	breaker_ok = breaker_ok and is_equal_approx(float(skills.get("breaker_cooldown")), 8.0)
	dummy.set("armor", 0.0)
	dummy.set("critical_chance", 0.0)
	dummy.set("current_health", 1000.0)
	dummy.set("skill_damage_count", 0)
	skills.set("breaker_empowered_attack", true)
	skills.call("resolve_breaker_attack", dummy)
	var q_expected_damage := 69.0 + 30.0 + 69.0 * 0.5
	breaker_ok = breaker_ok and is_equal_approx(1000.0 - float(dummy.get("current_health")), q_expected_damage)
	breaker_ok = breaker_ok and int(dummy.get("skill_damage_count")) == 1
	breaker_ok = breaker_ok and float(dummy.get("silence_timer")) >= 1.5
	player.set("current_attack_is_breaker", true)
	breaker_ok = breaker_ok and is_equal_approx(float(player.call("get_current_attack_hit_range")), 2.5)
	breaker_ok = breaker_ok and is_equal_approx(float(player.call("_breaker_lunge_range")), 2.4)
	player.set("current_attack_is_breaker", false)
	breaker_ok = breaker_ok and is_equal_approx(float(player.call("get_current_attack_hit_range")), 1.95)
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
	var passive_ok := is_zero_approx(float(skills.call("get_courage_resistance_bonus")))
	passive_ok = passive_ok and is_equal_approx(float(skills.call("get_perseverance_regen_ratio_per_5", 1)), 0.015)
	passive_ok = passive_ok and is_equal_approx(float(skills.call("get_perseverance_regen_ratio_per_5", 6)), 0.025)
	passive_ok = passive_ok and is_equal_approx(float(skills.call("get_perseverance_regen_ratio_per_5", 13)), 0.081)
	passive_ok = passive_ok and is_equal_approx(float(skills.call("get_perseverance_regen_ratio_per_5", 30)), 0.149)
	skills.set("current_level", 1)
	skills.set("max_health", 1000.0)
	skills.set("current_health", 500.0)
	skills.set("passive_damage_lockout_remaining", 0.0)
	skills.set("passive_recovery_active", false)
	var passive_activation_count := int(skills.get("passive_recovery_activation_count"))
	skills.call("_update_perseverance", 5.0)
	passive_ok = passive_ok and is_equal_approx(float(skills.get("current_health")), 515.0)
	passive_ok = passive_ok and int(skills.get("passive_recovery_activation_count")) == passive_activation_count + 1
	var passive_front := skills.get_node("PerseveranceFront") as AnimatedSprite3D
	var passive_hip := skills.get_node("PerseveranceHip") as AnimatedSprite3D
	skills.set("current_health", float(skills.get("max_health")))
	skills.set("passive_damage_lockout_remaining", 0.0)
	skills.call("_update_perseverance", 0.0)
	skills.call("_update_perseverance_vfx", 0.3)
	passive_ok = passive_ok and passive_front.visible and passive_hip.visible
	passive_ok = passive_ok and is_equal_approx(passive_front.modulate.a, 0.3529412) and is_equal_approx(passive_hip.modulate.a, 0.27450982)
	skills.set("current_health", 500.0)
	skills.call("_update_perseverance_vfx", 0.3)
	passive_ok = passive_ok and passive_front.visible and passive_hip.visible
	passive_ok = passive_ok and passive_front.no_depth_test and passive_hip.no_depth_test
	passive_ok = passive_ok and is_equal_approx(passive_front.pixel_size, 0.015) and is_equal_approx(passive_hip.pixel_size, 0.015)
	passive_ok = passive_ok and passive_front.position.is_equal_approx(Vector3(0.12230945, -0.09625608, 0.08000004))
	passive_ok = passive_ok and passive_hip.position.is_equal_approx(Vector3(0.07588625, 0.45039487, 0.120000005))
	passive_ok = passive_ok and passive_front.animation == &"hip" and passive_hip.animation == &"slow1"
	passive_ok = passive_ok and is_equal_approx(passive_front.speed_scale, 0.5) and is_equal_approx(passive_hip.speed_scale, 0.5)
	passive_ok = passive_ok and is_equal_approx(passive_front.modulate.a, 0.3529412) and is_equal_approx(passive_hip.modulate.a, 0.27450982)
	passive_ok = passive_ok and passive_front.is_playing() and passive_hip.is_playing()
	var passive_motes := skills.get_node("PerseveranceMotes") as GPUParticles3D
	passive_ok = passive_ok and passive_motes != null and passive_motes.emitting and passive_motes.amount == 14
	skills.call("receive_incoming_damage", 10.0)
	passive_ok = passive_ok and is_equal_approx(float(skills.get("passive_damage_lockout_remaining")), 8.0)
	var locked_health := float(skills.get("current_health"))
	skills.call("_update_perseverance", 8.0)
	passive_ok = passive_ok and is_equal_approx(float(skills.get("current_health")), locked_health)
	skills.call("_update_perseverance_vfx", 0.5)
	passive_ok = passive_ok and not passive_front.visible and not passive_hip.visible
	passive_ok = passive_ok and not passive_motes.emitting

	skills.set("current_health", 1000.0)
	skills.set("rum_timer", 0.0)
	skills.set("black_sail_timer", 1.0)
	skills.set("normal_shield", 0.0)
	skills.call("receive_incoming_damage", 100.0)
	var expected_w_damage := CombatMath.resolve_damage(100.0, &"physical", 38.0, 32.0, CombatData.database()) * 0.75
	var reduction_ok := is_equal_approx(float(skills.get("current_health")), 1000.0 - expected_w_damage)

	skills.set("current_health", 1000.0)
	skills.set("black_sail_timer", 0.0)
	skills.set("breaker_timer", 0.0)
	skills.set("rum_timer", 10.0)
	skills.set("delayed_damage_pool", 0.0)
	skills.set("rum_settlement_pending", false)
	skills.call("receive_incoming_damage", 100.0)
	var expected_rum_damage := CombatMath.resolve_damage(100.0, &"physical", 38.0, 32.0, CombatData.database())
	var rum_ok := is_equal_approx(float(skills.get("current_health")), 1000.0 - expected_rum_damage * 0.5)
	rum_ok = rum_ok and is_equal_approx(float(skills.get("delayed_damage_pool")), expected_rum_damage * 0.5)
	rum_ok = rum_ok and bool(skills.get("rum_settlement_pending"))
	skills.call("apply_seven_seas_rum", 5.0, 0.20)
	rum_ok = rum_ok and is_equal_approx(float(skills.get("rum_timer")), 10.0)
	rum_ok = rum_ok and is_equal_approx(float(skills.call("get_move_speed_multiplier")), 1.20)
	skills.call("activate_black_sail_defenses")
	var cleanse_ok := is_equal_approx(float(skills.get("delayed_damage_pool")), expected_rum_damage * 0.5 * 0.70)
	cleanse_ok = cleanse_ok and is_equal_approx(float(skills.call("get_normal_shield")), 65.0)
	cleanse_ok = cleanse_ok and is_equal_approx(float(skills.call("get_control_duration_multiplier")), 0.40)
	skills.call("_update_timers", 0.75)
	cleanse_ok = cleanse_ok and is_zero_approx(float(skills.call("get_normal_shield")))
	cleanse_ok = cleanse_ok and is_equal_approx(float(skills.call("get_control_duration_multiplier")), 1.0)
	skills.set("courage_stacks", 30)
	cleanse_ok = cleanse_ok and is_equal_approx(float(skills.call("get_courage_resistance_bonus")), 30.0)
	cleanse_ok = cleanse_ok and is_equal_approx(float(skills.call("get_effective_armor")), 68.0)
	skills.set("is_casting", true)
	skills.set("current_skill", 3)
	skills.set("cooldowns", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var w_during_e_ok := bool(skills.call("begin_skill", 2, dummy))
	w_during_e_ok = w_during_e_ok and bool(skills.get("is_casting")) and int(skills.get("current_skill")) == 3
	cleanse_ok = cleanse_ok and w_during_e_ok
	skills.set("is_casting", false)
	skills.set("current_skill", 0)

	skills.set("current_health", 5.0)
	skills.set("rum_timer", 0.1)
	skills.set("delayed_damage_pool", 1000.0)
	skills.set("rum_settlement_pending", true)
	skills.call("_update_timers", 0.1)
	var nonlethal_ok := is_equal_approx(float(skills.get("current_health")), 1.0)
	var judgment_ok := is_equal_approx(float(skills.call("calculate_judgment_damage", 1000.0, 0.5)), 250.0)
	dummy.set("current_health", 1000.0)
	dummy.set("armor", 100.0)
	dummy.set("magic_resistance", 100.0)
	dummy.call("apply_normal_shield", 100.0)
	dummy.call("receive_skill_damage", 250.0, "暴君审判", false, player.global_position, &"true", &"judgment_hit")
	judgment_ok = judgment_ok and is_equal_approx(float(dummy.get("current_health")), 850.0)
	judgment_ok = judgment_ok and is_zero_approx(float(dummy.call("get_normal_shield")))

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
	var ghostship_blue_burst := skills.get("ghostship_blue_burst") as CPUParticles3D
	var ghostship_white_burst := skills.get("ghostship_white_burst") as CPUParticles3D
	impact_shockwave_ok = impact_shockwave_ok and ghostship_blue_burst != null and ghostship_blue_burst.emitting
	impact_shockwave_ok = impact_shockwave_ok and ghostship_white_burst != null and ghostship_white_burst.emitting
	impact_shockwave_ok = impact_shockwave_ok and int(skills.get("ghostship_impact_burst_count")) > 0
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
	var seven_seas_layer_count_before := int((skills.get("audio_cue_play_counts") as Dictionary).get(&"garen_r_buff_activate", 0))
	await skills.call("_cast_seven_seas")
	var ghost_area_ok := ghost.global_position.is_equal_approx(ghost_area_center)
	ghost_area_ok = ghost_area_ok and is_equal_approx(float(skills.get("ghostship_last_scheduled_impact_time")), 1.35)
	ghost_area_ok = ghost_area_ok and is_equal_approx(float(skills.get("ghostship_last_scheduled_buff_audio_delay")), 0.15)
	ghost_area_ok = ghost_area_ok and int((skills.get("audio_cue_play_counts") as Dictionary).get(&"garen_r_buff_activate", 0)) == seven_seas_layer_count_before + 1

	var ocean := skills.get_node("OceanStorm") as AnimatedSprite3D
	skills.set("is_casting", true)
	skills.set("current_skill", 3)
	var moving_storm_ok := bool(skills.call("allows_movement_while_casting"))
	moving_storm_ok = moving_storm_ok and bool(skills.call("has_super_armor"))
	moving_storm_ok = moving_storm_ok and bool(skills.call("preserves_character_animation"))
	moving_storm_ok = moving_storm_ok and is_equal_approx(float(skills.get("ocean_storm_radius")), 3.8)
	moving_storm_ok = moving_storm_ok and not bool(player.call("try_interrupt"))
	moving_storm_ok = moving_storm_ok and not bool(player.call("receive_knockback", Vector3.RIGHT, 4.0))
	var super_armor_outline := skills.get_node("SuperArmorOutline") as Node3D
	var super_armor_sprite := super_armor_outline.get_node("OutlineGlow") as Sprite3D
	character_frames.animation = &"spell3"
	character_frames.frame = mini(1, character_frames.sprite_frames.get_frame_count(&"spell3") - 1)
	# Losing the current victim may switch the logical state to CHASE, but E
	# retains the spell3 animation and repairs any external locomotion override.
	dummy.set("is_dead", true)
	player.set("target", dummy)
	skills.call("set_target", dummy)
	player.call("_refresh_target")
	moving_storm_ok = moving_storm_ok and player.get("target") != dummy
	moving_storm_ok = moving_storm_ok and character_frames.animation == &"spell3"
	character_frames.play(&"run")
	skills.set("ocean_storm_loop_active", true)
	skills.call("_update_ocean_storm_animation_loop", 0.05)
	moving_storm_ok = moving_storm_ok and character_frames.animation == &"spell3"
	dummy.set("is_dead", false)
	player.set("target", dummy)
	skills.call("set_target", dummy)
	super_armor_outline.call("set_active", true)
	super_armor_outline.call("_process", 0.0)
	var super_armor_visual_ok := super_armor_sprite.visible
	super_armor_visual_ok = super_armor_visual_ok and super_armor_sprite.texture == character_frames.sprite_frames.get_frame_texture(&"spell3", character_frames.frame)
	var super_armor_material := super_armor_sprite.material_override as ShaderMaterial
	var super_armor_red: Variant = super_armor_material.get_shader_parameter(&"outline_red") if super_armor_material != null else null
	var super_armor_gold: Variant = super_armor_material.get_shader_parameter(&"outline_gold") if super_armor_material != null else null
	super_armor_visual_ok = super_armor_visual_ok and super_armor_red is Color and super_armor_gold is Color
	super_armor_visual_ok = super_armor_visual_ok and (super_armor_red as Color).r > 0.95 and (super_armor_gold as Color).g > 0.65
	skills.set("current_skill", 4)
	skills.set("ocean_storm_loop_active", false)
	moving_storm_ok = moving_storm_ok and not bool(skills.call("allows_movement_while_casting"))
	moving_storm_ok = moving_storm_ok and not bool(skills.call("has_super_armor"))
	moving_storm_ok = moving_storm_ok and not bool(skills.call("preserves_character_animation"))
	super_armor_outline.call("set_active", false)
	super_armor_visual_ok = super_armor_visual_ok and not super_armor_sprite.visible
	skills.set("is_casting", false)
	var layering_ok := ocean.scale.is_equal_approx(Vector3.ONE * 1.4)
	layering_ok = layering_ok and ocean.render_priority > 0 and anchor.render_priority > 0
	layering_ok = layering_ok and anchor.no_depth_test
	layering_ok = layering_ok and (skills.get_node("JollyRoger") as AnimatedSprite3D).render_priority < 0
	layering_ok = layering_ok and (skills.get_node("JollyRoger") as AnimatedSprite3D).no_depth_test
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

	print("SKILL_RULES breaker=%s afterimage=%s super_armor_visual=%s impact_shockwave=%s passive=%s reduction=%s rum=%s cleanse=%s nonlethal=%s judgment=%s jolly=%s anchor=%s ghost=%s vfx_anchor=%s ghost_area=%s aoe=%s moving_storm=%s layering=%s filter=%s shader=%s canvas_fade=%s inward_edge=%s ground_occlusion=%s audio=%s" % [
		breaker_ok, afterimage_ok, super_armor_visual_ok, impact_shockwave_ok, passive_ok, reduction_ok, rum_ok, cleanse_ok, nonlethal_ok, judgment_ok,
		jolly_duration_ok, anchor_follow_ok, ghost_flip_ok, vfx_anchor_ok, ghost_area_ok, aoe_ok,
		moving_storm_ok, layering_ok, filter_clip_ok, shader_ok, canvas_fade_ok, inward_edge_ok, ground_occlusion_ok, audio_ok,
	])
	var passed := breaker_ok and afterimage_ok and super_armor_visual_ok and impact_shockwave_ok and passive_ok and reduction_ok and rum_ok
	passed = passed and cleanse_ok and nonlethal_ok and judgment_ok
	passed = passed and jolly_duration_ok and anchor_follow_ok and ghost_flip_ok
	passed = passed and vfx_anchor_ok and ghost_area_ok and aoe_ok
	passed = passed and moving_storm_ok and layering_ok and filter_clip_ok and shader_ok and canvas_fade_ok
	passed = passed and inward_edge_ok
	passed = passed and ground_occlusion_ok
	passed = passed and audio_ok
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
