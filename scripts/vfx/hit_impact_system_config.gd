class_name HitImpactSystemConfig
extends Resource

@export var pool_size := 8
@export var viewport_size := Vector2i(256, 256)
@export var base_pixel_size := 0.012
@export var normal_sequence_duration := 0.32
@export var critical_sequence_duration := 0.38
@export var normal_sequence_pixel_size := 0.0022
@export var critical_sequence_pixel_size := 0.0026
@export var critical_profile_id: StringName = &"critical"
@export var profiles: Array[Resource] = []
@export var hit_profile_map: Dictionary[StringName, StringName] = {}
