class_name TargetDummyModelPresenter
extends Node3D

signal animation_finished(animation_name: StringName)

@onready var blue_model: Node = $BlueModel
@onready var red_model: Node = $RedModel
var _active_model: Node

func _ready() -> void:
	blue_model.connect(&"animation_finished", _on_model_animation_finished.bind(blue_model))
	red_model.connect(&"animation_finished", _on_model_animation_finished.bind(red_model))

func configure_team(team: StringName) -> void:
	var use_blue := team == &"friendly"
	blue_model.set(&"visible", use_blue)
	red_model.set(&"visible", not use_blue)
	_active_model = blue_model if use_blue else red_model

func play_semantic(animation_name: StringName) -> void:
	if _active_model != null:
		_active_model.call(&"play_semantic", animation_name)

func set_facing(direction: Vector3) -> void:
	if _active_model != null:
		_active_model.call(&"set_facing", direction)

func set_reaction_scale(value: Vector2) -> void:
	if _active_model != null:
		_active_model.set(&"scale", Vector3(value.x, value.y, 1.0))

func _on_model_animation_finished(animation_name: StringName, source: Node) -> void:
	if source == _active_model:
		animation_finished.emit(animation_name)
