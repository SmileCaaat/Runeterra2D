@tool
class_name CombatDataBuilder
extends RefCounted

const CombatDatabaseScript = preload("res://data/definitions/combat_database.gd")
const CombatRuleScript = preload("res://data/definitions/combat_rule_definition.gd")
const StatScript = preload("res://data/definitions/stat_definition.gd")
const UnitScript = preload("res://data/definitions/unit_definition.gd")
const UnitStatScript = preload("res://data/definitions/unit_stat_value_definition.gd")
const SkillScript = preload("res://data/definitions/skill_definition.gd")
const SkillEffectScript = preload("res://data/definitions/skill_effect_definition.gd")
const BuffScript = preload("res://data/definitions/buff_definition.gd")
const BuffModifierScript = preload("res://data/definitions/buff_modifier_definition.gd")
const HitProfileScript = preload("res://data/definitions/hit_profile_definition.gd")
const AnimationEventScript = preload("res://data/definitions/animation_event_definition.gd")
const AssetProfileScript = preload("res://data/definitions/asset_profile_definition.gd")
const ParticleProfileScript = preload("res://data/definitions/particle_profile_definition.gd")
const AIProfileScript = preload("res://data/definitions/ai_profile_definition.gd")

const TABLE_FILES := [
	"combat_rules.csv", "stats.csv", "units.csv", "unit_stats.csv", "skills.csv", "skill_effects.csv",
	"buffs.csv", "buff_modifiers.csv", "hit_profiles.csv", "animation_events.csv",
	"asset_manifest.csv", "particle_profiles.csv", "ai_profiles.csv",
]

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var _source_dir := ""
var _tables: Dictionary = {}


func build(source_dir := "res://data/source", output_path := "res://data/generated/combat_database.tres") -> Dictionary:
	errors.clear()
	warnings.clear()
	_tables.clear()
	_source_dir = source_dir
	for file_name: String in TABLE_FILES:
		_tables[file_name] = _read_csv(file_name)
	if not errors.is_empty():
		return _result(false, output_path)

	_validate_source()
	if not errors.is_empty():
		return _result(false, output_path)

	var database := CombatDatabaseScript.new() as CombatDatabase
	_populate_rules(database)
	_populate_stats(database)
	_populate_units(database)
	_populate_unit_stats(database)
	_compile_unit_runtime_values(database)
	_populate_skills(database)
	_populate_skill_effects(database)
	_populate_buffs(database)
	_populate_buff_modifiers(database)
	_populate_hit_profiles(database)
	_populate_animation_events(database)
	_populate_asset_profiles(database)
	_populate_particle_profiles(database)
	_populate_ai_profiles(database)
	database.schema_version = int(database.get_rule(&"schema.version", 1))
	database.generated_at_utc = Time.get_datetime_string_from_system(true, true)
	database.source_digest = _source_digest()
	database.rebuild_indexes()

	var absolute_dir := ProjectSettings.globalize_path(output_path.get_base_dir())
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_error != OK:
		errors.append("Cannot create output directory %s: error %d" % [output_path.get_base_dir(), make_error])
		return _result(false, output_path)
	var save_error := ResourceSaver.save(database, output_path)
	if save_error != OK:
		errors.append("Cannot save %s: error %d" % [output_path, save_error])
		return _result(false, output_path)
	return _result(true, output_path, database)


func _read_csv(file_name: String) -> Array[Dictionary]:
	var path := _source_dir.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: cannot open file" % path)
		return []
	var header := file.get_csv_line()
	if header.is_empty():
		errors.append("%s: missing header" % path)
		return []
	var rows: Array[Dictionary] = []
	var line_number := 1
	while not file.eof_reached():
		line_number += 1
		var values := file.get_csv_line()
		if values.size() == 1 and values[0].strip_edges().is_empty():
			continue
		if values.size() != header.size():
			errors.append("%s:%d expected %d columns but found %d" % [file_name, line_number, header.size(), values.size()])
			continue
		var row := {"__file": file_name, "__line": line_number}
		for column: int in header.size():
			row[String(header[column]).strip_edges()] = String(values[column]).strip_edges()
		rows.append(row)
	return rows


