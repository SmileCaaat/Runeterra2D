class_name SkillEffectRankDefinition
extends Resource

@export var effect_id: StringName
@export_range(1, 5, 1) var rank := 1
@export var base_value := 0.0
@export var scaling_coefficient := 0.0
@export var target_missing_health_coefficient := 0.0
@export var delay := 0.0
@export var interval := 0.0
@export var control_duration := 0.0
@export var source_key := ""
@export var notes := ""
