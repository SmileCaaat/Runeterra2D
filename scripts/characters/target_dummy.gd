extends "res://scripts/actors/monster_instance.gd"

const STATUS_ICON_SLOTS := preload("res://scripts/presentation/status_icon_slots.gd")
const ARMOR_SHRED_BURST := preload("res://scripts/presentation/status_debuff_burst.gd")

@export_enum("friendly", "enemy") var team := "enemy"
@export var max_health := 1000.0
@export var attack_damage := 0.0
@export var attack_speed := 0.66
@export var attack_range := 1.75
@export var armor := 0.0
@export var magic_resistance := 0.0
@export var move_speed := 3.70
@export var gameplay_radius := 0.65
@export var pathing_radius := 0.30
@export var damage_reset_delay := 3.0
@export var respawn_delay := 3.0
@export var return_home_delay := 0.35
@export var return_home_tolerance := 0.08
@export var face_attacker_duration := 3.0
@export var source_faces_left := false
@export_range(0.0, 1.0, 0.01) var critical_chance := 0.25
@export var critical_multiplier := 1.75

@onready var collision_shape: CollisionShape3D = $EnemyCollision
@onready var character_frames: AnimatedSprite3D = $EnemyFrames
@onready var editor_placeholder: MeshInstance3D = $EnemyEditorPlaceholder
@onready var ground_shadow: Sprite3D = $GroundShadow
@onready var state_label: Label3D = $DummyStateLabel
@onready var hit_particles: CPUParticles3D = $HitSparkParticles
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio

var current_health := 1000.0
var total_damage := 0.0
var last_damage_tick := 0.0
var damage_per_second := 0.0
var damage_session_elapsed := 0.0
var damage_inactivity_timer := 0.0
var damage_session_active := false
var is_dead := false
var death_timer := 0.0
var home_position := Vector3.ZERO
var return_timer := 0.0
var knockback := Vector3.ZERO
var knockback_decay := 12.0
var hit_timer := 0.0
var silence_timer := 0.0
var stun_timer := 0.0
var hit_count := 0
var skill_damage_count := 0
var hit_sound_count := 0
var respawn_count := 0
var reset_count := 0
var facing_timer := 0.0
var normal_shield := 0.0
var last_attacker_position := Vector3.ZERO
var reaction_scale := Vector2.ONE
var reaction_velocity := Vector2.ZERO
var reaction_flash_timer := 0.0
var base_armor := 0.0
var armor_shred_timer := 0.0
var armor_shred_ratio := 0.0
var status_icon_slots: StatusIconSlots
var armor_shred_burst: StatusDebuffBurst
var unflipped_offset := Vector2.ZERO
var random := RandomNumberGenerator.new()
var combat_database: CombatDatabase
var unit_definition: UnitDefinition
var attacker_definition: UnitDefinition


func _ready() -> void:
	_apply_combat_data()
	base_armor = armor
	status_icon_slots = STATUS_ICON_SLOTS.new()
	status_icon_slots.name = "StatusIconSlots"
	add_child(status_icon_slots)
	armor_shred_burst = ARMOR_SHRED_BURST.get_or_create(self)
	bind_monster_instance(combat_database, unit_definition)
	random.seed = 20260824 + get_instance_id()
	current_health = max_health
	home_position = global_position
	unflipped_offset = character_frames.offset
	_configure_team_groups()
	_configure_visual_feedback()
	editor_placeholder.visible = character_frames.sprite_frames == null
	character_frames.animation_finished.connect(_on_animation_finished)
	character_frames.play(&"spawn")
	_update_label()


