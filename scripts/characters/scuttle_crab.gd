extends "res://scripts/actors/monster_instance.gd"

const STATUS_ICON_SLOTS := preload("res://scripts/presentation/status_icon_slots.gd")
const ARMOR_SHRED_BURST := preload("res://scripts/presentation/status_debuff_burst.gd")

signal return_completed(killer_team: StringName)
signal defeated(killer_team: StringName)

@export var level := 1
@export var first_spawn_form := true
@export var calm_move_speed := 1.55
@export var combat_move_speed := 2.55
@export var dash_move_speed := 7.5
@export var flee_duration := 3.0
@export var max_path_deviation := 2.0
@export var waypoint_tolerance := 0.25
@export var gameplay_radius := 0.50
@export var armor := 42.0
@export var magic_resistance := 42.0
@export var source_faces_right := true
@export var acceleration := 16.0
@export var death_return_tolerance := 0.12
@export var death_fade_duration := 0.38
@export var hurt_visual_duration := 0.12

@onready var collision_shape: CollisionShape3D = $Collision
@onready var frames: AnimatedSprite3D = $Frames
@onready var shadow: Sprite3D = $GroundShadow
@onready var label: Label3D = $StateLabel
@onready var hit_particles: CPUParticles3D = $HitSparkParticles
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio

var max_health := 1007.5
var current_health := 1007.5
var path_points := PackedVector3Array()
var waypoint_index := 0
var flee_timer := 0.0
var hurt_timer := 0.0
var last_threat_position := Vector3.ZERO
var killer_team: StringName = &"friendly"
var center_position := Vector3.ZERO
var spawn_position := Vector3.ZERO
var returning_on_death := false
var returning_to_navigation_origin := false
var dissolving := false
var random := RandomNumberGenerator.new()
var combat_database: CombatDatabase
var base_armor := 42.0
var armor_shred_timer := 0.0
var armor_shred_ratio := 0.0
var normal_shield := 0.0
var status_icon_slots: StatusIconSlots
var armor_shred_burst: StatusDebuffBurst
var unit_definition: UnitDefinition
var ai_definition: AIProfileDefinition
var attacker_definition: UnitDefinition
var hit_audio_pitch_min := 0.94
var hit_audio_pitch_max := 1.06

func _ready() -> void:
	spawn_position = global_position
	_apply_combat_data()
	base_armor = armor
	status_icon_slots = STATUS_ICON_SLOTS.new()
	status_icon_slots.name = "StatusIconSlots"
	add_child(status_icon_slots)
	armor_shred_burst = ARMOR_SHRED_BURST.get_or_create(self)
	bind_monster_instance(combat_database, unit_definition)
	random.seed = 20260824 + get_instance_id()
	max_health = _health_for_level()
	current_health = max_health
	add_to_group(&"neutral_actor")
	add_to_group(&"monster_actor")
	add_to_group(&"combat_target")
	frames.play(&"spawn")
	_update_label()

