class_name AIProfileDefinition
extends Resource

@export var id: StringName
@export var archetype_id: StringName
@export_enum("fighter", "wander", "stationary") var behavior := "fighter"
@export var chase_stop_distance := 1.5
@export var waypoint_tolerance := 0.65
@export var wander_wait_min := 0.25
@export var wander_wait_max := 0.8
@export var arena_min := Vector2(-7.5, -3.4)
@export var arena_max := Vector2(7.5, 3.4)
@export var demo_skill_gap := 0.8
@export var skill_sequence: Array[StringName] = []
@export var deterministic_seed := 0
