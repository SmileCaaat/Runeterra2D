class_name MeshAfterimage3D
extends Node

const AFTERIMAGE_SHADER := preload("res://assets/shaders/mesh_afterimage_3d.gdshader")

@export var lifetime := 0.22
@export var color := Color(0.16, 0.72, 1.0, 0.32)

var _ghosts: Array[Dictionary] = []


func capture(source: Node3D) -> void:
	if source == null or not is_instance_valid(source) or get_tree().current_scene == null:
		return
	var ghost := source.duplicate() as Node3D
	if ghost == null:
		return
	ghost.name = "MeshAfterimage"
	ghost.set_script(null)
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = source.global_transform
	for animator: AnimationPlayer in _find_nodes(ghost, AnimationPlayer):
		animator.stop()
	for mesh: MeshInstance3D in _find_nodes(ghost, MeshInstance3D):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = AFTERIMAGE_SHADER
		material.set_shader_parameter(&"ghost_color", color)
		mesh.material_override = material
	_ghosts.append({"node": ghost, "age": 0.0})


func _process(delta: float) -> void:
	for item: Dictionary in _ghosts.duplicate():
		var ghost := item.node as Node3D
		if ghost == null or not is_instance_valid(ghost):
			_ghosts.erase(item)
			continue
		item.age = float(item.age) + delta
		var progress := clampf(float(item.age) / maxf(lifetime, 0.01), 0.0, 1.0)
		for mesh: MeshInstance3D in _find_nodes(ghost, MeshInstance3D):
			var material := mesh.material_override as ShaderMaterial
			if material != null:
				material.set_shader_parameter(&"ghost_color", Color(color.r, color.g, color.b, color.a * (1.0 - progress) * (1.0 - progress)))
		if progress >= 1.0:
			ghost.queue_free()
			_ghosts.erase(item)


func _find_nodes(node: Node, type: Variant) -> Array:
	var result: Array = []
	if is_instance_of(node, type):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes(child, type))
	return result
