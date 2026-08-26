class_name CombatDatabase
extends Resource

@export var schema_version := 1
@export var generated_at_utc := ""
@export var source_digest := ""
@export var rules: Array[CombatRuleDefinition] = []
@export var stats: Array[StatDefinition] = []
@export var hero_classes: Array[Resource] = []
@export var hero_subclasses: Array[Resource] = []
@export var ai_archetypes: Array[Resource] = []
@export var units: Array[UnitDefinition] = []
@export var unit_stats: Array[UnitStatValueDefinition] = []
@export var skills: Array[SkillDefinition] = []
@export var skill_effects: Array[SkillEffectDefinition] = []
@export var skill_ranks: Array[SkillRankDefinition] = []
@export var skill_effect_ranks: Array[SkillEffectRankDefinition] = []
@export var unit_mode_modifiers: Array[UnitModeModifierDefinition] = []
@export var buffs: Array[BuffDefinition] = []
@export var buff_modifiers: Array[BuffModifierDefinition] = []
@export var hit_profiles: Array[HitProfileDefinition] = []
@export var animation_events: Array[AnimationEventDefinition] = []
@export var asset_profiles: Array[AssetProfileDefinition] = []
@export var particle_profiles: Array[ParticleProfileDefinition] = []
@export var ai_profiles: Array[AIProfileDefinition] = []

var _rule_index: Dictionary = {}
var _unit_index: Dictionary = {}
var _hero_class_index: Dictionary = {}
var _hero_subclass_index: Dictionary = {}
var _ai_archetype_index: Dictionary = {}
var _unit_stat_index: Dictionary = {}
var _skill_index: Dictionary = {}
var _skill_rank_index: Dictionary = {}
var _skill_effect_rank_index: Dictionary = {}
var _unit_mode_modifier_index: Dictionary = {}
var _buff_index: Dictionary = {}
var _hit_profile_index: Dictionary = {}
var _asset_profile_index: Dictionary = {}
var _particle_profile_index: Dictionary = {}
var _ai_profile_index: Dictionary = {}


func rebuild_indexes() -> void:
	_rule_index = _index_by_id(rules)
	_unit_index = _index_by_id(units)
	_hero_class_index = _index_by_id(hero_classes)
	_hero_subclass_index = _index_by_id(hero_subclasses)
	_ai_archetype_index = _index_by_id(ai_archetypes)
	_unit_stat_index.clear()
	for definition: UnitStatValueDefinition in unit_stats:
		_unit_stat_index[_unit_stat_key(definition.unit_id, definition.stat_id)] = definition
	_skill_index = _index_by_id(skills)
	_skill_rank_index.clear()
	for definition: SkillRankDefinition in skill_ranks:
		_skill_rank_index[_skill_rank_key(definition.skill_id, definition.rank)] = definition
	_skill_effect_rank_index.clear()
	for definition: SkillEffectRankDefinition in skill_effect_ranks:
		_skill_effect_rank_index[_skill_rank_key(definition.effect_id, definition.rank)] = definition
	_unit_mode_modifier_index.clear()
	for definition: UnitModeModifierDefinition in unit_mode_modifiers:
		var key := _unit_mode_modifier_key(definition.unit_id, definition.mode)
		if not _unit_mode_modifier_index.has(key):
			_unit_mode_modifier_index[key] = []
		(_unit_mode_modifier_index[key] as Array).append(definition)
	_buff_index = _index_by_id(buffs)
	_hit_profile_index = _index_by_id(hit_profiles)
	_asset_profile_index = _index_by_id(asset_profiles)
	_particle_profile_index = _index_by_id(particle_profiles)
	_ai_profile_index = _index_by_id(ai_profiles)


func get_rule(rule_id: StringName, fallback: Variant = null) -> Variant:
	_ensure_indexes()
	var definition := _rule_index.get(rule_id) as CombatRuleDefinition
	return definition.value() if definition != null else fallback


func get_unit(unit_id: StringName) -> UnitDefinition:
	_ensure_indexes()
	return _unit_index.get(unit_id) as UnitDefinition


func get_hero_class(class_id: StringName) -> Resource:
	_ensure_indexes()
	return _hero_class_index.get(class_id) as Resource


func get_hero_subclass(subclass_id: StringName) -> Resource:
	_ensure_indexes()
	return _hero_subclass_index.get(subclass_id) as Resource


func get_ai_archetype(archetype_id: StringName) -> Resource:
	_ensure_indexes()
	return _ai_archetype_index.get(archetype_id) as Resource


func get_unit_stat(unit_id: StringName, stat_id: StringName) -> UnitStatValueDefinition:
	_ensure_indexes()
	return _unit_stat_index.get(_unit_stat_key(unit_id, stat_id)) as UnitStatValueDefinition


func get_unit_stat_value(unit_id: StringName, stat_id: StringName, level := 1) -> float:
	var definition := get_unit_stat(unit_id, stat_id)
	if definition == null:
		return 0.0
	var level_cap := int(get_rule(&"progression.level_cap", 18))
	var resolved_level := clampi(level, 1, level_cap)
	match definition.growth_formula:
		"linear":
			return definition.base_value + definition.growth_value * float(resolved_level - 1)
		"primary":
			return _primary_growth(definition.base_value, definition.growth_value, resolved_level)
		"attack_speed":
			var ratio_definition := get_unit_stat(unit_id, &"attack_speed_ratio")
			var ratio := ratio_definition.base_value if ratio_definition != null else definition.base_value
			return _attack_speed_growth(definition.base_value, ratio, definition.growth_value, resolved_level)
		_:
			return definition.base_value


