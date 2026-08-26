class_name SkillRankDefinition
extends Resource

@export var skill_id: StringName
@export_range(1, 5, 1) var rank := 1
@export var cooldown := 0.0
@export var cast_time := 0.0
@export var recovery_time := 0.0
@export var cast_range := 0.0
@export var radius := 0.0
@export var duration := 0.0
@export var tick_interval := 0.0
@export var resource_cost := 0.0
@export var source_key := ""
@export var notes := ""
