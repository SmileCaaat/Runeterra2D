class_name GarenModelAnimator
extends Node3D

signal animation_finished(animation_name: StringName)
signal animation_progressed(animation_name: StringName, normalized_progress: float)

const SEMANTIC_TO_MODEL := {
	&"idle1": &"Idle1_Base",
	&"idle2": &"Idle2_Base",
	&"idle3": &"Garen_2013_Idle3_anm",
	&"run": &"Run",
	&"run_spell": &"Run_Spell1",
	&"attack1": &"Attack1",
	&"attack2": &"Attack2",
	&"attack3": &"Crit",
	&"channel_wndup": &"Channel_Wndup",
	&"channel": &"Channel",
	&"spell1": &"Spell1",
	&"spell3": &"Spell3_0",
	&"spell4": &"Spell4_Base",
	&"taunt": &"Taunt_Base",
	&"death": &"Death",
}
const LOOPING_STATES := {&"idle1": true, &"idle2": true, &"idle3": true, &"run": true, &"run_spell": true, &"channel": true, &"spell3": true}

@onready var animation_player: AnimationPlayer = _find_animation_player(self)
@onready var visual_model: Node3D = $Model

@export_group("Depth Presentation")
@export_range(0.0, 45.0, 0.5, "suffix:°") var max_visual_depth_yaw_degrees := 18.0
@export_range(0.1, 30.0, 0.1) var visual_yaw_smoothing := 12.0

@export_group("Animation Retiming")
# The GLB Attack1/Attack2/Crit clips are authored at 2.0s. 2.5x playback
# gives them an 0.8s action duration; the normalized hit event at 55% lands
# around 0.44s without changing damage, audio, or cancel rules.
@export var semantic_speed_scales: Dictionary[StringName, float] = {
	&"attack1": 2.5,
	&"attack2": 2.5,
	&"attack3": 2.5,
}

var current_animation: StringName = &"idle1"
var _logical_x_sign := 1.0
var _target_visual_yaw := 0.0

func _ready() -> void:
	if animation_player == null:
		push_error("GarenModelAnimator requires an imported AnimationPlayer below %s" % get_path())
		return
	animation_player.animation_finished.connect(_on_model_animation_finished)
	play_semantic(&"idle1")

func _process(delta: float) -> void:
	if animation_player != null and not current_animation.is_empty():
		animation_progressed.emit(current_animation, get_normalized_progress())
	if visual_model != null:
		visual_model.rotation.y = lerp_angle(
			visual_model.rotation.y,
			_target_visual_yaw,
			1.0 - exp(-visual_yaw_smoothing * delta),
		)

func play_semantic(animation_name: StringName, blend_seconds := 0.12) -> void:
	if animation_player == null:
		return
	var model_animation: StringName = SEMANTIC_TO_MODEL.get(animation_name, &"Idle1_Base")
	if not animation_player.has_animation(model_animation):
		push_warning("Garen model is missing mapped animation %s for %s" % [model_animation, animation_name])
		return
	current_animation = animation_name
	animation_player.play(model_animation, blend_seconds, get_semantic_speed(animation_name))

func get_semantic_speed(animation_name: StringName) -> float:
	return maxf(0.01, float(semantic_speed_scales.get(animation_name, 1.0)))

func is_playing() -> bool:
	return animation_player != null and animation_player.is_playing()

func get_normalized_progress() -> float:
	if animation_player == null:
		return 0.0
	var length := animation_player.get_current_animation_length()
	return clampf(animation_player.get_current_animation_position() / length, 0.0, 1.0) if length > 0.0 else 0.0

func get_elapsed_seconds() -> float:
	return animation_player.get_current_animation_position() if animation_player != null else 0.0

func set_facing(direction: Vector3) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() < 0.0025:
		return
	if absf(planar.x) > 0.05:
		_logical_x_sign = signf(planar.x)
	# Gameplay remains a left/right state machine. The model root therefore
	# snaps to the horizontal combat axis; only its visual child receives a
	# bounded, non-gameplay yaw derived from depth separation.
	rotation.y = PI * 0.5 if _logical_x_sign > 0.0 else -PI * 0.5
	var depth_angle := atan2(planar.z, maxf(absf(planar.x), 0.001))
	var depth_limit := deg_to_rad(max_visual_depth_yaw_degrees)
	_target_visual_yaw = clampf(-_logical_x_sign * depth_angle, -depth_limit, depth_limit)

func get_visual_depth_yaw() -> float:
	return _target_visual_yaw

func _on_model_animation_finished(model_animation: StringName) -> void:
	if LOOPING_STATES.has(current_animation):
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
