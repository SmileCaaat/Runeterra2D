class_name UnitStatValueDefinition
extends Resource

@export var unit_id: StringName
@export var stat_id: StringName
@export var base_value := 0.0
@export var growth_value := 0.0
@export_enum("none", "linear", "primary", "attack_speed") var growth_formula := "none"
@export var source_base_value := 0.0
@export var source_growth_value := 0.0
@export var conversion_scale := 1.0
@export var source_key := ""
@export var notes := ""
