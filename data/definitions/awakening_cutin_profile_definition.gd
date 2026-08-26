class_name AwakeningCutInProfileDefinition
extends Resource

@export var id: StringName
@export var owner_id: StringName
@export var skill_id: StringName
@export var display_name := ""
@export var subtitle := ""
@export var portrait_path := ""
@export var audio_path := ""
@export_enum("friendly", "enemy", "neutral") var faction := "friendly"
@export var priority := 0
@export var primary := false
@export var theme_color := Color.WHITE
@export var accent_color := Color.WHITE
@export_range(0.01, 1.0, 0.01) var enter_duration := 0.16
@export_range(0.01, 2.0, 0.01) var hold_duration := 0.35
@export_range(0.01, 1.0, 0.01) var exit_duration := 0.12
@export_range(-1.0, 1.0, 0.01) var slant := 0.28
@export_range(0.001, 0.2, 0.001) var feather := 0.015
@export_range(0.25, 3.0, 0.01) var portrait_scale := 1.0
@export var portrait_offset := Vector2.ZERO
@export_range(-80.0, 24.0, 0.1) var voice_volume_db := 0.0


func total_duration() -> float:
	return enter_duration + hold_duration + exit_duration