func configure_route(points: PackedVector3Array, arena_center: Vector3) -> void:
	path_points = points
	center_position = arena_center
	# Death is a presentation return to the concrete spawn anchor. Keep it
	# independent from navigation recovery so later route changes cannot move it.
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	_update_armor_shred(delta)
	_sync_frame_material()
	if dissolving:
		velocity = Vector3.ZERO
		return
	if returning_on_death:
		_update_death_return(delta)
		return
	flee_timer = maxf(0.0, flee_timer - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	var nearest := _nearest_path_point()
	var off_path := not path_points.is_empty() and _horizontal_distance(global_position, nearest) > max_path_deviation
	if returning_to_navigation_origin:
		_update_navigation_return(delta)
	elif off_path:
		_begin_navigation_return()
		_move_toward(center_position, dash_move_speed, delta, &"dash")
	elif flee_timer > 0.0:
		var away := global_position - last_threat_position
		away.y = 0.0
		if away.is_zero_approx(): away = Vector3.RIGHT
		_move_direction(away.normalized(), combat_move_speed, delta, &"run")
	else:
		_patrol(delta)
	_apply_gravity(delta)
	move_and_slide()
	if flee_timer > 0.0 and _collided_with_stage_boundary():
		_begin_navigation_return()
	_update_label()

func receive_hit(attacker_position: Vector3, attack_name: StringName) -> void:
	var damage := attacker_definition.attack_damage if attacker_definition != null else 69.0
	var event := combat_database.get_animation_event(&"garen", attack_name, "hit") if combat_database != null else null
	var hit_profile_id: StringName = event.payload_id if event != null else &"basic_melee"
	_apply_damage(damage, attacker_position, &"physical", true, hit_profile_id)

func receive_skill_damage(amount: float, _skill_name: String, _can_crit: bool, attacker_position: Vector3, damage_type: StringName = &"physical", _hit_profile_id: StringName = &"basic_melee") -> void:
	_apply_damage(amount, attacker_position, damage_type, _can_crit, _hit_profile_id)


func receive_breaker_attack(base_attack: float, bonus_damage: float, attacker_position: Vector3, hit_profile_id: StringName = &"breaker_hit") -> void:
	# Keep Q's base attack crit separate from its non-crit bonus, but emit one hit reaction.
	_apply_damage(base_attack, attacker_position, &"physical", true, hit_profile_id, bonus_damage)

func register_damage_source(attacker_position: Vector3, source_team: StringName) -> void:
	last_threat_position = attacker_position
	killer_team = source_team

func apply_silence(_duration: float) -> void:
	_trigger_flee(last_threat_position)

func apply_stun(_duration: float) -> void:
	_trigger_flee(last_threat_position)


func apply_armor_shred(duration: float, reduction_ratio: float) -> void:
	armor_shred_timer = maxf(armor_shred_timer, duration)
	armor_shred_ratio = clampf(reduction_ratio, 0.0, 0.95)
	armor = base_armor * (1.0 - armor_shred_ratio)
	armor_shred_burst.play_burst()


func _update_armor_shred(delta: float) -> void:
	if armor_shred_timer <= 0.0:
		return
	armor_shred_timer = maxf(0.0, armor_shred_timer - delta)
	if armor_shred_timer <= 0.0:
		armor_shred_ratio = 0.0
		armor = base_armor

func get_team() -> StringName:
	return &"neutral"

func is_enemy_of(other_team: StringName) -> bool:
	return other_team != &"neutral"

func is_targetable() -> bool:
	return not returning_on_death and not dissolving

func get_health_ratio() -> float:
	return current_health / maxf(max_health, 1.0)


func apply_normal_shield(amount: float) -> void:
	normal_shield = maxf(0.0, normal_shield + amount)


func get_normal_shield() -> float:
	return normal_shield

func _apply_damage(amount: float, attacker_position: Vector3, damage_type: StringName, can_crit: bool, hit_profile_id: StringName, flat_post_crit_bonus: float = 0.0) -> void:
	if not is_targetable(): return
	last_threat_position = attacker_position
	var critical_chance := attacker_definition.critical_chance if attacker_definition != null else 0.0
	var critical_damage := attacker_definition.critical_damage if attacker_definition != null else 1.75
	var critical := can_crit and random.randf() < critical_chance
	var raw_damage := amount * (critical_damage if critical else 1.0) + flat_post_crit_bonus
	var hit_profile := combat_database.get_hit_profile(hit_profile_id) if combat_database != null else null
	var damage := CombatMath.resolve_damage(
		raw_damage, damage_type, armor, magic_resistance, combat_database
	) if combat_database != null else raw_damage
	damage = maxf(_rule_float(&"damage.minimum_damage", 1.0), damage)
	present_resolved_damage(damage, damage_type, critical)
	var health_damage := maxf(0.0, damage - normal_shield)
	normal_shield = maxf(0.0, normal_shield - damage)
	current_health = maxf(0.0, current_health - health_damage)
	_trigger_flee(attacker_position)
	if returning_to_navigation_origin:
		hurt_timer = 0.0
		frames.play(&"dash")
	else:
		hurt_timer = hurt_visual_duration
		frames.play(&"hurt")
	var away := global_position - attacker_position
	away.y = 0.0
	if away.is_zero_approx(): away = Vector3.RIGHT
	hit_particles.call("burst", global_position + Vector3.UP * 0.7, away.normalized(), critical, hit_profile_id)
	if not CombatAudio.play_hit(hit_audio, combat_database, hit_profile, &"flesh", critical, random):
		hit_audio.pitch_scale = random.randf_range(hit_audio_pitch_min, hit_audio_pitch_max)
		hit_audio.play()
	if current_health <= 0.0:
		_begin_death_return()
	_update_label()

func _trigger_flee(source: Vector3) -> void:
	last_threat_position = source
	if not returning_to_navigation_origin:
		flee_timer = flee_duration

func _begin_navigation_return() -> void:
	returning_to_navigation_origin = true
	flee_timer = 0.0
	hurt_timer = 0.0
	set_ghost_collision_active(true)
	frames.play(&"dash")

func _update_navigation_return(delta: float) -> void:
	if _horizontal_distance(global_position, center_position) > waypoint_tolerance:
		_move_toward(center_position, dash_move_speed, delta, &"dash")
		return
	global_position.x = center_position.x
	global_position.z = center_position.z
	velocity.x = 0.0
	velocity.z = 0.0
	flee_timer = 0.0
	returning_to_navigation_origin = false
	set_ghost_collision_active(false)
	frames.play(&"run" if not path_points.is_empty() else &"idle")

func _collided_with_stage_boundary() -> bool:
	for index: int in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group(&"stage_bound"):
			return true
	return false

func _begin_death_return() -> void:
	returning_on_death = true
	flee_timer = 0.0
	remove_from_group(&"combat_target")
	collision_shape.set_deferred(&"disabled", true)
	label.visible = false
	frames.modulate = Color(0.78, 0.95, 1.0, 1.0)
	frames.play(&"dash")
	defeated.emit(killer_team)

func _update_death_return(delta: float) -> void:
	var distance := _horizontal_distance(global_position, spawn_position)
	if distance > death_return_tolerance:
		var destination := Vector3(spawn_position.x, global_position.y, spawn_position.z)
		var direction := (destination - global_position).normalized()
		_face_direction(direction)
		frames.play(&"dash")
		global_position = global_position.move_toward(destination, dash_move_speed * delta)
		velocity = direction * dash_move_speed
		return
	global_position.x = spawn_position.x
	global_position.z = spawn_position.z
	velocity = Vector3.ZERO
	_start_dissolve()

func _start_dissolve() -> void:
	if dissolving: return
	dissolving = true
	frames.pause()
	var material := frames.material_override as ShaderMaterial
	if material != null:
		material = material.duplicate() as ShaderMaterial
		frames.material_override = material
		material.set_shader_parameter(&"dissolve_amount", 0.0)
		material.set_shader_parameter(&"tint", Color.WHITE)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(
			func(value: float) -> void: material.set_shader_parameter(&"tint", Color(1.0, 1.0, 1.0, value)),
			1.0, 0.0, death_fade_duration
		)
		tween.parallel().tween_property(shadow, "modulate:a", 0.0, death_fade_duration)
		tween.finished.connect(_finish_death)
	else:
		_finish_death()

func _finish_death() -> void:
	return_completed.emit(killer_team)
	queue_free()

func _patrol(delta: float) -> void:
	if path_points.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		if hurt_timer <= 0.0: frames.play(&"idle")
		return
	var destination := path_points[waypoint_index]
	if _horizontal_distance(global_position, destination) <= waypoint_tolerance:
		waypoint_index = (waypoint_index + 1) % path_points.size()
		destination = path_points[waypoint_index]
	_move_toward(destination, calm_move_speed, delta, &"run")

func _move_toward(destination: Vector3, speed: float, delta: float, animation: StringName) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	_move_direction(direction.normalized(), speed, delta, animation)

func _move_direction(direction: Vector3, speed: float, delta: float, animation: StringName) -> void:
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	_face_direction(direction)
	if hurt_timer <= 0.0 and frames.animation != animation: frames.play(animation)

func _face_direction(direction: Vector3) -> void:
	if absf(direction.x) < 0.02: return
	var flip := direction.x < 0.0 if source_faces_right else direction.x > 0.0
	frames.flip_h = flip

func _nearest_path_point() -> Vector3:
	if path_points.is_empty(): return center_position
	if path_points.size() == 1: return path_points[0]
	var nearest := path_points[0]
	var best := INF
	for index: int in range(path_points.size()):
		var segment_start := path_points[index]
		var segment_end := path_points[(index + 1) % path_points.size()]
		var point := _closest_point_on_path_segment(global_position, segment_start, segment_end)
		var distance := _horizontal_distance(global_position, point)
		if distance < best: best = distance; nearest = point
	return nearest

func _closest_point_on_path_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> Vector3:
	var start_2d := Vector2(segment_start.x, segment_start.z)
	var end_2d := Vector2(segment_end.x, segment_end.z)
	var point_2d := Vector2(point.x, point.z)
	var segment := end_2d - start_2d
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return segment_start
	var ratio := clampf((point_2d - start_2d).dot(segment) / length_squared, 0.0, 1.0)
	var projected := start_2d + segment * ratio
	return Vector3(projected.x, segment_start.y, projected.y)

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _apply_gravity(delta: float) -> void:
	var floor_velocity := _rule_float(&"combat.floor_stick_velocity", -0.1)
	var gravity := _rule_float(&"combat.gravity", 20.0)
	velocity.y = floor_velocity if is_on_floor() else velocity.y - gravity * delta

func _health_for_level() -> float:
	if combat_database != null:
		var stat_id := &"max_health" if first_spawn_form else &"normal_max_health"
		var configured := combat_database.get_unit_stat_value(&"scuttle_crab", stat_id, level)
		if configured > 0.0:
			return configured
	var clamped_level := clampi(level, 1, 18)
	var base := 1007.5 if first_spawn_form else 1550.0
	var growth := 142.235294 if first_spawn_form else 218.823529
	return base + growth * float(clamped_level - 1)

func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		push_warning("Combat database is unavailable; Scuttle Crab is using inspector fallbacks")
		return
	unit_definition = combat_database.get_unit(&"scuttle_crab")
	attacker_definition = combat_database.get_unit(&"garen")
	if unit_definition != null:
		combat_move_speed = unit_definition.move_speed
		acceleration = unit_definition.acceleration
		armor = unit_definition.armor
		magic_resistance = unit_definition.magic_resistance
		gameplay_radius = combat_database.get_unit_stat_value(&"scuttle_crab", &"gameplay_radius", level)
		calm_move_speed = combat_database.get_unit_stat_value(&"scuttle_crab", &"out_of_combat_move_speed", level)
		dash_move_speed = combat_database.get_unit_stat_value(&"scuttle_crab", &"dash_move_speed", level)
		max_path_deviation = combat_database.get_unit_stat_value(&"scuttle_crab", &"navigation_leash_radius", level)
		ai_definition = combat_database.get_ai_profile(unit_definition.ai_profile_id)
	if ai_definition != null:
		waypoint_tolerance = ai_definition.waypoint_tolerance
	flee_duration = _rule_float(&"scuttle.flee_duration", flee_duration)
	death_return_tolerance = _rule_float(&"scuttle.death_return_tolerance", death_return_tolerance)
	death_fade_duration = _rule_float(&"scuttle.death_fade_duration", death_fade_duration)
	hurt_visual_duration = _rule_float(&"scuttle.hurt_visual_duration", hurt_visual_duration)
	var audio_profile := CombatAudio.configure_player(hit_audio, combat_database, &"garen_basic_hit_flesh")
	if audio_profile != null:
		hit_audio_pitch_min = audio_profile.pitch_min
		hit_audio_pitch_max = audio_profile.pitch_max

func _rule_float(rule_id: StringName, fallback: float) -> float:
	return float(combat_database.get_rule(rule_id, fallback)) if combat_database != null else fallback

func _sync_frame_material() -> void:
	var material := frames.material_override as ShaderMaterial
	if material != null and frames.sprite_frames != null:
		var frame_texture := frames.sprite_frames.get_frame_texture(frames.animation, frames.frame)
		material.set_shader_parameter(&"texture_albedo", frame_texture)

func _update_label() -> void:
	label.text = "峡谷迅捷蟹 · LV%d  HP %.0f/%.0f" % [level, current_health, max_health]

func _on_animation_finished() -> void:
	if frames.animation == &"spawn" or frames.animation == &"hurt":
		frames.play(&"run" if not path_points.is_empty() else &"idle")
