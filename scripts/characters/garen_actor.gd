extends "res://scripts/actors/hero_instance.gd"

## Garen runtime actor; skill mechanics live in GarenSkillController.

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
@export_range(1.0, 5.0, 0.1) var manual_turn_acceleration_multiplier := 3.0
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
var current_attack_is_manual := false
var current_attack_facing_direction := Vector2.RIGHT
var attack_combo: Array[StringName] = ATTACK_COMBO.duplicate()
var combat_database: CombatDatabase
var garen_definition: UnitDefinition
var fighter_ai: AIProfileDefinition
var ai_archetype: Resource
var ai_brain: HeroBrain
var ai_decision: HeroAIDecision
var ai_decision_timer := 0.0
var last_consumed_decision_generation := -1
var ai_recent_damage_accumulator := 0.0
var ai_recent_damage_hold_timer := 0.0
@export var ai_debug := false
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
	if not _apply_combat_data():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_setup_ai_brain()
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


func get_skill_cooldown_state(slot: StringName) -> Dictionary:
	var skill_index := [&"q", &"w", &"e", &"r", &"t"].find(slot)
	if skill_index < 0 or not is_instance_valid(skill_controller):
		return {"remaining": 0.0, "total": 0.0}
	return skill_controller.call("get_skill_cooldown_state", skill_index + 1)


