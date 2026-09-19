extends Node3D

## Soft foot-ring faction marker beside GroundShadow: thin, low-alpha, blue/red.
## Neutrals hide the ring. Call refresh_team_visuals() after team changes.

const RING_TEXTURE := preload("res://assets/fx/soft_team_ground_ring.svg")

@export_node_path("AnimatedSprite3D") var source_sprite_path: NodePath
@export_node_path("Node") var team_source_path := NodePath("..")
@export var ring_pixel_size := 0.0056
@export var ring_height := 0.022
@export var friendly_color := Color(0.34, 0.74, 1.0, 0.34)
@export var enemy_color := Color(1.0, 0.40, 0.40, 0.34)

var _ring: Sprite3D


func _ready() -> void:
	_ensure_ring()
	refresh_team_visuals()


func refresh_team_visuals() -> void:
	_ensure_ring()
	if _ring == null:
		return
	var team := _resolve_team()
	match team:
		&"friendly":
			_ring.visible = true
			_ring.modulate = friendly_color
		&"enemy":
			_ring.visible = true
			_ring.modulate = enemy_color
		_:
			_ring.visible = false


func _ensure_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		return
	_ring = get_node_or_null("TeamGroundRing") as Sprite3D
	if _ring == null:
		_ring = Sprite3D.new()
		_ring.name = "TeamGroundRing"
		add_child(_ring)
	_ring.texture = RING_TEXTURE
	_ring.pixel_size = ring_pixel_size
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.shaded = false
	_ring.transparent = true
	_ring.double_sided = true
	_ring.centered = true
	_ring.no_depth_test = true
	_ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_ring.render_priority = -9
	_ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_ring.position = Vector3(0.0, ring_height, 0.0)


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
