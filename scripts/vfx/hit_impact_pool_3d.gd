class_name HitImpactPool3D
extends Node3D

const HIT_EFFECT_SCRIPT := preload("res://scripts/vfx/procedural_hit_effect_2d.gd")

const SYSTEM_CONFIG := preload("res://assets/vfx/hit/hit_impact_system.tres")

var slots: Array[Dictionary] = []
var cursor := 0
var play_count := 0
var last_profile_id: StringName
var profiles_by_id: Dictionary[StringName, Resource] = {}


static func get_or_create(source: Node) -> Node:
	var tree := source.get_tree()
	var existing := tree.get_first_node_in_group(&"hit_impact_vfx_pool")
	if existing != null:
		return existing
	var pool: Node = (load("res://scripts/vfx/hit_impact_pool_3d.gd") as Script).new()
	pool.name = "HitImpactVFXPool"
	tree.root.add_child(pool)
	return pool


func _ready() -> void:
	add_to_group(&"hit_impact_vfx_pool")
	for profile: Resource in SYSTEM_CONFIG.profiles:
		profiles_by_id[StringName(profile.get("id"))] = profile
	for index: int in range(SYSTEM_CONFIG.pool_size):
		_build_slot(index)
	set_process(false)


func play(
	world_position: Vector3,
	world_direction: Vector3,
	profile_id: StringName = &"normal"
) -> void:
	if slots.is_empty():
		return
	var resolved_id := profile_id if profiles_by_id.has(profile_id) else &"normal"
	var profile: Variant = profiles_by_id[resolved_id]
	var slot := slots[cursor]
	cursor = (cursor + 1) % slots.size()

	var sprite := slot.sprite as Sprite3D
	var effect := slot.effect as Node2D
	var viewport := slot.viewport as SubViewport
	sprite.global_position = world_position
	sprite.pixel_size = SYSTEM_CONFIG.base_pixel_size * profile.world_scale
	sprite.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var direction_2d := Vector2(world_direction.x, -world_direction.z * 0.4)
	effect.play(profile, direction_2d)
	slot.elapsed = 0.0
	slot.duration = profile.duration + 0.08
	slots[(cursor - 1 + slots.size()) % slots.size()] = slot
	play_count += 1
	last_profile_id = resolved_id
	set_process(true)


func _process(delta: float) -> void:
	var any_active := false
	for index: int in range(slots.size()):
		var slot := slots[index]
		var sprite := slot.sprite as Sprite3D
		if not sprite.visible:
			continue
		slot.elapsed = float(slot.elapsed) + delta
		if float(slot.elapsed) >= float(slot.duration):
			sprite.visible = false
			(slot.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			any_active = true
		slots[index] = slot
	if not any_active:
		set_process(false)


func _build_slot(index: int) -> void:
	var viewport := SubViewport.new()
	viewport.name = "HitViewport%d" % index
	viewport.size = SYSTEM_CONFIG.viewport_size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)

	var effect := HIT_EFFECT_SCRIPT.new() as Node2D
	effect.name = "ProceduralHitEffect"
	effect.position = Vector2(SYSTEM_CONFIG.viewport_size) * 0.5
	viewport.add_child(effect)

	var sprite := Sprite3D.new()
	sprite.name = "HitImpactSprite%d" % index
	sprite.texture = viewport.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 39
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.visible = false
	add_child(sprite)

	slots.append({
		"viewport": viewport,
		"effect": effect,
		"sprite": sprite,
		"elapsed": 0.0,
		"duration": 0.0,
	})
