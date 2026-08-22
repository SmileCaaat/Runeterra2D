class_name ParticleProfileDefinition
extends Resource

@export var id: StringName
@export var amount := 16
@export var lifetime := 0.3
@export var randomness := 0.0
@export var spread := 45.0
@export var gravity := Vector3.ZERO
@export var velocity_min := 1.0
@export var velocity_max := 2.0
@export var angular_velocity_min := 0.0
@export var angular_velocity_max := 0.0
@export var scale_min := 1.0
@export var scale_max := 1.0
@export var mesh_size := Vector2(0.1, 0.1)
@export var emission_color := Color.WHITE
@export var emission_energy := 1.0
@export var gradient_start := Color.WHITE
@export var gradient_mid := Color.WHITE
@export var gradient_late := Color.WHITE
@export var gradient_end := Color.TRANSPARENT
