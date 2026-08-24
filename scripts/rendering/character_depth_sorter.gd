extends Node3D

const DEPTH_SORT_BODY_GROUP := &"depth_sort_body"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred(&"_configure_all_bodies")


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _configure_all_bodies() -> void:
	for node: Node in get_tree().get_nodes_in_group(DEPTH_SORT_BODY_GROUP):
		_configure_body(node)


func _on_node_added(node: Node) -> void:
	if node.is_in_group(DEPTH_SORT_BODY_GROUP):
		_configure_body.call_deferred(node)


func _configure_body(node: Node) -> void:
	var sprite := node as SpriteBase3D
	if sprite == null:
		return
	# Keep every body at one priority so Godot can sort transparent sprites
	# back-to-front from the actor/foot origin instead of the animation AABB.
	sprite.render_priority = 0
	sprite.sorting_use_aabb_center = false
