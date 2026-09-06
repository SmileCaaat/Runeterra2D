extends "res://scripts/actors/hero_instance.gd"

## Training implementation of the data-authored Ryze kit.  It intentionally
## keeps targeting and all authored ranges in meters, so later player input can
## reuse the same Q/W/E/T/R calls without changing combat numbers.

const FRAMES := preload("res://assets/characters/rune_mage_ryze/ryze_sprite_frames.tres")
const VFX_FRAMES := preload("res://assets/vfx/ryze_skills/ryze_skill_vfx_frames.tres")
const CHARACTER_ANCHOR_JSON := "res://assets/characters/rune_mage_ryze/idle/spritesheet.json"
const BASIC_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/projectile/spritesheet.json"
const Q_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/Spell1_Q/spritesheet.json"
const IMPACT_ANCHOR_JSON := "res://assets/vfx/ryze_skills/impact/spritesheet.json"
const E_PROJECTILE_ANCHOR_JSON := "res://assets/vfx/ryze_skills/Spell3_E/spritesheet.json"
const DEFAULT_PIXEL_SIZE := 0.004
const DEFAULT_IMPACT_CONTACT_Y_BIAS := -0.8
const DEFAULT_E_LAUNCH_Y_BIAS := 0.8
const DEFAULT_E_HIT_X_BIAS := 0.5
const DEFAULT_CAST_RANGE := 5.5
const DEFAULT_WARP_RANGE := 25.0
const SUPER_ARMOR_OUTLINE := preload("res://scripts/presentation/super_armor_outline.gd")
const BREAKER_AFTERIMAGE_SHADER := preload("res://assets/vfx/garen_skills/garen_breaker_afterimage.gdshader")
const ELASTIC_VOXEL_SHELL := preload("res://scripts/vfx/elastic_voxel_shell.gd")
const ZAP_LIGHTNING := preload("res://assets/BinbunVFX_Vol2/ElectricFX/effects/zap/vfx_zap_lightning_01.tscn")
const LIGHTNING_CHAIN := preload("res://addons/vfx_library/effects/lightning_chain.tscn")

@export_enum("friendly", "enemy") var team := "friendly"
@export var level := 1
@export var enabled := false

var database: CombatDatabase
var definition: UnitDefinition
var target: CharacterBody3D
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
var super_armor_outline: Node3D
var t_buff_authored_position := Vector3.ZERO
var r_winddown_authored_position := Vector3.ZERO
var r_winddown_authored_scale := Vector3.ONE
var supercharge_afterimages: Array[Sprite3D] = []
var supercharge_afterimage_ages: Array[float] = []
var supercharge_afterimage_cursor := 0
var supercharge_afterimage_lifetime := 0.28
var supercharge_afterimage_alpha := 0.36
var supercharge_afterimage_color := Color(0.16, 0.72, 1.0, 1.0)
var e_orb_from_center_px := Vector2(126.5, 622.5)
var _r_landing_resolving := false
var _r_landing_zapped: Dictionary = {}

@export_category("Scene VFX Preview")
@export var cast_vfx_preview_enabled := false

@onready var character_frames: AnimatedSprite3D = $CharacterFrames
@onready var label: Label3D = $AIStateLabel
@onready var shield: AnimatedSprite3D = $Shield
@onready var t_buff: AnimatedSprite3D = $TBuff
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
	add_to_group(&"combat_target")
	_configure_team_groups()
	character_frames.sprite_frames = FRAMES
	_apply_sprite_canvas_anchor()
	character_frames.play(&"idle")
	shield.sprite_frames = VFX_FRAMES
	t_buff_authored_position = t_buff.position
	t_buff.visible = false
	if r_winddown_template != null:
		r_winddown_authored_position = r_winddown_template.position
		r_winddown_authored_scale = r_winddown_template.scale
	# The imported shield is authored with alpha.  Do not use Screen blending:
	# on this sprite it resolves as an opaque white rectangle.
	shield.material_override = null
	_configure_cast_vfx_templates()
	_cache_e_orb_from_center()
	_build_super_armor_outline()
	_build_supercharge_afterimage_pool()
	character_frames.frame_changed.connect(_capture_supercharge_afterimage)
	_refresh_target()
	_update_label()


