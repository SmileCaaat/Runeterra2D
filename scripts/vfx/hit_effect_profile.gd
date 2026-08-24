class_name HitEffectProfile
extends Resource

@export var id: StringName = &"normal"
@export var duration := 0.28
@export var world_scale := 1.0

@export_group("Palette")
@export var core_color := Color(1.0, 0.95, 0.55, 1.0)
@export var hot_color := Color(1.0, 0.62, 0.08, 1.0)
@export var fade_color := Color(1.0, 0.16, 0.02, 0.0)

@export_group("Flash")
@export var flash_duration := 0.11
@export var flash_scale := 1.15

@export_group("Burst")
@export var burst_amount := 12
@export var burst_speed := Vector2(130.0, 260.0)
@export var burst_scale := Vector2(0.35, 0.85)

@export_group("Sparks")
@export var spark_amount := 10
@export var spark_speed := Vector2(280.0, 520.0)
@export var spark_spread := 24.0
@export var spark_scale := Vector2(0.55, 1.25)

@export_group("Shockwave")
@export var shockwave_duration := 0.22
@export var shockwave_radius := 78.0
@export var shockwave_width := 5.0

@export_group("Dust")
@export var dust_amount := 5
@export var dust_speed := Vector2(35.0, 90.0)
@export var dust_gravity := 85.0

@export_group("Debris")
@export var debris_amount := 6
@export var debris_speed := Vector2(90.0, 210.0)
@export var debris_gravity := 240.0