func _validate_source() -> void:
	_validate_unique("combat_rules.csv", "rule_id")
	_validate_unique("stats.csv", "stat_id")
	_validate_unique("units.csv", "unit_id")
	_validate_unique_pair("unit_stats.csv", "unit_id", "stat_id")
	_validate_unique("skills.csv", "skill_id")
	_validate_unique("skill_effects.csv", "effect_id")
	_validate_unique("buffs.csv", "buff_id")
	_validate_unique("buff_modifiers.csv", "modifier_id")
	_validate_unique("hit_profiles.csv", "profile_id")
	_validate_unique("animation_events.csv", "event_id")
	_validate_unique("asset_manifest.csv", "asset_id")
	_validate_unique("particle_profiles.csv", "profile_id")
	_validate_unique("ai_profiles.csv", "profile_id")

	var unit_ids := _id_set("units.csv", "unit_id")
	var skill_ids := _id_set("skills.csv", "skill_id")
	var buff_ids := _id_set("buffs.csv", "buff_id")
	var stat_ids := _id_set("stats.csv", "stat_id")
	var hit_ids := _id_set("hit_profiles.csv", "profile_id")
	var asset_ids := _id_set("asset_manifest.csv", "asset_id")
	var particle_ids := _id_set("particle_profiles.csv", "profile_id")
	var ai_ids := _id_set("ai_profiles.csv", "profile_id")

	for row: Dictionary in _tables["units.csv"]:
		_require_ref(row, "ai_profile_id", ai_ids, true)
		for skill_id: StringName in _names(row, "skill_ids"):
			if not skill_ids.has(skill_id):
				_error(row, "skill_ids references unknown skill '%s'" % skill_id)

	for row: Dictionary in _tables["unit_stats.csv"]:
		_require_ref(row, "unit_id", unit_ids)
		_require_ref(row, "stat_id", stat_ids)
		_validate_enum(row, "growth_formula", ["none", "primary", "attack_speed"])
		if _f(row, "conversion_scale") <= 0.0:
			_error(row, "conversion_scale must be > 0")
		if not _s(row, "source_key").is_empty():
			var scale := _f(row, "conversion_scale")
			if not is_equal_approx(_f(row, "base_value"), _f(row, "source_base_value") * scale):
				_error(row, "base_value must equal source_base_value * conversion_scale")
			if not is_equal_approx(_f(row, "growth_value"), _f(row, "source_growth_value") * scale):
				_error(row, "growth_value must equal source_growth_value * conversion_scale")

	for row: Dictionary in _tables["skills.csv"]:
		_require_ref(row, "owner_id", unit_ids)
		_require_ref(row, "vfx_profile_id", asset_ids, true)
		_require_ref(row, "audio_profile_id", asset_ids, true)
		_validate_enum(row, "target_type", ["self", "unit", "direction", "ground_area", "self_area"])
		_validate_enum(row, "cast_type", ["instant", "cast", "channel", "empower", "travel"])
		_validate_enum(row, "movement_policy", ["locked", "allowed", "slowed", "forced"])
		_require_nonnegative(row, "cooldown")
		_require_nonnegative(row, "duration")
		if _s(row, "cast_type") == "channel" and _f(row, "duration") <= 0.0:
			_error(row, "channel skill requires duration > 0")
		if _f(row, "tick_interval") > 0.0 and _f(row, "duration") > 0.0:
			var ticks := _f(row, "duration") / _f(row, "tick_interval")
			if not is_equal_approx(ticks, roundf(ticks)):
				_warning(row, "duration is not an integer multiple of tick_interval")

	for row: Dictionary in _tables["skill_effects.csv"]:
		_require_ref(row, "skill_id", skill_ids)
		_require_ref(row, "buff_id", buff_ids, true)
		_require_ref(row, "hit_profile_id", hit_ids, true)
		_require_ref(row, "scaling_stat", stat_ids, true)
		_validate_enum(row, "effect_type", ["damage", "apply_buff", "apply_control", "cleanse", "delayed_damage", "shield"])
		_validate_enum(row, "damage_type", ["physical", "magic", "true", "none"])
		if _s(row, "effect_type") == "damage" and _f(row, "base_value") < 0.0:
			_error(row, "damage base_value cannot be negative")

	for row: Dictionary in _tables["buffs.csv"]:
		_require_ref(row, "vfx_profile_id", asset_ids, true)
		_require_nonnegative(row, "duration")
		if _i(row, "max_stacks") < 1:
			_error(row, "max_stacks must be at least 1")

	for row: Dictionary in _tables["buff_modifiers.csv"]:
		_require_ref(row, "buff_id", buff_ids)
		_require_ref(row, "stat_id", stat_ids)
		_validate_enum(row, "operation", ["flat", "add_percent", "multiply", "override"])

	for row: Dictionary in _tables["hit_profiles.csv"]:
		_require_ref(row, "hit_vfx_profile_id", _merged_set([asset_ids, particle_ids]), true)
		_require_ref(row, "hit_audio_profile_id", asset_ids, true)
		var start := _f(row, "active_start_normalized")
		var end := _f(row, "active_end_normalized")
		if start < 0.0 or end > 1.0 or start > end:
			_error(row, "active normalized window must satisfy 0 <= start <= end <= 1")

	for row: Dictionary in _tables["animation_events.csv"]:
		_require_ref(row, "owner_id", unit_ids)
		match _s(row, "event_type"):
			"hit": _require_ref(row, "payload_id", hit_ids)
			"audio", "vfx": _require_ref(row, "payload_id", asset_ids)
		_validate_enum(row, "timing_mode", ["frame", "normalized", "seconds"])

	for row: Dictionary in _tables["asset_manifest.csv"]:
		for field: String in ["resource_path", "audio_path", "shader_material_path"]:
			var path := _s(row, field)
			if not path.is_empty() and not ResourceLoader.exists(path):
				_error(row, "%s does not exist: %s" % [field, path])

	_validate_animation_names()
	_validate_bound_lifecycles()


