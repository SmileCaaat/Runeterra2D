class_name BuffModifierDefinition
extends Resource

@export var id: StringName
@export var buff_id: StringName
@export var stat_id: StringName
@export_enum("flat", "add_percent", "multiply", "override") var operation := "flat"
@export var value := 0.0
@export_enum("always", "while_active", "on_apply", "on_expire") var phase := "while_active"
@export var priority := 0