func _apply_sprite_canvas_anchor() -> void:
	var file := FileAccess.open(CHARACTER_ANCHOR_JSON, FileAccess.READ)
	if file == null:
		push_warning("Ryze character anchor metadata was not found: %s" % CHARACTER_ANCHOR_JSON)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Ryze character anchor metadata is invalid: %s" % CHARACTER_ANCHOR_JSON)
		return
	var canvas: Dictionary = (parsed as Dictionary).get("meta", {}).get("canvas", {})
	var width := float(canvas.get("width", 0.0))
	var height := float(canvas.get("height", 0.0))
	if width <= 0.0 or height <= 0.0:
		push_warning("Ryze character anchor metadata has no canvas dimensions")
		return
	var origin_x := float(canvas.get("originPixelX", width * 0.5))
	var origin_y := float(canvas.get("originPixelY", height))
	character_frames.offset = Vector2(width * 0.5 - origin_x, origin_y - height * 0.5)
	# The sprite's native visual content is already scaled to the game.  Only
	# correct its origin; scaling by full canvas height incorrectly enlarged Ryze.
	character_frames.pixel_size = _character_pixel_size()


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
	_sync_t_buff_presentation()
	shield.visible = supercharged_casts > 0 and supercharged_timer > 0.0
	if super_armor_outline != null:
		super_armor_outline.set_active(has_super_armor())
	_update_label()
	_update_supercharge_afterimages(delta)
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
		character_frames.play(&"run")
		move_and_slide()
		return
	if distance < _preferred_distance():
		velocity = -to_target.normalized() * _move_speed()
		character_frames.play(&"run")
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
	await _play_action_to_end(animation, _cast_frame(animation, 5), func() -> void:
		_launch_projectile(victim, &"basic_attack", _basic_missile_speed(), &"basic")
	)


func _cast_q(victim: CharacterBody3D) -> void:
	cooldowns[&"q"] = _skill_cooldown(&"ryze_overload", 4.0)
	_add_arcane_stack(true)
	await _play_action_to_end(&"spell1", _cast_frame(&"spell1", 3), func() -> void:
		_launch_projectile(victim, &"Spell1_Q", _rulef(&"ryze.q.missile_speed", 17.0), &"q")
	)


