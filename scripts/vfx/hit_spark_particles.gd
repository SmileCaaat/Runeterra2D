extends CPUParticles3D

const NORMAL_HIT_TEXTURE := preload("res://assets/vfx/hit/hit_yellow1.png")
const CRITICAL_HIT_TEXTURE := preload("res://assets/vfx/hit/hit_yellow2.png")
const HIT_IMPACT_POOL_SCRIPT := preload("res://scripts/vfx/hit_impact_pool_3d.gd")
const SYSTEM_CONFIG := preload("res://assets/vfx/hit/hit_impact_system.tres")
const SHEET_COLUMNS := 4
const SHEET_ROWS := 4
const FRAME_COUNT := SHEET_COLUMNS * SHEET_ROWS

var burst_count := 0
var last_critical := false
var hit_sprite: Sprite3D
var playback_elapsed := 0.0
var playback_duration := 0.32
var playback_active := false
var impact_pool: Node


func _ready() -> void:
	# Keep the existing node type/API so unit scenes and gameplay callers remain compatible,
	# but render the new sequence instead of emitting procedural particles.
	emitting = false
	amount = 1
	mesh = null
	set_process(false)

	hit_sprite = Sprite3D.new()
	hit_sprite.name = "HitSequence"
	hit_sprite.texture = NORMAL_HIT_TEXTURE
	hit_sprite.hframes = SHEET_COLUMNS
	hit_sprite.vframes = SHEET_ROWS
	hit_sprite.frame = 0
	hit_sprite.pixel_size = SYSTEM_CONFIG.normal_sequence_pixel_size
	hit_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hit_sprite.shaded = false
	hit_sprite.no_depth_test = true
	hit_sprite.render_priority = 40
	hit_sprite.visible = false
	add_child(hit_sprite)
	call_deferred(&"_bind_impact_pool")


func _process(delta: float) -> void:
	if not playback_active:
		return
	playback_elapsed += delta
	var frame_index := mini(int(playback_elapsed / playback_duration * FRAME_COUNT), FRAME_COUNT - 1)
	hit_sprite.frame = frame_index
	if playback_elapsed >= playback_duration:
		playback_active = false
		hit_sprite.visible = false
		set_process(false)


func burst(
	world_contact: Vector3,
	impact_direction: Vector3,
	critical: bool = false,
	hit_profile_id: StringName = &"basic_melee"
) -> void:
	global_position = world_contact
	last_critical = critical
	hit_sprite.texture = CRITICAL_HIT_TEXTURE if critical else NORMAL_HIT_TEXTURE
	hit_sprite.pixel_size = SYSTEM_CONFIG.critical_sequence_pixel_size if critical else SYSTEM_CONFIG.normal_sequence_pixel_size
	hit_sprite.flip_h = impact_direction.x < 0.0
	hit_sprite.frame = 0
	hit_sprite.visible = true
	playback_duration = SYSTEM_CONFIG.critical_sequence_duration if critical else SYSTEM_CONFIG.normal_sequence_duration
	playback_elapsed = 0.0
	playback_active = true
	set_process(true)
	burst_count += 1
	if impact_pool == null:
		impact_pool = HIT_IMPACT_POOL_SCRIPT.get_or_create(self)
	if impact_pool != null:
		impact_pool.play(world_contact, impact_direction, _resolve_procedural_profile(hit_profile_id, critical))


func _bind_impact_pool() -> void:
	if is_inside_tree() and impact_pool == null:
		impact_pool = HIT_IMPACT_POOL_SCRIPT.get_or_create(self)


func _resolve_procedural_profile(hit_profile_id: StringName, critical: bool) -> StringName:
	if critical:
		return SYSTEM_CONFIG.critical_profile_id
	return SYSTEM_CONFIG.hit_profile_map.get(hit_profile_id, &"normal")
