class_name CombatRuleDefinition
extends Resource

@export var id: StringName
@export var category: StringName
@export_enum("float", "int", "bool", "string", "enum") var value_type := "float"
@export var float_value := 0.0
@export var int_value := 0
@export var bool_value := false
@export var string_value := ""
@export var description := ""


func value() -> Variant:
	match value_type:
		"float":
			return float_value
		"int":
			return int_value
		"bool":
			return bool_value
		_:
			return string_value