func _validate_animation_names() -> void:
	var owner_frame_libraries := {}
	for row: Dictionary in _tables["asset_manifest.csv"]:
		if _s(row, "asset_type") != "character_animation":
			continue
		var frames := load(_s(row, "resource_path")) as SpriteFrames
		if frames != null:
			owner_frame_libraries["garen"] = frames
	for row: Dictionary in _tables["skills.csv"]:
		var frames: SpriteFrames = owner_frame_libraries.get(_s(row, "owner_id"))
		for field: String in ["windup_animation_name", "animation_name", "movement_animation_name", "empowered_animation_name"]:
			var animation := _sn(row, field)
			if frames != null and not animation.is_empty() and not frames.has_animation(animation):
				_error(row, "%s references missing animation '%s'" % [field, animation])
	for row: Dictionary in _tables["animation_events.csv"]:
		var frames: SpriteFrames = owner_frame_libraries.get(_s(row, "owner_id"))
		if frames != null and not frames.has_animation(_sn(row, "animation_name")):
			_error(row, "animation_name references missing animation '%s'" % _s(row, "animation_name"))


func _validate_bound_lifecycles() -> void:
	var assets := _rows_by_id("asset_manifest.csv", "asset_id")
	for buff_row: Dictionary in _tables["buffs.csv"]:
		var asset_id := _s(buff_row, "vfx_profile_id")
		if asset_id.is_empty():
			continue
		var asset_row: Dictionary = assets.get(asset_id, {})
		if _s(asset_row, "lifecycle") != "buff":
			_error(buff_row, "bound VFX '%s' must use lifecycle=buff" % asset_id)
		if not is_equal_approx(_f(buff_row, "duration"), _f(asset_row, "duration")):
			_error(buff_row, "buff duration must match bound VFX duration for '%s'" % asset_id)


