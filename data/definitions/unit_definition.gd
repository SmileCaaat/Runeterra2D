class_name UnitDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_enum("hero", "monster", "training_dummy", "summon") var unit_type := "hero"
@export var role: StringName
@export var resource_type: StringName
@export var range_type: StringName
@export var level := 1
@export var max_health := 1000.0
@export var max_resource := 0.0
@export var attack_damage := 50.0
@export var ability_power := 0.0
@export var armor := 0.0
@export var magic_resistance := 0.0
@export var move_speed := 3.0
@export var acceleration := 12.0
@export var attack_range := 1.5
@export var attack_speed := 1.0
@export_range(0.0, 1.0, 0.001) var critical_chance := 0.0
@export var critical_damage := 1.75
@export var ability_haste := 0.0
@export_range(0.0, 1.0, 0.001) var tenacity := 0.0
@export var poise := 0.0
@export var collision_radius := 0.5
@export var depth_radius := 0.5
@export var selection_radius := 0.5
@export var selection_height := 1.8
@export var acquisition_radius := 6.0
@export var attack_windup := 0.3
@export var attack_windup_modifier := 1.0
@export var attack_delay_offset := 0.0
@export var ai_profile_id: StringName
@export var skill_ids: Array[StringName] = []
