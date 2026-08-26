class_name AssetProfileDefinition
extends Resource

@export var id: StringName
@export_enum("character_animation", "skill_vfx", "passive_vfx", "particle_vfx", "hit_vfx", "combat_text_font", "skill_icon", "status_icon", "audio") var asset_type := "skill_vfx"
@export var resource_file := ""
@export var node_path := ""
@export var animation_name: StringName
@export var audio_path := ""
@export var volume_db := 0.0
@export var pitch_min := 1.0
@export var pitch_max := 1.0
@export var max_distance := 20.0
@export var scale := Vector3.ONE
@export var offset := Vector2.ZERO
@export var pixel_size := 0.005
@export var local_position := Vector3.ZERO
@export_range(0.0, 1.0, 0.001) var opacity := 1.0
@export var render_priority := 0
@export var no_depth_test := false
@export var shader_material_path := ""
@export_enum("animation", "buff", "duration", "manual") var lifecycle := "animation"
@export var duration := 0.0
@export var flip_with_facing := false
