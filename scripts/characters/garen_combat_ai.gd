extends "res://scripts/actors/hero_instance.gd"

signal attack_landed(animation_name: StringName)

enum CombatState { IDLE, CHASE, ATTACK }

const ATTACK_COMBO: Array[StringName] = [&"attack1", &"attack2", &"attack3"]
const HERO_HIT_FEEDBACK := preload("res://scripts/presentation/hero_hit_feedback_3d.gd")
const SKILL_Q := 1
const SKILL_W := 2
const SKILL_E := 3
const SKILL_R := 4
const SKILL_T := 5

@export_node_path("CharacterBody3D") var target_path := NodePath()
@export_range(0.1, 10.0, 0.1) var move_speed := 3.4
@export_range(0.5, 4.0, 0.05) var attack_range := 1.5
@export_range(0.0, 20.0, 0.1) var acceleration := 14.0
@export_enum("friendly", "enemy") var team := "friendly"
@export var level := 1

@onready var character_model: GarenModelAnimator = $GarenModel
@onready var state_label: Label3D = $AIStateLabel
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var skill_controller: Node3D = $SkillController

var target: CharacterBody3D
var state := CombatState.IDLE
var combo_index := -1
var attack_hit_sent := false
var attack_audio_events_sent: Dictionary[StringName, bool] = {}
var attack_sound_count := 0
var current_attack_name: StringName = &"attack1"
var current_attack_is_breaker := false
var attack_combo: Array[StringName] = ATTACK_COMBO.duplicate()
var combat_database: CombatDatabase
var garen_definition: UnitDefinition
var fighter_ai: AIProfileDefinition
var ai_archetype: Resource
var attack_hit_range := 1.95
var breaker_hit_range := 2.5
var arena_min := Vector2(-14.5, -4.3)
var arena_max := Vector2(14.5, 4.3)
var external_move_speed_modifiers: Dictionary = {}
var attack_pitches: Array[float] = [1.08, 1.0, 0.88]
var breaker_lunge_pending := false
var is_dead := false
var hit_feedback: HeroHitFeedback3D


func _ready() -> void:
	_apply_combat_data()
	bind_hero_instance(combat_database, garen_definition)
	_build_hit_feedback()
	add_to_group(&"combat_target")
	_configure_team_groups()
	# Training dummies are optional debugging targets, never a forced default.
	# Selection starts from the same hostile-priority query used at runtime.
	target = _find_closest_target()
	_set_target_outline(target, true)
	skill_controller.call("set_target", target)
	character_model.animation_finished.connect(_on_animation_finished)
	_set_state(CombatState.CHASE if is_instance_valid(target) else CombatState.IDLE)


func _configure_team_groups() -> void:
	if team == "friendly":
		add_to_group(&"friendly_actor")
		remove_from_group(&"enemy_actor")
	else:
		add_to_group(&"enemy_actor")
		remove_from_group(&"friendly_actor")
	var readability := get_node_or_null("UnitReadability")
	if readability != null and readability.has_method("refresh_team_visuals"):
		readability.call("refresh_team_visuals")
	set_outline_selected(is_in_group(&"player_actor"))


