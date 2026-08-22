class_name SkillDefinition
extends Resource

@export var id: StringName
@export var owner_id: StringName
@export var slot := 0
@export var display_name := ""
@export_enum("self", "unit", "direction", "ground_area", "self_area") var target_type := "unit"
@export_enum("instant", "cast", "channel", "empower", "travel") var cast_type := "instant"
@export var cooldown := 0.0
@export var cast_time := 0.0
@export var recovery_time := 0.0
@export var cast_range := 0.0
@export var radius := 0.0
@export var duration := 0.0
@export var tick_interval := 0.0
@export var resource_cost := 0.0
@export_enum("locked", "allowed", "slowed", "forced") var movement_policy := "locked"
@export_enum("cast_time", "continuous", "none") var facing_policy := "cast_time"
@export var snapshot_target_position := false
@export var windup_animation_name: StringName
@export var animation_name: StringName
@export var movement_animation_name: StringName
@export var empowered_animation_name: StringName
@export var travel_start_offset := 0.0
@export var travel_duration := 0.0
@export var vfx_profile_id: StringName
@export var audio_profile_id: StringName
@export var tags: Array[StringName] = []
