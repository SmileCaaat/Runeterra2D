class_name ActorModelAnimator
extends Node3D

signal animation_finished(animation_name: StringName)

@export var animation_map: Dictionary = {}
@export var looping_states: Array[StringName] = []

@onready var animation_player: AnimationPlayer = _find_animation_player(self)
var current_animation: StringName = &"idle"
var animation_speed_scale := 1.0

func _ready() -> void:
	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)

func play_semantic(semantic: StringName, blend_seconds := 0.1) -> void:
	if animation_player == null:
		return
	var model_animation := StringName(animation_map.get(semantic, animation_map.get(&"idle", &"")))
	if model_animation.is_empty() or not animation_player.has_animation(model_animation):
		return
	if current_animation == semantic and animation_player.is_playing():
		return
	current_animation = semantic
	animation_player.play(model_animation, blend_seconds)
	animation_player.speed_scale = animation_speed_scale

func set_animation_speed(value: float) -> void:
	animation_speed_scale = maxf(value, 0.01)
	if animation_player != null:
		animation_player.speed_scale = animation_speed_scale

func is_playing() -> bool:
	return animation_player != null and animation_player.is_playing()

func get_elapsed_seconds() -> float:
	return animation_player.get_current_animation_position() if animation_player != null else 0.0

func get_animation_length() -> float:
	return animation_player.get_current_animation_length() / maxf(animation_speed_scale, 0.01) if animation_player != null else 0.0

func get_semantic_animation_length(semantic: StringName) -> float:
	if animation_player == null:
		return 0.0
	var model_animation := StringName(animation_map.get(semantic, animation_map.get(&"idle", &"")))
	if model_animation.is_empty() or not animation_player.has_animation(model_animation):
		return 0.0
	return animation_player.get_animation(model_animation).length / maxf(animation_speed_scale, 0.01)

func set_facing(direction: Vector3) -> void:
	if absf(direction.x) > 0.02:
		rotation.y = PI * 0.5 if direction.x > 0.0 else -PI * 0.5

func _on_animation_finished(model_animation: StringName) -> void:
	if looping_states.has(current_animation):
		animation_player.play(model_animation)
		return
	animation_finished.emit(current_animation)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
