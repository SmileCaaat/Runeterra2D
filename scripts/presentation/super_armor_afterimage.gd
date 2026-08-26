class_name SuperArmorAfterimage
extends Node3D

# Reusable presentation component. Gameplay only supplies an active/inactive state;
# this component captures the source sprite's immediately preceding animation frame.
const AFTERIMAGE_SHADER := preload("res://assets/vfx/garen_skills/garen_breaker_afterimage.gdshader")

var source_sprite: AnimatedSprite3D
var previous_frame: Sprite3D
var tint := Color(1.0, 0.12, 0.10, 1.0)
var opacity := 0.62
var active := false


func configure(source: AnimatedSprite3D, profile: AssetProfileDefinition, next_tint: Color) -> void:
	source_sprite = source
	tint = next_tint
	opacity = profile.opacity if profile != null else opacity
	if previous_frame == null:
		previous_frame = Sprite3D.new()
		previous_frame.name = "PreviousFrame"
		previous_frame.visible = false
		previous_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		previous_frame.transparent = true
		previous_frame.shaded = false
		var material := ShaderMaterial.new()
		material.shader = AFTERIMAGE_SHADER
		previous_frame.material_override = material
		add_child(previous_frame)
		previous_frame.top_level = true
	if profile != null:
		previous_frame.render_priority = profile.render_priority
		previous_frame.no_depth_test = profile.no_depth_test


func set_active(next_active: bool) -> void:
	active = next_active
	if not active and previous_frame != null:
		previous_frame.visible = false


func _process(_delta: float) -> void:
	if not active or source_sprite == null or source_sprite.sprite_frames == null:
		if previous_frame != null:
			previous_frame.visible = false
		return
	var frame_count := source_sprite.sprite_frames.get_frame_count(source_sprite.animation)
	if frame_count <= 0:
		previous_frame.visible = false
		return
	var previous_index := posmod(source_sprite.frame - 1, frame_count)
	var texture := source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, previous_index)
	if texture == null:
		previous_frame.visible = false
		return
	previous_frame.texture = texture
	previous_frame.global_transform = source_sprite.global_transform
	previous_frame.offset = source_sprite.offset
	previous_frame.pixel_size = source_sprite.pixel_size
	previous_frame.axis = source_sprite.axis
	previous_frame.billboard = source_sprite.billboard
	previous_frame.fixed_size = source_sprite.fixed_size
	previous_frame.centered = source_sprite.centered
	previous_frame.double_sided = source_sprite.double_sided
	previous_frame.texture_filter = source_sprite.texture_filter
	previous_frame.flip_h = source_sprite.flip_h
	previous_frame.flip_v = source_sprite.flip_v
	previous_frame.layers = source_sprite.layers
	previous_frame.render_priority = mini(previous_frame.render_priority, source_sprite.render_priority - 1)
	var material := previous_frame.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"frame_texture", texture)
		material.set_shader_parameter(&"ocean_tint", Color(tint.r, tint.g, tint.b, opacity))
	previous_frame.visible = source_sprite.visible