func get_skill_cooldown_state(slot: StringName) -> Dictionary:
	var skill_index := [&"q", &"w", &"e", &"r", &"t"].find(slot)
	if skill_index < 0 or not is_instance_valid(skill_controller):
		return {"remaining": 0.0, "total": 0.0}
	return skill_controller.call("get_skill_cooldown_state", skill_index + 1)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		return
	_refresh_target()
	if state == CombatState.ATTACK:
		_check_attack_audio()
	if not _is_target_available(target):
		if bool(skill_controller.call("allows_movement_while_casting")):
			skill_controller.call("cancel_ocean_storm")
		_set_state(CombatState.IDLE)
		_slow_down(delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	skill_controller.call("set_target", target)
	if bool(skill_controller.get("is_casting")):
		if bool(skill_controller.call("allows_movement_while_casting")):
			_move_during_ocean_storm(delta)
			return
		else:
			_slow_down(delta)
			_apply_gravity(delta)
			move_and_slide()
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector3.ZERO
	_face_direction(direction)

	match state:
		CombatState.ATTACK:
			_slow_down(delta)
			_check_attack_hit(distance)
		_:
			if distance <= attack_range or (bool(skill_controller.call("should_use_breaker_attack")) and distance <= _breaker_lunge_range()):
				_start_next_attack()
			else:
				_set_state(CombatState.CHASE)
				var speed_multiplier := float(skill_controller.call("get_move_speed_multiplier")) * _external_move_speed_multiplier()
				velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, acceleration * delta)
				velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, acceleration * delta)

	_apply_gravity(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func _start_next_attack() -> void:
	attack_hit_sent = false
	attack_audio_events_sent.clear()
	state = CombatState.ATTACK
	current_attack_is_breaker = bool(skill_controller.call("should_use_breaker_attack"))
	if current_attack_is_breaker:
		var breaker := combat_database.get_skill_by_slot(&"garen", 1) if combat_database != null else null
		current_attack_name = breaker.empowered_animation_name if breaker != null else &"spell1"
		state_label.text = "SKILL 1 · 破舰"
	else:
		combo_index = (combo_index + 1) % attack_combo.size()
		current_attack_name = attack_combo[combo_index]
		state_label.text = "AI · COMBO %d" % (combo_index + 1)
	if current_attack_is_breaker and _should_lunge_to_target():
		breaker_lunge_pending = true
		await _perform_breaker_lunge()
		breaker_lunge_pending = false
	character_model.play_semantic(current_attack_name)


func _check_attack_hit(distance: float) -> void:
	if attack_hit_sent or breaker_lunge_pending:
		return
	var hit_event := combat_database.get_animation_event(&"garen", character_model.current_animation, "hit") if combat_database != null else null
	var impact_normalized := hit_event.timing_value if hit_event != null and hit_event.timing_mode == "normalized" else 0.55
	if character_model.get_normalized_progress() < impact_normalized:
		return
	attack_hit_sent = true
	if not _is_target_available(target):
		return
	if distance <= get_current_attack_hit_range():
		if target.has_method("register_damage_source"):
			target.call("register_damage_source", global_position, get_team())
		if current_attack_is_breaker:
			skill_controller.call("resolve_breaker_attack", target)
			current_attack_is_breaker = false
		else:
			var damage := garen_definition.attack_damage if garen_definition != null else 69.0
			var hit_profile_id: StringName = hit_event.payload_id if hit_event != null else &"basic_melee"
			if target.has_method("receive_hit"):
				target.call("receive_hit", global_position, character_model.current_animation, damage, self)
			elif target.has_method("receive_skill_damage"):
				target.call("receive_skill_damage", damage, String(character_model.current_animation), true, global_position, &"physical", hit_profile_id, self)
			if skill_controller != null:
				skill_controller.call("register_courage_kill", target)
		attack_landed.emit(character_model.current_animation)


func _check_attack_audio() -> void:
	var audio_events := combat_database.get_animation_events(&"garen", character_model.current_animation, "audio") if combat_database != null else []
	if audio_events.is_empty():
		if attack_audio_events_sent.has(&"fallback") or _animation_normalized_progress() < 0.45:
			return
		var fallback_pitch := attack_pitches[combo_index] if combo_index >= 0 and combo_index < attack_pitches.size() else 1.0
		attack_audio.pitch_scale = 0.94 if current_attack_is_breaker else fallback_pitch
		attack_audio.play()
		attack_audio_events_sent[&"fallback"] = true
		attack_sound_count += 1
		return
	for audio_event: AnimationEventDefinition in audio_events:
		if attack_audio_events_sent.has(audio_event.id) or not _animation_event_reached(audio_event):
			continue
		attack_audio_events_sent[audio_event.id] = true
		if attack_audio_events_sent.size() == 1:
			if CombatAudio.configure_player(attack_audio, combat_database, audio_event.payload_id) != null:
				attack_audio.pitch_scale = audio_event.float_value if audio_event.float_value > 0.0 else 1.0
				attack_audio.play()
				attack_sound_count += 1
		elif skill_controller.has_method("play_audio_cue"):
			if skill_controller.call("play_audio_cue", audio_event.payload_id, global_position, audio_event.float_value) != null:
				attack_sound_count += 1


func _animation_event_reached(event: AnimationEventDefinition) -> bool:
	match event.timing_mode:
		"frame":
			return false
		"seconds":
			return _animation_elapsed_seconds() >= event.timing_value
		_:
			return _animation_normalized_progress() >= event.timing_value


func _animation_normalized_progress() -> float:
	return character_model.get_normalized_progress()


func _animation_elapsed_seconds() -> float:
	return character_model.get_elapsed_seconds()


func _on_animation_finished(_animation_name: StringName) -> void:
	if state != CombatState.ATTACK or not _is_target_available(target):
		return
	state = CombatState.CHASE
	if bool(skill_controller.call("try_begin_demo_skill")):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() <= attack_range + 0.25:
		_start_next_attack()
	else:
		_set_state(CombatState.CHASE)


func select_ai_skill() -> int:
	# Hero-specific expression of the reusable Juggernaut pressure archetype.
	# The profile supplies all thresholds; the order is intentionally conditional,
	# never a blocking Q/W/E/R/T carousel.
	if ai_archetype == null or ai_archetype.decision_mode != "melee_pressure" or not _is_target_available(target):
		return 0
	var distance := _target_distance()
	var target_health_ratio := _target_health_ratio(target)
	var nearby_enemy_count := _count_nearby_enemies(ai_archetype.engage_distance)
	var skill_cooldowns: Array = skill_controller.get("cooldowns") as Array

	# R is a true-damage finisher. Evaluate calculated damage instead of merely
	# waiting for an arbitrary health percentage, then keep a percentage guard so
	# future high-health targets do not get prematurely executed.
	if _skill_ready(skill_cooldowns, SKILL_R) and distance <= _skill_range(SKILL_R):
		var target_max_health := float(target.get("max_health"))
		var projected_damage := float(skill_controller.call("calculate_judgment_damage", target_max_health, target_health_ratio))
		var target_health := target_max_health * target_health_ratio
		if target_health_ratio <= ai_archetype.execute_health_ratio or projected_damage >= target_health:
			return SKILL_R

	# T is an awakening-scale ground AOE. It is reserved for a real group hit;
	# the low-health fallback still lets the training scene demonstrate it without
	# turning every single-target exchange into a Ghostship cast.
	if _skill_ready(skill_cooldowns, SKILL_T) and distance <= _skill_range(SKILL_T):
		if nearby_enemy_count >= ai_archetype.aoe_min_targets or target_health_ratio <= ai_archetype.awakening_health_ratio:
			return SKILL_T

	# Defensive W is reactive and stays available during E by design.
	if _skill_ready(skill_cooldowns, SKILL_W) and get_health_ratio() <= ai_archetype.defend_health_ratio:
		return SKILL_W

	# E owns close-range sustained pressure. Its self-area targeting also makes
	# it the preferred multi-target response once the juggernaut has connected.
	if _skill_ready(skill_cooldowns, SKILL_E) and distance <= _skill_range(SKILL_E):
		if nearby_enemy_count >= ai_archetype.aoe_min_targets or target_health_ratio <= ai_archetype.pressure_health_ratio:
			return SKILL_E

	# Q begins the approach and hands the next attack its lunge/empower state.
	if _skill_ready(skill_cooldowns, SKILL_Q) and distance <= ai_archetype.engage_distance:
		return SKILL_Q
	return 0


func _skill_ready(skill_cooldowns: Array, skill_index: int) -> bool:
	return skill_index >= 0 and skill_index < skill_cooldowns.size() and float(skill_cooldowns[skill_index]) <= 0.0


func _skill_range(skill_index: int) -> float:
	if combat_database == null:
		return attack_range
	var definition := combat_database.get_skill_by_slot(&"garen", skill_index)
	if definition == null:
		return attack_range
	if definition.target_type == "self" or definition.target_type == "self_area":
		return definition.radius
	return definition.cast_range


func _target_distance() -> float:
	if not _is_target_available(target):
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _target_health_ratio(candidate: CharacterBody3D) -> float:
	if candidate.has_method("get_health_ratio"):
		return clampf(float(candidate.call("get_health_ratio")), 0.0, 1.0)
	return 1.0


func _count_nearby_enemies(radius: float) -> int:
	var count := 0
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate == self or not _is_target_available(candidate):
			continue
		if not _is_hostile_candidate(candidate):
			continue
		var planar := candidate.global_position - global_position
		planar.y = 0.0
		if planar.length() <= radius:
			count += 1
	return count


func _set_state(next_state: CombatState) -> void:
	# E is a moving channel and retains ownership of spell3 even when retargeting
	# changes the logical AI state to CHASE or IDLE.
	if skill_controller != null and bool(skill_controller.call("preserves_character_animation")):
		state = next_state
		match state:
			CombatState.IDLE:
				state_label.text = "AI · IDLE"
			CombatState.CHASE:
				state_label.text = "AI · CHASE"
		return
	var expected_animation := &"idle1"
	if next_state == CombatState.CHASE:
		expected_animation = skill_controller.call("get_run_animation") as StringName
	if state == next_state and character_model.is_playing() and character_model.current_animation == expected_animation:
		return
	state = next_state
	match state:
		CombatState.IDLE:
			character_model.play_semantic(&"idle1")
			state_label.text = "AI · IDLE"
		CombatState.CHASE:
			character_model.play_semantic(skill_controller.call("get_run_animation") as StringName)
			state_label.text = "AI · CHASE"
		CombatState.ATTACK:
			pass


func _face_direction(direction: Vector3) -> void:
	if absf(direction.x) > 0.05:
		character_model.set_facing(direction)


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)


