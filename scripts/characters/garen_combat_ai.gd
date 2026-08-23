extends CharacterBody3D

signal attack_landed(animation_name: StringName)

enum CombatState { IDLE, CHASE, ATTACK }

const ATTACK_COMBO: Array[StringName] = [&"attack1", &"attack2", &"attack3"]
const ATTACK_PITCHES: Array[float] = [1.08, 1.0, 0.88]
const CHARACTER_ANCHOR_JSON := "res://assets/characters/rogue_admiral_garen/idle1/spritesheet.json"

@export_node_path("CharacterBody3D") var target_path := NodePath("../EnemyPlaceholder")
@export_range(0.1, 10.0, 0.1) var move_speed := 3.4
@export_range(0.5, 4.0, 0.05) var attack_range := 1.5
@export_range(0.0, 20.0, 0.1) var acceleration := 14.0

@onready var character_frames: AnimatedSprite3D = $CharacterFrames
@onready var state_label: Label3D = $AIStateLabel
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var skill_controller: Node3D = $SkillController

var target: CharacterBody3D
var state := CombatState.IDLE
var combo_index := -1
var attack_hit_sent := false
var attack_sound_count := 0
var unflipped_sprite_offset := Vector2.ZERO
var current_attack_name: StringName = &"attack1"
var current_attack_is_breaker := false
var attack_combo: Array[StringName] = ATTACK_COMBO.duplicate()
var combat_database: CombatDatabase
var garen_definition: UnitDefinition
var fighter_ai: AIProfileDefinition
var attack_hit_range := 1.95
var arena_min := Vector2(-14.5, -4.3)
var arena_max := Vector2(14.5, 4.3)


func _ready() -> void:
	_apply_combat_data()
	target = get_node_or_null(target_path) as CharacterBody3D
	skill_controller.call("set_target", target)
	_apply_sprite_canvas_anchor()
	unflipped_sprite_offset = character_frames.offset
	character_frames.animation_finished.connect(_on_animation_finished)
	_set_state(CombatState.CHASE if is_instance_valid(target) else CombatState.IDLE)


func _apply_sprite_canvas_anchor() -> void:
	var file := FileAccess.open(CHARACTER_ANCHOR_JSON, FileAccess.READ)
	if file == null:
		push_warning("Could not read character anchor metadata: %s" % CHARACTER_ANCHOR_JSON)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Invalid character anchor metadata: %s" % CHARACTER_ANCHOR_JSON)
		return
	var meta: Dictionary = (parsed as Dictionary).get("meta", {})
	var canvas: Dictionary = meta.get("canvas", {})
	var canvas_width := float(canvas.get("width", 0.0))
	var canvas_height := float(canvas.get("height", 0.0))
	if canvas_width <= 0.0 or canvas_height <= 0.0:
		push_warning("Missing character canvas dimensions: %s" % CHARACTER_ANCHOR_JSON)
		return
	var origin_x := float(canvas.get("originPixelX", canvas_width * 0.5))
	var origin_y := float(canvas.get("originPixelY", canvas_height))
	character_frames.offset = Vector2(
		canvas_width * 0.5 - origin_x,
		origin_y - canvas_height * 0.5,
	)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
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
			if distance <= attack_range:
				_start_next_attack()
			else:
				_set_state(CombatState.CHASE)
				var speed_multiplier := float(skill_controller.call("get_move_speed_multiplier"))
				velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, acceleration * delta)
				velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, acceleration * delta)

	_apply_gravity(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_min.x, arena_max.x)
	global_position.z = clampf(global_position.z, arena_min.y, arena_max.y)


func _start_next_attack() -> void:
	attack_hit_sent = false
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
	character_frames.play(current_attack_name)


func _check_attack_hit(distance: float) -> void:
	if attack_hit_sent:
		return
	var frame_count := character_frames.sprite_frames.get_frame_count(character_frames.animation)
	var hit_event := combat_database.get_animation_event(&"garen", character_frames.animation, "hit") if combat_database != null else null
	var impact_normalized := hit_event.timing_value if hit_event != null and hit_event.timing_mode == "normalized" else 0.55
	var impact_frame := maxi(1, int(frame_count * impact_normalized))
	if character_frames.frame < impact_frame:
		return
	attack_hit_sent = true
	var audio_event := combat_database.get_animation_event(&"garen", character_frames.animation, "audio") if combat_database != null else null
	var fallback_pitch := ATTACK_PITCHES[combo_index] if combo_index >= 0 and combo_index < ATTACK_PITCHES.size() else 1.0
	attack_audio.pitch_scale = audio_event.float_value if audio_event != null else (0.94 if current_attack_is_breaker else fallback_pitch)
	attack_audio.play()
	attack_sound_count += 1
	if distance <= attack_hit_range:
		if current_attack_is_breaker:
			skill_controller.call("resolve_breaker_attack", target)
			current_attack_is_breaker = false
		elif target.has_method("receive_hit"):
			target.call("receive_hit", global_position, character_frames.animation)
		attack_landed.emit(character_frames.animation)


func _on_animation_finished() -> void:
	if state != CombatState.ATTACK or not is_instance_valid(target):
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


func _set_state(next_state: CombatState) -> void:
	var expected_animation := &"idle1"
	if next_state == CombatState.CHASE:
		expected_animation = skill_controller.call("get_run_animation") as StringName
	if state == next_state and character_frames.is_playing() and character_frames.animation == expected_animation:
		return
	state = next_state
	match state:
		CombatState.IDLE:
			character_frames.play(&"idle1")
			state_label.text = "AI · IDLE"
		CombatState.CHASE:
			character_frames.play(skill_controller.call("get_run_animation") as StringName)
			state_label.text = "AI · CHASE"
		CombatState.ATTACK:
			pass


func _face_direction(direction: Vector3) -> void:
	if absf(direction.x) > 0.05:
		var faces_left := direction.x < 0.0
		character_frames.flip_h = faces_left
		character_frames.offset = Vector2(
			-unflipped_sprite_offset.x if faces_left else unflipped_sprite_offset.x,
			unflipped_sprite_offset.y,
		)


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
		var speed_multiplier := float(skill_controller.call("get_move_speed_multiplier"))
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
	var hit_profile := combat_database.get_hit_profile(&"basic_melee")
	if hit_profile != null:
		attack_hit_range = hit_profile.size.x
	var attack_profile := combat_database.get_asset_profile(&"garen_attack_audio")
	if attack_profile != null:
		var stream := load(attack_profile.audio_path) as AudioStream
		if stream != null:
			attack_audio.stream = stream
		attack_audio.volume_db = attack_profile.volume_db
		attack_audio.max_distance = attack_profile.max_distance
