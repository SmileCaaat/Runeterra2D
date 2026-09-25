extends "res://scripts/actors/hero_instance.gd"

## Training implementation of the data-authored Ryze kit.  It intentionally
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
var cooldowns := {&"q": 0.0, &"w": 0.0, &"e": 0.0, &"r": 0.0, &"t": 0.0}
var arcane_stacks := 0
var arcane_timer := 0.0
var supercharged_casts := 0
var supercharged_timer := 0.0
var desperate_timer := 0.0
var attack_index := 0
var attack_timer := 0.0
var action_lock := 0.0
var root_timer := 0.0
var ai_profile: Resource
var ai_archetype: Resource
var arena_min := Vector2(-14.5, -3.4)
var arena_max := Vector2(14.5, 3.4)
var super_armor_timer := 0.0
var r_winddown_authored_position := Vector3.ZERO
var r_winddown_authored_scale := Vector3.ONE
var supercharge_mesh_afterimage: Node
var e_orb_from_center_px := Vector2(126.5, 622.5)
var _r_landing_resolving := false
var _r_landing_zapped: Dictionary = {}
var _faces_left := false

@export_category("Scene VFX Preview")
@export var cast_vfx_preview_enabled := false

@onready var character_model: Node3D = $RyzeModel
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


func _ready() -> void:
	database = CombatData.database()
	definition = database.get_unit(&"ryze") if database != null else null
	if definition != null:
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


func _sync_self_vfx_node(plus_x: AnimatedSprite3D, flip_x: AnimatedSprite3D, animation: StringName, active: bool) -> void:
	var use_flip := _facing_left() and flip_x != null
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
	for key: StringName in cooldowns:
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	arcane_timer = maxf(0.0, arcane_timer - delta)
	if arcane_timer <= 0.0 and arcane_stacks > 0:
		arcane_stacks = 0
	supercharged_timer = maxf(0.0, supercharged_timer - delta)
	if supercharged_timer <= 0.0:
		supercharged_casts = 0
	desperate_timer = maxf(0.0, desperate_timer - delta)
	super_armor_timer = maxf(0.0, super_armor_timer - delta)
	silence_timer = maxf(0.0, silence_timer - delta)
	_update_armor_shred(delta)
	_update_magic_resist_shred(delta)
	_sync_t_buff_presentation()
	_sync_shield_presentation()
	_update_label()
	if is_dead:
		velocity = Vector3.ZERO
		return
	if root_timer > 0.0:
		root_timer = maxf(0.0, root_timer - delta)
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not enabled:
		return
	_refresh_target()
	if target == null:
		return
	action_lock = maxf(0.0, action_lock - delta)
	if action_lock > 0.0:
		return
	if silence_timer > 0.0:
		var silence_offset := target.global_position - global_position
		silence_offset.y = 0.0
		var silence_distance := silence_offset.length()
		_face(silence_offset)
		if silence_distance > _cast_range():
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
	if _should_escape_warp(distance):
		cast_realm_warp(_escape_destination(to_target))
		return
	if _should_burst_t(distance):
		cast_desperate_power()
		return
	if _should_engage_warp(distance):
		cast_realm_warp(_engage_destination())
		return
	if distance > _cast_range():
		velocity = to_target.normalized() * _move_speed()
		character_model.call(&"play_semantic", &"run")
		move_and_slide()
		return
	if distance < _preferred_distance():
		velocity = -to_target.normalized() * _move_speed()
		# Kiting changes the travel vector. Face the actual run direction instead
		# of the target, otherwise the skeletal Run animation visibly moonwalks.
		_face(velocity)
		character_model.call(&"play_semantic", &"run")
		move_and_slide()
		return
	velocity = Vector3.ZERO
	if cooldowns[&"e"] <= 0.0:
		_cast_e(target)
	elif cooldowns[&"w"] <= 0.0:
		_cast_w(target)
	elif cooldowns[&"q"] <= 0.0:
		_cast_q(target)
	else:
		_basic_attack(target)


