class_name AnimationEventDefinition
extends Resource

@export var id: StringName
@export var owner_id: StringName
@export var animation_name: StringName
@export_enum("hit", "audio", "vfx", "move", "cancel_open", "cancel_close", "invulnerable_open", "invulnerable_close") var event_type := "hit"
@export_enum("frame", "normalized", "seconds") var timing_mode := "normalized"
@export var timing_value := 0.0
@export var end_value := 0.0
@export var payload_id: StringName
@export var vector_value := Vector3.ZERO
@export var float_value := 0.0
