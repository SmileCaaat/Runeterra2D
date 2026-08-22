class_name HitProfileDefinition
extends Resource

@export var id: StringName
@export_enum("box", "sphere", "capsule", "self_area", "ground_area") var shape := "box"
@export var size := Vector3.ONE
@export var offset := Vector3.ZERO
@export var depth_tolerance := 0.65
@export var active_start_normalized := 0.5
@export var active_end_normalized := 0.65
@export var hitstop := 0.06
@export var hitstun := 0.18
@export var poise_damage := 0.0
@export var knockback_speed := 0.0
@export var knockback_decay := 12.0
@export var launch_velocity := 0.0
@export var hit_vfx_profile_id: StringName
@export var hit_audio_profile_id: StringName
