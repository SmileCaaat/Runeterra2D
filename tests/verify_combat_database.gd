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

	var counts_ok := database.rules.size() == 66 and database.stats.size() == 48
	counts_ok = counts_ok and database.units.size() == 3 and database.unit_stats.size() == 109
	counts_ok = counts_ok and database.skills.size() == 5
	counts_ok = counts_ok and database.skill_effects.size() == 11 and database.buffs.size() == 5
	counts_ok = counts_ok and database.buff_modifiers.size() == 6 and database.ai_profiles.size() == 4
	counts_ok = counts_ok and database.hit_profiles.size() == 5 and database.animation_events.size() == 13
	counts_ok = counts_ok and database.asset_profiles.size() == 11 and database.particle_profiles.size() == 4

	var armor_ok := is_equal_approx(CombatMath.resolve_resistance(100.0, 100.0, 100.0), 50.0)
	armor_ok = armor_ok and is_equal_approx(CombatMath.resolve_resistance(100.0, -100.0, 100.0), 150.0)
	var haste_ok := is_equal_approx(CombatMath.cooldown_with_haste(10.0, 100.0, database), 5.0)
	var tenacity_ok := is_equal_approx(CombatMath.control_duration(2.0, 0.25, database), 1.5)

	var garen := database.get_unit(&"garen")
	var identity_ok := garen != null and garen.role == &"juggernaut"
	identity_ok = identity_ok and garen.resource_type == &"none" and garen.range_type == &"melee"
	identity_ok = identity_ok and database.schema_version == 3

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
	growth_ok = growth_ok and is_equal_approx(database.get_unit_stat_value(&"garen", &"max_health", 99), 2356.0)
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
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.max_health, 1000.0)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.attack_speed, 0.66)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.attack_range, 1.75)
	world_units_ok = world_units_ok and is_equal_approx(target_dummy.move_speed, 3.70)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"training_dummy", &"gameplay_radius", 1), 0.65)
	world_units_ok = world_units_ok and is_equal_approx(database.get_unit_stat_value(&"training_dummy", &"pathing_radius", 1), 0.30)
	world_units_ok = world_units_ok and target_dummy.ai_profile_id == &"dummy_passive"
	var scuttle := database.get_unit(&"scuttle_crab")
	world_units_ok = world_units_ok and scuttle != null and scuttle.role == &"neutral"
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

	var ocean := database.get_skill(&"garen_ocean_storm")
	var seven := database.get_skill(&"garen_seven_seas")
	var semantic_ok := garen != null and garen.skill_ids.size() == 5
	semantic_ok = semantic_ok and ocean != null and ocean.target_type == "self_area"
	semantic_ok = semantic_ok and ocean.movement_policy == "allowed" and is_equal_approx(ocean.tick_interval, 0.5)
	semantic_ok = semantic_ok and seven != null and seven.target_type == "ground_area" and seven.snapshot_target_position

	var black_sail := database.get_buff(&"black_sail")
	var jolly := database.get_asset_profile(&"jolly_roger")
	var lifecycle_ok := black_sail != null and jolly != null
	lifecycle_ok = lifecycle_ok and black_sail.vfx_profile_id == jolly.id and jolly.lifecycle == "buff"
	lifecycle_ok = lifecycle_ok and is_equal_approx(black_sail.duration, jolly.duration)

	var basic_hit := database.get_hit_profile(&"basic_melee")
	var attack_event := database.get_animation_event(&"garen", &"attack1", "hit")
	var action_ok := basic_hit != null and attack_event != null
	action_ok = action_ok and attack_event.payload_id == basic_hit.id
	action_ok = action_ok and is_equal_approx(basic_hit.hitstun, 0.24)
	action_ok = action_ok and basic_hit.depth_tolerance > 0.0 and basic_hit.knockback_speed > 0.0

	print("COMBAT_DATABASE build=%s generated=%s plugin=%s counts=%s identity=%s base=%s source=%s growth=%s world_units=%s timing=%s armor=%s haste=%s tenacity=%s semantic=%s lifecycle=%s action=%s digest=%s" % [
		build_ok, generated_ok, editor_plugin_ok, counts_ok, identity_ok, base_stats_ok, source_ok, growth_ok, world_units_ok, timing_ok,
		armor_ok, haste_ok, tenacity_ok, semantic_ok, lifecycle_ok, action_ok,
		database.source_digest.left(12),
	])
	var passed: bool = build_ok and generated_ok and editor_plugin_ok and counts_ok and armor_ok and haste_ok and tenacity_ok
	passed = passed and identity_ok and base_stats_ok and source_ok and growth_ok and world_units_ok and timing_ok
	passed = passed and semantic_ok and lifecycle_ok and action_ok
	if not passed:
		push_error("Combat database verification failed")
	quit(0 if passed else 2)
