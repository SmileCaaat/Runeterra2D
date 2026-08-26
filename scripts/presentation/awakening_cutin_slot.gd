class_name AwakeningCutInSlot
extends Control

signal playback_finished(slot: AwakeningCutInSlot)

@onready var panel: ColorRect = $Panel
@onready var name_label: Label = $NameLabel
@onready var subtitle_label: Label = $SubtitleLabel

var current_profile: AwakeningCutInProfileDefinition
var request_sequence := 0
var _material: ShaderMaterial
var _playback_generation := 0
var _layout_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = panel.material.duplicate() as ShaderMaterial
	panel.material = _material
	resized.connect(_update_panel_aspect)
	visible = false
	_update_panel_aspect()


func play_profile(profile: AwakeningCutInProfileDefinition, layout: Rect2, mirror: bool, sequence: int) -> void:
	_playback_generation += 1
	var generation := _playback_generation
	current_profile = profile
	request_sequence = sequence
	_apply_profile(profile, mirror)
	apply_layout(layout, false)
	_set_reveal(0.0)
	_set_exit_progress(0.0)
	_set_shine(0.0)
	_material.set_shader_parameter(&"global_alpha", 1.0)
	visible = true
	_run_lifecycle(generation)


func apply_layout(layout: Rect2, animated := true) -> void:
	if _layout_tween != null and _layout_tween.is_valid():
		_layout_tween.kill()
	if not animated or not visible:
		anchor_left = layout.position.x
		anchor_top = layout.position.y
		anchor_right = layout.end.x
		anchor_bottom = layout.end.y
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
		call_deferred(&"_update_panel_aspect")
		return
	_layout_tween = create_tween().set_parallel(true)
	_layout_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_layout_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_layout_tween.tween_property(self, "anchor_left", layout.position.x, 0.12)
	_layout_tween.tween_property(self, "anchor_top", layout.position.y, 0.12)
	_layout_tween.tween_property(self, "anchor_right", layout.end.x, 0.12)
	_layout_tween.tween_property(self, "anchor_bottom", layout.end.y, 0.12)
	_layout_tween.chain().tween_callback(_update_panel_aspect)


func stop_immediately() -> void:
	_playback_generation += 1
	visible = false
	current_profile = null
	request_sequence = 0


func _apply_profile(profile: AwakeningCutInProfileDefinition, mirror: bool) -> void:
	var portrait := load(profile.portrait_path) as Texture2D
	_material.set_shader_parameter(&"portrait_texture", portrait)
	_material.set_shader_parameter(&"theme_color", profile.theme_color)
	_material.set_shader_parameter(&"accent_color", profile.accent_color)
	_material.set_shader_parameter(&"slant", profile.slant)
	_material.set_shader_parameter(&"feather", profile.feather)
	_material.set_shader_parameter(&"portrait_scale", profile.portrait_scale)
	_material.set_shader_parameter(&"portrait_offset", profile.portrait_offset)
	_material.set_shader_parameter(&"mirror_mask", 1.0 if mirror else 0.0)
	if portrait != null and portrait.get_height() > 0:
		_material.set_shader_parameter(&"image_aspect", float(portrait.get_width()) / float(portrait.get_height()))
	name_label.text = profile.display_name
	subtitle_label.text = profile.subtitle
	name_label.modulate = profile.accent_color
	subtitle_label.modulate = Color(profile.accent_color, 0.88)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT


func _run_lifecycle(generation: int) -> void:
	var enter := create_tween().set_parallel(true)
	enter.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	enter.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	enter.tween_method(_set_reveal, 0.0, 1.0, current_profile.enter_duration)
	enter.tween_method(_set_shine, 0.0, 1.0, current_profile.enter_duration * 1.35)
	await enter.finished
	if generation != _playback_generation or current_profile == null:
		return
	var hold := create_tween()
	hold.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	hold.tween_interval(current_profile.hold_duration)
	await hold.finished
	if generation != _playback_generation or current_profile == null:
		return
	var exit := create_tween()
	exit.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_method(_set_exit_progress, 0.0, 1.0, current_profile.exit_duration)
	await exit.finished
	if generation != _playback_generation:
		return
	visible = false
	current_profile = null
	request_sequence = 0
	playback_finished.emit(self)


func _set_reveal(value: float) -> void:
	_material.set_shader_parameter(&"reveal", value)


func _set_exit_progress(value: float) -> void:
	_material.set_shader_parameter(&"exit_progress", value)


func _set_shine(value: float) -> void:
	_material.set_shader_parameter(&"shine_progress", value)


func _update_panel_aspect() -> void:
	if _material == null or size.y <= 0.0:
		return
	_material.set_shader_parameter(&"panel_aspect", size.x / size.y)
