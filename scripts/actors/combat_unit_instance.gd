class_name CombatUnitInstance
extends CharacterBody3D

const FLOATING_DAMAGE_NUMBERS := preload("res://scripts/presentation/floating_damage_numbers.gd")

# Shared runtime presentation contract for every combat-capable world unit.
# Individual actors continue to own their movement, state machine and death
# behaviour; this template owns only reusable combat-instance services.
var _instance_database: CombatDatabase
var _instance_definition: UnitDefinition
var _floating_damage_numbers: Node3D
var _ghost_collision_active := false
var _normal_collision_layer := 0
var _normal_collision_mask := 0


func set_ghost_collision_active(active: bool) -> void:
	if _ghost_collision_active == active:
		return
	_ghost_collision_active = active
	if active:
		_normal_collision_layer = collision_layer
		_normal_collision_mask = collision_mask
		# World geometry stays on layer 1; combat bodies use layer 2.
		# A ghost retains ground collision but removes its body layer so either
		# CharacterBody can pass through the other during a dash.
		collision_layer = 0
		collision_mask = 1
		return
	collision_layer = _normal_collision_layer
	collision_mask = _normal_collision_mask


func has_ghost_collision() -> bool:
	return _ghost_collision_active


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


func is_courage_stack_eligible() -> bool:
	return _instance_definition != null and _instance_definition.courage_stack_eligible
