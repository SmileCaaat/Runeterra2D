extends Node3D

## Low-contrast ground team indicator and weak Toon Fresnel team tint.
## Interaction outlines are managed separately.

const RING_TEXTURE := preload("res://assets/fx/soft_team_ground_ring.svg")
const TOON_SHADER := preload("res://assets/shaders/character_toon_3d.gdshader")

@export_node_path("Node") var team_source_path := NodePath("..")
@export_range(0.0, 1.0, 0.01) var ring_opacity := 0.36
@export var ring_height := 0.025
@export_range(1.0, 2.0, 0.05) var ring_width_multiplier := 1.3
@export_range(1.0, 2.0, 0.05) var ring_depth_multiplier := 1.25
@export_range(0.1, 0.8, 0.01) var fallback_collision_radius := 0.4
@export var friendly_color := Color(0.36, 0.68, 0.76, 1.0)
@export var enemy_color := Color(0.82, 0.43, 0.37, 1.0)
@export var neutral_color := Color(1.0, 0.78, 0.24, 1.0)
@export var friendly_rim_color := Color(0.34, 0.72, 0.86, 1.0)
@export var enemy_rim_color := Color(0.92, 0.36, 0.28, 1.0)
@export var neutral_rim_color := Color(1.0, 0.72, 0.18, 1.0)
@export_range(0.08, 0.18, 0.01) var team_rim_strength := 0.12
@export_range(1.0, 8.0, 0.1) var team_rim_power := 3.5
@export_range(0.0, 0.3, 0.01) var selected_pulse_amount := 0.06

var _ring: Sprite3D
var _selected := false
var _pulse_time := 0.0


func _ready() -> void:
	_ensure_ring()
	refresh_team_visuals()
	call_deferred(&"_apply_toon_team_rim")


func _process(delta: float) -> void:
	if not _selected or _ring == null or not _ring.visible:
		return
	_pulse_time += delta
	var pulse := 1.0 - selected_pulse_amount * 0.5 + sin(_pulse_time * TAU * 1.5) * selected_pulse_amount * 0.5
	var color := _team_indicator_color()
	_ring.modulate = Color(color.r, color.g, color.b, ring_opacity * pulse)


func set_selected(active: bool) -> void:
	_selected = active
	if not active:
		_pulse_time = 0.0
	refresh_team_visuals()


func refresh_team_visuals() -> void:
	_ensure_ring()
	if _ring == null:
		return
	var team := _resolve_team()
	match team:
		&"friendly":
			_ring.visible = true
		&"enemy":
			_ring.visible = true
		&"neutral":
			_ring.visible = true
		_:
			_ring.visible = false
	if _ring.visible:
		var color := _team_indicator_color()
		_ring.modulate = Color(color.r, color.g, color.b, ring_opacity)
	_update_ring_size()
	call_deferred(&"_apply_toon_team_rim")


func _ensure_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		return
	_ring = get_node_or_null("TeamGroundRing") as Sprite3D
	if _ring == null:
		_ring = Sprite3D.new()
		_ring.name = "TeamGroundRing"
		_ring.visible = false
		add_child(_ring)
	_ring.texture = RING_TEXTURE
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.shaded = false
	_ring.transparent = true
	_ring.double_sided = true
	_ring.centered = true
	_ring.no_depth_test = false
	_ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_ring.render_priority = -10
	_ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_ring.position = Vector3(0.0, ring_height, 0.0)
	_update_ring_size()


func _team_indicator_color() -> Color:
	match _resolve_team():
		&"friendly":
			return friendly_color
		&"enemy":
			return enemy_color
		&"neutral":
			return neutral_color
		_:
			return enemy_color


func _update_ring_size() -> void:
	if _ring == null:
		return
	var actor := get_node_or_null(team_source_path)
	if actor == null:
		actor = get_parent()
	var radius := fallback_collision_radius
	if actor != null:
		for child in actor.get_children():
			if child is CollisionShape3D and child.shape != null:
				var shape: Shape3D = child.shape
				if shape is CapsuleShape3D or shape is SphereShape3D or shape is CylinderShape3D:
					radius = float(shape.get("radius"))
					break
	var diameter := maxf(radius * 2.0, 0.1)
	var desired_width := diameter * ring_width_multiplier
	var desired_depth := diameter * ring_depth_multiplier
	_ring.pixel_size = desired_width / 256.0
	_ring.scale = Vector3(1.0, desired_depth / maxf(_ring.pixel_size * 128.0, 0.001), 1.0)


func _apply_toon_team_rim() -> void:
	var actor := get_node_or_null(team_source_path)
	if actor == null:
		actor = get_parent()
	if actor == null:
		return
	var team := _resolve_team()
	var tint := friendly_rim_color
	if team == &"enemy":
		tint = enemy_rim_color
	elif team == &"neutral":
		tint = neutral_rim_color
	var strength := team_rim_strength if team == &"friendly" or team == &"enemy" or team == &"neutral" else 0.0
	var model_roots := _find_model_roots(actor)
	if model_roots.is_empty():
		model_roots.append(actor)
	for model_root: Node in model_roots:
		for mesh in _find_meshes(model_root):
			if mesh.mesh == null:
				continue
			for surface_index in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface_index) as ShaderMaterial
				if material == null or material.shader != TOON_SHADER:
					var source_material := mesh.get_active_material(surface_index)
					if source_material is ShaderMaterial:
						continue
					material = ShaderMaterial.new()
					material.shader = TOON_SHADER
					var base_material := source_material as BaseMaterial3D
					if base_material != null:
						material.set_shader_parameter(&"base_color", base_material.albedo_color)
						material.set_shader_parameter(&"albedo_texture", base_material.albedo_texture)
						material.set_shader_parameter(&"use_albedo_texture", base_material.albedo_texture != null)
						material.set_shader_parameter(&"roughness", base_material.roughness)
					mesh.set_surface_override_material(surface_index, material)
				material.set_shader_parameter(&"team_color", tint)
				material.set_shader_parameter(&"team_rim_strength", strength)
				material.set_shader_parameter(&"team_rim_power", team_rim_power)


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and not node.name.begins_with("OutlineHighlight_"):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result


func _find_model_roots(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node.is_in_group(&"depth_sort_body"):
		result.append(node)
		return result
	for child in node.get_children():
		result.append_array(_find_model_roots(child))
	return result


func _resolve_team() -> StringName:
	var source := get_node_or_null(team_source_path)
	if source == null:
		source = get_parent()
	if source == null:
		return &""
	if source.has_method("get_team"):
		return StringName(source.call("get_team"))
	var team_value: Variant = source.get("team")
	if typeof(team_value) == TYPE_STRING or typeof(team_value) == TYPE_STRING_NAME:
		return StringName(team_value)
	return &""