func _populate_rules(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["combat_rules.csv"]:
		var definition := CombatRuleScript.new() as CombatRuleDefinition
		definition.id = _sn(row, "rule_id")
		definition.category = _sn(row, "category")
		definition.value_type = _s(row, "value_type")
		match definition.value_type:
			"float": definition.float_value = _f(row, "value")
			"int": definition.int_value = _i(row, "value")
			"bool": definition.bool_value = _b(row, "value")
			_: definition.string_value = _s(row, "value")
		definition.description = _s(row, "description")
		database.rules.append(definition)


func _populate_stats(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["stats.csv"]:
		var definition := StatScript.new() as StatDefinition
		definition.id = _sn(row, "stat_id")
		definition.display_name = _s(row, "display_name")
		definition.category = _sn(row, "category")
		definition.unit = _s(row, "unit")
		definition.default_operation = _s(row, "default_operation")
		definition.minimum = _f(row, "minimum")
		definition.maximum = _f(row, "maximum")
		definition.description = _s(row, "description")
		database.stats.append(definition)


func _populate_units(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["units.csv"]:
		var definition := UnitScript.new() as UnitDefinition
		definition.id = _sn(row, "unit_id")
		definition.display_name = _s(row, "display_name")
		definition.unit_type = _s(row, "unit_type")
		definition.role = _sn(row, "role")
		definition.resource_type = _sn(row, "resource_type")
		definition.range_type = _sn(row, "range_type")
		definition.level = _i(row, "level")
		definition.ai_profile_id = _sn(row, "ai_profile_id")
		definition.skill_ids = _names(row, "skill_ids")
		database.units.append(definition)


func _populate_unit_stats(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["unit_stats.csv"]:
		var definition := UnitStatScript.new() as UnitStatValueDefinition
		definition.unit_id = _sn(row, "unit_id")
		definition.stat_id = _sn(row, "stat_id")
		definition.base_value = _f(row, "base_value")
		definition.growth_value = _f(row, "growth_value")
		definition.growth_formula = _s(row, "growth_formula")
		definition.source_base_value = _f(row, "source_base_value")
		definition.source_growth_value = _f(row, "source_growth_value")
		definition.conversion_scale = _f(row, "conversion_scale")
		definition.source_key = _s(row, "source_key")
		definition.notes = _s(row, "notes")
		database.unit_stats.append(definition)


func _compile_unit_runtime_values(database: CombatDatabase) -> void:
	database.rebuild_indexes()
	var direct_properties := {
		&"max_health": &"max_health", &"max_resource": &"max_resource",
		&"attack_damage": &"attack_damage", &"ability_power": &"ability_power",
		&"armor": &"armor", &"magic_resistance": &"magic_resistance",
		&"move_speed": &"move_speed", &"acceleration": &"acceleration",
		&"attack_range": &"attack_range", &"attack_speed": &"attack_speed",
		&"critical_chance": &"critical_chance", &"critical_damage": &"critical_damage",
		&"ability_haste": &"ability_haste", &"tenacity": &"tenacity",
		&"poise": &"poise", &"depth_radius": &"depth_radius",
		&"selection_radius": &"selection_radius", &"selection_height": &"selection_height",
		&"acquisition_radius": &"acquisition_radius", &"attack_windup": &"attack_windup",
		&"attack_windup_modifier": &"attack_windup_modifier", &"attack_delay_offset": &"attack_delay_offset",
	}
	for unit: UnitDefinition in database.units:
		for stat_id: StringName in direct_properties:
			var stat := database.get_unit_stat(unit.id, stat_id)
			if stat != null:
				unit.set(direct_properties[stat_id], database.get_unit_stat_value(unit.id, stat_id, unit.level))
		var pathing := database.get_unit_stat(unit.id, &"pathing_radius")
		if pathing != null:
			unit.collision_radius = pathing.base_value


func _populate_skills(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["skills.csv"]:
		var definition := SkillScript.new() as SkillDefinition
		definition.id = _sn(row, "skill_id")
		definition.owner_id = _sn(row, "owner_id")
		definition.slot = _i(row, "slot")
		definition.display_name = _s(row, "display_name")
		for field: String in ["target_type", "cast_type", "movement_policy", "facing_policy"]:
			definition.set(field, _s(row, field))
		for field: String in ["cooldown", "cast_time", "recovery_time", "cast_range", "radius", "duration", "tick_interval", "resource_cost", "travel_start_offset", "travel_duration"]:
			definition.set(field, _f(row, field))
		definition.snapshot_target_position = _b(row, "snapshot_target_position")
		definition.windup_animation_name = _sn(row, "windup_animation_name")
		definition.animation_name = _sn(row, "animation_name")
		definition.movement_animation_name = _sn(row, "movement_animation_name")
		definition.empowered_animation_name = _sn(row, "empowered_animation_name")
		definition.vfx_profile_id = _sn(row, "vfx_profile_id")
		definition.audio_profile_id = _sn(row, "audio_profile_id")
		definition.tags = _names(row, "tags")
		database.skills.append(definition)


func _populate_skill_effects(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["skill_effects.csv"]:
		var definition := SkillEffectScript.new() as SkillEffectDefinition
		definition.id = _sn(row, "effect_id")
		definition.skill_id = _sn(row, "skill_id")
		definition.order = _i(row, "order")
		for field: String in ["trigger", "effect_type", "target_selector", "damage_type"]:
			definition.set(field, _s(row, field))
		for field: String in ["base_value", "scaling_coefficient", "target_missing_health_coefficient", "delay", "interval", "control_duration"]:
			definition.set(field, _f(row, field))
		definition.scaling_stat = _sn(row, "scaling_stat")
		definition.can_crit = _b(row, "can_crit")
		definition.nonlethal = _b(row, "nonlethal")
		definition.buff_id = _sn(row, "buff_id")
		definition.control_type = _sn(row, "control_type")
		definition.hit_profile_id = _sn(row, "hit_profile_id")
		definition.tags = _names(row, "tags")
		database.skill_effects.append(definition)


func _populate_buffs(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["buffs.csv"]:
		var definition := BuffScript.new() as BuffDefinition
		definition.id = _sn(row, "buff_id")
		definition.display_name = _s(row, "display_name")
		definition.duration = _f(row, "duration")
		definition.max_stacks = _i(row, "max_stacks")
		definition.stacking_policy = _s(row, "stacking_policy")
		definition.refresh_policy = _s(row, "refresh_policy")
		definition.dispel_category = _s(row, "dispel_category")
		definition.visible = _b(row, "visible")
		definition.nonlethal = _b(row, "nonlethal")
		definition.vfx_profile_id = _sn(row, "vfx_profile_id")
		definition.tags = _names(row, "tags")
		database.buffs.append(definition)


func _populate_buff_modifiers(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["buff_modifiers.csv"]:
		var definition := BuffModifierScript.new() as BuffModifierDefinition
		definition.id = _sn(row, "modifier_id")
		definition.buff_id = _sn(row, "buff_id")
		definition.stat_id = _sn(row, "stat_id")
		definition.operation = _s(row, "operation")
		definition.value = _f(row, "value")
		definition.phase = _s(row, "phase")
		definition.priority = _i(row, "priority")
		database.buff_modifiers.append(definition)


func _populate_hit_profiles(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["hit_profiles.csv"]:
		var definition := HitProfileScript.new() as HitProfileDefinition
		definition.id = _sn(row, "profile_id")
		definition.shape = _s(row, "shape")
		definition.size = Vector3(_f(row, "size_x"), _f(row, "size_y"), _f(row, "size_z"))
		definition.offset = Vector3(_f(row, "offset_x"), _f(row, "offset_y"), _f(row, "offset_z"))
		for field: String in ["depth_tolerance", "active_start_normalized", "active_end_normalized", "hitstop", "hitstun", "poise_damage", "knockback_speed", "knockback_decay", "launch_velocity"]:
			definition.set(field, _f(row, field))
		definition.hit_vfx_profile_id = _sn(row, "hit_vfx_profile_id")
		definition.hit_audio_profile_id = _sn(row, "hit_audio_profile_id")
		database.hit_profiles.append(definition)


func _populate_animation_events(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["animation_events.csv"]:
		var definition := AnimationEventScript.new() as AnimationEventDefinition
		definition.id = _sn(row, "event_id")
		definition.owner_id = _sn(row, "owner_id")
		definition.animation_name = _sn(row, "animation_name")
		definition.event_type = _s(row, "event_type")
		definition.timing_mode = _s(row, "timing_mode")
		definition.timing_value = _f(row, "timing_value")
		definition.end_value = _f(row, "end_value")
		definition.payload_id = _sn(row, "payload_id")
		definition.vector_value = Vector3(_f(row, "vector_x"), _f(row, "vector_y"), _f(row, "vector_z"))
		definition.float_value = _f(row, "float_value")
		database.animation_events.append(definition)


func _populate_asset_profiles(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["asset_manifest.csv"]:
		var definition := AssetProfileScript.new() as AssetProfileDefinition
		definition.id = _sn(row, "asset_id")
		definition.asset_type = _s(row, "asset_type")
		definition.resource_file = _s(row, "resource_path")
		definition.node_path = _s(row, "node_path")
		definition.animation_name = _sn(row, "animation_name")
		definition.audio_path = _s(row, "audio_path")
		for field: String in ["volume_db", "pitch_min", "pitch_max", "max_distance", "pixel_size", "duration"]:
			definition.set(field, _f(row, field))
		definition.scale = Vector3(_f(row, "scale_x"), _f(row, "scale_y"), _f(row, "scale_z"))
		definition.offset = Vector2(_f(row, "offset_x"), _f(row, "offset_y"))
		definition.render_priority = _i(row, "render_priority")
		definition.no_depth_test = _b(row, "no_depth_test")
		definition.shader_material_path = _s(row, "shader_material_path")
		definition.lifecycle = _s(row, "lifecycle")
		definition.flip_with_facing = _b(row, "flip_with_facing")
		database.asset_profiles.append(definition)


func _populate_particle_profiles(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["particle_profiles.csv"]:
		var definition := ParticleProfileScript.new() as ParticleProfileDefinition
		definition.id = _sn(row, "profile_id")
		definition.amount = _i(row, "amount")
		for field: String in ["lifetime", "randomness", "spread", "velocity_min", "velocity_max", "angular_velocity_min", "angular_velocity_max", "scale_min", "scale_max", "emission_energy"]:
			definition.set(field, _f(row, field))
		definition.gravity = Vector3(_f(row, "gravity_x"), _f(row, "gravity_y"), _f(row, "gravity_z"))
		definition.mesh_size = Vector2(_f(row, "mesh_width"), _f(row, "mesh_height"))
		definition.emission_color = Color.html(_s(row, "emission_color"))
		definition.gradient_start = Color.html(_s(row, "gradient_start"))
		definition.gradient_mid = Color.html(_s(row, "gradient_mid"))
		definition.gradient_late = Color.html(_s(row, "gradient_late"))
		definition.gradient_end = Color.html(_s(row, "gradient_end"))
		database.particle_profiles.append(definition)


func _populate_ai_profiles(database: CombatDatabase) -> void:
	for row: Dictionary in _tables["ai_profiles.csv"]:
		var definition := AIProfileScript.new() as AIProfileDefinition
		definition.id = _sn(row, "profile_id")
		definition.behavior = _s(row, "behavior")
		for field: String in ["chase_stop_distance", "waypoint_tolerance", "wander_wait_min", "wander_wait_max", "demo_skill_gap"]:
			definition.set(field, _f(row, field))
		definition.arena_min = Vector2(_f(row, "arena_min_x"), _f(row, "arena_min_y"))
		definition.arena_max = Vector2(_f(row, "arena_max_x"), _f(row, "arena_max_y"))
		definition.skill_sequence = _names(row, "skill_sequence")
		definition.deterministic_seed = _i(row, "deterministic_seed")
		database.ai_profiles.append(definition)


func _validate_unique(table: String, id_field: String) -> void:
	var seen := {}
	for row: Dictionary in _tables.get(table, []):
		var id := _s(row, id_field)
		if id.is_empty():
			_error(row, "%s cannot be empty" % id_field)
		elif seen.has(id):
			_error(row, "duplicate %s '%s'" % [id_field, id])
		else:
			seen[id] = true


func _validate_unique_pair(table: String, first_field: String, second_field: String) -> void:
	var seen := {}
	for row: Dictionary in _tables.get(table, []):
		var key := "%s|%s" % [_s(row, first_field), _s(row, second_field)]
		if _s(row, first_field).is_empty() or _s(row, second_field).is_empty():
			_error(row, "%s and %s cannot be empty" % [first_field, second_field])
		elif seen.has(key):
			_error(row, "duplicate composite id '%s'" % key)
		else:
			seen[key] = true


func _validate_enum(row: Dictionary, field: String, allowed: Array) -> void:
	var value := _s(row, field)
	if not allowed.has(value):
		_error(row, "%s has invalid value '%s'" % [field, value])


func _require_ref(row: Dictionary, field: String, allowed: Dictionary, optional := false) -> void:
	var value := _sn(row, field)
	if value.is_empty() and optional:
		return
	if not allowed.has(value):
		_error(row, "%s references unknown id '%s'" % [field, value])


func _require_positive(row: Dictionary, field: String) -> void:
	if _f(row, field) <= 0.0:
		_error(row, "%s must be > 0" % field)


func _require_nonnegative(row: Dictionary, field: String) -> void:
	if _f(row, field) < 0.0:
		_error(row, "%s must be >= 0" % field)


func _id_set(table: String, field: String) -> Dictionary:
	var result := {}
	for row: Dictionary in _tables.get(table, []):
		result[_sn(row, field)] = true
	return result


func _rows_by_id(table: String, field: String) -> Dictionary:
	var result := {}
	for row: Dictionary in _tables.get(table, []):
		result[_s(row, field)] = row
	return result


func _merged_set(sets: Array) -> Dictionary:
	var result := {}
	for set: Dictionary in sets:
		result.merge(set, true)
	return result


func _s(row: Dictionary, field: String) -> String:
	return String(row.get(field, "")).strip_edges()


func _sn(row: Dictionary, field: String) -> StringName:
	return StringName(_s(row, field))


func _f(row: Dictionary, field: String) -> float:
	return _s(row, field).to_float()


func _i(row: Dictionary, field: String) -> int:
	return _s(row, field).to_int()


func _b(row: Dictionary, field: String) -> bool:
	return _s(row, field).to_lower() in ["true", "1", "yes"]


func _names(row: Dictionary, field: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: String in _s(row, field).split("|", false):
		if not value.strip_edges().is_empty():
			result.append(StringName(value.strip_edges()))
	return result


func _error(row: Dictionary, message: String) -> void:
	errors.append("%s:%d %s" % [row.get("__file", "?"), row.get("__line", 0), message])


func _warning(row: Dictionary, message: String) -> void:
	warnings.append("%s:%d %s" % [row.get("__file", "?"), row.get("__line", 0), message])


func _source_digest() -> String:
	var digest_source := ""
	for file_name: String in TABLE_FILES:
		digest_source += FileAccess.get_sha256(_source_dir.path_join(file_name))
	return digest_source.sha256_text()


func _result(success: bool, output_path: String, database: CombatDatabase = null) -> Dictionary:
	return {
		"success": success,
		"output_path": output_path,
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"database": database,
	}
