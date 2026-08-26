class_name UnitModeModifierDefinition
extends Resource

@export var unit_id: StringName
@export var mode: StringName
@export var stat_id: StringName
@export_enum("flat", "add_percent", "multiply", "override") var operation := "flat"
@export var value := 0.0
@export var source_key := ""
@export var notes := ""
