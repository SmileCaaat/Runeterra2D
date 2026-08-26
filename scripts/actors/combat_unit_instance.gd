class_name CombatUnitInstance
extends CharacterBody3D

const FLOATING_DAMAGE_NUMBERS := preload("res://scripts/presentation/floating_damage_numbers.gd")

# Shared runtime presentation contract for every combat-capable world unit.
# Individual actors continue to own their movement, state machine and death
# behaviour; this template owns only reusable combat-instance services.
var _instance_database: CombatDatabase
var _instance_definition: UnitDefinition
var _floating_damage_numbers: Node3D


func bind_combat_instance(database: CombatDatabase, definition: UnitDefinition) -> void:
	_instance_database = database
	_instance_definition = definition
	_floating_damage_numbers = FLOATING_DAMAGE_NUMBERS.get_or_create(self, database)


func present_resolved_damage(amount: float, damage_type: StringName, is_critical := false) -> void:
	if amount <= 0.0:
		return
	if _floating_damage_numbers == null:
		_floating_damage_numbers = FLOATING_DAMAGE_NUMBERS.get_or_create(self, _instance_database)
	_floating_damage_numbers.call("show_damage", amount, damage_type, is_critical)


func present_miss() -> void:
	if _floating_damage_numbers == null:
		_floating_damage_numbers = FLOATING_DAMAGE_NUMBERS.get_or_create(self, _instance_database)
	_floating_damage_numbers.call("show_miss")


func get_instance_template_id() -> StringName:
	return _instance_definition.instance_template_id if _instance_definition != null else &""
