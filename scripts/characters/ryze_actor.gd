extends "res://scripts/actors/hero_instance.gd"

## Ryze runtime actor for movement, authority, targeting, and AI adaptation. It intentionally
## keeps targeting and all authored ranges in meters, so later player input can
## reuse the same Q/W/E/T/R calls without changing combat numbers.

const VFX_FRAMES := preload("res://assets/vfx/ryze_skills/ryze_skill_vfx_frames.tres")
const BASIC_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/projectile/spritesheet.json"
const Q_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/Spell1_Q/spritesheet.json"
const IMPACT_ANCHOR_JSON := "res://assets/vfx/ryze_skills/impact/spritesheet.json"
const E_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/Spell3_E/spritesheet.json"
const DEFAULT_PIXEL_SIZE := 0.004
const DEFAULT_IMPACT_CONTACT_Y_BIAS := 0.0
const DEFAULT_E_LAUNCH_Y_BIAS := 0.8
const DEFAULT_E_HIT_X_BIAS := 0.5
const DEFAULT_CAST_RANGE := 5.5
const DEFAULT_WARP_RANGE := 25.0
const MESH_AFTERIMAGE := preload("res://scripts/presentation/mesh_afterimage_3d.gd")
const HERO_HIT_FEEDBACK := preload("res://scripts/presentation/hero_hit_feedback_3d.gd")
const ELASTIC_VOXEL_SHELL := preload("res://scripts/vfx/elastic_voxel_shell.gd")
const ZAP_LIGHTNING := preload("res://assets/BinbunVFX_Vol2/ElectricFX/effects/zap/vfx_zap_lightning_01.tscn")
const LIGHTNING_CHAIN := preload("res://addons/vfx_library/effects/lightning_chain.tscn")

@export_enum("friendly", "enemy") var team := "friendly"
@export var level := 1
@export var enabled := false

var database: CombatDatabase
var definition: UnitDefinition
var target: CharacterBody3D
var max_health := 620.0
var current_health := 620.0
var armor := 22.0
var magic_resistance := 32.0
var is_dead := false
var hit_feedback: HeroHitFeedback3D
var silence_timer := 0.0
var armor_shred_timer := 0.0
var armor_shred_ratio := 0.0
var base_armor := 22.0
var base_magic_resistance := 32.0
var magic_resist_shred_timer := 0.0
var cooldowns: Dictionary:
	get: return skill_controller.cooldowns
	set(value): skill_controller.cooldowns = value
var arcane_stacks: int:
	get: return skill_controller.arcane_stacks
	set(value): skill_controller.arcane_stacks = value
var arcane_timer: float:
	get: return skill_controller.arcane_timer
	set(value): skill_controller.arcane_timer = value
var supercharged_casts: int:
	get: return skill_controller.supercharged_casts
	set(value): skill_controller.supercharged_casts = value
var supercharged_timer: float:
	get: return skill_controller.supercharged_timer
	set(value): skill_controller.supercharged_timer = value
var desperate_timer: float:
	get: return skill_controller.desperate_timer
	set(value): skill_controller.desperate_timer = value
var attack_index: int:
	get: return skill_controller.attack_index
	set(value): skill_controller.attack_index = value
var attack_timer: float:
	get: return skill_controller.attack_timer
	set(value): skill_controller.attack_timer = value
var action_lock: float:
	get: return skill_controller.action_lock
	set(value): skill_controller.action_lock = value
var ai_profile: Resource
var ai_archetype: Resource
var ai_brain: HeroBrain
var ai_decision: HeroAIDecision
var ai_decision_timer := 0.0
var last_consumed_decision_generation := -1
var ai_recent_damage_accumulator := 0.0
var ai_recent_damage_hold_timer := 0.0
@export var ai_debug := false
var arena_min := Vector2(-14.5, -3.4)
var arena_max := Vector2(14.5, 3.4)
var super_armor_timer: float:
	get: return skill_controller.super_armor_timer
	set(value): skill_controller.super_armor_timer = value
var r_winddown_authored_position := Vector3.ZERO
var r_winddown_authored_scale := Vector3.ONE
var supercharge_mesh_afterimage: Node
var e_orb_from_center_px := Vector2(126.5, 622.5)
var _r_landing_resolving: bool:
	get: return skill_controller.r_landing_resolving
	set(value): skill_controller.r_landing_resolving = value
var _r_landing_zapped: Dictionary:
	get: return skill_controller.r_landing_zapped
	set(value): skill_controller.r_landing_zapped = value
var _faces_left := false

@export_category("Scene VFX Preview")
@export var cast_vfx_preview_enabled := false

@onready var character_model: Node3D = $RyzeModel
var _skill_controller_cache: RyzeSkillController
var skill_controller: RyzeSkillController:
	get:
		if _skill_controller_cache == null:
			_skill_controller_cache = get_node_or_null("RyzeSkillController") as RyzeSkillController
		return _skill_controller_cache
	set(value): _skill_controller_cache = value
@onready var label: Label3D = $AIStateLabel
@onready var shield: AnimatedSprite3D = $Shield
@onready var t_buff: AnimatedSprite3D = $TBuff
@onready var shield_flip: AnimatedSprite3D = $ShieldFlip
@onready var t_buff_flip: AnimatedSprite3D = $TBuffFlip
@onready var basic_projectile_template: AnimatedSprite3D = $CastVFXPreview/BasicProjectile
@onready var q_projectile_template: AnimatedSprite3D = $CastVFXPreview/QProjectile
@onready var w_effect_template: AnimatedSprite3D = $CastVFXPreview/WEffect
@onready var e_projectile_template: AnimatedSprite3D = $CastVFXPreview/EProjectile
@onready var r_winddown_template: AnimatedSprite3D = $CastVFXPreview/RWinddown
@onready var w_loop_template: AnimatedSprite3D = $CastVFXPreview/WLoop
@onready var impact_template: AnimatedSprite3D = $CastVFXPreview/Impact


func _enter_tree() -> void:
	skill_controller = get_node_or_null("RyzeSkillController") as RyzeSkillController
	if skill_controller == null:
		push_error("Ryze actor requires an authored RyzeSkillController child")


func _ready() -> void:
	if skill_controller == null:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	database = CombatData.database()
	if database == null:
		push_error("Ryze requires CombatDatabase")
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	definition = database.get_unit(&"ryze")
	if definition == null:
		push_error("Ryze requires unit definition ryze")
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	for skill_id: StringName in [&"ryze_overload", &"ryze_rune_prison", &"ryze_spell_flux", &"ryze_realm_warp", &"ryze_desperate_power"]:
		if database.get_skill(skill_id) == null or database.get_skill_rank(skill_id, 1) == null:
			push_error("Ryze requires skill and rank data %s" % skill_id)
			process_mode = Node.PROCESS_MODE_DISABLED
			return
	for effect_id: StringName in [&"ryze_q_damage", &"ryze_w_damage", &"ryze_w_root", &"ryze_e_damage"]:
		if database.get_skill_effect_rank(effect_id, 1) == null:
			push_error("Ryze requires effect rank %s" % effect_id)
			process_mode = Node.PROCESS_MODE_DISABLED
			return
	for buff_id: StringName in [&"ryze_flux", &"ryze_arcane_mastery", &"ryze_supercharged", &"ryze_desperate_power"]:
		if database.get_buff(buff_id) == null:
			push_error("Ryze requires buff %s" % buff_id)
			process_mode = Node.PROCESS_MODE_DISABLED
			return
	for template: AnimatedSprite3D in [basic_projectile_template, q_projectile_template, w_effect_template, e_projectile_template, r_winddown_template, w_loop_template, impact_template]:
		if template == null:
			push_error("Ryze requires all authored CastVFXPreview templates")
			process_mode = Node.PROCESS_MODE_DISABLED
			return
	bind_hero_instance(database, definition)
	_bind_ai_profile()
	_bind_playable_bounds()
	max_health = definition.max_health
	current_health = max_health
	armor = definition.armor
	base_armor = definition.armor
	magic_resistance = definition.magic_resistance
	base_magic_resistance = definition.magic_resistance
	add_to_group(&"combat_target")
	_build_hit_feedback()
	_configure_team_groups()
	character_model.call(&"play_semantic", &"idle")
	if character_model.has_signal(&"animation_finished"):
		character_model.connect(&"animation_finished", _on_character_model_animation_finished)
	_bind_self_vfx_anchors()
	_hide_self_vfx_nodes()
	if r_winddown_template != null:
		r_winddown_authored_position = r_winddown_template.position
		r_winddown_authored_scale = r_winddown_template.scale
	_configure_cast_vfx_templates()
	_build_supercharge_mesh_afterimage()
	_cache_e_orb_from_center()
	_refresh_target()
	_setup_ai_brain()
	_update_label()


