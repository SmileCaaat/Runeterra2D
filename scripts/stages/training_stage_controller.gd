extends Node3D

const STAGE_LAYOUT_CATALOG := preload("res://scripts/stages/stage_layout_catalog.gd")

@export var stage_profile_id: StringName = &"small"
@export var stage_display_name := "训练场"

var active_stage_profile: Dictionary = {}


func _ready() -> void:
	var profiles: Dictionary = STAGE_LAYOUT_CATALOG.load_profiles()
	active_stage_profile = profiles.get(stage_profile_id, {})
	if active_stage_profile.is_empty():
		push_error("Missing stage layout profile: %s" % stage_profile_id)
		return
	_apply_stage_collision_dimensions(active_stage_profile)
	set_meta(&"stage_display_name", stage_display_name)
	set_meta(&"stage_profile_id", stage_profile_id)
	set_meta(&"stage_mode", &"training")


func _apply_stage_collision_dimensions(profile: Dictionary) -> void:
	var world_length := float(profile.world_length)
	var playable_depth := float(profile.playable_depth)

	var ground_shape := $World/Ground/GroundCollision.shape as BoxShape3D
	ground_shape.size = Vector3(world_length, 0.5, playable_depth)

	$World/Architecture/BackWall.position = Vector3(0.0, 1.5, -playable_depth * 0.5)
	$World/StageBounds/FrontLimit.position = Vector3(0.0, 1.5, playable_depth * 0.5)
	$World/Architecture/LeftWall.position = Vector3(-world_length * 0.5, 1.5, 0.0)
	$World/StageBounds/RightLimit.position = Vector3(world_length * 0.5, 1.5, 0.0)

	($World/Architecture/BackWall/BackWallCollision.shape as BoxShape3D).size = Vector3(world_length, 3.0, 0.3)
	($World/StageBounds/FrontLimit/FrontCollision.shape as BoxShape3D).size = Vector3(world_length, 3.0, 0.3)
	($World/Architecture/LeftWall/LeftWallCollision.shape as BoxShape3D).size = Vector3(0.3, 3.0, playable_depth)
	($World/StageBounds/RightLimit/RightCollision.shape as BoxShape3D).size = Vector3(0.3, 3.0, playable_depth)