func _basic_attack(victim: CharacterBody3D) -> void:
	var animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"crit"]
	var animation := animations[attack_index]
	attack_index = (attack_index + 1) % animations.size()
	await _play_action_to_end(animation, _cast_event_seconds(animation, 0.5), func() -> void:
		_launch_projectile(victim, &"basic_attack", _basic_missile_speed(), &"basic")
	)


func _cast_q(victim: CharacterBody3D) -> void:
	cooldowns[&"q"] = _skill_cooldown(&"ryze_overload", 4.0)
	_add_arcane_stack(true)
	await _play_action_to_end(&"spell1", _cast_event_seconds(&"spell1", 0.3), func() -> void:
		_launch_projectile(victim, &"Spell1_Q", _rulef(&"ryze.q.missile_speed", 17.0), &"q")
	)


func _cast_w(victim: CharacterBody3D) -> void:
	cooldowns[&"w"] = _skill_cooldown(&"ryze_rune_prison", 14.0)
	_add_arcane_stack(true)
	await _play_action_to_end(&"spell2", _cast_event_seconds(&"spell2", 0.5), func() -> void:
		if _valid_target(victim):
			_play_target_vfx(victim, &"Spell2_W")
			_damage(victim, _ranked_damage(&"ryze_w_damage", 80.0), &"magic", &"ryze_w_hit")
			var root_duration := _ranked_control(&"ryze_w_damage", 1.0)
			if victim.has_method("apply_root"):
				victim.call("apply_root", root_duration)
			_play_w_loop(victim, root_duration)
	)


func _cast_e(victim: CharacterBody3D) -> void:
	cooldowns[&"e"] = _skill_cooldown(&"ryze_spell_flux", 7.0)
	_add_arcane_stack(true)
	await _play_action_to_end(&"spell3", _cast_event_seconds(&"spell3", 0.6), func() -> void:
		_launch_projectile(victim, &"Spell3_E", _rulef(&"ryze.e.missile_speed", 15.0), &"e")
	)


func cast_desperate_power() -> void:
	if cooldowns[&"t"] > 0.0:
		return
	cooldowns[&"t"] = _skill_cooldown(&"ryze_desperate_power", 50.0)
	character_model.call(&"play_semantic", &"taunt")
	var channel := _rulef(&"ryze.t.channel_duration", 0.8)
	action_lock = channel
	super_armor_timer = channel
	_request_awakening_cutin(&"ryze_desperate_power")
	await get_tree().create_timer(channel).timeout
	desperate_timer = _desperate_duration()
	_sync_t_buff_presentation()
	if _rulei(&"ryze.t.grant_supercharge", 1) != 0:
		_grant_supercharge()
	else:
		_add_arcane_stack(false)


func _request_awakening_cutin(skill_id: StringName) -> void:
	var manager := get_node_or_null("/root/AwakeningCutIn")
	if manager == null:
		manager = get_tree().get_first_node_in_group(&"awakening_cutin_manager")
	if manager == null or not manager.has_method("request_skill"):
		return
	manager.call("request_skill", skill_id, {"source": self})