func _physics_process(delta: float) -> void:
	_update_armor_shred(delta)
	_update_visual_feedback(delta)
	if is_dead:
		death_timer = maxf(0.0, death_timer - delta)
		velocity = Vector3.ZERO
		if death_timer <= 0.0:
			_respawn()
		return

	silence_timer = maxf(0.0, silence_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	_update_damage_session(delta)
	_update_passive_movement(delta)
	if not is_on_floor():
		var gravity := float(combat_database.get_rule(&"combat.gravity", 20.0)) if combat_database != null else 20.0
		velocity.y -= gravity * delta
	else:
		velocity.y = float(combat_database.get_rule(&"combat.floor_stick_velocity", -0.1)) if combat_database != null else -0.1
	move_and_slide()
	_update_label()


func receive_hit(attacker_position: Vector3, attack_name: StringName) -> void:
	var damage := attacker_definition.attack_damage if attacker_definition != null else 58.0
	var event := combat_database.get_animation_event(&"garen", attack_name, "hit") if combat_database != null else null
	var hit_profile_id: StringName = event.payload_id if event != null else &"basic_melee"
	_apply_damage(damage, String(attack_name), true, attacker_position, &"physical", hit_profile_id)


func receive_skill_damage(
	amount: float,
	skill_name: String,
	can_crit: bool,
	attacker_position: Vector3,
	damage_type: StringName = &"physical",
	hit_profile_id: StringName = &"basic_melee"
) -> void:
	skill_damage_count += 1
	_apply_damage(amount, skill_name, can_crit, attacker_position, damage_type, hit_profile_id)


func receive_breaker_attack(base_attack: float, bonus_damage: float, attacker_position: Vector3, hit_profile_id: StringName = &"breaker_hit") -> void:
	# Q keeps one impact while only its base attack portion can critically strike.
	skill_damage_count += 1
	_apply_damage(base_attack, "破舰", true, attacker_position, &"physical", hit_profile_id, bonus_damage)


func apply_silence(duration: float) -> void:
	if is_dead:
		return
	silence_timer = maxf(silence_timer, duration)


func apply_armor_shred(duration: float, reduction_ratio: float) -> void:
	if is_dead:
		return
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


func apply_stun(duration: float) -> void:
	if is_dead:
		return
	stun_timer = maxf(stun_timer, duration)


func get_health_ratio() -> float:
	return current_health / maxf(max_health, 1.0)


func apply_normal_shield(amount: float) -> void:
	normal_shield = maxf(0.0, normal_shield + amount)


func get_normal_shield() -> float:
	return normal_shield


func get_team() -> StringName:
	return StringName(team)


func is_enemy_of(other_team: StringName) -> bool:
	return StringName(team) != other_team


func is_targetable() -> bool:
	return not is_dead


func get_damage_metrics() -> Dictionary:
	return {
		"total_damage": total_damage,
		"damage_per_second": damage_per_second,
		"last_damage_tick": last_damage_tick,
		"session_elapsed": damage_session_elapsed,
	}


func _apply_damage(
	amount: float,
	source_name: String,
	can_crit: bool,
	attacker_position: Vector3,
	damage_type: StringName,
	hit_profile_id: StringName,
	flat_post_crit_bonus: float = 0.0
) -> void:
	if is_dead:
		return
	hit_count += 1
	var hit_profile := combat_database.get_hit_profile(hit_profile_id) if combat_database != null else null
	hit_timer = hit_profile.hitstun if hit_profile != null else 0.18
	var critical := can_crit and random.randf() < critical_chance
	var raw_damage := amount * (critical_multiplier if critical else 1.0) + flat_post_crit_bonus
	var resolved_damage := CombatMath.resolve_damage(
		raw_damage, damage_type, armor, magic_resistance, combat_database
	) if combat_database != null else raw_damage
	var minimum_damage := float(combat_database.get_rule(&"damage.minimum_damage", 1.0)) if combat_database != null else 1.0
	resolved_damage = maxf(minimum_damage, resolved_damage)
	present_resolved_damage(resolved_damage, damage_type, critical)
	var health_damage := maxf(0.0, resolved_damage - normal_shield)
	normal_shield = maxf(0.0, normal_shield - resolved_damage)
	var applied_damage := minf(current_health, health_damage)
	current_health = maxf(0.0, current_health - health_damage)
	_record_damage(applied_damage)
	_face_attacker(attacker_position)

	var away := global_position - attacker_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.RIGHT
	var knockback_speed := hit_profile.knockback_speed if hit_profile != null else 2.8
	knockback_decay = hit_profile.knockback_decay if hit_profile != null else 12.0
	knockback = away.normalized() * knockback_speed
	return_timer = return_home_delay
	var contact_point := global_position - away.normalized() * gameplay_radius + Vector3.UP * 1.15
	hit_particles.call("burst", contact_point, away.normalized(), critical, hit_profile_id)
	if not CombatAudio.play_hit(hit_audio, combat_database, hit_profile, &"wood", critical, random):
		hit_audio.pitch_scale = random.randf_range(0.94, 1.06)
		hit_audio.play()
	hit_sound_count += 1
	_start_hit_reaction()

	if current_health <= 0.0:
		_die()
	else:
		character_frames.play(&"hurt")
		_update_label("CRIT %s" % source_name if critical else source_name)


func _record_damage(applied_damage: float) -> void:
	if not damage_session_active:
		damage_session_active = true
		total_damage = 0.0
		damage_session_elapsed = 0.0
	total_damage += applied_damage
	last_damage_tick = applied_damage
	damage_inactivity_timer = damage_reset_delay
	damage_per_second = total_damage / maxf(damage_session_elapsed, 0.001)


func _update_damage_session(delta: float) -> void:
	if not damage_session_active:
		return
	damage_session_elapsed += delta
	damage_inactivity_timer = maxf(0.0, damage_inactivity_timer - delta)
	damage_per_second = total_damage / maxf(damage_session_elapsed, 0.001)
	if damage_inactivity_timer <= 0.0:
		_reset_training_session(true)


func _reset_training_session(restore_health: bool) -> void:
	damage_session_active = false
	total_damage = 0.0
	last_damage_tick = 0.0
	damage_per_second = 0.0
	damage_session_elapsed = 0.0
	damage_inactivity_timer = 0.0
	if restore_health and not is_dead:
		current_health = max_health
		normal_shield = 0.0
	reset_count += 1
	_update_label()


func _die() -> void:
	is_dead = true
	death_timer = respawn_delay
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	collision_shape.set_deferred(&"disabled", true)
	remove_from_group(&"enemy_actor")
	remove_from_group(&"friendly_actor")
	remove_from_group(&"combat_target")
	state_label.visible = false
	ground_shadow.visible = false
	character_frames.modulate = Color.WHITE
	character_frames.play(&"death")
	_update_label("DEAD · %.1fs" % death_timer)


func _respawn() -> void:
	is_dead = false
	death_timer = 0.0
	global_position = home_position
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	current_health = max_health
	normal_shield = 0.0
	collision_shape.set_deferred(&"disabled", false)
	_configure_team_groups()
	state_label.visible = true
	ground_shadow.visible = true
	_reset_training_session(false)
	respawn_count += 1
	character_frames.modulate = Color.WHITE
	character_frames.play(&"spawn")
	_update_label("RESPAWN")


func _update_passive_movement(delta: float) -> void:
	if hit_timer > 0.0:
		hit_timer = maxf(0.0, hit_timer - delta)
		velocity.x = knockback.x
		velocity.z = knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, knockback_decay * delta)
		return
	return_timer = maxf(0.0, return_timer - delta)
	var home_offset := home_position - global_position
	home_offset.y = 0.0
	var home_distance := home_offset.length()
	if return_timer <= 0.0 and home_distance > return_home_tolerance:
		var arrival_speed := minf(move_speed, home_distance * 6.0)
		var return_velocity := home_offset.normalized() * arrival_speed
		velocity.x = move_toward(velocity.x, return_velocity.x, 8.0 * delta)
		velocity.z = move_toward(velocity.z, return_velocity.z, 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if home_distance <= return_home_tolerance and Vector2(velocity.x, velocity.z).length() <= 0.2:
			global_position.x = home_position.x
			global_position.z = home_position.z
			velocity.x = 0.0
			velocity.z = 0.0


func _on_animation_finished() -> void:
	if is_dead:
		character_frames.pause()
		return
	if character_frames.animation == &"hurt" or character_frames.animation == &"spawn":
		character_frames.play(&"idle")


func _configure_team_groups() -> void:
	add_to_group(&"training_dummy")
	add_to_group(&"combat_target")
	if team == "friendly":
		add_to_group(&"friendly_actor")
		remove_from_group(&"enemy_actor")
		state_label.modulate = Color(0.48, 0.84, 1.0, 1.0)
	else:
		add_to_group(&"enemy_actor")
		remove_from_group(&"friendly_actor")
		state_label.modulate = Color(1.0, 0.56, 0.56, 1.0)


func _configure_visual_feedback() -> void:
	# Team outline is supplied by UnitReadability's shared Outline Glow shader.
	pass


func _face_attacker(attacker_position: Vector3) -> void:
	last_attacker_position = attacker_position
	facing_timer = face_attacker_duration
	_apply_facing()


func _apply_facing() -> void:
	var horizontal_offset := last_attacker_position.x - global_position.x
	if absf(horizontal_offset) <= 0.02:
		return
	var attacker_is_right := horizontal_offset > 0.0
	var flip := attacker_is_right if source_faces_left else not attacker_is_right
	character_frames.flip_h = flip
	var anchored_x := -unflipped_offset.x if flip else unflipped_offset.x
	character_frames.offset.x = anchored_x


func _start_hit_reaction() -> void:
	reaction_scale = Vector2(0.82, 1.12)
	reaction_velocity = Vector2(1.8, -1.2)
	reaction_flash_timer = 0.24
	character_frames.modulate = Color(1.0, 0.88, 0.52, 1.0)


func _update_visual_feedback(delta: float) -> void:
	if facing_timer > 0.0:
		facing_timer = maxf(0.0, facing_timer - delta)
		_apply_facing()

	var spring_force := (Vector2.ONE - reaction_scale) * 145.0
	reaction_velocity += spring_force * delta
	reaction_velocity *= exp(-11.0 * delta)
	reaction_scale += reaction_velocity * delta
	if reaction_scale.distance_to(Vector2.ONE) < 0.001 and reaction_velocity.length() < 0.01:
		reaction_scale = Vector2.ONE
		reaction_velocity = Vector2.ZERO
	character_frames.scale = Vector3(reaction_scale.x, reaction_scale.y, 1.0)

	if reaction_flash_timer > 0.0:
		reaction_flash_timer = maxf(0.0, reaction_flash_timer - delta)
		var flash_ratio := reaction_flash_timer / 0.24
		character_frames.modulate = Color.WHITE.lerp(Color(1.0, 0.82, 0.42, 1.0), flash_ratio)
	else:
		character_frames.modulate = character_frames.modulate.lerp(Color.WHITE, minf(delta * 18.0, 1.0))
func _update_label(status := "") -> void:
	var side_label := "友方" if team == "friendly" else "敌方"
	if is_dead:
		state_label.text = "%s训练假人 · DEAD %.1fs\nTOTAL %.0f  DPS %.1f  LAST %.0f" % [
			side_label, death_timer, total_damage, damage_per_second, last_damage_tick,
		]
		return
	var status_suffix := " · %s" % status if not status.is_empty() else ""
	state_label.text = "%s训练假人%s\nHP %d/%d  TOTAL %.0f  DPS %.1f  LAST %.0f" % [
		side_label, status_suffix, int(current_health), int(max_health),
		total_damage, damage_per_second, last_damage_tick,
	]


func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		return
	unit_definition = combat_database.get_unit(&"training_dummy")
	attacker_definition = combat_database.get_unit(&"garen")
	if unit_definition != null:
		max_health = unit_definition.max_health
		attack_damage = unit_definition.attack_damage
		attack_speed = unit_definition.attack_speed
		attack_range = unit_definition.attack_range
		armor = unit_definition.armor
		magic_resistance = unit_definition.magic_resistance
		move_speed = unit_definition.move_speed
		gameplay_radius = combat_database.get_unit_stat_value(&"training_dummy", &"gameplay_radius", 1)
		pathing_radius = combat_database.get_unit_stat_value(&"training_dummy", &"pathing_radius", 1)
	if attacker_definition != null:
		critical_chance = attacker_definition.critical_chance
		critical_multiplier = attacker_definition.critical_damage
	CombatAudio.configure_player(hit_audio, combat_database, &"garen_basic_hit_wood")