func _apply_vfx_canvas_anchor(sprite: AnimatedSprite3D, json_path: String) -> void:
	if sprite == null:
		return
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("Ryze VFX anchor metadata was not found: %s" % json_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Ryze VFX anchor metadata is invalid: %s" % json_path)
		return
	var canvas: Dictionary = (parsed as Dictionary).get("meta", {}).get("canvas", {})
	var width := float(canvas.get("width", 0.0))
	var height := float(canvas.get("height", 0.0))
	if width <= 0.0 or height <= 0.0:
		push_warning("Ryze VFX anchor metadata has no canvas dimensions: %s" % json_path)
		return
	var origin_x := float(canvas.get("originPixelX", width * 0.5))
	var origin_y := float(canvas.get("originPixelY", height * 0.5))
	sprite.offset = Vector2(width * 0.5 - origin_x, origin_y - height * 0.5)


func _bind_self_vfx_anchors() -> void:
	if shield == null:
		shield = get_node_or_null("Shield") as AnimatedSprite3D
	if t_buff == null:
		t_buff = get_node_or_null("TBuff") as AnimatedSprite3D
	if shield_flip == null:
		shield_flip = get_node_or_null("ShieldFlip") as AnimatedSprite3D
	if t_buff_flip == null:
		t_buff_flip = get_node_or_null("TBuffFlip") as AnimatedSprite3D
	if shield != null:
		shield.sprite_frames = VFX_FRAMES
		shield.material_override = null
	if shield_flip != null:
		shield_flip.sprite_frames = VFX_FRAMES
		shield_flip.material_override = null
	if t_buff != null:
		t_buff.sprite_frames = VFX_FRAMES
	if t_buff_flip != null:
		t_buff_flip.sprite_frames = VFX_FRAMES


func _hide_self_vfx_nodes() -> void:
	if shield != null:
		shield.visible = false
	if shield_flip != null:
		shield_flip.visible = false
	if t_buff != null:
		t_buff.visible = false
	if t_buff_flip != null:
		t_buff_flip.visible = false


func _facing_left() -> bool:
	return _faces_left


func _sync_self_vfx_node(plus_x: AnimatedSprite3D, flip_x: AnimatedSprite3D, animation: StringName, active: bool, follow_facing := true) -> void:
	var use_flip := follow_facing and _facing_left() and flip_x != null
	var next_sprite := flip_x if use_flip else plus_x
	var current_sprite := plus_x if plus_x != null and plus_x.visible else (flip_x if flip_x != null and flip_x.visible else null)
	if active and next_sprite != null and current_sprite != null and next_sprite != current_sprite:
		if current_sprite.animation == animation and next_sprite.sprite_frames == current_sprite.sprite_frames:
			next_sprite.play(animation)
			next_sprite.set_frame_and_progress(current_sprite.frame, current_sprite.frame_progress)
	if plus_x != null:
		plus_x.visible = active and not use_flip
		if plus_x.visible:
			if plus_x.animation != animation or not plus_x.is_playing():
				plus_x.play(animation)
		elif plus_x.is_playing():
			plus_x.pause()
	if flip_x != null:
		flip_x.visible = active and use_flip
		if flip_x.visible:
			if flip_x.animation != animation or not flip_x.is_playing():
				flip_x.play(animation)
		elif flip_x.is_playing():
			flip_x.pause()


func _physics_process(delta: float) -> void:
	ai_recent_damage_hold_timer = maxf(0.0, ai_recent_damage_hold_timer - delta)
	if ai_recent_damage_hold_timer <= 0.0:
		ai_recent_damage_accumulator = 0.0
	skill_controller.tick_effects(delta)
	silence_timer = maxf(0.0, silence_timer - delta)
	_update_armor_shred(delta)
	_update_magic_resist_shred(delta)
	_sync_t_buff_presentation()
	_sync_shield_presentation()
	_update_label()
	if is_dead:
		velocity = Vector3.ZERO
		return
	var rooted := tick_root(delta)
	if rooted:
		velocity.x = 0.0
		velocity.z = 0.0
	if not enabled:
		return
	_refresh_target()
	skill_controller.tick_action_lock(delta)
	if action_lock > 0.0:
		return
	if is_player_controlled():
		_apply_player_movement(rooted)
		return
	if target == null:
		return
	if silence_timer > 0.0:
		var silence_offset := target.global_position - global_position
		silence_offset.y = 0.0
		var silence_distance := silence_offset.length()
		_face(silence_offset)
		if silence_distance > _cast_range():
			if rooted:
				velocity = Vector3.ZERO
			else:
				velocity = silence_offset.normalized() * _move_speed()
				character_model.call(&"play_semantic", &"run")
			move_and_slide()
		else:
			velocity = Vector3.ZERO
			_basic_attack(target)
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	_face(to_target)
	_update_ai_decision(delta)
	_execute_ai_decision(ai_decision)


func uses_hero_brain() -> bool:
	return true


func _apply_player_movement(rooted: bool) -> void:
	var direction := Vector3(player_move_input.x, 0.0, player_move_input.y)
	velocity = Vector3.ZERO if rooted else direction * _move_speed()
	if velocity.length_squared() > 0.0001:
		_face(velocity)
		character_model.call(&"play_semantic", &"run")
	else:
		character_model.call(&"play_semantic", &"idle")
	move_and_slide()
	global_position = _clamp_to_arena(global_position)


func request_player_basic_attack(direction_input := Vector2.ZERO) -> bool:
	return _request_player_action(&"basic_attack", Vector3.ZERO, false, direction_input)


func request_player_skill(slot: StringName, direction_input := Vector2.ZERO) -> bool:
	if slot not in [&"q", &"w", &"e", &"r", &"t"]:
		return false
	var slot_index := _player_skill_index(slot)
	var skill := database.get_skill_by_slot(&"ryze", slot_index) if database != null else null
	if skill == null:
		return false
	if direction_input.is_finite() and direction_input.length_squared() > 0.0001:
		player_facing_direction = direction_input.normalized()
		_face(Vector3(player_facing_direction.x, 0.0, player_facing_direction.y))
	if skill.target_type == "ground_area":
		var aim := _player_aim_direction(direction_input)
		var distance := minf(_rulef(&"ryze.r.manual_warp_distance", 8.0), minf(_warp_range(), skill.cast_range))
		var destination := _clamp_to_arena(global_position + Vector3(aim.x, 0.0, aim.y) * distance)
		if destination.distance_to(global_position) < 0.01:
			return false
		return _request_player_action(&"skill_r", destination, true)
	return _request_player_action(StringName("skill_" + slot))


func _request_player_action(
	action: StringName,
	destination := Vector3.ZERO,
	has_destination := false,
	direction_input := Vector2.ZERO
) -> bool:
	if not is_player_controlled() or is_dead or not enabled or action_lock > 0.0:
		return false
	if direction_input.is_finite() and direction_input.length_squared() > 0.0001:
		player_facing_direction = direction_input.normalized()
		_face(Vector3(player_facing_direction.x, 0.0, player_facing_direction.y))
	var request := HeroActionRequest.new()
	request.source = HeroActionRequest.Source.PLAYER
	request.action_id = action
	request.direction = _player_aim_direction(direction_input)
	request.ground_position = destination
	request.has_ground_position = has_destination
	if action != &"basic_attack":
		request.skill_slot = StringName(String(action).trim_prefix("skill_"))
		var skill := database.get_skill_by_slot(&"ryze", _player_skill_index(request.skill_slot)) if database != null else null
		if skill != null and skill.target_type == "unit":
			_refresh_target()
			request.target = target
	return execute_action(request)


func _player_skill_index(slot: StringName) -> int:
	match slot:
		&"q": return 1
		&"w": return 2
		&"e": return 3
		&"r": return 4
		&"t": return 5
	return -1


func _player_aim_direction(direction_input: Vector2) -> Vector2:
	if direction_input.is_finite() and direction_input.length_squared() > 0.0001:
		return direction_input.normalized()
	return player_facing_direction.normalized() if player_facing_direction.length_squared() > 0.0001 else Vector2.RIGHT


func _player_aim_vector3() -> Vector3:
	var aim := player_facing_direction.normalized() if player_facing_direction.length_squared() > 0.0001 else Vector2.RIGHT
	return Vector3(aim.x, 0.0, aim.y)


func _is_player_combat_action_ready(slot: StringName) -> bool:
	if is_rooted() and slot == &"r":
		return false
	if slot == &"basic_attack":
		return action_lock <= 0.0
	return cooldowns.get(slot, 0.0) <= 0.0 and action_lock <= 0.0


func supports_player_control() -> bool:
	return true


func _on_control_authority_changed(_authority: ControlAuthority) -> void:
	player_move_input = Vector2.ZERO
	_invalidate_ai_decision("control authority changed")


func _setup_ai_brain() -> void:
	ai_brain = HeroBrain.new()
	ai_brain.configure(BattlemageZoneEvaluator.new(), RyzeAIKit.new(), database)


func _build_ai_context() -> HeroAIContext:
	var ctx := HeroAIContext.new()
	ctx.actor = self
	ctx.target = target if is_instance_valid(target) and _valid_target(target) else null
	ctx.database = database
	ctx.archetype = ai_archetype as AIArchetypeDefinition
	ctx.archetype_evaluator = ai_brain.archetype_evaluator if ai_brain != null else null
	ctx.profile = ai_profile as AIProfileDefinition
	ctx.now_seconds = float(Time.get_ticks_msec()) / 1000.0
	ctx.delta = get_physics_process_delta_time()
	ctx.self_position = global_position
	ctx.self_health_ratio = get_health_ratio()
	ctx.cast_range = _cast_range()
	ctx.attack_range = ctx.cast_range
	ctx.output_range = ctx.cast_range
	ctx.control_range = ctx.cast_range
	ctx.preferred_distance = _preferred_distance()
	ctx.engage_distance = float(ai_archetype.engage_distance) if ai_archetype != null else ctx.cast_range
	ctx.disengage_distance = float(ai_archetype.disengage_distance) if ai_archetype != null else 1.5
	ctx.q_ready = cooldowns[&"q"] <= 0.0
	ctx.w_ready = cooldowns[&"w"] <= 0.0
	ctx.e_ready = cooldowns[&"e"] <= 0.0
	ctx.r_ready = cooldowns[&"r"] <= 0.0
	ctx.t_ready = cooldowns[&"t"] <= 0.0
	ctx.silenced = silence_timer > 0.0
	ctx.control_available = ctx.w_ready and not ctx.silenced
	ctx.rooted = is_rooted()
	ctx.action_locked = action_lock > 0.0
	ctx.arena_min = arena_min
	ctx.arena_max = arena_max
	ctx.extras[&"arcane_stacks"] = arcane_stacks
	ctx.extras[&"arcane_timer"] = arcane_timer
	ctx.extras[&"supercharged_casts"] = supercharged_casts
	ctx.extras[&"supercharged_timer"] = supercharged_timer
	ctx.extras[&"supercharged"] = _is_supercharged()
	ctx.extras[&"desperate_timer"] = desperate_timer
	ctx.extras[&"desperate_active"] = desperate_timer > 0.0
	ctx.extras[&"ready_basic_spell_count"] = _ready_basic_spell_count()
	ctx.extras[&"warp_range"] = _warp_range()
	ctx.extras[&"r_channel_duration"] = _rulef(&"ryze.r.channel_duration", 0.9)
	ctx.extras[&"r_cooldown_duration"] = _skill_cooldown(&"ryze_realm_warp", 180.0)
	ctx.move_speed = _move_speed()
	ctx.recent_damage_ratio = ai_recent_damage_accumulator / maxf(max_health, 1.0)
	if ctx.target != null:
		ctx.target_position = target.global_position
		ctx.target_velocity = target.velocity
		ctx.target_health_ratio = float(target.call("get_health_ratio")) if target.has_method("get_health_ratio") else 1.0
		ctx.target_distance = _current_target_distance()
		ctx.target_is_hero = target.is_in_group(&"hero_actor")
		ctx.target_is_training_dummy = target.is_in_group(&"training_dummy")
		ctx.target_rooted = target.has_method("is_rooted") and bool(target.call("is_rooted"))
		var to_actor := global_position - target.global_position
		to_actor.y = 0.0
		var planar_velocity := target.velocity
		planar_velocity.y = 0.0
		ctx.target_closing_speed = planar_velocity.dot(to_actor.normalized()) if to_actor.length_squared() > 0.0001 else 0.0
		ctx.extras[&"escape_destination"] = _escape_destination(target.global_position - global_position)
		ctx.extras[&"engage_destination"] = _engage_destination()
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := node as CharacterBody3D
		if candidate == null or candidate == self or not _can_harm(candidate):
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		if offset.length() <= ctx.cast_range:
			ctx.nearby_enemy_count += 1
		ctx.nearest_enemy_distance = minf(ctx.nearest_enemy_distance, offset.length())
		if candidate != target:
			ctx.enemies.append(candidate)
	if ai_brain != null and ai_brain.current_decision != null:
		ctx.current_intent = ai_brain.current_decision.action_id
		ctx.current_intent_age = ctx.now_seconds - ai_brain.current_intent_started_at
	if ctx.rooted:
		for action: StringName in [&"approach", &"retreat", &"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition"]:
			ctx.block_action(action, "rooted")
	if ctx.silenced:
		for action: StringName in [&"skill_q", &"skill_w", &"skill_e", &"skill_t", &"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition"]:
			ctx.block_action(action, "silenced")
	return ctx


func _update_ai_decision(delta: float) -> void:
	if ai_brain == null:
		return
	ai_decision_timer -= delta
	if ai_decision_timer > 0.0 and ai_decision != null:
		return
	ai_decision_timer = maxf(float(ai_archetype.decision_interval), 0.05) if ai_archetype != null else 0.16
	var context := _build_ai_context()
	ai_decision = ai_brain.think(context)
	if ai_debug:
		var parts: Array[String] = []
		var limit := int(database.get_rule(&"ai.utility.debug_top_count", 3)) if database != null else 3
		for candidate: HeroAIDecision in ai_brain.debug_top_candidates(limit):
			parts.append(_format_ai_candidate_debug(candidate))
		var outcome: Dictionary = context.outcome_evaluations.get(&"ryze_r_engage", {})
		var outcome_text := ""
		if not outcome.is_empty():
			outcome_text = "\nR engage base=%.1f warp=%.1f channel=%.1f cooldown=%.1f net=%.1f" % [
				float(outcome.get(&"baseline_state_value", 0.0)),
				float(outcome.get(&"warp_state_value", 0.0)),
				float(outcome.get(&"channel_risk", 0.0)),
				float(outcome.get(&"cooldown_cost", 0.0)),
				float(outcome.get(&"net_gain", 0.0)),
			]
		label.text += "\nAI %s: %s%s" % [String(ai_decision.action_id), " | ".join(parts), outcome_text]


func _format_ai_candidate_debug(candidate: HeroAIDecision) -> String:
	var details: Array[String] = []
	if candidate.metadata.has(&"anti_dive_bonus"):
		details.append("anti+%.0f" % float(candidate.metadata[&"anti_dive_bonus"]))
	if candidate.metadata.has(&"channel_risk_penalty"):
		details.append("channel-%.0f" % float(candidate.metadata[&"channel_risk_penalty"]))
	if candidate.metadata.has(&"position_improvement"):
		details.append("position+%.0f" % float(candidate.metadata[&"position_improvement"]))
	if candidate.metadata.has(&"root_relief"):
		details.append("root-%.0f" % float(candidate.metadata[&"root_relief"]))
	var suffix := " [%s]" % ", ".join(details) if not details.is_empty() else ""
	return "%s %.0f%s" % [String(candidate.action_id), candidate.score, suffix]


func _invalidate_ai_decision(_reason: String = "") -> void:
	if ai_brain != null:
		ai_brain.clear_intent()
	ai_decision = null
	ai_decision_timer = 0.0


func _current_target_distance() -> float:
	if not is_instance_valid(target) or not _valid_target(target):
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


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
	request.ground_position = decision.destination
	request.has_ground_position = decision.has_destination
	return request


## Final gate for both intent sources; skill effects remain in Ryze's existing
## cast methods while manual direction and AI target tracking stay distinct.
func can_execute_action(request: HeroActionRequest) -> bool:
	if request == null or is_dead or not enabled or action_lock > 0.0:
		return false
	var action := request.action_id
	if request.source == HeroActionRequest.Source.PLAYER:
		if not is_player_controlled():
			return false
		if action == &"basic_attack":
			return _is_player_combat_action_ready(&"basic_attack") and request.direction.is_finite() and request.direction.length_squared() > 0.0001
		var slot := request.skill_slot
		var skill := database.get_skill_by_slot(&"ryze", _player_skill_index(slot)) if database != null else null
		if skill == null or action != StringName("skill_" + slot) or silence_timer > 0.0 or not _is_player_combat_action_ready(slot):
			return false
		match skill.target_type:
			"unit":
				if not CombatTargetQuery.matches_relation(self, request.target, skill.target_relation):
					return false
				var target_offset := request.target.global_position - global_position
				target_offset.y = 0.0
				return target_offset.length() <= skill.cast_range
			"ground_area":
				return request.has_ground_position and request.ground_position.is_finite() \
					and request.ground_position.distance_to(global_position) <= _warp_range() + 0.01 \
					and _clamp_to_arena(request.ground_position).distance_to(request.ground_position) <= 0.01 \
					and not is_rooted()
			"direction":
				return request.direction.is_finite() and request.direction.length_squared() > 0.0001
			"self", "self_area":
				return true
		return false
	if action not in [&"hold", &"player_r"] and (not is_instance_valid(target) or not _can_harm(target)):
		return false
	if request.target != null and request.target != target:
		return false
	if is_rooted() and action in [&"approach", &"retreat", &"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition", &"player_r"]:
		return false
	if silence_timer > 0.0 and action in [&"skill_q", &"skill_w", &"skill_e", &"skill_t", &"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition", &"player_r"]:
		return false
	var distance := _current_target_distance()
	match action:
		&"basic_attack": return distance <= _cast_range()
		&"skill_q": return cooldowns[&"q"] <= 0.0 and distance <= _cast_range()
		&"skill_w": return cooldowns[&"w"] <= 0.0 and distance <= _cast_range()
		&"skill_e": return cooldowns[&"e"] <= 0.0 and distance <= _cast_range()
		&"skill_t": return cooldowns[&"t"] <= 0.0
		&"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition", &"player_r": return _is_valid_warp_destination(request)
	return true


func _is_valid_ai_warp_destination(decision: HeroAIDecision) -> bool:
	return _is_valid_warp_destination(_ai_action_request(decision))


func _is_valid_warp_destination(request: HeroActionRequest) -> bool:
	if request == null or cooldowns[&"r"] > 0.0 or not request.has_ground_position or not request.ground_position.is_finite():
		return false
	var travel := request.ground_position - global_position
	travel.y = 0.0
	if travel.length() > _warp_range() + 0.01:
		return false
	return _clamp_to_arena(request.ground_position).distance_to(request.ground_position) <= 0.01


func _start_ai_one_shot(decision: HeroAIDecision) -> bool:
	return _start_combat_action(decision)


func _start_combat_action(decision: HeroAIDecision) -> bool:
	return execute_action(_ai_action_request(decision))


## Executes an accepted request through the established attack and skill paths.
func execute_action(request: HeroActionRequest) -> bool:
	if not can_execute_action(request):
		return false
	velocity = Vector3.ZERO
	if request.source == HeroActionRequest.Source.PLAYER:
		var aim := Vector3(request.direction.x, 0.0, request.direction.y)
		match request.skill_slot:
			&"":
				_face(aim)
				_basic_attack_directional(aim)
			&"q":
				_face(aim)
				_cast_q_directional(aim)
			&"w", &"e":
				var skill := database.get_skill_by_slot(&"ryze", _player_skill_index(request.skill_slot))
				if skill.facing_policy != "none":
					_face(request.target.global_position - global_position)
				if request.skill_slot == &"w":
					_cast_w(request.target)
				else:
					_cast_e(request.target)
			&"r":
				_face(request.ground_position - global_position)
				cast_realm_warp(request.ground_position)
			&"t": cast_desperate_power()
			_: return false
		return true
	match request.action_id:
		&"basic_attack": _basic_attack(target)
		&"skill_q": _cast_q(target)
		&"skill_w": _cast_w(target)
		&"skill_e": _cast_e(target)
		&"skill_t": cast_desperate_power()
		&"ryze_r_escape", &"ryze_r_engage", &"ryze_r_reposition", &"player_r": cast_realm_warp(request.ground_position)
		_: return false
	return true


func _try_consume_ai_one_shot(decision: HeroAIDecision) -> bool:
	if decision == null or decision.generation == last_consumed_decision_generation:
		return false
	if not _start_ai_one_shot(decision):
		_invalidate_ai_decision("one-shot rejected")
		return false
	last_consumed_decision_generation = decision.generation
	_invalidate_ai_decision()
	return true


func _execute_ai_decision(decision: HeroAIDecision) -> void:
	if decision == null:
		return
	if decision.action_id in [&"hold", &"approach", &"retreat"]:
		if not _can_execute_ai_decision(decision):
			_invalidate_ai_decision("movement rejected")
			return
		match decision.action_id:
			&"approach":
				var direction := target.global_position - global_position
				direction.y = 0.0
				_face(direction)
				velocity = direction.normalized() * _move_speed()
				character_model.call(&"play_semantic", &"run")
			&"retreat":
				var direction := global_position - target.global_position
				direction.y = 0.0
				velocity = direction.normalized() * _move_speed()
				_face(velocity)
				character_model.call(&"play_semantic", &"run")
			&"hold":
				velocity = Vector3.ZERO
				character_model.call(&"play_semantic", &"idle")
		move_and_slide()
		return
	_try_consume_ai_one_shot(decision)


func record_ai_damage_taken(actual_health_loss: float) -> void:
	if actual_health_loss <= 0.0:
		return
	ai_recent_damage_accumulator += actual_health_loss
	ai_recent_damage_hold_timer = 1.0


func _basic_attack(victim: CharacterBody3D) -> void:
	skill_controller.basic_attack(victim)


func _basic_attack_directional(direction: Vector3) -> void:
	skill_controller.basic_attack_directional(direction)


func _cast_q(victim: CharacterBody3D) -> void:
	skill_controller.cast_q(victim)


func _cast_q_directional(direction: Vector3) -> void:
	skill_controller.cast_q_directional(direction)


func _cast_w(victim: CharacterBody3D) -> void:
	skill_controller.cast_w(victim)


func _cast_e(victim: CharacterBody3D) -> void:
	skill_controller.cast_e(victim)


func cast_desperate_power() -> void:
	skill_controller.cast_desperate_power()


func _request_awakening_cutin(skill_id: StringName) -> void:
	skill_controller._request_awakening_cutin(skill_id)


func cast_realm_warp(destination: Vector3) -> void:
	skill_controller.cast_realm_warp(destination)


func _play_realm_warp_windup(channel_duration: float) -> float:
	return skill_controller._play_realm_warp_windup(channel_duration)


func _on_character_model_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"spell4_winddown":
		action_lock = 0.0




func get_team() -> StringName:
	return StringName(team)


func get_display_name() -> String:
	return "瑞兹"


func is_enemy_of(other_team: StringName) -> bool:
	return StringName(team) != other_team


func is_targetable() -> bool:
	return enabled and not is_dead and current_health > 0.0


func get_health_ratio() -> float:
	return current_health / maxf(max_health, 1.0)


func receive_hit(attacker_position: Vector3, _attack_name: StringName, amount: float = -1.0, source_actor: Node = null) -> void:
	var damage := amount if amount >= 0.0 else definition.attack_damage
	receive_skill_damage(damage, "普攻", true, attacker_position, &"physical", &"basic_melee", source_actor)


func receive_breaker_attack(base_attack: float, bonus_damage: float, attacker_position: Vector3, hit_profile_id: StringName = &"breaker_hit", source_actor: Node = null) -> void:
	receive_skill_damage(base_attack + bonus_damage, "破舰", true, attacker_position, &"physical", hit_profile_id, source_actor)


func receive_skill_damage(amount: float, source_name: String, is_critical: bool, attacker_position: Vector3, damage_type: StringName = &"magic", hit_profile_id: StringName = &"ryze_e_hit", source_actor: Node = null) -> void:
	if is_dead or amount <= 0.0:
		return
	var health_before := current_health
	var resolved := CombatMath.resolve_damage(amount, damage_type, armor, magic_resistance, database)
	var applied_damage := minf(current_health, resolved)
	current_health = maxf(0.0, current_health - resolved)
	record_ai_damage_taken(maxf(0.0, health_before - current_health))
	if source_actor != null and applied_damage > 0.0:
		var stats := get_node_or_null("/root/CombatStats")
		if stats != null:
			stats.call("record_damage", source_actor, self, applied_damage, source_name, damage_type)
	if resolved > 0.0:
		present_resolved_damage(resolved, damage_type, is_critical)
		if hit_feedback != null:
			hit_feedback.play_hit(attacker_position, hit_profile_id, is_critical)
	if current_health <= 0.0:
		_die()


func _build_hit_feedback() -> void:
	hit_feedback = get_node_or_null("HeroHitFeedback3D") as HeroHitFeedback3D
	if hit_feedback == null:
		hit_feedback = HERO_HIT_FEEDBACK.new()
		hit_feedback.name = "HeroHitFeedback3D"
		hit_feedback.configure(database, &"RyzeModel")
		add_child(hit_feedback)
	else:
		hit_feedback.configure(database, &"RyzeModel")


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


func apply_magic_resistance_shred(multiplier: float, duration: float) -> void:
	if is_dead:
		return
	magic_resistance = base_magic_resistance * clampf(multiplier, 0.0, 1.0)
	magic_resist_shred_timer = maxf(magic_resist_shred_timer, duration)


func force_retarget_hostile() -> void:
	target = null
	_invalidate_ai_decision("force retarget")
	_refresh_target()


func _die() -> void:
	if is_dead:
		return
	_invalidate_ai_decision("death")
	is_dead = true
	current_health = 0.0
	enabled = false
	target = null
	velocity = Vector3.ZERO
	remove_from_group(&"combat_target")
	character_model.call(&"play_semantic", &"death")
	_update_label()


func revive_for_training() -> void:
	_invalidate_ai_decision("revive")
	is_dead = false
	enabled = true
	current_health = max_health
	armor = base_armor
	magic_resistance = base_magic_resistance
	armor_shred_timer = 0.0
	armor_shred_ratio = 0.0
	magic_resist_shred_timer = 0.0
	silence_timer = 0.0
	if not is_in_group(&"combat_target"):
		add_to_group(&"combat_target")
	character_model.call(&"play_semantic", &"idle")
	_configure_team_groups()
	_update_label()


func _update_armor_shred(delta: float) -> void:
	if armor_shred_timer <= 0.0:
		return
	armor_shred_timer = maxf(0.0, armor_shred_timer - delta)
	if armor_shred_timer <= 0.0:
		armor_shred_ratio = 0.0
		armor = base_armor


func _update_magic_resist_shred(delta: float) -> void:
	if magic_resist_shred_timer <= 0.0:
		return
	magic_resist_shred_timer = maxf(0.0, magic_resist_shred_timer - delta)
	if magic_resist_shred_timer <= 0.0:
		magic_resistance = base_magic_resistance




func _launch_projectile(victim: CharacterBody3D, animation: StringName, speed: float, payload: StringName) -> void:
	skill_controller.launch_projectile(victim, animation, speed, payload)


func _create_projectile(payload: StringName, animation: StringName) -> AnimatedSprite3D:
	var template := _projectile_template(payload)
	if template == null:
		push_error("Ryze projectile template missing for %s" % payload)
		return null
	var projectile := template.duplicate() as AnimatedSprite3D
	projectile.visible = true
	projectile.set_meta(&"authored_offset", projectile.offset)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin(payload)
	return projectile


func _launch_directional_projectile(animation: StringName, speed: float, payload: StringName, direction: Vector3, max_range: float) -> void:
	skill_controller.launch_directional_projectile(animation, speed, payload, direction, max_range)


func _first_enemy_on_projectile_segment(from: Vector3, to: Vector3) -> CharacterBody3D:
	return skill_controller.first_enemy_on_projectile_segment(from, to)


func _basic_attack_range() -> float:
	return skill_controller.basic_attack_range()


func _update_q_travel_deform(
	projectile: AnimatedSprite3D,
	base_scale: Vector3,
	direction: Vector3,
	elapsed: float
) -> void:
	if projectile == null:
		return
	var stretch_strength := _rulef(&"ryze.q.travel_stretch", 0.38)
	var squash_strength := _rulef(&"ryze.q.travel_squash", 0.24)
	var launch_pulse := _rulef(&"ryze.q.launch_pulse", 1.15)
	var throb_hz := _rulef(&"ryze.q.throb_hz", 5.5)
	var throb_amount := _rulef(&"ryze.q.throb_amount", 0.07)
	var pulse := exp(-elapsed * 7.5) * launch_pulse
	var throb := sin(elapsed * TAU * throb_hz) * throb_amount
	var speed_factor := clampf(direction.length() / maxf(_rulef(&"ryze.q.missile_speed", 17.0), 0.001), 0.35, 1.0)
	var stretch := 1.0 + (stretch_strength * (0.55 + pulse * 0.85) + throb) * speed_factor
	var squash := 1.0 - (squash_strength * (0.55 + pulse * 0.75) - throb * 0.5) * speed_factor
	squash = maxf(squash, 0.55)
	projectile.scale = Vector3(base_scale.x * stretch, base_scale.y * squash, base_scale.z)


func _projectile_origin(payload: StringName) -> Vector3:
	# Real editor-authored VFX nodes double as the runtime spawn templates. Their
	# local X is mirrored with the character, so one placement serves both sides.
	var template := _projectile_template(payload)
	if template == null:
		push_error("Ryze requires projectile template for %s" % payload)
		return global_position
	var local := template.position
	if _facing_left():
		local.x = -local.x
	if payload == &"e":
		local.y += _rulef(&"ryze.e.launch_y_bias", DEFAULT_E_LAUNCH_Y_BIAS)
	return global_position + local


func _play_target_vfx(victim: CharacterBody3D, animation: StringName) -> void:
	# W is authored against Ryze in the scene as a convenient stand-in target;
	# its local transform is then transferred to the real victim at runtime.
	var template: AnimatedSprite3D = w_effect_template if animation == &"Spell2_W" else null
	if template == null:
		push_error("Ryze target VFX template missing for %s" % animation)
		return
	var effect := template.duplicate() as AnimatedSprite3D
	effect.visible = true
	get_tree().current_scene.add_child(effect)
	effect.global_position = victim.global_position + template.position
	effect.frame = 0
	effect.play()
	effect.animation_finished.connect(effect.queue_free)


func _play_w_loop(victim: CharacterBody3D, duration: float) -> void:
	if not _valid_target(victim):
		return
	var effect := w_loop_template.duplicate() as AnimatedSprite3D
	effect.visible = true
	get_tree().current_scene.add_child(effect)
	effect.global_position = victim.global_position + w_loop_template.position
	effect.frame = 0
	effect.play()
	get_tree().create_timer(duration).timeout.connect(effect.queue_free)


func _play_r_landing_zap_once(victim: CharacterBody3D) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var key := victim.get_instance_id()
	if _r_landing_zapped.has(key):
		return
	_r_landing_zapped[key] = true
	_play_r_landing_zap(victim)


func _play_r_landing_zap(victim: CharacterBody3D) -> void:
	if not _can_harm(victim) or ZAP_LIGHTNING == null:
		return
	var effect := ZAP_LIGHTNING.instantiate() as Node3D
	if effect == null:
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = victim.global_position
	var zap_scale := _rulef(&"ryze.r.zap_scale", 0.5)
	effect.scale = Vector3.ONE * zap_scale
	if "one_shot" in effect:
		effect.set("one_shot", true)
	if effect.has_signal("finished"):
		effect.finished.connect(effect.queue_free, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(_rulef(&"ryze.r.zap_lifetime", 0.8)).timeout.connect(effect.queue_free)
	if effect.has_method("play"):
		effect.call("play")


func _play_r_winddown() -> void:
	if r_winddown_template == null:
		return
	# The lightning/portal sequence is presentation only.  It intentionally
	# uses its own SpriteFrames duration and does not participate in action_lock.
	var duration := _sprite_animation_duration(r_winddown_template, &"Spell4_R_winddown")
	r_winddown_template.visible = true
	r_winddown_template.position = Vector3(
		r_winddown_authored_position.x * (-1.0 if _facing_left() else 1.0),
		r_winddown_authored_position.y,
		r_winddown_authored_position.z
	)
	r_winddown_template.scale = r_winddown_authored_scale
	r_winddown_template.flip_h = _facing_left()
	r_winddown_template.frame = 0
	r_winddown_template.play(&"Spell4_R_winddown")
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(r_winddown_template):
		return
	r_winddown_template.stop()
	r_winddown_template.visible = false
	r_winddown_template.position = r_winddown_authored_position
	r_winddown_template.scale = r_winddown_authored_scale


func _sprite_animation_duration(sprite: AnimatedSprite3D, animation: StringName) -> float:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return 0.0
	var frames := sprite.sprite_frames
	var speed := maxf(frames.get_animation_speed(animation), 0.001)
	var total := 0.0
	for index in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, index)
	return total / speed


func _configure_cast_vfx_templates() -> void:
	_apply_vfx_canvas_anchor(basic_projectile_template, BASIC_PROJECTILE_ANCHOR_JSON)
	_apply_vfx_canvas_anchor(q_projectile_template, Q_PROJECTILE_ANCHOR_JSON)
	# E and Impact were placed in the editor as centered sprites. Applying
	# originPixel lifts both about 2.5m and breaks the authored launch height.
	if e_projectile_template != null:
		e_projectile_template.offset = Vector2.ZERO
	if impact_template != null:
		impact_template.offset = Vector2.ZERO
	for template: AnimatedSprite3D in [basic_projectile_template, q_projectile_template, w_effect_template, e_projectile_template, r_winddown_template, w_loop_template, impact_template]:
		template.sprite_frames = VFX_FRAMES
		template.visible = cast_vfx_preview_enabled
		if cast_vfx_preview_enabled:
			template.play()
		else:
			template.stop()


func _projectile_template(payload: StringName) -> AnimatedSprite3D:
	match payload:
		&"basic": return basic_projectile_template
		&"q": return q_projectile_template
		&"e": return e_projectile_template
	return null


func _target_visual_position(victim: CharacterBody3D) -> Vector3:
	if victim.has_method("get_hit_contact_point"):
		return victim.call("get_hit_contact_point", global_position)
	return victim.global_position + Vector3.UP * _rulef(&"ryze.hit.fallback_height", 1.15)


func _skill_travel_point(victim: CharacterBody3D, payload: StringName) -> Vector3:
	# Particles and Impact stay on the dummy contact socket. Q/E keep the
	# authored launch height so their orbs do not dive to the impact point.
	var contact := _target_visual_position(victim)
	if payload != &"q" and payload != &"e":
		return contact
	var origin := _projectile_origin(payload)
	var point := Vector3(contact.x, origin.y, contact.z)
	if payload == &"e":
		point.x += _rulef(&"ryze.e.hit_x_bias", DEFAULT_E_HIT_X_BIAS)
	return point


func _update_projectile_facing(projectile: AnimatedSprite3D, direction: Vector3) -> void:
	if projectile == null:
		return
	var face_left := _facing_left()
	if absf(direction.x) > 0.02:
		face_left = direction.x < 0.0
	projectile.flip_h = face_left
	var authored := Vector2.ZERO
	if projectile.has_meta(&"authored_offset"):
		authored = projectile.get_meta(&"authored_offset")
	else:
		authored = projectile.offset
		projectile.set_meta(&"authored_offset", authored)
	# flip_h only swaps UVs. originPixel stays pinned only if offset.x flips too.
	projectile.offset = Vector2(-authored.x if face_left else authored.x, authored.y)


func _resolve_e_chain(victim: CharacterBody3D) -> void:
	skill_controller.resolve_e_chain(victim)


func _cache_e_orb_from_center() -> void:
	# E keeps offset=0 so the authored orb stays at the accepted launch height.
	# The node origin is still the canvas center; Spell3_E's author (0,0) sits
	# 126.5 / 622.5 px away. Voxels must follow that orb, not E_LAUNCH_Y_BIAS.
	var file := FileAccess.open(E_PROJECTILE_ANCHOR_JSON, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var canvas: Dictionary = (parsed as Dictionary).get("meta", {}).get("canvas", {})
	var width := float(canvas.get("width", 0.0))
	var height := float(canvas.get("height", 0.0))
	if width <= 0.0 or height <= 0.0:
		return
	var origin_x := float(canvas.get("originPixelX", width * 0.5))
	var origin_y := float(canvas.get("originPixelY", height * 0.5))
	e_orb_from_center_px = Vector2(origin_x - width * 0.5, origin_y - height * 0.5)


func _e_orb_local_offset(projectile: AnimatedSprite3D) -> Vector3:
	var pixel := projectile.pixel_size if projectile != null else _character_pixel_size()
	var local := Vector3(e_orb_from_center_px.x * pixel, -e_orb_from_center_px.y * pixel, 0.0)
	if projectile != null and projectile.flip_h:
		local.x = -local.x
	return local


func _sync_e_voxel_shell(projectile: AnimatedSprite3D, shell: Node3D) -> void:
	if projectile == null or shell == null:
		return
	shell.position = _e_orb_local_offset(projectile)


func _attach_e_voxel_shell(projectile: AnimatedSprite3D, bounce: bool) -> Node3D:
	if projectile == null:
		return null
	var shell: Node3D = ELASTIC_VOXEL_SHELL.new()
	shell.name = "ElasticVoxelShell"
	projectile.add_child(shell)
	_sync_e_voxel_shell(projectile, shell)
	if shell.has_method("configure"):
		shell.call("configure", database)
	if bounce and shell.has_method("pulse_elastic"):
		shell.call("pulse_elastic", _rulef(&"ryze.e.launch_pulse", 1.35))
	return shell


func _launch_e_bounce(source: CharacterBody3D, victim: CharacterBody3D, damage_multiplier: float, return_target: CharacterBody3D) -> void:
	skill_controller.launch_e_bounce(source, victim, damage_multiplier, return_target)


func _apply_e(victim: CharacterBody3D, damage_multiplier: float = 1.0) -> void:
	skill_controller.apply_e(victim, damage_multiplier)


func _damage(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	skill_controller.damage(victim, amount, type, hit_profile)


func _deal_hit(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	skill_controller.deal_hit(victim, amount, type, hit_profile)


func _spill_desperate(primary: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	skill_controller.spill_desperate(primary, amount, type, hit_profile)


func _hit_vfx_contact(victim: CharacterBody3D) -> Vector3:
	# Particles, Impact sequence, and arcane splash must share one world point.
	return _target_visual_position(victim) + Vector3.UP * _rulef(
		&"ryze.impact.contact_y_bias",
		DEFAULT_IMPACT_CONTACT_Y_BIAS
	)


func _play_t_overflow_lightning(victim: CharacterBody3D) -> void:
	if not _can_harm(victim) or LIGHTNING_CHAIN == null:
		return
	var host := Node3D.new()
	host.name = "TOverflowLightning"
	get_tree().current_scene.add_child(host)
	host.global_position = _hit_vfx_contact(victim)
	var viewport := SubViewport.new()
	var viewport_size := _rulei(&"ryze.t.lightning_viewport_size", 256)
	viewport.size = Vector2i(viewport_size, viewport_size)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var lightning := LIGHTNING_CHAIN.instantiate() as Node2D
	var chain_scale := _rulef(&"presentation.library_lightning_chain_scale", 4.0)
	var lifetime := _rulef(&"presentation.library_lightning_chain_lifetime", 0.4)
	var center := float(viewport_size) * 0.5
	lightning.position = Vector2(center, center)
	lightning.scale = Vector2.ONE * chain_scale
	viewport.add_child(lightning)
	for child: Node in lightning.get_children():
		var emitter := child as CPUParticles2D
		if emitter != null:
			emitter.emitting = false
			emitter.restart()
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = _rulef(&"ryze.t.lightning_pixel_size", 0.01)
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = 42
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(sprite)
	get_tree().create_timer(lifetime).timeout.connect(host.queue_free)


func _play_impact(victim: CharacterBody3D) -> void:
	# Pin the authored explosion (originPixel) onto the same contact as the
	# magic particles / arcane splash. Do not reintroduce a Y bias patch.
	if not _can_harm(victim) or impact_template == null:
		return
	var effect := impact_template.duplicate() as AnimatedSprite3D
	effect.visible = true
	effect.render_priority = 41
	_apply_vfx_canvas_anchor(effect, IMPACT_ANCHOR_JSON)
	get_tree().current_scene.add_child(effect)
	effect.global_position = _hit_vfx_contact(victim)
	effect.frame = 0
	effect.play()
	effect.animation_finished.connect(effect.queue_free)


func _grant_supercharge() -> void:
	skill_controller.grant_supercharge()


func _add_arcane_stack(consumes_supercharge: bool) -> void:
	skill_controller.add_arcane_stack(consumes_supercharge)


func _ranked_damage(effect: StringName, _fallback: float) -> float:
	return skill_controller.ranked_damage(effect)


func _ranked_control(effect: StringName, _fallback: float) -> float:
	return skill_controller.ranked_control(effect)


func _cast_event_seconds(animation: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var event := database.get_animation_event(&"ryze", animation, "hit")
	if event == null or event.timing_mode != "seconds":
		return fallback
	return event.timing_value


func _refresh_target() -> void:
	if not is_instance_valid(target):
		target = null
	var preferred := _find_preferred_hostile()
	if preferred == null:
		if is_instance_valid(target):
			_set_target_outline(target, false)
		target = null
		_invalidate_ai_decision("target lost")
		return
	var should_switch := not is_instance_valid(target)
	if not should_switch:
		should_switch = not _valid_target(target)
	if (
		not should_switch
		and is_instance_valid(target)
		and target.is_in_group(&"training_dummy")
		and preferred.is_in_group(&"hero_actor")
	):
		should_switch = true
	if should_switch:
		if is_instance_valid(target):
			_set_target_outline(target, false)
		target = preferred
		_set_target_outline(target, true)
		_invalidate_ai_decision("target changed")


func _set_target_outline(candidate: Node, active: bool) -> void:
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("set_outline_targeted"):
		return
	candidate.call("set_outline_targeted", active)


func _find_preferred_hostile() -> CharacterBody3D:
	return CombatTargetQuery.nearest_hostile(get_tree(), self, global_position, INF, true)


func _valid_target(candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not (candidate is CharacterBody3D):
		return false
	return not candidate.has_method("is_targetable") or bool(candidate.call("is_targetable"))


func _face(direction: Vector3) -> void:
	if absf(direction.x) > 0.02:
		_faces_left = direction.x < 0.0
		character_model.call(&"set_facing", direction)


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


func _bind_ai_profile() -> void:
	if database == null or definition == null:
		return
	ai_profile = database.get_ai_profile(definition.ai_profile_id)
	if ai_profile == null:
		return
	arena_min = ai_profile.arena_min
	arena_max = ai_profile.arena_max
	ai_archetype = database.get_ai_archetype(ai_profile.archetype_id)


func _bind_playable_bounds() -> void:
	var ground := _find_ground_mesh()
	if ground == null:
		return
	var aabb := ground.global_transform * ground.get_aabb()
	var inset := _rulef(&"ryze.arena.ground_inset", 0.6)
	var ground_min := Vector2(aabb.position.x + inset, aabb.position.z + inset)
	var ground_max := Vector2(aabb.position.x + aabb.size.x - inset, aabb.position.z + aabb.size.z - inset)
	if ground_min.x >= ground_max.x or ground_min.y >= ground_max.y:
		return
	arena_min = Vector2(maxf(arena_min.x, ground_min.x), maxf(arena_min.y, ground_min.y))
	arena_max = Vector2(minf(arena_max.x, ground_max.x), minf(arena_max.y, ground_max.y))


func _find_ground_mesh() -> MeshInstance3D:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return null
	return scene.find_child("GroundMesh", true, false) as MeshInstance3D


func has_super_armor() -> bool:
	return skill_controller.super_armor_timer > 0.0


func _desperate_duration() -> float:
	return skill_controller.desperate_duration()


func _sync_t_buff_presentation() -> void:
	_sync_self_vfx_node(t_buff, t_buff_flip, &"T_Buff", desperate_timer > 0.0, false)


func _sync_shield_presentation() -> void:
	# Ryze is a 3D model: turning left/right only rotates the model below the
	# actor root. Keep the shield at one actor-local anchor instead of switching
	# to the legacy hand-offset Sprite, which made it appear to jump sideways.
	_sync_self_vfx_node(shield, shield_flip, &"Ryze_Shield", supercharged_casts > 0 and supercharged_timer > 0.0, false)


func _is_supercharged() -> bool:
	return skill_controller.is_supercharged()


func _ready_basic_spell_count() -> int:
	return skill_controller.ready_basic_spell_count()


func _is_supercharge_cast_animation(animation: StringName) -> bool:
	return skill_controller.is_supercharge_cast_animation(animation)


func _cast_speed() -> float:
	return skill_controller.cast_speed()


func _supercharge_cast_speed() -> float:
	return skill_controller.supercharge_cast_speed()


func _animation_elapsed_seconds() -> float:
	return float(character_model.call(&"get_elapsed_seconds"))


func _build_supercharge_mesh_afterimage() -> void:
	supercharge_mesh_afterimage = MESH_AFTERIMAGE.new()
	supercharge_mesh_afterimage.name = "SuperchargeMeshAfterimage"
	supercharge_mesh_afterimage.lifetime = _rulef(&"presentation.breaker_afterimage_lifetime", 0.22)
	supercharge_mesh_afterimage.color = Color.from_string(
		String(database.get_rule(&"presentation.breaker_afterimage_color", "29b8ffff")) if database != null else "29b8ffff",
		Color(0.16, 0.72, 1.0, 0.32)
	)
	supercharge_mesh_afterimage.color.a = _rulef(&"presentation.breaker_afterimage_alpha", 0.32)
	add_child(supercharge_mesh_afterimage)


func _engage_destination() -> Vector3:
	if not _valid_target(target):
		return global_position
	return _standoff_from(target.global_position, _preferred_distance())


func _preferred_distance() -> float:
	return 3.0 if ai_archetype == null else float(ai_archetype.preferred_distance)


func _standoff_from(anchor: Vector3, hold: float) -> Vector3:
	var planar := anchor - global_position
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = Vector3.LEFT if _facing_left() else Vector3.RIGHT
	var landing := anchor - planar.normalized() * hold
	landing.y = global_position.y
	return _clamp_to_arena(landing)


func _is_enemy_candidate(candidate: CharacterBody3D) -> bool:
	return _can_harm(candidate)


func _can_harm(candidate: CharacterBody3D) -> bool:
	return CombatTargetQuery.matches_relation(self, candidate, "hostile")


func _escape_destination(away_from_target: Vector3) -> Vector3:
	var planar := away_from_target
	planar.y = 0.0
	if planar.length_squared() <= 0.0001:
		planar = Vector3.LEFT if _facing_left() else Vector3.RIGHT
	return _clamp_to_arena(global_position - planar.normalized() * _rulef(&"ryze.r.escape_distance", 8.0))


func _clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena_min.x, arena_max.x), point.y, clampf(point.z, arena_min.y, arena_max.y))


func _count_nearby_enemies(radius: float) -> int:
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := node as CharacterBody3D
		if candidate == null or candidate == self or not _valid_target(candidate):
			continue
		if candidate.has_method("is_enemy_of") and not bool(candidate.call("is_enemy_of", get_team())):
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		if offset.length() <= radius:
			count += 1
	return count


func _update_label() -> void:
	var state := "超负荷 %d" % supercharged_casts if _is_supercharged() else "奥术 %d/%d" % [arcane_stacks, _buff_max_stacks(&"ryze_arcane_mastery", 5)]
	if desperate_timer > 0.0:
		state += " · 觉醒"
	label.text = "瑞兹 · %s\n%s · HP %d/%d" % [
		"蓝方" if team == "friendly" else "红方",
		state,
		int(current_health),
		int(max_health),
	]


func _rulef(rule_id: StringName, fallback: float) -> float:
	return skill_controller.rulef(rule_id, fallback)


func _rulei(rule_id: StringName, fallback: int) -> int:
	return skill_controller.rulei(rule_id, fallback)


func _cast_range() -> float:
	return _skill_range(&"ryze_overload", DEFAULT_CAST_RANGE)


func _warp_range() -> float:
	return _skill_range(&"ryze_realm_warp", DEFAULT_WARP_RANGE)


func _move_speed() -> float:
	var speed := database.get_unit_stat_value(&"ryze", &"move_speed", level) if database != null else 0.0
	if speed <= 0.0:
		push_error("Ryze requires positive move_speed unit stat")
	return speed


func _basic_missile_speed() -> float:
	var speed := database.get_unit_stat_value(&"ryze", &"missile_speed", level) if database != null else 0.0
	if speed <= 0.0:
		push_error("Ryze requires positive missile_speed unit stat")
	return speed


func _character_pixel_size() -> float:
	if database != null:
		var profile := database.get_asset_profile(&"ryze_character")
		if profile != null and profile.pixel_size > 0.0:
			return profile.pixel_size
	return DEFAULT_PIXEL_SIZE


func _skill_cooldown(skill_id: StringName, _fallback: float) -> float:
	return skill_controller.skill_cooldown(skill_id)


func get_skill_cooldown_state(slot: StringName) -> Dictionary:
	return skill_controller.get_skill_cooldown_state(slot)


func _skill_range(skill_id: StringName, _fallback: float) -> float:
	return skill_controller.skill_range(skill_id)


func _skill_radius(skill_id: StringName, _fallback: float) -> float:
	return skill_controller.skill_radius(skill_id)


func _skill_cast_time(skill_id: StringName, _fallback: float) -> float:
	return skill_controller.skill_cast_time(skill_id)


func _buff_duration(buff_id: StringName, _fallback: float) -> float:
	return skill_controller.buff_duration(buff_id)


func _buff_max_stacks(buff_id: StringName, _fallback: int) -> int:
	return skill_controller.buff_max_stacks(buff_id)


func _flux_remain_multiplier() -> float:
	return skill_controller.flux_remain_multiplier()


func _flux_duration() -> float:
	return _buff_duration(&"ryze_flux", 5.0)