func cast_realm_warp(destination: Vector3) -> void:
	if cooldowns[&"r"] > 0.0:
		return
	cooldowns[&"r"] = _skill_cooldown(&"ryze_realm_warp", 180.0)
	character_model.call(&"play_semantic", &"spell4")
	var channel := _skill_cast_time(&"ryze_realm_warp", 2.0)
	action_lock = channel
	await get_tree().create_timer(channel).timeout
	# Capture allies at the portal origin before Ryze moves, then share the same planar delta.
	var origin := global_position
	var planar := _clamp_to_arena(destination) - origin
	planar.y = 0.0
	var delta := planar.limit_length(_warp_range())
	var ally_radius := _skill_radius(&"ryze_realm_warp", 5.5)
	var allies := _collect_warp_allies(ally_radius)
	_teleport_actor(self, origin + delta)
	for ally: CharacterBody3D in allies:
		_teleport_actor(ally, ally.global_position + delta)
	character_model.call(&"play_semantic", &"spell4_winddown")
	# Query the requested semantic clip directly. Reading the player's current
	# length during a blend can still return the prior 2.333s Spell4_Idle clip.
	# The completion signal below remains the authoritative early release.
	action_lock = float(character_model.call(&"get_semantic_animation_length", &"spell4_winddown"))
	_play_r_winddown()
	_r_landing_resolving = true
	_r_landing_zapped.clear()
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate == null or candidate == self or not _is_enemy_candidate(candidate):
			continue
		if candidate.global_position.distance_to(global_position) <= ally_radius:
			_play_r_landing_zap_once(candidate)
			for _i in _rulei(&"ryze.r.landing_e_hits", 3):
				_apply_e(candidate)
	_r_landing_resolving = false
	_r_landing_zapped.clear()
	_add_arcane_stack(true)


func _on_character_model_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"spell4_winddown":
		action_lock = 0.0