func get_skill(skill_id: StringName) -> SkillDefinition:
	_ensure_indexes()
	return _skill_index.get(skill_id) as SkillDefinition


func get_skill_by_slot(owner_id: StringName, slot: int) -> SkillDefinition:
	for definition: SkillDefinition in skills:
		if definition.owner_id == owner_id and definition.slot == slot:
			return definition
	return null


func get_skill_effects(skill_id: StringName, trigger := "") -> Array[SkillEffectDefinition]:
	var matches: Array[SkillEffectDefinition] = []
	for definition: SkillEffectDefinition in skill_effects:
		if definition.skill_id == skill_id and (trigger.is_empty() or definition.trigger == trigger):
			matches.append(definition)
	matches.sort_custom(func(a: SkillEffectDefinition, b: SkillEffectDefinition) -> bool: return a.order < b.order)
	return matches


func get_skill_rank(skill_id: StringName, rank: int) -> SkillRankDefinition:
	_ensure_indexes()
	return _skill_rank_index.get(_skill_rank_key(skill_id, rank)) as SkillRankDefinition


func get_skill_effect_rank(effect_id: StringName, rank: int) -> SkillEffectRankDefinition:
	_ensure_indexes()
	return _skill_effect_rank_index.get(_skill_rank_key(effect_id, rank)) as SkillEffectRankDefinition


func get_unit_mode_modifiers(unit_id: StringName, mode: StringName) -> Array[UnitModeModifierDefinition]:
	_ensure_indexes()
	var values: Array[UnitModeModifierDefinition] = []
	for definition: UnitModeModifierDefinition in _unit_mode_modifier_index.get(_unit_mode_modifier_key(unit_id, mode), []):
		values.append(definition)
	return values


func get_buff(buff_id: StringName) -> BuffDefinition:
	_ensure_indexes()
	return _buff_index.get(buff_id) as BuffDefinition


func get_buff_modifier(buff_id: StringName, stat_id: StringName) -> BuffModifierDefinition:
	for definition: BuffModifierDefinition in buff_modifiers:
		if definition.buff_id == buff_id and definition.stat_id == stat_id:
			return definition
	return null


func get_hit_profile(profile_id: StringName) -> HitProfileDefinition:
	_ensure_indexes()
	return _hit_profile_index.get(profile_id) as HitProfileDefinition


func get_animation_event(owner_id: StringName, animation_name: StringName, event_type: String) -> AnimationEventDefinition:
	for definition: AnimationEventDefinition in animation_events:
		if definition.owner_id == owner_id and definition.animation_name == animation_name and definition.event_type == event_type:
			return definition
	return null


func get_animation_events(owner_id: StringName, animation_name: StringName, event_type: String) -> Array[AnimationEventDefinition]:
	var matches: Array[AnimationEventDefinition] = []
	for definition: AnimationEventDefinition in animation_events:
		if definition.owner_id == owner_id and definition.animation_name == animation_name and definition.event_type == event_type:
			matches.append(definition)
	matches.sort_custom(
		func(a: AnimationEventDefinition, b: AnimationEventDefinition) -> bool:
			if not is_equal_approx(a.timing_value, b.timing_value):
				return a.timing_value < b.timing_value
			return String(a.id) < String(b.id)
	)
	return matches


func get_asset_profile(profile_id: StringName) -> AssetProfileDefinition:
	_ensure_indexes()
	return _asset_profile_index.get(profile_id) as AssetProfileDefinition


func get_particle_profile(profile_id: StringName) -> ParticleProfileDefinition:
	_ensure_indexes()
	return _particle_profile_index.get(profile_id) as ParticleProfileDefinition


func get_ai_profile(profile_id: StringName) -> AIProfileDefinition:
	_ensure_indexes()
	return _ai_profile_index.get(profile_id) as AIProfileDefinition


func _ensure_indexes() -> void:
	if _rule_index.is_empty():
		rebuild_indexes()


func _index_by_id(definitions: Array) -> Dictionary:
	var result := {}
	for definition: Resource in definitions:
		result[definition.get("id")] = definition
	return result


func _unit_stat_key(unit_id: StringName, stat_id: StringName) -> StringName:
	return StringName("%s|%s" % [unit_id, stat_id])


func _skill_rank_key(id: StringName, rank: int) -> StringName:
	return StringName("%s|%d" % [id, rank])


func _unit_mode_modifier_key(unit_id: StringName, mode: StringName) -> StringName:
	return StringName("%s|%s" % [unit_id, mode])


func _primary_growth(base_value: float, growth_value: float, level: int) -> float:
	var level_ups := maxf(0.0, float(level - 1))
	return base_value + growth_value * _growth_factor(level_ups)


func _attack_speed_growth(base_attack_speed: float, attack_speed_ratio: float, growth_ratio: float, level: int) -> float:
	var level_ups := maxf(0.0, float(level - 1))
	var growth_bonus := growth_ratio * _growth_factor(level_ups)
	return base_attack_speed + growth_bonus * attack_speed_ratio


func _growth_factor(level_ups: float) -> float:
	var linear := float(get_rule(&"progression.growth_linear_coefficient", 0.7025))
	var quadratic := float(get_rule(&"progression.growth_quadratic_coefficient", 0.0175))
	return level_ups * (linear + quadratic * level_ups)