func _physics_process(delta: float) -> void:
	ai_recent_damage_hold_timer = maxf(0.0, ai_recent_damage_hold_timer - delta)
	if ai_recent_damage_hold_timer <= 0.0:
		ai_recent_damage_accumulator = 0.0
	if is_dead:
		velocity = Vector3.ZERO
		return
	var rooted := tick_root(delta)
	if rooted:
		velocity.x = 0.0
		velocity.z = 0.0
	_refresh_target()
	if state == CombatState.ATTACK:
		_check_attack_audio()
	if is_player_controlled():
		_physics_process_player(delta, rooted)
		return
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
			_update_ai_decision(delta)
			if ai_decision != null and ai_decision.action_id == &"skill_w":
				_try_consume_ai_one_shot(ai_decision)
			if rooted:
				_slow_down(delta)
				_apply_gravity(delta)
				move_and_slide()
			else:
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

	if state == CombatState.ATTACK:
		_slow_down(delta)
		_check_attack_hit(distance)
	else:
		_update_ai_decision(delta)
		_execute_ai_decision(ai_decision, delta, direction)

	_apply_gravity(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func _physics_process_player(delta: float, rooted: bool) -> void:
	if _is_target_available(target):
		skill_controller.call("set_target", target)
	var casting := bool(skill_controller.get("is_casting"))
	if state == CombatState.ATTACK:
		_slow_down(delta)
		_check_attack_hit(_target_distance())
	elif casting and not bool(skill_controller.call("allows_movement_while_casting")):
		_slow_down(delta)
	else:
		_apply_player_movement(delta, rooted)
	_apply_gravity(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func _apply_player_movement(delta: float, rooted: bool) -> void:
	var direction := Vector3(player_move_input.x, 0.0, player_move_input.y)
	if rooted:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_state(CombatState.IDLE)
	elif direction.is_zero_approx():
		_slow_down(delta)
		_set_state(CombatState.IDLE)
	else:
		var speed := move_speed * float(skill_controller.call("get_move_speed_multiplier")) * _external_move_speed_multiplier()
		var turn_acceleration := acceleration
		var planar_velocity := Vector2(velocity.x, velocity.z)
		var planar_direction := Vector2(direction.x, direction.z)
		if not planar_velocity.is_zero_approx() and planar_velocity.dot(planar_direction) < 0.0:
			turn_acceleration *= manual_turn_acceleration_multiplier
		velocity.x = move_toward(velocity.x, direction.x * speed, turn_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, turn_acceleration * delta)
		_face_direction(direction)
		_set_state(CombatState.CHASE)


func request_player_basic_attack(direction_input := Vector2.ZERO) -> bool:
	return _request_player_action(&"basic_attack", direction_input)


func request_player_skill(slot: StringName, direction_input := Vector2.ZERO) -> bool:
	if slot not in [&"q", &"w", &"e", &"r", &"t"]:
		return false
	return _request_player_action(StringName("skill_" + slot), direction_input)


func _request_player_action(action: StringName, direction_input := Vector2.ZERO) -> bool:
	if not is_player_controlled() or is_dead or process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if direction_input.is_finite() and direction_input.length_squared() > 0.0001:
		player_facing_direction = direction_input.normalized()
		_face_direction(Vector3(player_facing_direction.x, 0.0, player_facing_direction.y))
	var request := HeroActionRequest.new()
	request.source = HeroActionRequest.Source.PLAYER
	request.action_id = action
	request.direction = _player_aim_direction(direction_input)
	if action != &"basic_attack":
		var skill_index := _player_skill_index(action)
		if skill_index == 0 or combat_database == null:
			return false
		request.skill_slot = StringName(String(action).trim_prefix("skill_"))
		var skill := combat_database.get_skill_by_slot(&"garen", skill_index)
		if skill == null:
			return false
		match skill.target_type:
			"unit":
				_refresh_target()
				request.target = target
			"ground_area":
				var aim := request.direction
				request.ground_position = global_position + Vector3(aim.x, 0.0, aim.y) * skill.cast_range
				request.ground_position.x = clampf(request.ground_position.x, arena_min.x, arena_max.x)
				request.ground_position.z = clampf(request.ground_position.z, arena_min.y, arena_max.y)
				request.has_ground_position = true
	return execute_action(request)


func _player_skill_index(action: StringName) -> int:
	match action:
		&"skill_q": return SKILL_Q
		&"skill_w": return SKILL_W
		&"skill_e": return SKILL_E
		&"skill_r": return SKILL_R
		&"skill_t": return SKILL_T
	return 0


func _player_aim_direction(direction_input: Vector2) -> Vector2:
	if direction_input.is_finite() and direction_input.length_squared() > 0.0001:
		return direction_input.normalized()
	return player_facing_direction.normalized() if player_facing_direction.length_squared() > 0.0001 else Vector2.RIGHT


func _start_next_attack(manual_attack := false) -> void:
	attack_hit_sent = false
	attack_audio_events_sent.clear()
	current_attack_is_manual = manual_attack
	if manual_attack:
		current_attack_facing_direction = player_facing_direction.normalized()
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
	if current_attack_is_breaker and not manual_attack and _should_lunge_to_target():
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
	var hit_target := _find_manual_attack_target() if current_attack_is_manual else target
	if not _is_target_available(hit_target):
		return
	var hit_offset := hit_target.global_position - global_position
	hit_offset.y = 0.0
	var hit_distance := hit_offset.length() if current_attack_is_manual else distance
	if hit_distance <= get_current_attack_hit_range():
		if hit_target.has_method("register_damage_source"):
			hit_target.call("register_damage_source", global_position, get_team())
		if current_attack_is_breaker:
			skill_controller.call("resolve_breaker_attack", hit_target)
			current_attack_is_breaker = false
		else:
			var damage := garen_definition.attack_damage
			var hit_profile_id: StringName = hit_event.payload_id if hit_event != null else &"basic_melee"
			if hit_target.has_method("receive_hit"):
				hit_target.call("receive_hit", global_position, character_model.current_animation, damage, self)
			elif hit_target.has_method("receive_skill_damage"):
				hit_target.call("receive_skill_damage", damage, String(character_model.current_animation), true, global_position, &"physical", hit_profile_id, self)
			if skill_controller != null:
				skill_controller.call("register_courage_kill", hit_target)
		attack_landed.emit(character_model.current_animation)


func _find_manual_attack_target() -> CharacterBody3D:
	var facing := Vector3(current_attack_facing_direction.x, 0.0, current_attack_facing_direction.y).normalized()
	return CombatTargetQuery.first_hostile_in_facing_arc(get_tree(), self, global_position, facing, get_current_attack_hit_range(), 0.15)


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
	if state != CombatState.ATTACK:
		return
	current_attack_is_manual = false
	state = CombatState.CHASE
	_invalidate_ai_decision("attack finished")
	_set_state(CombatState.CHASE)


func uses_hero_brain() -> bool:
	return true


func supports_player_control() -> bool:
	return true


func _on_control_authority_changed(_authority: ControlAuthority) -> void:
	player_move_input = Vector2.ZERO
	_invalidate_ai_decision("control authority changed")


func _setup_ai_brain() -> void:
	ai_brain = HeroBrain.new()
	ai_brain.configure(JuggernautPressureEvaluator.new(), GarenAIKit.new(), combat_database)


func _build_ai_context() -> HeroAIContext:
	var ctx := HeroAIContext.new()
	ctx.actor = self
	ctx.target = target if _is_target_available(target) else null
	ctx.database = combat_database
	ctx.archetype = ai_archetype as AIArchetypeDefinition
	ctx.profile = fighter_ai
	ctx.now_seconds = float(Time.get_ticks_msec()) / 1000.0
	ctx.delta = get_physics_process_delta_time()
	ctx.self_position = global_position
	ctx.self_health_ratio = get_health_ratio()
	ctx.preferred_distance = float(ai_archetype.preferred_distance) if ai_archetype != null else attack_range
	ctx.engage_distance = float(ai_archetype.engage_distance) if ai_archetype != null else attack_range + 1.0
	ctx.disengage_distance = float(ai_archetype.disengage_distance) if ai_archetype != null else 0.0
	ctx.attack_range = attack_range
	ctx.cast_range = ctx.engage_distance
	ctx.rooted = is_rooted()
	ctx.arena_min = arena_min
	ctx.arena_max = arena_max
	var skill_cooldowns: Array = skill_controller.get("cooldowns") as Array
	ctx.q_ready = _skill_ready(skill_cooldowns, SKILL_Q)
	ctx.w_ready = _skill_ready(skill_cooldowns, SKILL_W)
	ctx.e_ready = _skill_ready(skill_cooldowns, SKILL_E)
	ctx.r_ready = _skill_ready(skill_cooldowns, SKILL_R)
	ctx.t_ready = _skill_ready(skill_cooldowns, SKILL_T)
	ctx.extras[&"breaker_empowered"] = bool(skill_controller.call("should_use_breaker_attack"))
	ctx.extras[&"is_casting"] = bool(skill_controller.get("is_casting"))
	ctx.extras[&"current_skill"] = int(skill_controller.get("current_skill"))
	ctx.extras[&"r_range"] = _skill_range(SKILL_R)
	ctx.extras[&"e_range"] = _skill_range(SKILL_E)
	ctx.extras[&"t_range"] = _skill_range(SKILL_T)
	ctx.extras[&"breaker_lunge_range"] = _breaker_lunge_range()
	ctx.extras[&"move_speed_multiplier"] = float(skill_controller.call("get_move_speed_multiplier")) * _external_move_speed_multiplier()
	ctx.extras[&"attack_damage"] = garen_definition.attack_damage
	ctx.extras[&"recent_damage_ratio"] = ai_recent_damage_accumulator / maxf(float(skill_controller.get("max_health")), 1.0)
	if ctx.target != null:
		ctx.target_position = target.global_position
		ctx.target_velocity = target.velocity
		ctx.target_distance = _target_distance()
		ctx.target_health_ratio = _target_health_ratio(target)
		ctx.target_is_hero = target.is_in_group(&"hero_actor")
		ctx.target_is_training_dummy = target.is_in_group(&"training_dummy")
		var target_max_health := float(target.get("max_health"))
		ctx.extras[&"target_health"] = target_max_health * ctx.target_health_ratio
		ctx.extras[&"projected_execute_damage"] = float(skill_controller.call("calculate_judgment_damage", target_max_health, ctx.target_health_ratio))
	ctx.nearby_enemy_count = _count_nearby_enemies(maxf(ctx.engage_distance, _skill_range(SKILL_E)))
	if ctx.rooted:
		ctx.block_action(&"approach", "rooted")
	var casting := bool(ctx.extras[&"is_casting"])
	if casting and int(ctx.extras[&"current_skill"]) == SKILL_E:
		for action: StringName in [&"approach", &"retreat", &"basic_attack", &"skill_q", &"skill_e", &"skill_r", &"skill_t"]:
			ctx.block_action(action, "ocean storm active")
	elif casting or state == CombatState.ATTACK:
		for action: StringName in [&"approach", &"retreat", &"basic_attack", &"skill_q", &"skill_w", &"skill_e", &"skill_r", &"skill_t"]:
			ctx.block_action(action, "action locked")
	return ctx


func _update_ai_decision(delta: float) -> void:
	if ai_brain == null:
		return
	ai_decision_timer -= delta
	if ai_decision_timer > 0.0 and ai_decision != null:
		return
	ai_decision_timer = maxf(float(ai_archetype.decision_interval), 0.05) if ai_archetype != null else 0.15
	ai_decision = ai_brain.think(_build_ai_context())
	if ai_debug:
		var parts: Array[String] = []
		var limit := int(combat_database.get_rule(&"ai.utility.debug_top_count", 3)) if combat_database != null else 3
		for candidate: HeroAIDecision in ai_brain.debug_top_candidates(limit):
			parts.append("%s %.0f" % [String(candidate.action_id), candidate.score])
		state_label.text = "AI %s\n%s" % [String(ai_decision.action_id), " | ".join(parts)]


func _invalidate_ai_decision(_reason: String = "") -> void:
	if ai_brain != null:
		ai_brain.clear_intent()
	ai_decision = null
	ai_decision_timer = 0.0


func _can_execute_ai_decision(decision: HeroAIDecision) -> bool:
	return can_execute_action(_ai_action_request(decision))


func _ai_action_request(decision: HeroAIDecision) -> HeroActionRequest:
	if decision == null:
		return null
	var request := HeroActionRequest.new()
	request.source = HeroActionRequest.Source.AI
	request.action_id = decision.action_id
	request.skill_slot = decision.skill_slot
	request.target = decision.target
	request.has_ground_position = decision.has_destination
	request.ground_position = decision.destination
	return request


## Final hero-local gate for both intent sources. AI retains its chosen target
## and range policy; manual casts follow the skill's targeting semantics.
func can_execute_action(request: HeroActionRequest) -> bool:
	if request == null or is_dead or process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	var action := request.action_id
	var casting := bool(skill_controller.get("is_casting"))
	var ocean_storm := casting and int(skill_controller.get("current_skill")) == SKILL_E
	if request.source == HeroActionRequest.Source.PLAYER:
		if not is_player_controlled() or state == CombatState.ATTACK:
			return false
		if action == &"basic_attack":
			return not casting
		var player_skill_index := _player_skill_index(action)
		if player_skill_index == 0 or combat_database == null:
			return false
		var skill := combat_database.get_skill_by_slot(&"garen", player_skill_index)
		if skill == null or request.skill_slot != StringName(String(action).trim_prefix("skill_")):
			return false
		var skill_cooldowns: Array = skill_controller.get("cooldowns") as Array
		if not _skill_ready(skill_cooldowns, player_skill_index):
			return false
		if float(skill_controller.get("silence_timer")) > 0.0 and player_skill_index != SKILL_W:
			return false
		if casting and not (player_skill_index == SKILL_W and ocean_storm):
			return false
		match skill.target_type:
			"unit":
				if not CombatTargetQuery.matches_relation(self, request.target, skill.target_relation):
					return false
				var target_offset := request.target.global_position - global_position
				target_offset.y = 0.0
				return target_offset.length() <= skill.cast_range
			"ground_area":
				if not request.has_ground_position or not request.ground_position.is_finite():
					return false
				var ground_offset := request.ground_position - global_position
				ground_offset.y = 0.0
				return ground_offset.length() >= 0.05 and ground_offset.length() <= skill.cast_range + 0.01
			"direction":
				return request.direction.is_finite() and request.direction.length_squared() > 0.0001
			"self", "self_area":
				return true
		return false
	if action != &"hold" and not _is_target_available(target):
		return false
	if request.target != null and request.target != target:
		return false
	if action == &"approach":
		return not casting and not is_rooted() and state != CombatState.ATTACK
	if action == &"hold":
		return true
	if action == &"basic_attack":
		return not casting and state != CombatState.ATTACK and (_target_distance() <= attack_range or (bool(skill_controller.call("should_use_breaker_attack")) and _target_distance() <= _breaker_lunge_range()))
	var skill_index := _player_skill_index(action)
	if skill_index == 0:
		return false
	var skill_cooldowns: Array = skill_controller.get("cooldowns") as Array
	if not _skill_ready(skill_cooldowns, skill_index):
		return false
	if skill_index == SKILL_W:
		return state != CombatState.ATTACK and (not casting or ocean_storm)
	if casting or not can_start_skill():
		return false
	if skill_index == SKILL_Q:
		return _target_distance() <= maxf(float(ai_archetype.engage_distance), _breaker_lunge_range())
	return _target_distance() <= _skill_range(skill_index)


func _try_consume_ai_one_shot(decision: HeroAIDecision) -> bool:
	if decision == null or decision.generation == last_consumed_decision_generation:
		return false
	if not _start_combat_action(decision):
		_invalidate_ai_decision("one-shot rejected")
		return false
	last_consumed_decision_generation = decision.generation
	_invalidate_ai_decision()
	return true


func _start_combat_action(decision: HeroAIDecision) -> bool:
	return execute_action(_ai_action_request(decision))


## Starts only requests accepted by can_execute_action; damage and cooldowns
## remain owned by the existing attack and skill implementations.
func execute_action(request: HeroActionRequest) -> bool:
	if not can_execute_action(request):
		return false
	if request.action_id == &"basic_attack":
		if request.source == HeroActionRequest.Source.PLAYER:
			_face_direction(Vector3(request.direction.x, 0.0, request.direction.y))
		_start_next_attack(request.source == HeroActionRequest.Source.PLAYER)
		return true
	var skill_index := _player_skill_index(request.action_id)
	if skill_index == 0:
		return false
	if request.source == HeroActionRequest.Source.AI:
		return bool(skill_controller.call("begin_skill", skill_index, target))
	var skill := combat_database.get_skill_by_slot(&"garen", skill_index)
	var ground_point := request.ground_position if request.has_ground_position else Vector3.INF
	if skill.target_type == "ground_area":
		_face_direction(Vector3(request.direction.x, 0.0, request.direction.y))
	var started := bool(skill_controller.call("begin_skill", skill_index, request.target, ground_point))
	if started and skill.target_type == "unit" and skill.facing_policy != "none" and is_instance_valid(request.target):
		_face_direction(request.target.global_position - global_position)
	return started


func _execute_ai_decision(decision: HeroAIDecision, delta: float, direction: Vector3) -> void:
	if decision == null:
		_slow_down(delta)
		return
	if decision.action_id == &"approach":
		if not _can_execute_ai_decision(decision):
			_invalidate_ai_decision("approach rejected")
			_slow_down(delta)
			return
		_set_state(CombatState.CHASE)
		var speed_multiplier := float(skill_controller.call("get_move_speed_multiplier")) * _external_move_speed_multiplier()
		velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, acceleration * delta)
	elif decision.action_id == &"hold":
		_slow_down(delta)
		_set_state(CombatState.IDLE)
	else:
		_slow_down(delta)
		_try_consume_ai_one_shot(decision)


func record_ai_damage_taken(actual_health_loss: float) -> void:
	if actual_health_loss <= 0.0:
		return
	ai_recent_damage_accumulator += actual_health_loss
	ai_recent_damage_hold_timer = 1.0


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
	return CombatTargetQuery.hostiles_in_radius(get_tree(), self, global_position, radius).size()


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
	var floor_velocity := float(combat_database.get_rule(&"combat.floor_stick_velocity"))
	var gravity := float(combat_database.get_rule(&"combat.gravity"))
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
	if not is_instance_valid(target):
		target = null
	var preferred := _find_closest_target()
	if preferred == null:
		_set_target_outline(target, false)
		target = null
		_invalidate_ai_decision("target lost")
		skill_controller.call("set_target", target)
		return
	var should_switch := not _is_target_available(target)
	if not should_switch and _is_training_dummy(target) and _is_hero_actor(preferred):
		should_switch = true
	if not should_switch:
		return
	_set_target_outline(target, false)
	target = preferred
	_invalidate_ai_decision("target changed")
	_set_target_outline(target, true)
	skill_controller.call("set_target", target)
	if state != CombatState.ATTACK and not bool(skill_controller.get("is_casting")):
		_set_state(CombatState.CHASE)


func _set_target_outline(candidate: Node, active: bool) -> void:
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("set_outline_targeted"):
		return
	candidate.call("set_outline_targeted", active)


func force_retarget_hostile() -> void:
	if is_dead:
		return
	target = null
	_invalidate_ai_decision("force retarget")
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
	return CombatTargetQuery.nearest_hostile(get_tree(), self, global_position, INF, true)


func _is_hostile_candidate(candidate: CharacterBody3D) -> bool:
	return CombatTargetQuery.matches_relation(self, candidate, "hostile")


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
	var damage := amount if amount >= 0.0 else garen_definition.attack_damage
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
	_invalidate_ai_decision("death")
	is_dead = true
	target = null
	state = CombatState.IDLE
	velocity = Vector3.ZERO
	breaker_lunge_pending = false
	if skill_controller != null:
		# E maintains spell3 from the skill controller's process loop. Cancel it
		# before playing death so neither that loop nor its async cast can reclaim
		# the model animation on a later frame.
		skill_controller.call("interrupt_for_death")
		skill_controller.call("set_target", null)
	if is_in_group(&"combat_target"):
		remove_from_group(&"combat_target")
	character_model.play_semantic(&"death")
	state_label.text = "AI · DEFEATED"


func revive_for_training() -> void:
	_invalidate_ai_decision("revive")
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


func get_control_duration_multiplier() -> float:
	return float(skill_controller.call("get_control_duration_multiplier")) if skill_controller != null else 1.0


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
	if is_rooted() or not _is_target_available(target):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= attack_range or distance > _breaker_lunge_range():
		return
	var direction := offset.normalized()
	_face_direction(direction)
	var standoff := float(combat_database.get_rule(&"garen.breaker.lunge_standoff"))
	var destination := target.global_position - direction * standoff
	destination.y = global_position.y
	destination.x = clampf(destination.x, arena_min.x, arena_max.x)
	destination.z = clampf(destination.z, arena_min.y, arena_max.y)
	var origin := global_position
	var duration := float(combat_database.get_rule(&"garen.breaker.lunge_duration"))
	var elapsed := 0.0
	while elapsed < duration and not is_rooted() and _is_target_available(target):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		global_position = origin.lerp(destination, ease(clampf(elapsed / duration, 0.0, 1.0), -1.6))


func _apply_combat_data() -> bool:
	combat_database = CombatData.database()
	if combat_database == null:
		push_error("Garen requires CombatDatabase")
		return false
	garen_definition = combat_database.get_unit(&"garen")
	if garen_definition == null:
		push_error("Garen requires unit definition garen")
		return false
	for rule_id: StringName in [&"combat.floor_stick_velocity", &"combat.gravity", &"garen.breaker.lunge_standoff", &"garen.breaker.lunge_duration"]:
		if combat_database.get_rule(rule_id) == null:
			push_error("Garen requires combat rule %s" % rule_id)
			return false
	var configured_combo: Array[StringName] = []
	for event: AnimationEventDefinition in combat_database.animation_events:
		if event.owner_id == &"garen" and event.event_type == "hit" and event.payload_id == &"basic_melee" and not configured_combo.has(event.animation_name):
			configured_combo.append(event.animation_name)
	if configured_combo.is_empty():
		push_error("Garen requires authored basic melee animation events")
		return false
	attack_combo = configured_combo
	move_speed = garen_definition.move_speed
	acceleration = garen_definition.acceleration
	attack_range = garen_definition.attack_range
	fighter_ai = combat_database.get_ai_profile(garen_definition.ai_profile_id)
	if fighter_ai == null:
		push_error("Garen requires AI profile %s" % garen_definition.ai_profile_id)
		return false
	arena_min = fighter_ai.arena_min
	arena_max = fighter_ai.arena_max
	ai_archetype = combat_database.get_ai_archetype(fighter_ai.archetype_id)
	if ai_archetype == null:
		push_error("Garen requires archetype %s" % fighter_ai.archetype_id)
		return false
	var hit_profile := combat_database.get_hit_profile(&"basic_melee")
	var breaker_profile := combat_database.get_hit_profile(&"breaker_hit")
	if hit_profile == null or breaker_profile == null:
		push_error("Garen requires basic_melee and breaker_hit profiles")
		return false
	attack_hit_range = hit_profile.size.x
	breaker_hit_range = breaker_profile.size.x
	var attack_profile := combat_database.get_asset_profile(&"garen_attack_audio")
	if attack_profile == null:
		push_error("Garen requires attack audio profile")
		return false
	var stream := load(attack_profile.audio_path) as AudioStream
	if stream == null:
		push_error("Garen requires attack audio stream %s" % attack_profile.audio_path)
		return false
	attack_audio.stream = stream
	attack_audio.volume_db = attack_profile.volume_db
	attack_audio.max_distance = attack_profile.max_distance
	attack_pitches = [attack_profile.pitch_max, 1.0, attack_profile.pitch_min]
	return true
