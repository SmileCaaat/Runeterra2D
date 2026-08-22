class_name StatDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var category: StringName
@export var unit := ""
@export_enum("flat", "add_percent", "multiply", "override") var default_operation := "flat"
@export var minimum := -INF
@export var maximum := INF
@export var description := ""
