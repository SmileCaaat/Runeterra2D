class_name HeroInstance
extends "res://scripts/actors/combat_unit_instance.gd"

signal control_authority_changed(authority: ControlAuthority)

enum ControlAuthority { AI, PLAYER }
var control_authority := ControlAuthority.AI
var player_move_input := Vector2.ZERO


func supports_player_control() -> bool:
	return false


func set_control_authority(next_authority: ControlAuthority) -> void:
	if control_authority == next_authority:
		return
	control_authority = next_authority
	player_move_input = Vector2.ZERO
	_on_control_authority_changed(control_authority)
	control_authority_changed.emit(control_authority)


func get_control_authority() -> ControlAuthority:
	return control_authority


func is_player_controlled() -> bool:
	return control_authority == ControlAuthority.PLAYER


func set_player_move_input(input_vector: Vector2) -> void:
	player_move_input = input_vector.limit_length(1.0) if input_vector.is_finite() else Vector2.ZERO


func get_player_move_input() -> Vector2:
	return player_move_input


func request_player_basic_attack() -> bool:
	return false


func request_player_skill(_slot: StringName, _direction_input := Vector2.ZERO) -> bool:
	return false


func _on_control_authority_changed(_authority: ControlAuthority) -> void:
	pass


func bind_hero_instance(database: CombatDatabase, definition: UnitDefinition) -> void:
	bind_combat_instance(database, definition)
	add_to_group(&"hero_actor")
