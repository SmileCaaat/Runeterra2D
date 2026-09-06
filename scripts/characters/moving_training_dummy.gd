extends "res://scripts/actors/monster_instance.gd"

@export_range(0.1, 5.0, 0.1) var wander_speed := 1.25
@export_range(0.5, 5.0, 0.1) var waypoint_tolerance := 0.65
@export var arena_min := Vector2(-7.5, -3.4)
@export var arena_max := Vector2(7.5, 3.4)
@export var max_health := 2400.0
@export_range(0.0, 1.0, 0.01) var critical_chance := 0.25
@export var critical_multiplier := 1.75

@onready var body_mesh: MeshInstance3D = $EnemyEditorPlaceholder
@onready var state_label: Label3D = $DummyStateLabel
@onready var hit_particles: CPUParticles3D = $HitSparkParticles
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio

var random := RandomNumberGenerator.new()
var waypoint := Vector3.ZERO
var wait_timer := 0.0
var hit_timer := 0.0
var hit_count := 0
var hit_sound_count := 0
var current_health := 2400.0
var silence_timer := 0.0
var stun_timer := 0.0
var skill_damage_count := 0
var knockback := Vector3.ZERO
var body_material: StandardMaterial3D
var normal_color := Color(0.784, 0.36, 0.384, 1.0)
var combat_database: CombatDatabase
var unit_definition: UnitDefinition
var attacker_definition: UnitDefinition
var ai_definition: AIProfileDefinition
var armor := 0.0
var magic_resistance := 0.0
var tenacity := 0.0
var knockback_decay := 12.0
var hit_audio_pitch_min := 0.94
var hit_audio_pitch_max := 1.06


func _ready() -> void:
	_apply_combat_data()
	random.seed = 20260815
	if ai_definition != null:
		random.seed = ai_definition.deterministic_seed
	current_health = max_health
	bind_monster_instance(combat_database, unit_definition)
	var source_material := body_mesh.material_override as StandardMaterial3D
	if source_material != null:
		body_material = source_material.duplicate() as StandardMaterial3D
		body_mesh.material_override = body_material
		normal_color = body_material.albedo_color
	_choose_waypoint()