func _move_during_ocean_storm(delta: float) -> void:
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector3.ZERO
	_face_direction(direction)
	if distance > attack_range * 0.85:
		var speed_multiplier := float(skill_controller.call("get_move_speed_multiplier")) * _external_move_speed_multiplier()
		velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, acceleration * delta)
	else:
		_slow_down(delta)
	_apply_gravity(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func _apply_gravity(delta: float) -> void:
	var floor_velocity := float(combat_database.get_rule(&"combat.floor_stick_velocity", -0.1)) if combat_database != null else -0.1
	var gravity := float(combat_database.get_rule(&"combat.gravity", 20.0)) if combat_database != null else 20.0
	if is_on_floor():
		velocity.y = floor_velocity
	else:
		velocity.y -= gravity * delta


func can_start_skill() -> bool:
	return state != CombatState.ATTACK


func try_interrupt() -> bool:
	# E's super armor rejects external interruption while preserving movement.
	return not bool(skill_controller.call("has_super_armor"))


func receive_knockback(direction: Vector3, speed: float) -> bool:
	# Shared future-facing forced-movement entry point for enemies and skills.
	if bool(skill_controller.call("has_super_armor")):
		return false
	var planar := direction
	planar.y = 0.0
	if planar.length_squared() > 0.0001:
		velocity += planar.normalized() * speed
	return true


func _refresh_target() -> void:
	if is_dead:
		return
	if target != null and not is_instance_valid(target):
		target = null
	var preferred := _find_closest_target()
	if preferred == null:
		_set_target_outline(target, false)
		target = null
		skill_controller.call("set_target", target)
		return
	var should_switch := not _is_target_available(target)
	if not should_switch and _is_training_dummy(target) and _is_hero_actor(preferred):
		should_switch = true
	if not should_switch:
		return
	_set_target_outline(target, false)
	target = preferred
	_set_target_outline(target, true)
	skill_controller.call("set_target", target)
	_set_state(CombatState.CHASE)


func _set_target_outline(candidate: Node, active: bool) -> void:
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("set_outline_targeted"):
		return
	candidate.call("set_outline_targeted", active)


func force_retarget_hostile() -> void:
	if is_dead:
		return
	target = null
	_refresh_target()


func _is_target_available(candidate: Node) -> bool:
	# Freed refs are still Objects, but no longer CharacterBody3D subclasses.
	# Accept Node so the validity check can run before any typed use.
	if candidate == null or not is_instance_valid(candidate) or candidate == self:
		return false
	if not (candidate is CharacterBody3D):
		return false
	# The training panel removes disabled units from this group. A hidden target
	# must become invalid immediately even if its own script is process-disabled.
	if not candidate.is_in_group(&"combat_target"):
		return false
	if candidate.has_method("is_targetable"):
		return bool(candidate.call("is_targetable"))
	return true


func _find_closest_target() -> CharacterBody3D:
	var closest_hero: CharacterBody3D
	var closest_hero_distance := INF
	var closest_any: CharacterBody3D
	var closest_any_distance := INF
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		if not is_instance_valid(candidate_node):
			continue
		var candidate := candidate_node as CharacterBody3D
		if candidate == null or candidate == self or not _is_target_available(candidate):
			continue
		if not _is_hostile_candidate(candidate):
			continue
		var candidate_distance := global_position.distance_squared_to(candidate.global_position)
		if candidate_distance < closest_any_distance:
			closest_any = candidate
			closest_any_distance = candidate_distance
		if _is_hero_actor(candidate) and candidate_distance < closest_hero_distance:
			closest_hero = candidate
			closest_hero_distance = candidate_distance
	return closest_hero if closest_hero != null else closest_any


func _is_hostile_candidate(candidate: CharacterBody3D) -> bool:
	if not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_enemy_of"):
		return bool(candidate.call("is_enemy_of", get_team()))
	if candidate.has_method("get_team"):
		return StringName(candidate.call("get_team")) != get_team()
	return false


func _is_hero_actor(candidate: Node) -> bool:
	return candidate != null and is_instance_valid(candidate) and candidate.is_in_group(&"hero_actor")


func _is_training_dummy(candidate: Node) -> bool:
	return candidate != null and is_instance_valid(candidate) and candidate.is_in_group(&"training_dummy")


func get_team() -> StringName:
	return StringName(team)


func get_display_name() -> String:
	return "盖伦"


func is_enemy_of(other_team: StringName) -> bool:
	return StringName(team) != other_team


var max_health: float:
	get:
		if skill_controller == null:
			return 1000.0
		return float(skill_controller.get("max_health"))


var current_health: float:
	get:
		if skill_controller == null:
			return 1000.0
		return float(skill_controller.get("current_health"))


func get_health_ratio() -> float:
	if skill_controller == null:
		return 1.0
	var maximum := float(skill_controller.get("max_health"))
	return float(skill_controller.get("current_health")) / maxf(maximum, 1.0)


func is_targetable() -> bool:
	if is_dead:
		return false
	if skill_controller == null:
		return true
	return float(skill_controller.get("current_health")) > 0.0


func receive_hit(attacker_position: Vector3, _attack_name: StringName, amount: float = -1.0, source_actor: Node = null) -> void:
	var damage := amount if amount >= 0.0 else (garen_definition.attack_damage if garen_definition != null else 69.0)
	receive_skill_damage(damage, "普攻", true, attacker_position, &"physical", &"basic_melee", source_actor)


func receive_breaker_attack(base_attack: float, bonus_damage: float, attacker_position: Vector3, _hit_profile_id: StringName = &"breaker_hit", source_actor: Node = null) -> void:
	receive_skill_damage(base_attack + bonus_damage, "破舰", true, attacker_position, &"physical", &"breaker_hit", source_actor)


func receive_skill_damage(amount: float, source_name: String, can_crit: bool, attacker_position: Vector3, damage_type: StringName = &"physical", hit_profile_id: StringName = &"basic_melee", source_actor: Node = null) -> void:
	if is_dead or skill_controller == null or amount <= 0.0:
		return
	skill_controller.call("receive_incoming_damage", amount, damage_type, can_crit, source_actor, self, source_name)
	if hit_feedback != null:
		hit_feedback.play_hit(attacker_position, hit_profile_id, can_crit)
	if float(skill_controller.get("current_health")) <= 0.0:
		_die()


func _build_hit_feedback() -> void:
	hit_feedback = get_node_or_null("HeroHitFeedback3D") as HeroHitFeedback3D
	if hit_feedback == null:
		hit_feedback = HERO_HIT_FEEDBACK.new()
		hit_feedback.name = "HeroHitFeedback3D"
		hit_feedback.configure(combat_database, &"GarenModel")
		add_child(hit_feedback)
	else:
		hit_feedback.configure(combat_database, &"GarenModel")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	target = null
	state = CombatState.IDLE
	velocity = Vector3.ZERO
	breaker_lunge_pending = false
	if skill_controller != null:
		skill_controller.call("set_target", null)
		skill_controller.set("is_casting", false)
	if is_in_group(&"combat_target"):
		remove_from_group(&"combat_target")
	character_model.play_semantic(&"death")
	state_label.text = "AI · DEFEATED"


func revive_for_training() -> void:
	is_dead = false
	target = null
	state = CombatState.IDLE
	velocity = Vector3.ZERO
	breaker_lunge_pending = false
	if skill_controller != null:
		skill_controller.set("current_health", skill_controller.get("max_health"))
		skill_controller.set("is_casting", false)
		skill_controller.call("set_target", null)
	if not is_in_group(&"combat_target"):
		add_to_group(&"combat_target")
	_configure_team_groups()
	character_model.play_semantic(&"idle1")
	state_label.text = "AI · IDLE"
	force_retarget_hostile()


func apply_silence(duration: float) -> void:
	if skill_controller != null and skill_controller.has_method("apply_silence"):
		skill_controller.call("apply_silence", duration)


func apply_armor_shred(duration: float, reduction_ratio: float) -> void:
	if skill_controller != null and skill_controller.has_method("apply_armor_shred"):
		skill_controller.call("apply_armor_shred", duration, reduction_ratio)


func apply_magic_resistance_shred(multiplier: float, duration: float) -> void:
	if skill_controller != null and skill_controller.has_method("apply_magic_resistance_shred"):
		skill_controller.call("apply_magic_resistance_shred", multiplier, duration)


func apply_seven_seas_rum(duration: float, move_speed_bonus: float) -> void:
	if skill_controller != null:
		skill_controller.call("apply_seven_seas_rum", duration, move_speed_bonus)


func set_external_move_speed_modifier(source_id: StringName, multiplier: float) -> void:
	external_move_speed_modifiers[source_id] = maxf(0.0, multiplier)


func clear_external_move_speed_modifier(source_id: StringName) -> void:
	external_move_speed_modifiers.erase(source_id)


func _external_move_speed_multiplier() -> float:
	var result := 1.0
	for value: Variant in external_move_speed_modifiers.values():
		result *= float(value)
	return result


func _breaker_lunge_range() -> float:
	var breaker := combat_database.get_skill_by_slot(&"garen", 1) if combat_database != null else null
	return breaker.cast_range if breaker != null else 2.4


func get_current_attack_hit_range() -> float:
	return breaker_hit_range if current_attack_is_breaker else attack_hit_range


func _should_lunge_to_target() -> bool:
	if not _is_target_available(target):
		return false
	var horizontal := target.global_position - global_position
	horizontal.y = 0.0
	return horizontal.length() > attack_range and horizontal.length() <= _breaker_lunge_range()


func _perform_breaker_lunge() -> void:
	if not _is_target_available(target):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= attack_range or distance > _breaker_lunge_range():
		return
	var direction := offset.normalized()
	_face_direction(direction)
	var standoff := float(combat_database.get_rule(&"garen.breaker.lunge_standoff", 0.85)) if combat_database != null else 0.85
	var destination := target.global_position - direction * standoff
	destination.y = global_position.y
	destination.x = clampf(destination.x, arena_min.x, arena_max.x)
	destination.z = clampf(destination.z, arena_min.y, arena_max.y)
	var origin := global_position
	var duration := float(combat_database.get_rule(&"garen.breaker.lunge_duration", 0.12)) if combat_database != null else 0.12
	var elapsed := 0.0
	while elapsed < duration and _is_target_available(target):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		global_position = origin.lerp(destination, ease(clampf(elapsed / duration, 0.0, 1.0), -1.6))


func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		push_warning("Combat database is unavailable; using inspector fallback values")
		return
	garen_definition = combat_database.get_unit(&"garen")
	var configured_combo: Array[StringName] = []
	for event: AnimationEventDefinition in combat_database.animation_events:
		if event.owner_id == &"garen" and event.event_type == "hit" and event.payload_id == &"basic_melee" and not configured_combo.has(event.animation_name):
			configured_combo.append(event.animation_name)
	if not configured_combo.is_empty():
		attack_combo = configured_combo
	if garen_definition != null:
		move_speed = garen_definition.move_speed
		acceleration = garen_definition.acceleration
		attack_range = garen_definition.attack_range
		fighter_ai = combat_database.get_ai_profile(garen_definition.ai_profile_id)
	if fighter_ai != null:
		arena_min = fighter_ai.arena_min
		arena_max = fighter_ai.arena_max
		ai_archetype = combat_database.get_ai_archetype(fighter_ai.archetype_id)
	var hit_profile := combat_database.get_hit_profile(&"basic_melee")
	if hit_profile != null:
		attack_hit_range = hit_profile.size.x
	var breaker_profile := combat_database.get_hit_profile(&"breaker_hit")
	if breaker_profile != null:
		breaker_hit_range = breaker_profile.size.x
	var attack_profile := combat_database.get_asset_profile(&"garen_attack_audio")
	if attack_profile != null:
		var stream := load(attack_profile.audio_path) as AudioStream
		if stream != null:
			attack_audio.stream = stream
		attack_audio.volume_db = attack_profile.volume_db
		attack_audio.max_distance = attack_profile.max_distance
		attack_pitches = [attack_profile.pitch_max, 1.0, attack_profile.pitch_min]