func _collect_warp_allies(radius: float) -> Array[CharacterBody3D]:
	var allies: Array[CharacterBody3D] = []
	var seen: Dictionary = {}
	for group_name: StringName in [&"combat_target", &"friendly_actor", &"enemy_actor", &"player_actor", &"hero_actor"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := node as CharacterBody3D
			if candidate == null or seen.has(candidate.get_instance_id()):
				continue
			if not _is_warp_ally(candidate):
				continue
			var offset := candidate.global_position - global_position
			offset.y = 0.0
			if offset.length() > radius:
				continue
			seen[candidate.get_instance_id()] = true
			allies.append(candidate)
	return allies


func _is_warp_ally(candidate: CharacterBody3D) -> bool:
	if candidate == null or candidate == self or not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
		return false
	if candidate.has_method("get_team"):
		return String(candidate.call("get_team")) == String(get_team())
	if team == "friendly":
		return candidate.is_in_group(&"friendly_actor")
	if team == "enemy":
		return candidate.is_in_group(&"enemy_actor")
	return false


func _teleport_actor(actor: CharacterBody3D, destination: Vector3) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.global_position = _clamp_to_arena(destination)
	actor.velocity = Vector3.ZERO


func apply_root(duration: float) -> void:
	root_timer = maxf(root_timer, duration)


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
	var damage := amount if amount >= 0.0 else (definition.attack_damage if definition != null else 55.0)
	receive_skill_damage(damage, "普攻", true, attacker_position, &"physical", &"basic_melee", source_actor)


func receive_breaker_attack(base_attack: float, bonus_damage: float, attacker_position: Vector3, hit_profile_id: StringName = &"breaker_hit", source_actor: Node = null) -> void:
	receive_skill_damage(base_attack + bonus_damage, "破舰", true, attacker_position, &"physical", hit_profile_id, source_actor)


func receive_skill_damage(amount: float, source_name: String, is_critical: bool, attacker_position: Vector3, damage_type: StringName = &"magic", hit_profile_id: StringName = &"ryze_e_hit", source_actor: Node = null) -> void:
	if is_dead or amount <= 0.0:
		return
	var resolved := CombatMath.resolve_damage(amount, damage_type, armor, magic_resistance, database)
	var applied_damage := minf(current_health, resolved)
	current_health = maxf(0.0, current_health - resolved)
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
	_refresh_target()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	enabled = false
	target = null
	velocity = Vector3.ZERO
	remove_from_group(&"combat_target")
	character_model.call(&"play_semantic", &"death")
	_update_label()


func revive_for_training() -> void:
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


func _play_action_to_end(animation: StringName, cast_event_seconds: float, event: Callable) -> void:
	# Event times are authored directly in seconds and remain independent of the GLB clip name.
	action_lock = INF
	var supercharged := _is_supercharged() and _is_supercharge_cast_animation(animation)
	var speed := _supercharge_cast_speed() if supercharged else _cast_speed()
	character_model.call(&"set_animation_speed", speed)
	character_model.call(&"play_semantic", animation)
	var event_sent := false
	var event_elapsed := -1.0
	var event_time := cast_event_seconds / speed
	var recovery := _rulef(&"ryze.cast.recovery_seconds", 0.35)
	var min_lock := _rulef(&"ryze.supercharge.min_lock_seconds", 0.70) if supercharged else _rulef(&"ryze.cast.min_lock_seconds", 0.90)
	while StringName(character_model.get(&"current_animation")) == animation and bool(character_model.call(&"is_playing")):
		var elapsed := _animation_elapsed_seconds()
		if not event_sent and elapsed >= event_time:
			event_sent = true
			event_elapsed = elapsed
			if supercharged and supercharge_mesh_afterimage != null:
				supercharge_mesh_afterimage.capture(character_model)
			event.call()
		var unlock_at := min_lock
		if event_sent:
			unlock_at = maxf(event_elapsed + recovery, min_lock)
		if elapsed >= unlock_at:
			break
		await get_tree().process_frame
	if not event_sent:
		if supercharged and supercharge_mesh_afterimage != null:
			supercharge_mesh_afterimage.capture(character_model)
		event.call()
	action_lock = 0.0


func _launch_projectile(victim: CharacterBody3D, animation: StringName, speed: float, payload: StringName) -> void:
	if not _valid_target(victim):
		return
	var template := _projectile_template(payload)
	var projectile := template.duplicate() as AnimatedSprite3D if template != null else AnimatedSprite3D.new()
	if template == null:
		projectile.sprite_frames = VFX_FRAMES
		projectile.animation = animation
		projectile.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		projectile.pixel_size = _character_pixel_size()
		projectile.no_depth_test = true
		projectile.render_priority = 3
	projectile.visible = true
	projectile.set_meta(&"authored_offset", projectile.offset)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin(payload)
	_update_projectile_facing(projectile, _skill_travel_point(victim, payload) - projectile.global_position)
	projectile.frame = 0
	projectile.play()
	var e_shell: Node3D = _attach_e_voxel_shell(projectile, false) if payload == &"e" else null
	var q_base_scale := projectile.scale
	var q_elapsed := 0.0
	if payload == &"q":
		_update_q_travel_deform(projectile, q_base_scale, _skill_travel_point(victim, payload) - projectile.global_position, 0.0)
	while is_instance_valid(projectile) and _valid_target(victim):
		var hit_point := _skill_travel_point(victim, payload)
		var direction := hit_point - projectile.global_position
		var stop_distance := _rulef(&"ryze.basic.stop_distance", 0.45) if payload == &"basic" else _rulef(&"ryze.skill.stop_distance", 0.08)
		if direction.length() <= stop_distance:
			if payload != &"basic":
				projectile.global_position = hit_point
			break
		_update_projectile_facing(projectile, direction)
		if e_shell != null:
			_sync_e_voxel_shell(projectile, e_shell)
			if e_shell.has_method("set_travel"):
				e_shell.call("set_travel", direction)
		if payload == &"q":
			_update_q_travel_deform(projectile, q_base_scale, direction, q_elapsed)
			q_elapsed += 1.0 / 60.0
		var step := speed / 60.0
		if payload != &"basic" and direction.length() <= step:
			projectile.global_position = hit_point
			break
		projectile.global_position += direction.normalized() * step
		if not projectile.is_playing():
			projectile.play()
		await get_tree().physics_frame
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not _valid_target(victim):
		return
	match payload:
		&"basic":
			_damage(victim, definition.attack_damage if definition != null else 55.0, &"physical", &"ryze_basic_hit")
		&"q":
			_damage(victim, _ranked_damage(&"ryze_q_damage", 60.0), &"magic", &"ryze_q_hit")
		&"e": _resolve_e_chain(victim)


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
		return global_position + Vector3.UP * _rulef(&"ryze.hit.fallback_height", 1.15)
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
	var effect := template.duplicate() as AnimatedSprite3D if template != null else AnimatedSprite3D.new()
	if template == null:
		effect.sprite_frames = VFX_FRAMES
		effect.animation = animation
		effect.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		effect.pixel_size = _character_pixel_size()
		effect.no_depth_test = true
		effect.render_priority = 3
	effect.visible = true
	get_tree().current_scene.add_child(effect)
	effect.global_position = victim.global_position + (template.position if template != null else Vector3.UP * _rulef(&"ryze.w.fallback_height", 1.1))
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
	_apply_e(victim)
	var chain: Array[CharacterBody3D] = []
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate != null and candidate != victim and _valid_target(candidate) and candidate.global_position.distance_to(victim.global_position) <= _skill_radius(&"ryze_spell_flux", 3.5):
			chain.append(candidate)
	for candidate: CharacterBody3D in chain.slice(0, _rulei(&"ryze.e.max_bounce_targets", 6)):
		_launch_e_bounce(victim, candidate, 1.0, victim)
	if chain.is_empty():
		_launch_e_bounce(victim, victim, _rulef(&"ryze.e.bounce_damage_ratio", 0.5), null)


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
	if not _valid_target(source) or not _valid_target(victim):
		return
	var projectile := e_projectile_template.duplicate() as AnimatedSprite3D
	projectile.visible = true
	projectile.set_meta(&"authored_offset", projectile.offset)
	get_tree().current_scene.add_child(projectile)
	var start := _skill_travel_point(source, &"e")
	var destination := _skill_travel_point(victim, &"e")
	projectile.global_position = start
	projectile.frame = 0
	projectile.play()
	var authored_scale := projectile.scale
	var e_shell := _attach_e_voxel_shell(projectile, true)
	var distance := start.distance_to(destination)
	var duration := maxf(distance / maxf(_rulef(&"ryze.e.missile_speed", 15.0), 0.01), _rulef(&"ryze.e.min_travel_seconds", 0.08))
	var elapsed := 0.0
	var landing_pulse := false
	while is_instance_valid(projectile) and _valid_target(victim) and elapsed < duration:
		var step := minf(1.0 / 60.0, duration - elapsed)
		elapsed += step
		var progress := elapsed / duration
		var eased := ease(progress, _rulef(&"ryze.e.bounce_ease", -2.2))
		var hop := sin(progress * PI) + sin(progress * PI * 2.0) * _rulef(&"ryze.e.bounce_hop", 0.14)
		var arc := hop * minf(_rulef(&"ryze.e.bounce_arc_cap", 0.85), distance * _rulef(&"ryze.e.bounce_arc_ratio", 0.26))
		var next_position := start.lerp(destination, eased) + Vector3.UP * maxf(arc, 0.0)
		var travel := next_position - projectile.global_position
		_update_projectile_facing(projectile, travel)
		_sync_e_voxel_shell(projectile, e_shell)
		projectile.global_position = next_position
		var apex := sin(progress * PI)
		projectile.scale = Vector3(
			authored_scale.x * (_rulef(&"ryze.e.bounce_scale_x", 1.16) - apex * _rulef(&"ryze.e.bounce_squash_x", 0.30)),
			authored_scale.y * (_rulef(&"ryze.e.bounce_scale_y", 0.76) + apex * _rulef(&"ryze.e.bounce_squash_y", 0.40)),
			authored_scale.z
		)
		if e_shell != null:
			if e_shell.has_method("set_travel"):
				e_shell.call("set_travel", travel)
			if e_shell.has_method("set_apex_stretch"):
				e_shell.call("set_apex_stretch", apex)
			if not landing_pulse and progress >= _rulef(&"ryze.e.landing_pulse_progress", 0.78) and e_shell.has_method("pulse_elastic"):
				e_shell.call("pulse_elastic", _rulef(&"ryze.e.landing_pulse", 1.15))
				landing_pulse = true
		if not projectile.is_playing():
			projectile.play()
		await get_tree().physics_frame
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not _valid_target(victim):
		return
	_apply_e(victim, damage_multiplier)
	if return_target != null and _valid_target(return_target):
		_launch_e_bounce(victim, return_target, _rulef(&"ryze.e.bounce_damage_ratio", 0.5), null)


func _apply_e(victim: CharacterBody3D, damage_multiplier: float = 1.0) -> void:
	if not _can_harm(victim):
		return
	_damage(victim, _ranked_damage(&"ryze_e_damage", 36.0) * damage_multiplier, &"magic", &"ryze_e_hit")
	if victim.has_method("apply_magic_resistance_shred"):
		victim.call("apply_magic_resistance_shred", _flux_remain_multiplier(), _flux_duration())


func _damage(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	if not _can_harm(victim):
		return
	_deal_hit(victim, amount, type, hit_profile)
	if desperate_timer <= 0.0:
		return
	_play_t_overflow_lightning(victim)
	_spill_desperate(victim, amount, type, hit_profile)


func _deal_hit(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	if not _can_harm(victim):
		return
	if victim.has_method("receive_skill_damage"):
		victim.call("receive_skill_damage", amount, "瑞兹", false, global_position, type, hit_profile, self)
	_play_impact(victim)


func _spill_desperate(primary: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := node as CharacterBody3D
		if candidate == null or candidate == primary or not _can_harm(candidate):
			continue
		var offset := candidate.global_position - primary.global_position
		offset.y = 0.0
		if offset.length() <= _skill_radius(&"ryze_desperate_power", 3.5):
			_deal_hit(candidate, amount * _rulef(&"ryze.t.spill_damage_ratio", 0.5), type, hit_profile)
			if _r_landing_resolving:
				_play_r_landing_zap_once(candidate)


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
	supercharged_casts = _rulei(&"ryze.supercharge.max_casts", 5)
	supercharged_timer = _rulef(&"ryze.supercharge.duration", 2.5)
	arcane_stacks = 0


func _add_arcane_stack(consumes_supercharge: bool) -> void:
	var max_stacks := _buff_max_stacks(&"ryze_arcane_mastery", 5)
	arcane_stacks = mini(max_stacks, arcane_stacks + 1)
	arcane_timer = _buff_duration(&"ryze_arcane_mastery", 6.0)
	if arcane_stacks == max_stacks:
		_grant_supercharge()
	if consumes_supercharge and supercharged_casts > 0:
		supercharged_casts -= 1
		var refund := _rulef(&"ryze.supercharge.cooldown_refund", 4.0)
		for key: StringName in cooldowns:
			cooldowns[key] = maxf(0.0, float(cooldowns[key]) - refund)


func _ranked_damage(effect: StringName, fallback: float) -> float:
	var row := database.get_skill_effect_rank(effect, 1) if database != null else null
	return row.base_value if row != null else fallback


func _ranked_control(effect: StringName, fallback: float) -> float:
	var row := database.get_skill_effect_rank(effect, 1) if database != null else null
	return row.control_duration if row != null else fallback


func _cast_event_seconds(animation: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var event := database.get_animation_event(&"ryze", animation, "hit")
	if event == null or event.timing_mode != "seconds":
		return fallback
	return event.timing_value


func _refresh_target() -> void:
	if target != null and not is_instance_valid(target):
		target = null
	var preferred := _find_preferred_hostile()
	if preferred == null:
		_set_target_outline(target, false)
		target = null
		return
	var should_switch := not _valid_target(target)
	if (
		not should_switch
		and is_instance_valid(target)
		and target.is_in_group(&"training_dummy")
		and preferred.is_in_group(&"hero_actor")
	):
		should_switch = true
	if should_switch:
		_set_target_outline(target, false)
		target = preferred
		_set_target_outline(target, true)


func _set_target_outline(candidate: Node, active: bool) -> void:
	if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("set_outline_targeted"):
		return
	candidate.call("set_outline_targeted", active)


func _find_preferred_hostile() -> CharacterBody3D:
	var closest_hero: CharacterBody3D
	var closest_hero_distance := INF
	var closest_any: CharacterBody3D
	var closest_any_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		if not is_instance_valid(node):
			continue
		var candidate := node as CharacterBody3D
		if candidate == null or candidate == self or not _can_harm(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < closest_any_distance:
			closest_any = candidate
			closest_any_distance = distance
		if candidate.is_in_group(&"hero_actor") and distance < closest_hero_distance:
			closest_hero = candidate
			closest_hero_distance = distance
	return closest_hero if closest_hero != null else closest_any


func _valid_target(candidate: Node) -> bool:
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
	set_outline_selected(is_in_group(&"player_actor"))


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
	return super_armor_timer > 0.0


func _desperate_duration() -> float:
	if database == null:
		return 6.0
	var rank := database.get_skill_rank(&"ryze_desperate_power", 1)
	if rank != null and rank.duration > 0.0:
		return rank.duration
	var skill := database.get_skill(&"ryze_desperate_power")
	return skill.duration if skill != null and skill.duration > 0.0 else 6.0


func _sync_t_buff_presentation() -> void:
	_sync_self_vfx_node(t_buff, t_buff_flip, &"T_Buff", desperate_timer > 0.0)


func _sync_shield_presentation() -> void:
	_sync_self_vfx_node(shield, shield_flip, &"Ryze_Shield", supercharged_casts > 0 and supercharged_timer > 0.0)


func _is_supercharged() -> bool:
	return supercharged_casts > 0 and supercharged_timer > 0.0


func _ready_basic_spell_count() -> int:
	var count := 0
	for key: StringName in [&"q", &"w", &"e"]:
		if float(cooldowns[key]) <= 0.0:
			count += 1
	return count


func _is_supercharge_cast_animation(animation: StringName) -> bool:
	return animation == &"spell1" or animation == &"spell2" or animation == &"spell3" \
		or animation == &"attack1" or animation == &"attack2" or animation == &"attack3" or animation == &"crit"


func _cast_speed() -> float:
	return _rulef(&"ryze.cast.speed_scale", 1.35)


func _supercharge_cast_speed() -> float:
	return _rulef(&"ryze.supercharge.cast_speed_scale", 1.8)


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


func _should_burst_t(_distance: float) -> bool:
	# Desperate Power is an offensive amp. Open it when a weave is available,
	# not as a low-health panic button.
	if cooldowns[&"t"] > 0.0 or desperate_timer > 0.0 or not _valid_target(target):
		return false
	return _ready_basic_spell_count() >= _rulei(&"ryze.t.ready_spell_count", 2) or arcane_stacks >= _rulei(&"ryze.t.ready_stack_count", 4) or _is_supercharged()


func _should_escape_warp(distance: float) -> bool:
	if cooldowns[&"r"] > 0.0 or not _valid_target(target):
		return false
	var disengage := 1.5 if ai_archetype == null else float(ai_archetype.disengage_distance)
	var pack := 2 if ai_archetype == null else int(ai_archetype.aoe_min_targets)
	return distance <= disengage or _count_nearby_enemies(_cast_range()) >= pack + 1


func _should_engage_warp(distance: float) -> bool:
	if cooldowns[&"r"] > 0.0 or not _valid_target(target):
		return false
	if distance <= _cast_range() or distance > _warp_range():
		return false
	return _ready_basic_spell_count() >= 1 or cooldowns[&"t"] <= 0.0 or _is_supercharged()


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
	if candidate == null or candidate == self or not _valid_target(candidate):
		return false
	if candidate.has_method("get_team") and String(candidate.call("get_team")) == String(get_team()):
		return false
	if candidate.has_method("is_enemy_of"):
		return bool(candidate.call("is_enemy_of", get_team()))
	return true


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
	return float(database.get_rule(rule_id, fallback)) if database != null else fallback


func _rulei(rule_id: StringName, fallback: int) -> int:
	return int(database.get_rule(rule_id, fallback)) if database != null else fallback


func _cast_range() -> float:
	return _skill_range(&"ryze_overload", DEFAULT_CAST_RANGE)


func _warp_range() -> float:
	return _skill_range(&"ryze_realm_warp", DEFAULT_WARP_RANGE)


func _move_speed() -> float:
	if database == null:
		return 3.4
	var speed := database.get_unit_stat_value(&"ryze", &"move_speed", level)
	return speed if speed > 0.0 else 3.4


func _basic_missile_speed() -> float:
	if database == null:
		return 13.0
	var speed := database.get_unit_stat_value(&"ryze", &"missile_speed", level)
	return speed if speed > 0.0 else 13.0


func _character_pixel_size() -> float:
	if database != null:
		var profile := database.get_asset_profile(&"ryze_character")
		if profile != null and profile.pixel_size > 0.0:
			return profile.pixel_size
	return DEFAULT_PIXEL_SIZE


func _skill_cooldown(skill_id: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var rank := database.get_skill_rank(skill_id, 1)
	if rank != null and rank.cooldown > 0.0:
		return rank.cooldown
	var skill := database.get_skill(skill_id)
	return skill.cooldown if skill != null and skill.cooldown > 0.0 else fallback


func get_skill_cooldown_state(slot: StringName) -> Dictionary:
	var cooldown_data: Dictionary = {
		&"q": [&"ryze_overload", 4.0],
		&"w": [&"ryze_rune_prison", 14.0],
		&"e": [&"ryze_spell_flux", 7.0],
		&"r": [&"ryze_realm_warp", 180.0],
		&"t": [&"ryze_desperate_power", 50.0],
	}
	if not cooldown_data.has(slot):
		return {"remaining": 0.0, "total": 0.0}
	var skill_data: Array = cooldown_data[slot]
	return {
		"remaining": float(cooldowns.get(slot, 0.0)),
		"total": _skill_cooldown(skill_data[0], float(skill_data[1])),
	}


func _skill_range(skill_id: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var rank := database.get_skill_rank(skill_id, 1)
	if rank != null and rank.cast_range > 0.0:
		return rank.cast_range
	var skill := database.get_skill(skill_id)
	return skill.cast_range if skill != null and skill.cast_range > 0.0 else fallback


func _skill_radius(skill_id: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var rank := database.get_skill_rank(skill_id, 1)
	if rank != null and rank.radius > 0.0:
		return rank.radius
	var skill := database.get_skill(skill_id)
	return skill.radius if skill != null and skill.radius > 0.0 else fallback


func _skill_cast_time(skill_id: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var rank := database.get_skill_rank(skill_id, 1)
	if rank != null and rank.cast_time > 0.0:
		return rank.cast_time
	var skill := database.get_skill(skill_id)
	return skill.cast_time if skill != null and skill.cast_time > 0.0 else fallback


func _buff_duration(buff_id: StringName, fallback: float) -> float:
	if database == null:
		return fallback
	var buff := database.get_buff(buff_id)
	return buff.duration if buff != null and buff.duration > 0.0 else fallback


func _buff_max_stacks(buff_id: StringName, fallback: int) -> int:
	if database == null:
		return fallback
	var buff := database.get_buff(buff_id)
	return buff.max_stacks if buff != null and buff.max_stacks > 0 else fallback


func _flux_remain_multiplier() -> float:
	if database == null:
		return _rulef(&"ryze.e.mr_remain_multiplier", 0.92)
	var modifier := database.get_buff_modifier(&"ryze_flux", &"magic_resistance")
	return modifier.value if modifier != null else _rulef(&"ryze.e.mr_remain_multiplier", 0.92)


func _flux_duration() -> float:
	return _buff_duration(&"ryze_flux", 5.0)
