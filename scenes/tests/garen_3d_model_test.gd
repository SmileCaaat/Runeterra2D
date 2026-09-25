extends Node3D

const CAMERA_DISTANCE := 11.5
const CAMERA_HEIGHT := 4.6

@onready var model: Node3D = $GarenModel
@onready var status_label: Label = $CanvasLayer/Panel/Status

var _animation_player: AnimationPlayer
var _animations: PackedStringArray = []
var _animation_index := 0
var _auto_rotate := false

func _ready() -> void:
	_animation_player = _find_animation_player(model)
	if _animation_player == null:
		push_error("Garen 3D test: imported model has no AnimationPlayer")
		status_label.text = "Import failed: no AnimationPlayer found."
		return
	_animations = _animation_player.get_animation_list()
	_animations.sort()
	if _animations.is_empty():
		push_error("Garen 3D test: imported AnimationPlayer contains no animations")
		status_label.text = "Import failed: AnimationPlayer contains no animations."
		return
	_animation_index = _animations.find(&"Idle1_Base")
	if _animation_index < 0:
		_animation_index = 0
	_play_selected_animation()

func _process(delta: float) -> void:
	if _auto_rotate:
		model.rotate_y(delta * 0.7)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT, KEY_SPACE:
			_select_animation(1)
		KEY_LEFT:
			_select_animation(-1)
		KEY_R:
			_auto_rotate = not _auto_rotate
			_update_status()
		KEY_ESCAPE:
			get_tree().quit()

func _select_animation(direction: int) -> void:
	if _animations.is_empty():
		return
	_animation_index = posmod(_animation_index + direction, _animations.size())
	_play_selected_animation()

func _play_selected_animation() -> void:
	_animation_player.play(_animations[_animation_index], 0.15)
	_update_status()

func _update_status() -> void:
	var animation_name := _animations[_animation_index] if not _animations.is_empty() else "none"
	status_label.text = (
		"Rogue Admiral Garen — 3D candidate\n"
		+ "Animation %d / %d: %s\n" % [_animation_index + 1, _animations.size(), animation_name]
		+ "← / → or Space: switch animation    R: auto-rotate (%s)    Esc: exit"
	) % ("on" if _auto_rotate else "off")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
