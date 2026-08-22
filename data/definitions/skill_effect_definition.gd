class_name SkillEffectDefinition
extends Resource

@export var id: StringName
@export var skill_id: StringName
@export var order := 0
@export_enum("on_cast", "on_next_attack", "periodic", "on_impact", "on_expire") var trigger := "on_cast"
@export_enum("damage", "apply_buff", "apply_control", "cleanse", "delayed_damage", "shield") var effect_type := "damage"
@export_enum("self", "target", "enemies_in_area", "allies_in_area", "self_and_allies") var target_selector := "target"
@export_enum("physical", "magic", "true", "none") var damage_type := "none"
@export var base_value := 0.0
@export var scaling_stat: StringName
@export var scaling_coefficient := 0.0
@export var target_missing_health_coefficient := 0.0
@export var delay := 0.0
@export var interval := 0.0
@export var can_crit := false
@export var nonlethal := false
@export var buff_id: StringName
@export var control_type: StringName
@export var control_duration := 0.0
@export var hit_profile_id: StringName
@export var tags: Array[StringName] = []
