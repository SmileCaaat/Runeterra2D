extends SceneTree

const BuilderScript = preload("res://scripts/data/combat_data_builder.gd")


func _initialize() -> void:
	var build_result: Dictionary = BuilderScript.new().build("res://data/source", "user://combat_database_test.tres")
	var database := build_result.database as CombatDatabase
	var build_ok: bool = bool(build_result.success) and database != null and build_result.errors.is_empty()
	if not build_ok:
		for error: String in build_result.errors:
			push_error(error)
		quit(2)
		return
	var generated_database := load("res://data/generated/combat_database.tres") as CombatDatabase
	var generated_ok := generated_database != null and generated_database.source_digest == database.source_digest
	var editor_plugin_ok := load("res://addons/combat_data/editor_plugin.gd") != null

	var counts_ok := database.rules.size() == 177 and database.stats.size() == 62
	counts_ok = counts_ok and database.hero_classes.size() == 7 and database.hero_subclasses.size() == 13 and database.ai_archetypes.size() == 13
	counts_ok = counts_ok and database.units.size() == 4 and database.unit_stats.size() == 145
	counts_ok = counts_ok and database.skills.size() == 12
	counts_ok = counts_ok and database.skill_effects.size() == 25 and database.skill_ranks.size() == 44
	counts_ok = counts_ok and database.skill_effect_ranks.size() == 53 and database.unit_mode_modifiers.is_empty() and database.buffs.size() == 11
	counts_ok = counts_ok and database.buff_modifiers.size() == 8 and database.ai_profiles.size() == 5
	counts_ok = counts_ok and database.hit_profiles.size() == 10 and database.animation_events.size() == 24
	counts_ok = counts_ok and database.asset_profiles.size() == 67 and database.particle_profiles.size() == 9
	counts_ok = counts_ok and database.awakening_cutin_profiles.size() == 2

	var armor_ok := is_equal_approx(CombatMath.resolve_resistance(100.0, 100.0, 100.0), 50.0)
	armor_ok = armor_ok and is_equal_approx(CombatMath.resolve_resistance(100.0, -100.0, 100.0), 150.0)
	armor_ok = armor_ok and is_equal_approx(CombatMath.resolve_damage(250.0, &"true", 100.0, 100.0, database), 250.0)
	var haste_ok := is_equal_approx(CombatMath.cooldown_with_haste(10.0, 100.0, database), 5.0)
	var tenacity_ok := is_equal_approx(CombatMath.control_duration(2.0, 0.25, database), 1.5)

	var garen := database.get_unit(&"garen")
	var identity_ok := garen != null and garen.role == &"juggernaut"
	identity_ok = identity_ok and garen.resource_type == &"none" and garen.range_type == &"melee"
	identity_ok = identity_ok and garen.class_id == &"fighter" and garen.subclass_id == &"juggernaut"
	identity_ok = identity_ok and database.get_hero_class(&"fighter") != null and database.get_hero_subclass(&"juggernaut") != null
	identity_ok = identity_ok and database.get_ai_archetype(&"juggernaut_pressure") != null
	identity_ok = identity_ok and database.get_ai_profile(&"garen_demo").archetype_id == &"juggernaut_pressure"
	identity_ok = identity_ok and database.schema_version == 20
	identity_ok = identity_ok and database.get_rule(&"progression.level_cap", 0) == 30

	var base_stats_ok := garen != null and is_equal_approx(garen.max_health, 690.0)
	base_stats_ok = base_stats_ok and is_equal_approx(garen.attack_damage, 69.0)
	base_stats_ok = base_stats_ok and is_equal_approx(garen.attack_speed, 0.625)
	base_stats_ok = base_stats_ok and is_equal_approx(garen.armor, 38.0)
	base_stats_ok = base_stats_ok and is_equal_approx(garen.magic_resistance, 32.0)
	base_stats_ok = base_stats_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"health_regen_per_5", 1), 8.0)
	base_stats_ok = base_stats_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"critical_damage", 1), 2.0)

	var garen_health := database.get_unit_stat(&"garen", &"max_health")
	var garen_speed := database.get_unit_stat(&"garen", &"move_speed")
	var source_ok := garen_health != null and garen_speed != null
	source_ok = source_ok and is_equal_approx(garen_health.source_base_value, 690.0)
	source_ok = source_ok and is_equal_approx(garen_health.source_growth_value, 98.0)
	source_ok = source_ok and garen_health.source_key == "hp_base|hp_lvl"
	source_ok = source_ok and is_equal_approx(garen_speed.source_base_value, 340.0)
	source_ok = source_ok and is_equal_approx(garen_speed.conversion_scale, 0.01)

	var growth_ok := is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 1), 690.0)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 2), 760.56)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 18), 2356.0)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 30), 4128.82)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 99), 4128.82)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"attack_damage", 18), 145.5)
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"attack_speed", 18), 1.0128125)

	var world_units_ok := garen != null and is_equal_approx(garen.move_speed, 3.4)
	world_units_ok = world_units_ok and is_equal_approx(garen.attack_range, 1.75)
	world_units_ok = world_units_ok and is_equal_approx(garen.collision_radius, 0.35)
	world_units_ok = world_units_ok and is_equal_approx(garen.selection_radius, 1.2)
	world_units_ok = world_units_ok and is_equal_approx(garen.selection_height, 1.888889)
	world_units_ok = world_units_ok and is_equal_approx(garen.acquisition_radius, 6.0)
	var target_dummy := database.get_unit(&"training_dummy")
	world_units_ok = world_units_ok and target_dummy != null
	world_units_ok = world_units_ok and garen.instance_template_id == "hero" and target_dummy.instance_template_id == "monster"
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.max_health, 1000.0)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.attack_speed, 0.66)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.attack_range, 1.75)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.move_speed, 3.70)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"training_dummy", &"gameplay_radius", 1), 0.65)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"training_dummy", &"pathing_radius", 1), 0.30)
	world_units_ok = world_units_ok and target_dummy.ai_profile_id == &"dummy_passive"
	var scuttle := database.get_unit(&"scuttle_crab")
	world_units_ok = world_units_ok and scuttle != null and scuttle.role == &"neutral" and scuttle.instance_template_id == "monster"
	world_units_ok = world_units_ok and is_equal_approx(scuttle.max_health, 1007.5)
	world_units_ok = world_units_ok and is_equal_approx(scuttle.move_speed, 2.55)
	world_units_ok = world_units_ok and is_equal_approx(scuttle.armor, 42.0)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"scuttle_crab", &"pathing_radius", 1), 1.0)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"scuttle_crab", &"max_health", 18), 3425.5)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"scuttle_crab", &"normal_max_health", 18), 5270.0)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"scuttle_crab", &"out_of_combat_move_speed", 1), 1.55)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"scuttle_crab", &"dash_move_speed", 1), 7.5)

	var timing_ok := garen != null and is_equal_approx(garen.attack_windup, 0.18)
	timing_ok = timing_ok and is_equal_approx(garen.attack_windup_modifier, 0.5)
	timing_ok = timing_ok and is_equal_approx(garen.attack_delay_offset, -0.12)
	timing_ok = timing_ok and is_zero_approx(garen.missile_speed)
	timing_ok = timing_ok and is_equal_approx(garen.critical_damage_base, 2.0)
	timing_ok = timing_ok and is_zero_approx(garen.critical_damage_modifier)
	var rank_schema_ok := database.get_skill_rank(&"garen_breaker", 1) != null
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_breaker", 1).duration, 1.4)
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_breaker", 5).duration, 3.6)
	var breaker_damage_rank := database.get_skill_effect_rank(&"breaker_damage", 5)
	rank_schema_ok = rank_schema_ok and breaker_damage_rank != null
	rank_schema_ok = rank_schema_ok and is_equal_approx(breaker_damage_rank.base_value, 150.0) and is_equal_approx(breaker_damage_rank.scaling_coefficient, 0.5)
	rank_schema_ok = rank_schema_ok and database.get_skill(&"garen_breaker").source_slot == &"q"
	rank_schema_ok = rank_schema_ok and database.get_skill(&"garen_tyrant_judgment").max_rank == 3
	var r_icon := database.get_asset_profile(&"garen_demacian_justice_icon")
	rank_schema_ok = rank_schema_ok and database.get_skill(&"garen_tyrant_judgment").icon_profile_id == &"garen_demacian_justice_icon"
	rank_schema_ok = rank_schema_ok and r_icon != null and ResourceLoader.exists(r_icon.resource_file)
	var r_rank_three := database.get_skill_effect_rank(&"judgment_damage", 3)
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_tyrant_judgment", 1).cooldown, 45.0)
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_tyrant_judgment", 3).cooldown, 35.0)
	rank_schema_ok = rank_schema_ok and r_rank_three != null and is_equal_approx(r_rank_three.base_value, 275.0) and is_equal_approx(r_rank_three.target_missing_health_coefficient, 0.35)
	var seven_seas := database.get_skill(&"garen_seven_seas")
	var seven_rank_three := database.get_skill_effect_rank(&"seven_seas_damage", 3)
	var rum_rank_three := database.get_skill_effect_rank(&"seven_seas_rum", 3)
	rank_schema_ok = rank_schema_ok and seven_seas != null and seven_seas.source_slot == &"t" and seven_seas.max_rank == 3
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_seven_seas", 1).cooldown, 120.0)
	rank_schema_ok = rank_schema_ok and is_equal_approx(database.get_skill_rank(&"garen_seven_seas", 3).cooldown, 80.0)
	rank_schema_ok = rank_schema_ok and seven_rank_three != null and is_equal_approx(seven_rank_three.base_value, 600.0)
	rank_schema_ok = rank_schema_ok and rum_rank_three != null and is_equal_approx(rum_rank_three.base_value, 7.0) and is_equal_approx(rum_rank_three.scaling_coefficient, 0.30)
	var ghostship_icon := database.get_asset_profile(&"garen_ghostship_icon")
	var rum_icon := database.get_asset_profile(&"seven_seas_rum_icon")
	rank_schema_ok = rank_schema_ok and seven_seas.icon_profile_id == &"garen_ghostship_icon" and ghostship_icon != null and FileAccess.file_exists(ghostship_icon.resource_file)
	rank_schema_ok = rank_schema_ok and rum_icon != null and FileAccess.file_exists(rum_icon.resource_file)
	var perseverance := database.get_skill(&"garen_perseverance")
	var breaker_icon := database.get_asset_profile(&"garen_decisive_strike_icon")
	rank_schema_ok = rank_schema_ok and database.get_skill(&"garen_breaker").max_rank == 5
	rank_schema_ok = rank_schema_ok and database.get_skill(&"garen_breaker").icon_profile_id == &"garen_decisive_strike_icon"
	rank_schema_ok = rank_schema_ok and breaker_icon != null and ResourceLoader.exists(breaker_icon.resource_file)
	rank_schema_ok = rank_schema_ok and perseverance != null and perseverance.source_slot == &"p"
	rank_schema_ok = rank_schema_ok and perseverance.icon_profile_id == &"garen_perseverance_icon"
	var perseverance_icon := database.get_asset_profile(&"garen_perseverance_icon")
	rank_schema_ok = rank_schema_ok and perseverance_icon != null and ResourceLoader.exists(perseverance_icon.resource_file)
	var perseverance_front := database.get_asset_profile(&"garen_perseverance_front")
	var perseverance_hip := database.get_asset_profile(&"garen_perseverance_hip")
	rank_schema_ok = rank_schema_ok and perseverance_front != null and perseverance_hip != null
	rank_schema_ok = rank_schema_ok and database.get_asset_profile(&"garen_perseverance_back") == null
	rank_schema_ok = rank_schema_ok and is_equal_approx(perseverance_front.pixel_size, 0.015)
	rank_schema_ok = rank_schema_ok and is_equal_approx(perseverance_hip.pixel_size, 0.015)
	rank_schema_ok = rank_schema_ok and perseverance_front.animation_name == &"hip" and perseverance_hip.animation_name == &"slow1"
	rank_schema_ok = rank_schema_ok and perseverance_front.local_position.is_equal_approx(Vector3(0.12230945, -0.09625608, 0.08000004))
	rank_schema_ok = rank_schema_ok and perseverance_hip.local_position.is_equal_approx(Vector3(0.07588625, 0.45039487, 0.120000005))
	rank_schema_ok = rank_schema_ok and is_equal_approx(perseverance_front.opacity, 0.3529412) and is_equal_approx(perseverance_hip.opacity, 0.27450982)
	var perseverance_motes := database.get_particle_profile(&"garen_perseverance_motes")
	rank_schema_ok = rank_schema_ok and perseverance_motes != null and perseverance_motes.amount == 14 and is_equal_approx(perseverance_motes.lifetime, 2.6)
	rank_schema_ok = rank_schema_ok and is_equal_approx(float(database.get_rule(&"ryze.q.travel_stretch", 0.0)), 0.38)
	rank_schema_ok = rank_schema_ok and is_equal_approx(float(database.get_rule(&"ryze.q.launch_pulse", 0.0)), 1.15)
	rank_schema_ok = rank_schema_ok and is_equal_approx(float(database.get_rule(&"presentation.perseverance_vfx_frame_rate", 0.0)), 6.0)
	rank_schema_ok = rank_schema_ok and database.get_unit_mode_modifiers(&"garen", &"training").is_empty()
	var super_armor_profile := database.get_asset_profile(&"super_armor_outline_glow")
	rank_schema_ok = rank_schema_ok and super_armor_profile != null and is_equal_approx(super_armor_profile.opacity, 0.78)
	rank_schema_ok = rank_schema_ok and String(database.get_rule(&"presentation.super_armor_outline_red", "")) == "ff3020ff"
	rank_schema_ok = rank_schema_ok and String(database.get_rule(&"presentation.super_armor_outline_gold", "")) == "ffd45cff"
	rank_schema_ok = rank_schema_ok and is_equal_approx(float(database.get_rule(&"presentation.outline_alpha_threshold", 0.0)), 0.35)
	rank_schema_ok = rank_schema_ok and database.get_asset_profile(&"vfx_library_combo_ring") != null
	rank_schema_ok = rank_schema_ok and database.get_asset_profile(&"vfx_library_armor_shred_sparks") != null
	rank_schema_ok = rank_schema_ok and database.get_asset_profile(&"vfx_library_water_splash") != null
	var damage_digits := database.get_asset_profile(&"damage_numbers_brush_colored")
	var damage_miss := database.get_asset_profile(&"damage_numbers_brush_primary")
	rank_schema_ok = rank_schema_ok and damage_digits != null and damage_miss != null
	rank_schema_ok = rank_schema_ok and damage_digits.asset_type == "combat_text_font" and FileAccess.file_exists(damage_digits.resource_file)
	rank_schema_ok = rank_schema_ok and is_equal_approx(float(database.get_rule(&"presentation.damage_number_critical_scale", 0.0)), 1.42)

	var ocean := database.get_skill(&"garen_ocean_storm")
	var seven := seven_seas
	var semantic_ok := garen != null and garen.skill_ids.size() == 6
	semantic_ok = semantic_ok and ocean != null and ocean.target_type == "self_area"
	semantic_ok = semantic_ok and ocean.movement_policy == "allowed" and ocean.icon_profile_id == &"garen_judgment_icon"
	semantic_ok = semantic_ok and is_equal_approx(ocean.radius, 3.8)
	semantic_ok = semantic_ok and is_equal_approx(database.get_skill_rank(&"garen_ocean_storm", 1).radius, 3.8)
	semantic_ok = semantic_ok and is_equal_approx(database.get_skill_rank(&"garen_ocean_storm", 5).radius, 3.8)
	semantic_ok = semantic_ok and is_equal_approx(database.get_skill_rank(&"garen_ocean_storm", 1).cooldown, 9.0)
	semantic_ok = semantic_ok and is_equal_approx(database.get_skill_rank(&"garen_ocean_storm", 5).cooldown, 6.0)
	var ocean_rank_five := database.get_skill_effect_rank(&"ocean_damage", 5)
	semantic_ok = semantic_ok and ocean_rank_five != null and is_equal_approx(ocean_rank_five.base_value, 16.0) and is_equal_approx(ocean_rank_five.scaling_coefficient, 0.52)
	semantic_ok = semantic_ok and database.get_buff(&"judgment_armor_shred") != null
	semantic_ok = semantic_ok and database.get_asset_profile(&"judgment_armor_shred_icon") != null
	semantic_ok = semantic_ok and database.get_asset_profile(&"ryze_flux_icon") != null
	semantic_ok = semantic_ok and seven != null and seven.target_type == "ground_area" and seven.snapshot_target_position
	semantic_ok = semantic_ok and is_equal_approx(seven.travel_duration, 1.35)
	semantic_ok = semantic_ok and seven.identity_status == &"adapted"
	var seven_cutin := database.get_awakening_cutin_profile_for_skill(&"garen_seven_seas")
	semantic_ok = semantic_ok and seven_cutin != null and seven_cutin.id == &"garen_seven_seas_awaken"
	semantic_ok = semantic_ok and FileAccess.file_exists(seven_cutin.portrait_path) and FileAccess.file_exists(seven_cutin.audio_path)
	var seven_impact_effects := database.get_skill_effects(&"garen_seven_seas", "on_impact")
	semantic_ok = semantic_ok and seven_impact_effects.size() == 2
	for effect: SkillEffectDefinition in seven_impact_effects:
		semantic_ok = semantic_ok and is_equal_approx(effect.delay, 1.35)
	var rum_effects := database.get_skill_effects(&"garen_seven_seas", "on_path")
	semantic_ok = semantic_ok and rum_effects.size() == 1 and rum_effects[0].target_selector == &"allies_in_path"

	var black_sail := database.get_buff(&"black_sail")
	var black_sail_guard := database.get_buff(&"black_sail_guard")
	var courage := database.get_buff(&"courage_stacks")
	var jolly := database.get_asset_profile(&"jolly_roger")
	var courage_icon := database.get_asset_profile(&"garen_courage_icon")
	var black_sail_skill := database.get_skill(&"garen_black_sail")
	var lifecycle_ok := black_sail != null and black_sail_guard != null and courage != null and jolly != null
	lifecycle_ok = lifecycle_ok and black_sail.vfx_profile_id == jolly.id and jolly.lifecycle == "buff"
	lifecycle_ok = lifecycle_ok and is_equal_approx(black_sail.duration, jolly.duration)
	lifecycle_ok = lifecycle_ok and courage.max_stacks == 30 and is_equal_approx(float(database.get_rule(&"garen.courage.resistance_per_stack", 0.0)), 1.0)
	lifecycle_ok = lifecycle_ok and is_equal_approx(black_sail_guard.duration, 0.75)
	lifecycle_ok = lifecycle_ok and black_sail_skill.icon_profile_id == &"garen_courage_icon" and courage_icon != null and FileAccess.file_exists(courage_icon.resource_file)
	lifecycle_ok = lifecycle_ok and is_equal_approx(database.get_skill_rank(&"garen_black_sail", 1).cooldown, 22.0)
	lifecycle_ok = lifecycle_ok and is_equal_approx(database.get_skill_rank(&"garen_black_sail", 5).cooldown, 12.0)
	lifecycle_ok = lifecycle_ok and is_equal_approx(database.get_skill_effect_rank(&"black_sail_damage_reduction", 5).base_value, 0.41)
	lifecycle_ok = lifecycle_ok and is_equal_approx(database.get_skill_effect_rank(&"black_sail_shield", 1).base_value, 65.0)

	var basic_hit := database.get_hit_profile(&"basic_melee")
	var breaker_hit := database.get_hit_profile(&"breaker_hit")
	var attack_event := database.get_animation_event(&"garen", &"attack1", "hit")
	var action_ok := basic_hit != null and breaker_hit != null and attack_event != null
	action_ok = action_ok and attack_event.payload_id == basic_hit.id
	action_ok = action_ok and is_equal_approx(basic_hit.hitstun, 0.24)
	action_ok = action_ok and basic_hit.depth_tolerance > 0.0 and basic_hit.knockback_speed > 0.0
	action_ok = action_ok and is_equal_approx(breaker_hit.size.x, 2.5)
	var q_skill := database.get_skill(&"garen_breaker")
	var q_audio_layers := database.get_animation_events(&"garen", &"spell1", "audio")
	var audio_ok := q_skill != null and q_skill.audio_profile_id == &"garen_q_cast"
	audio_ok = audio_ok and q_audio_layers.size() == 2
	audio_ok = audio_ok and q_audio_layers[0].payload_id == &"garen_q_attack_cast_1"
	audio_ok = audio_ok and q_audio_layers[1].payload_id == &"garen_q_attack_cast_2"
	audio_ok = audio_ok and basic_hit.hit_audio_profile_id == &"garen_basic_hit_wood"
	audio_ok = audio_ok and database.get_hit_profile(&"ocean_hit").hit_audio_profile_id == &"garen_e_hit"
	audio_ok = audio_ok and database.get_hit_profile(&"judgment_hit").hit_audio_profile_id == &"garen_r_hit"
	audio_ok = audio_ok and database.get_hit_profile(&"ghostship_hit").hit_audio_profile_id == &"garen_basic_hit_wood"
	var passive_audio := database.get_asset_profile(&"garen_passive_recovery_activate")
	audio_ok = audio_ok and passive_audio != null and FileAccess.file_exists(passive_audio.audio_path)
	var ghostship_audio := database.get_asset_profile(&"ghostship_audio")
	audio_ok = audio_ok and ghostship_audio != null
	audio_ok = audio_ok and is_equal_approx(ghostship_audio.volume_db, 5.0)
	audio_ok = audio_ok and ghostship_audio.max_distance >= 44.0
	audio_ok = audio_ok and is_equal_approx(float(database.get_rule(&"presentation.seven_seas_buff_audio_delay", 0.0)), 0.15)

	print("COMBAT_DATABASE build=%s generated=%s plugin=%s counts=%s identity=%s base=%s source=%s growth=%s world_units=%s timing=%s ranks=%s armor=%s haste=%s tenacity=%s semantic=%s lifecycle=%s action=%s audio=%s digest=%s" % [
		build_ok, generated_ok, editor_plugin_ok, counts_ok, identity_ok, base_stats_ok, source_ok, growth_ok, world_units_ok, timing_ok,
		rank_schema_ok, armor_ok, haste_ok, tenacity_ok, semantic_ok, lifecycle_ok, action_ok, audio_ok,
		database.source_digest.left(12),
	])
	var passed: bool = build_ok and generated_ok and editor_plugin_ok and counts_ok and armor_ok and haste_ok and tenacity_ok
	passed = passed and identity_ok and base_stats_ok and source_ok and growth_ok and world_units_ok and timing_ok and rank_schema_ok
	passed = passed and semantic_ok and lifecycle_ok and action_ok and audio_ok
	if not passed:
		push_error("Combat database verification failed")
	quit(0 if passed else 2)
