class_name MeshOutlineHighlight3D
extends Node3D

## Generic inverted-hull highlight. It has no knowledge of actor factions;
## callers opt into one of the explicit interaction states below.

const OUTLINE_SHADER := preload("res://assets/shaders/mesh_outline_highlight_3d.gdshader")

@export var selected_color := Color(0.78, 0.96, 1.0, 1.0)
@export var targeted_color := Color(1.0, 0.34, 0.14, 1.0)
@export var highlighted_color := Color(1.0, 0.82, 0.36, 1.0)
@export_range(0.001, 0.04, 0.001) var selected_width := 0.006
@export_range(0.001, 0.04, 0.001) var targeted_width := 0.009
@export_range(0.001, 0.04, 0.001) var highlighted_width := 0.012

var _pairs: Array[Dictionary] = []
var _built := false
var _selected := false
var _targeted := false
var _highlighted := false


func _ready() -> void:
	_built = false
	_pairs.clear()
	call_deferred(&"_rebuild_outlines", get_parent())


func set_selected(active: bool) -> void:
	_selected = active
	_refresh_outline_state()


func set_targeted(active: bool) -> void:
	_targeted = active
	_refresh_outline_state()


func set_highlighted(active: bool) -> void:
	_highlighted = active
	_refresh_outline_state()


func is_selected() -> bool:
	return _selected


func is_targeted() -> bool:
	return _targeted


func is_highlighted() -> bool:
	return _highlighted


func _process(_delta: float) -> void:
	_refresh_outline_state()


func _refresh_outline_state() -> void:
	var color := Color.WHITE
	var active_width := 0.0
	if _selected:
		color = selected_color
		active_width = selected_width
	elif _targeted:
		color = targeted_color
		active_width = targeted_width
	elif _highlighted:
		color = highlighted_color
		active_width = highlighted_width
	for pair in _pairs:
		var source := pair.get("source") as MeshInstance3D
		var outline := pair.get("outline") as MeshInstance3D
		if source == null or outline == null or not is_instance_valid(source) or not is_instance_valid(outline):
			continue
		outline.visible = active_width > 0.0 and source.is_visible_in_tree()
		var material := outline.material_override as ShaderMaterial
		if material != null and active_width > 0.0:
			material.set_shader_parameter(&"outline_color", color)
			material.set_shader_parameter(&"outline_width", active_width)


func _rebuild_outlines(root: Node) -> void:
	if root == null:
		return
	_remove_generated_outlines(root)
	_build_outlines(root)
	_refresh_outline_state()


func _remove_generated_outlines(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.name.begins_with("OutlineHighlight_"):
			child.visible = false
			node.remove_child(child)
			child.queue_free()
			continue
		_remove_generated_outlines(child)


func _build_outlines(root: Node) -> void:
	if _built:
		return
	_built = true
	var model_roots := _find_model_roots(root)
	if model_roots.is_empty():
		model_roots.append(root)
	for model_root: Node in model_roots:
		for source: MeshInstance3D in _find_meshes(model_root):
			if source.name.begins_with("OutlineHighlight_") or source.mesh == null:
				continue
			var outline := MeshInstance3D.new()
			outline.name = "OutlineHighlight_%s" % source.name
			outline.mesh = source.mesh
			outline.skin = source.skin
			outline.transform = source.transform
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			outline.visible = false
			var material := ShaderMaterial.new()
			material.shader = OUTLINE_SHADER
			outline.material_override = material
			source.get_parent().add_child(outline)
			var skeleton_node := source.get_node_or_null(source.skeleton) as Skeleton3D
			if skeleton_node != null:
				outline.skeleton = outline.get_path_to(skeleton_node)
			_pairs.append({"source": source, "outline": outline})


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
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
