class_name SuperArmorOutline
extends Node3D

# Reusable super-armor presentation. It is a current-frame outline, not an
# afterimage, so it can be reused by any future super-armor skill/state.
const OUTLINE_SHADER := preload("res://assets/shaders/super_armor_outline_glow.gdshader")

var source_sprite: AnimatedSprite3D
var outline_sprite: Sprite3D
var red := Color(1.0, 0.12, 0.08, 1.0)
var gold := Color(1.0, 0.80, 0.20, 1.0)
var opacity := 0.78
var outline_width_pixels := 2.5
var alpha_threshold := 0.35
var glow_intensity := 1.4
var active := false
var extra_offset := Vector2.ZERO
var _mask_atlas_cache: Dictionary = {}


func configure(
	source: AnimatedSprite3D,
	profile: AssetProfileDefinition,
	next_red: Color,
	next_gold: Color,
	next_width: float,
	next_glow: float,
	next_opacity := -1.0,
	next_offset := Vector2.ZERO,
	next_alpha_threshold := -1.0,
) -> void:
	source_sprite = source
	red = next_red
	gold = next_gold
	outline_width_pixels = next_width
	glow_intensity = next_glow
	opacity = next_opacity if next_opacity >= 0.0 else (profile.opacity if profile != null else opacity)
	extra_offset = next_offset
	alpha_threshold = next_alpha_threshold if next_alpha_threshold >= 0.0 else alpha_threshold
	if outline_sprite == null:
		outline_sprite = Sprite3D.new()
		outline_sprite.name = "OutlineGlow"
		outline_sprite.visible = false
		outline_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline_sprite.transparent = true
		outline_sprite.shaded = false
		outline_sprite.no_depth_test = true
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		outline_sprite.material_override = material
		add_child(outline_sprite)
		outline_sprite.top_level = true
	if profile != null:
		outline_sprite.render_priority = profile.render_priority
		outline_sprite.no_depth_test = profile.no_depth_test


func set_active(next_active: bool) -> void:
	active = next_active
	if not active:
		if outline_sprite != null:
			outline_sprite.visible = false
		return
	_sync_current_frame()


func _process(_delta: float) -> void:
	_sync_current_frame()


func _sync_current_frame() -> void:
	if not active or source_sprite == null or source_sprite.sprite_frames == null or outline_sprite == null:
		if outline_sprite != null:
			outline_sprite.visible = false
		return
	# Always capture the source's current animation frame. This component never
	# samples from, or stores, a prior frame; temporal afterimages remain a
	# separate presentation used by effects such as Rum.
	var texture := source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	if texture == null:
		outline_sprite.visible = false
		return
	outline_sprite.texture = texture
	outline_sprite.global_transform = source_sprite.global_transform
	outline_sprite.offset = source_sprite.offset + extra_offset
	outline_sprite.pixel_size = source_sprite.pixel_size
	outline_sprite.axis = source_sprite.axis
	outline_sprite.billboard = source_sprite.billboard
	outline_sprite.fixed_size = source_sprite.fixed_size
	outline_sprite.centered = source_sprite.centered
	outline_sprite.double_sided = source_sprite.double_sided
	outline_sprite.texture_filter = source_sprite.texture_filter
	outline_sprite.flip_h = source_sprite.flip_h
	outline_sprite.flip_v = source_sprite.flip_v
	outline_sprite.layers = source_sprite.layers
	var material := outline_sprite.material_override as ShaderMaterial
	if material != null:
		# Some imported sprite sheets contain translucent internal fragments (weapon
		# glints, shadows, etc.).  When an authored procedural silhouette mask is
		# available beside a runtime atlas, sample that mask for the outline while
		# retaining the original texture for the Sprite3D geometry.
		material.set_shader_parameter(&"frame_texture", _outline_mask_texture(texture))
		material.set_shader_parameter(&"frame_uv_rect", _frame_uv_rect(texture))
		material.set_shader_parameter(&"outline_red", red)
		material.set_shader_parameter(&"outline_gold", gold)
		material.set_shader_parameter(&"outline_width_pixels", outline_width_pixels)
		material.set_shader_parameter(&"alpha_threshold", alpha_threshold)
		material.set_shader_parameter(&"glow_intensity", glow_intensity)
		# Source alpha includes fades such as a monster dissolving, so the outline
		# fades with the body instead of remaining as a detached silhouette.
		material.set_shader_parameter(&"opacity", opacity * source_sprite.modulate.a)
	outline_sprite.visible = source_sprite.visible


func _outline_mask_texture(frame_texture: Texture2D) -> Texture2D:
	if not frame_texture is AtlasTexture:
		return frame_texture
	var atlas_frame := frame_texture as AtlasTexture
	if atlas_frame.atlas == null:
		return frame_texture
	var atlas_path := atlas_frame.atlas.resource_path
	if not atlas_path.ends_with("/runtime_atlas.png"):
		return frame_texture
	if _mask_atlas_cache.has(atlas_path):
		var cached := _mask_atlas_cache[atlas_path] as Texture2D
		return cached if cached != null else frame_texture
	var mask_path := atlas_path.trim_suffix("runtime_atlas.png").path_join("runtime_outline_mask.png")
	var mask := load(mask_path) as Texture2D if ResourceLoader.exists(mask_path) else null
	_mask_atlas_cache[atlas_path] = mask
	return mask if mask != null else frame_texture


func _frame_uv_rect(frame_texture: Texture2D) -> Vector4:
	if frame_texture is AtlasTexture:
		var atlas_texture := frame_texture as AtlasTexture
		if atlas_texture.atlas != null:
			var atlas_size := Vector2(atlas_texture.atlas.get_size())
			if atlas_size.x > 0.0 and atlas_size.y > 0.0:
				var region := atlas_texture.region
				return Vector4(
					region.position.x / atlas_size.x,
					region.position.y / atlas_size.y,
					region.size.x / atlas_size.x,
					region.size.y / atlas_size.y,
				)
	return Vector4(0.0, 0.0, 1.0, 1.0)
