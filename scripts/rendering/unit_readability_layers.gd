extends Node3D

@export_node_path("AnimatedSprite3D") var source_sprite_path: NodePath
@export_node_path("Node") var team_source_path := NodePath("..")
@export var create_outline := true
@export_range(1.0, 1.2, 0.005) var outline_scale := 1.05
@export_range(1.0, 1.3, 0.005) var glow_scale := 1.09
@export_range(-128.0, 128.0, 1.0) var vertical_offset_px := -10.0
@export_range(0.0, 1.0, 0.01) var outline_alpha := 0.78
@export_range(0.0, 0.2, 0.01) var glow_alpha := 0.08

var source_sprite: AnimatedSprite3D
var outline: AnimatedSprite3D
var backlight_glow: AnimatedSprite3D


func _ready() -> void:
	source_sprite = get_node(source_sprite_path) as AnimatedSprite3D
	if source_sprite == null:
		push_error("Unit readability source is missing: %s" % source_sprite_path)
		return
	if create_outline:
		outline = _create_layer(&"Outline", outline_scale, -2)
	backlight_glow = _create_layer(&"BacklightGlow", glow_scale, -3)
	_sync_layers()


func _process(_delta: float) -> void:
	_sync_layers()


func _create_layer(layer_name: StringName, size_multiplier: float, priority: int) -> AnimatedSprite3D:
	var layer := AnimatedSprite3D.new()
	layer.name = layer_name
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.billboard = source_sprite.billboard
	layer.no_depth_test = false
	layer.texture_filter = source_sprite.texture_filter
	layer.render_priority = priority
	layer.sprite_frames = source_sprite.sprite_frames
	layer.pixel_size = source_sprite.pixel_size * size_multiplier
	add_child(layer)
	return layer


func _sync_layers() -> void:
	if source_sprite == null:
		return
	var team_color := _team_color(_resolve_team())
	var should_show := source_sprite.visible and _is_team_source_targetable()
	if outline != null:
		_sync_layer(outline)
		outline.visible = should_show
		outline.modulate = Color(team_color.r, team_color.g, team_color.b, outline_alpha)
	if backlight_glow != null:
		_sync_layer(backlight_glow)
		backlight_glow.visible = should_show
		backlight_glow.modulate = Color(team_color.r, team_color.g, team_color.b, glow_alpha)


func _sync_layer(layer: AnimatedSprite3D) -> void:
	layer.sprite_frames = source_sprite.sprite_frames
	layer.animation = source_sprite.animation
	layer.frame = source_sprite.frame
	layer.frame_progress = source_sprite.frame_progress
	layer.flip_h = source_sprite.flip_h
	layer.flip_v = source_sprite.flip_v
	layer.offset = source_sprite.offset + Vector2(0.0, vertical_offset_px)
	layer.scale = source_sprite.scale
	layer.visible = source_sprite.visible


func _resolve_team() -> StringName:
	var team_source := get_node_or_null(team_source_path)
	if team_source != null and team_source.has_method(&"get_team"):
		return StringName(team_source.call(&"get_team"))
	return &"neutral"


func _is_team_source_targetable() -> bool:
	var team_source := get_node_or_null(team_source_path)
	if team_source != null and team_source.has_method(&"is_targetable"):
		return bool(team_source.call(&"is_targetable"))
	return true


func _team_color(team: StringName) -> Color:
	match team:
		&"friendly":
			return Color(0.05, 0.66, 1.0, 1.0)
		&"enemy":
			return Color(1.0, 0.06, 0.035, 1.0)
		_:
			return Color(1.0, 0.76, 0.06, 1.0)