func _physics_process(delta: float) -> void:
	silence_timer = maxf(0.0, silence_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	if hit_timer > 0.0:
		_update_hit_reaction(delta)
	elif stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	else:
		_update_wander(delta)

	if is_on_floor():
		velocity.y = float(combat_database.get_rule(&"combat.floor_stick_velocity", -0.1)) if combat_database != null else -0.1
	else:
		var gravity := float(combat_database.get_rule(&"combat.gravity", 20.0)) if combat_database != null else 20.0
		velocity.y -= gravity * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func receive_hit(attacker_position: Vector3, attack_name: StringName) -> void:
	var damage := attacker_definition.attack_damage if attacker_definition != null else 58.0
	var event := combat_database.get_animation_event(&"garen", attack_name, "hit") if combat_database != null else null
	var hit_profile_id: StringName = event.payload_id if event != null else &"basic_melee"
	_apply_damage(damage, String(attack_name), true, attacker_position, &"physical", hit_profile_id)


func receive_skill_damage(amount: float, skill_name: String, can_crit: bool, attacker_position: Vector3, damage_type: StringName = &"physical", hit_profile_id: StringName = &"basic_melee") -> void:
	skill_damage_count += 1
	_apply_damage(amount, skill_name, can_crit, attacker_position, damage_type, hit_profile_id)


func apply_silence(duration: float) -> void:
	var resolved := CombatMath.control_duration(duration, tenacity, combat_database) if combat_database != null else duration
	silence_timer = maxf(silence_timer, resolved)


func apply_stun(duration: float) -> void:
	var resolved := CombatMath.control_duration(duration, tenacity, combat_database) if combat_database != null else duration
	stun_timer = maxf(stun_timer, resolved)


func get_health_ratio() -> float:
	return current_health / maxf(max_health, 1.0)


func get_hit_contact_point(attacker_position: Vector3) -> Vector3:
	var away := global_position - attacker_position
	away.y = 0.0
	var contact_direction := -away.normalized() if not away.is_zero_approx() else Vector3.LEFT
	return global_position + contact_direction * 0.48 + Vector3.UP * 1.05


func _apply_damage(amount: float, source_name: String, can_crit: bool, attacker_position: Vector3, damage_type: StringName, hit_profile_id: StringName) -> void:
	hit_count += 1
	var hit_profile := combat_database.get_hit_profile(hit_profile_id) if combat_database != null else null
	hit_timer = hit_profile.hitstun if hit_profile != null else 0.24
	var critical := can_crit and random.randf() < critical_chance
	var raw_damage := amount * (critical_multiplier if critical else 1.0)
	var resolved_damage := CombatMath.resolve_damage(raw_damage, damage_type, armor, magic_resistance, combat_database) if combat_database != null else raw_damage
	var minimum_damage := float(combat_database.get_rule(&"damage.minimum_damage", 1.0)) if combat_database != null else 1.0
	resolved_damage = maxf(minimum_damage, resolved_damage)
	present_resolved_damage(resolved_damage, damage_type, critical)
	var health_floor := 1.0 if unit_definition != null and unit_definition.unit_type == "training_dummy" else 0.0
	current_health = maxf(health_floor, current_health - resolved_damage)
	var away := global_position - attacker_position
	away.y = 0.0
	var knockback_speed := hit_profile.knockback_speed if hit_profile != null else 2.8
	knockback_decay = hit_profile.knockback_decay if hit_profile != null else 12.0
	knockback = away.normalized() * knockback_speed
	var contact_point := get_hit_contact_point(attacker_position)
	hit_particles.call("burst", contact_point, away.normalized(), critical, hit_profile_id)
	if not CombatAudio.play_hit(hit_audio, combat_database, hit_profile, &"wood", critical, random):
		hit_audio.pitch_scale = random.randf_range(hit_audio_pitch_min, hit_audio_pitch_max)
		hit_audio.play()
	hit_sound_count += 1
	state_label.text = "%s%s · HP %d" % ["CRIT " if critical else "", source_name, int(current_health)]
	body_mesh.scale = Vector3(0.82, 1.12, 0.82)
	if body_material != null:
		body_material.albedo_color = Color(1.0, 0.9, 0.55, 1.0)


func _update_hit_reaction(delta: float) -> void:
	hit_timer -= delta
	velocity.x = knockback.x
	velocity.z = knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, knockback_decay * delta)
	if hit_timer <= 0.0:
		body_mesh.scale = Vector3.ONE
		if body_material != null:
			body_material.albedo_color = normal_color
		if stun_timer > 0.0:
			state_label.text = "移动木桩 · STUN %.1fs" % stun_timer
		elif silence_timer > 0.0:
			state_label.text = "移动木桩 · SILENCE %.1fs" % silence_timer
		else:
			state_label.text = "移动木桩 · HP %d/%d" % [int(current_health), int(max_health)]
		_choose_waypoint()


func _update_wander(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		return

	var offset := waypoint - global_position
	offset.y = 0.0
	if offset.length() <= waypoint_tolerance:
		var wait_min := ai_definition.wander_wait_min if ai_definition != null else 0.25
		var wait_max := ai_definition.wander_wait_max if ai_definition != null else 0.8
		wait_timer = random.randf_range(wait_min, wait_max)
		_choose_waypoint()
		return
	var direction := offset.normalized()
	velocity.x = direction.x * wander_speed
	velocity.z = direction.z * wander_speed


func _choose_waypoint() -> void:
	waypoint = Vector3(
		random.randf_range(arena_min.x, arena_max.x),
		0.0,
		random.randf_range(arena_min.y, arena_max.y),
	)


func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		push_warning("Combat database is unavailable; using inspector fallback values")
		return
	unit_definition = combat_database.get_unit(&"training_dummy")
	attacker_definition = combat_database.get_unit(&"garen")
	if unit_definition != null:
		max_health = unit_definition.max_health
		wander_speed = unit_definition.move_speed
		armor = unit_definition.armor
		magic_resistance = unit_definition.magic_resistance
		tenacity = unit_definition.tenacity
		ai_definition = combat_database.get_ai_profile(unit_definition.ai_profile_id)
	if attacker_definition != null:
		critical_chance = attacker_definition.critical_chance
		critical_multiplier = attacker_definition.critical_damage
	if ai_definition != null:
		waypoint_tolerance = ai_definition.waypoint_tolerance
		arena_min = ai_definition.arena_min
		arena_max = ai_definition.arena_max
	var audio_profile := CombatAudio.configure_player(hit_audio, combat_database, &"garen_basic_hit_wood")
	if audio_profile != null:
		hit_audio_pitch_min = audio_profile.pitch_min
		hit_audio_pitch_max = audio_profile.pitch_max