func _cast_w(victim: CharacterBody3D) -> void:
	cooldowns[&"w"] = _skill_cooldown(&"ryze_rune_prison", 14.0)
	_add_arcane_stack(true)
	await _play_action_to_end(&"spell2", _cast_frame(&"spell2", 5), func() -> void:
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
	await _play_action_to_end(&"spell3", _cast_frame(&"spell3", 6), func() -> void:
		_launch_projectile(victim, &"Spell3_E", _rulef(&"ryze.e.missile_speed", 15.0), &"e")
	)


func cast_desperate_power() -> void:
	if cooldowns[&"t"] > 0.0:
		return
	cooldowns[&"t"] = _skill_cooldown(&"ryze_desperate_power", 50.0)
	character_frames.play(&"taunt")
	var channel := _rulef(&"ryze.t.channel_duration", 0.8)
	action_lock = channel
	super_armor_timer = channel
	var manager := get_tree().get_first_node_in_group(&"awakening_cutin_manager")
	if manager != null:
		manager.call("request_skill", &"ryze_desperate_power")
	await get_tree().create_timer(channel).timeout
	desperate_timer = _desperate_duration()
	_sync_t_buff_presentation()
	_add_arcane_stack(false)


func cast_realm_warp(destination: Vector3) -> void:
	if cooldowns[&"r"] > 0.0:
		return
	cooldowns[&"r"] = _skill_cooldown(&"ryze_realm_warp", 180.0)
	character_frames.play(&"spell4")
	var channel := _skill_cast_time(&"ryze_realm_warp", 2.0)
	action_lock = channel
	await get_tree().create_timer(channel).timeout
	var planar := _clamp_to_arena(destination) - global_position
	planar.y = 0.0
	global_position = _clamp_to_arena(global_position + planar.limit_length(_warp_range()))
	character_frames.play(&"spell4_winddown")
	action_lock = _sprite_animation_duration(character_frames, &"spell4_winddown")
	_play_r_winddown()
	_r_landing_resolving = true
	_r_landing_zapped.clear()
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate == null or candidate == self or not _is_enemy_candidate(candidate):
			continue
		if candidate.global_position.distance_to(global_position) <= _skill_radius(&"ryze_realm_warp", 5.5):
			_play_r_landing_zap_once(candidate)
			for _i in _rulei(&"ryze.r.landing_e_hits", 3):
				_apply_e(candidate)
	_r_landing_resolving = false
	_r_landing_zapped.clear()
	_add_arcane_stack(true)


func apply_root(duration: float) -> void:
	root_timer = maxf(root_timer, duration)


func get_team() -> StringName:
	return StringName(team)


func is_enemy_of(other_team: StringName) -> bool:
	return StringName(team) != other_team


func is_targetable() -> bool:
	return true


func receive_skill_damage(amount: float, _source: String, _crit: bool, _position: Vector3, _type: StringName = &"magic", _profile: StringName = &"ryze_e_hit") -> void:
	present_resolved_damage(amount, _type)


func _play_action_to_end(animation: StringName, cast_frame: int, event: Callable) -> void:
	# Supercharge speeds Q/W/E and basic attacks; it no longer clips recovery frames.
	action_lock = INF
	character_frames.speed_scale = _supercharge_cast_speed() if _is_supercharged() and _is_supercharge_cast_animation(animation) else 1.0
	character_frames.play(animation)
	var event_sent := false
	while character_frames.animation == animation and character_frames.is_playing():
		if not event_sent and character_frames.frame >= cast_frame:
			event_sent = true
			event.call()
		await get_tree().process_frame
	if not event_sent:
		event.call()
	character_frames.speed_scale = 1.0
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
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin(payload)
	projectile.frame = 0
	projectile.play()
	var e_shell: Node3D = _attach_e_voxel_shell(projectile, false) if payload == &"e" else null
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


func _projectile_origin(payload: StringName) -> Vector3:
	# Real editor-authored VFX nodes double as the runtime spawn templates. Their
	# local X is mirrored with the character, so one placement serves both sides.
	var template := _projectile_template(payload)
	if template == null:
		return global_position + Vector3.UP * _rulef(&"ryze.hit.fallback_height", 1.15)
	var local := template.position
	if character_frames.flip_h:
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
	var duration := _sprite_animation_duration(character_frames, &"spell4_winddown")
	r_winddown_template.visible = true
	r_winddown_template.position = Vector3(
		r_winddown_authored_position.x * (-1.0 if character_frames.flip_h else 1.0),
		r_winddown_authored_position.y,
		r_winddown_authored_position.z
	)
	r_winddown_template.scale = r_winddown_authored_scale
	r_winddown_template.flip_h = character_frames.flip_h
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
	if absf(direction.x) > 0.02:
		projectile.flip_h = direction.x < 0.0


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
		victim.call("receive_skill_damage", amount, "瑞兹", false, global_position, type, hit_profile)
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


func _play_t_overflow_lightning(victim: CharacterBody3D) -> void:
	if not _can_harm(victim) or LIGHTNING_CHAIN == null:
		return
	var host := Node3D.new()
	host.name = "TOverflowLightning"
	get_tree().current_scene.add_child(host)
	host.global_position = _target_visual_position(victim) + Vector3.UP * _rulef(&"ryze.impact.contact_y_bias", DEFAULT_IMPACT_CONTACT_Y_BIAS)
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
	# magic particles. Centered playback drops the blast under the dummy feet.
	if not _can_harm(victim) or impact_template == null:
		return
	var effect := impact_template.duplicate() as AnimatedSprite3D
	effect.visible = true
	effect.render_priority = 41
	_apply_vfx_canvas_anchor(effect, IMPACT_ANCHOR_JSON)
	get_tree().current_scene.add_child(effect)
	effect.global_position = _target_visual_position(victim) + Vector3.UP * _rulef(&"ryze.impact.contact_y_bias", DEFAULT_IMPACT_CONTACT_Y_BIAS)
	effect.frame = 0
	effect.play()
	effect.animation_finished.connect(effect.queue_free)


func _add_arcane_stack(consumes_supercharge: bool) -> void:
	var max_stacks := _buff_max_stacks(&"ryze_arcane_mastery", 5)
	arcane_stacks = mini(max_stacks, arcane_stacks + 1)
	arcane_timer = _buff_duration(&"ryze_arcane_mastery", 6.0)
	if arcane_stacks == max_stacks:
		supercharged_casts = _rulei(&"ryze.supercharge.max_casts", 5)
		supercharged_timer = _rulef(&"ryze.supercharge.duration", 2.5)
		arcane_stacks = 0
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


func _cast_frame(animation: StringName, fallback: int) -> int:
	if database == null:
		return fallback
	var event := database.get_animation_event(&"ryze", animation, "hit")
	if event == null or event.timing_mode != "frame":
		return fallback
	return roundi(event.timing_value)


func _refresh_target() -> void:
	if _valid_target(target):
		return
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := node as CharacterBody3D
		if candidate != self and _valid_target(candidate) and (not candidate.has_method("is_enemy_of") or candidate.call("is_enemy_of", get_team())):
			target = candidate
			return
	target = null


func _valid_target(candidate: CharacterBody3D) -> bool:
	return is_instance_valid(candidate) and (not candidate.has_method("is_targetable") or bool(candidate.call("is_targetable")))


func _face(direction: Vector3) -> void:
	if absf(direction.x) > 0.02:
		character_frames.flip_h = direction.x < 0.0


func _configure_team_groups() -> void:
	if team == "friendly":
		add_to_group(&"friendly_actor")
		remove_from_group(&"enemy_actor")
	else:
		add_to_group(&"enemy_actor")
		remove_from_group(&"friendly_actor")


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
	if t_buff == null:
		return
	var active := desperate_timer > 0.0
	t_buff.visible = active
	t_buff.position = Vector3(
		t_buff_authored_position.x * (-1.0 if character_frames.flip_h else 1.0),
		t_buff_authored_position.y,
		t_buff_authored_position.z
	)
	t_buff.flip_h = character_frames.flip_h
	if active:
		if t_buff.animation != &"T_Buff" or not t_buff.is_playing():
			t_buff.play(&"T_Buff")
		return
	if t_buff.is_playing():
		t_buff.pause()


func _build_super_armor_outline() -> void:
	super_armor_outline = SUPER_ARMOR_OUTLINE.new()
	super_armor_outline.name = "SuperArmorOutline"
	add_child(super_armor_outline)
	var profile := database.get_asset_profile(&"super_armor_outline_glow") if database != null else null
	var red := Color.from_string(
		String(database.get_rule(&"presentation.super_armor_outline_red", "ff3020ff")) if database != null else "ff3020ff",
		Color(1.0, 0.19, 0.13, 1.0)
	)
	var gold := Color.from_string(
		String(database.get_rule(&"presentation.super_armor_outline_gold", "ffd45cff")) if database != null else "ffd45cff",
		Color(1.0, 0.83, 0.36, 1.0)
	)
	var width := float(database.get_rule(&"presentation.super_armor_outline_width", 2.5)) if database != null else 2.5
	var glow := float(database.get_rule(&"presentation.super_armor_outline_glow", 1.4)) if database != null else 1.4
	var alpha_threshold := float(database.get_rule(&"presentation.outline_alpha_threshold", 0.35)) if database != null else 0.35
	super_armor_outline.configure(
		character_frames,
		profile,
		red,
		gold,
		width,
		glow,
		-1.0,
		Vector2.ZERO,
		alpha_threshold
	)


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


func _supercharge_cast_speed() -> float:
	if database == null:
		return 1.6
	return float(database.get_rule(&"ryze.supercharge.cast_speed_scale", 1.6))


func _build_supercharge_afterimage_pool() -> void:
	var count := 3
	if database != null:
		count = clampi(int(database.get_rule(&"presentation.breaker_afterimage_count", 3)), 2, 3)
		supercharge_afterimage_lifetime = float(database.get_rule(&"presentation.breaker_afterimage_lifetime", 0.28))
		supercharge_afterimage_alpha = float(database.get_rule(&"presentation.breaker_afterimage_alpha", 0.36))
		supercharge_afterimage_color = Color.from_string(
			String(database.get_rule(&"presentation.breaker_afterimage_color", "29b8ffff")),
			supercharge_afterimage_color
		)
	for index in count:
		var afterimage := Sprite3D.new()
		afterimage.name = "SuperchargeAfterimage%d" % index
		afterimage.visible = false
		afterimage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		afterimage.transparent = true
		afterimage.shaded = false
		afterimage.render_priority = maxi(-128, character_frames.render_priority - 1)
		var material := ShaderMaterial.new()
		material.shader = BREAKER_AFTERIMAGE_SHADER
		material.set_shader_parameter(&"ocean_tint", Color(
			supercharge_afterimage_color.r,
			supercharge_afterimage_color.g,
			supercharge_afterimage_color.b,
			supercharge_afterimage_alpha
		))
		afterimage.material_override = material
		add_child(afterimage)
		afterimage.top_level = true
		supercharge_afterimages.append(afterimage)
		supercharge_afterimage_ages.append(supercharge_afterimage_lifetime)


func _capture_supercharge_afterimage() -> void:
	if not _is_supercharged() or supercharge_afterimages.is_empty() or character_frames.sprite_frames == null:
		return
	if not _is_supercharge_cast_animation(character_frames.animation):
		return
	var frame_texture := character_frames.sprite_frames.get_frame_texture(character_frames.animation, character_frames.frame)
	if frame_texture == null:
		return
	var afterimage := supercharge_afterimages[supercharge_afterimage_cursor]
	afterimage.texture = frame_texture
	var material := afterimage.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"frame_texture", frame_texture)
		material.set_shader_parameter(&"ocean_tint", Color(
			supercharge_afterimage_color.r,
			supercharge_afterimage_color.g,
			supercharge_afterimage_color.b,
			supercharge_afterimage_alpha
		))
	afterimage.global_transform = character_frames.global_transform
	afterimage.offset = character_frames.offset
	afterimage.pixel_size = character_frames.pixel_size
	afterimage.axis = character_frames.axis
	afterimage.billboard = character_frames.billboard
	afterimage.fixed_size = character_frames.fixed_size
	afterimage.centered = character_frames.centered
	afterimage.double_sided = character_frames.double_sided
	afterimage.no_depth_test = character_frames.no_depth_test
	afterimage.texture_filter = character_frames.texture_filter
	afterimage.flip_h = character_frames.flip_h
	afterimage.flip_v = character_frames.flip_v
	afterimage.layers = character_frames.layers
	afterimage.modulate = Color.WHITE
	afterimage.visible = true
	supercharge_afterimage_ages[supercharge_afterimage_cursor] = 0.0
	supercharge_afterimage_cursor = (supercharge_afterimage_cursor + 1) % supercharge_afterimages.size()


func _update_supercharge_afterimages(delta: float) -> void:
	var lifetime := maxf(supercharge_afterimage_lifetime, 0.01)
	for index: int in range(supercharge_afterimages.size()):
		var afterimage := supercharge_afterimages[index]
		if not afterimage.visible:
			continue
		supercharge_afterimage_ages[index] += delta
		var progress := clampf(supercharge_afterimage_ages[index] / lifetime, 0.0, 1.0)
		if progress >= 1.0:
			afterimage.visible = false
			afterimage.texture = null
			continue
		var fade := 1.0 - progress
		var material := afterimage.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"ocean_tint", Color(
				supercharge_afterimage_color.r,
				supercharge_afterimage_color.g,
				supercharge_afterimage_color.b,
				supercharge_afterimage_alpha * fade * fade
			))


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
		planar = Vector3.LEFT if character_frames.flip_h else Vector3.RIGHT
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
		planar = Vector3.LEFT if character_frames.flip_h else Vector3.RIGHT
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
	label.text = "瑞兹 · %s\n%s" % ["蓝方" if team == "friendly" else "红方", state]


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
