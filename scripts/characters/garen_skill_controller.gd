extends Node3D

const BREAKER_AFTERIMAGE_SHADER := preload("res://assets/vfx/garen_skills/garen_breaker_afterimage.gdshader")
const SUPER_ARMOR_AFTERIMAGE := preload("res://scripts/presentation/super_armor_afterimage.gd")
const SUPER_ARMOR_OUTLINE := preload("res://scripts/presentation/super_armor_outline.gd")
const IMPACT_SHOCKWAVE_SHADER := preload("res://assets/vfx/garen_skills/garen_impact_shockwave.gdshader")
const WATER_VAPOR_BURST_SHADER := preload("res://assets/vfx/garen_skills/garen_water_vapor_burst.gdshader")
const SKILL_BREAKER := 1
const SKILL_BLACK_SAIL := 2
const SKILL_OCEAN_STORM := 3
const SKILL_TYRANT_JUDGMENT := 4
const SKILL_SEVEN_SEAS := 5

@export_group("Demo AI")
@export var automatic_demo := true
@export_range(0.1, 5.0, 0.1) var demo_gap := 0.8

@export_group("Skill 1 - 破舰")
@export var breaker_duration := 4.5
@export var breaker_speed_bonus := 0.35
@export var breaker_damage := 115.0
@export var breaker_damage_coefficient := 0.5
@export var breaker_silence_duration := 1.5
@export var breaker_cooldown := 6.0

@export_group("Skill 1 - 破舰残影")
@export_range(2, 3, 1) var breaker_afterimage_count := 3
@export_range(0.1, 0.5, 0.01) var breaker_afterimage_lifetime := 0.28
@export_range(0.05, 1.0, 0.01) var breaker_afterimage_alpha := 0.36
@export var breaker_afterimage_color := Color(0.16, 0.72, 1.0, 1.0)

@export_group("Skill 2 - 黑帆")
@export var black_sail_duration := 4.0
@export var black_sail_damage_reduction := 0.25
@export var black_sail_tenacity := 0.60
@export var black_sail_guard_duration := 0.75
@export var black_sail_shield := 65.0
@export var black_sail_shield_bonus_health_ratio := 0.18
@export var black_sail_cooldown := 22.0

@export_group("Skill 2 - 勇气")
@export var courage_max_stacks := 30
@export var courage_resistance_per_stack := 1.0

@export_group("Skill 3 - 翻江倒海")
@export var ocean_storm_duration := 3.0
@export var ocean_storm_tick := 0.5
@export var ocean_storm_radius := 3.8
@export var ocean_storm_damage := 48.0
@export var ocean_storm_damage_coefficient := 0.40
@export var ocean_storm_cooldown := 8.0

@export_group("Skill 4 - 暴君审判")
@export var judgment_base_damage := 125.0
@export var judgment_missing_health_damage := 0.25
@export var judgment_cooldown := 120.0

@export_group("Skill 4/5 - 命中震荡")
@export_range(1, 3, 1) var impact_shockwave_pool_size := 2
@export_range(0.1, 0.8, 0.01) var impact_shockwave_lifetime := 0.38
@export_range(0.0, 0.08, 0.001) var judgment_distortion_strength := 0.018
@export_range(0.0, 0.08, 0.001) var ghostship_distortion_strength := 0.024
@export var judgment_shockwave_size := 3.8
@export var ghostship_shockwave_size := 6.0
@export_range(0.05, 0.6, 0.01) var judgment_rebound_height := 0.26
@export_range(0.03, 0.3, 0.01) var judgment_rebound_up_duration := 0.09
@export_range(0.03, 0.4, 0.01) var judgment_rebound_down_duration := 0.14
@export_range(0.0, 0.3, 0.01) var judgment_tail_hold_duration := 0.07
@export_range(0.15, 1.0, 0.01) var judgment_tail_dissolve_duration := 0.42
@export_range(0.15, 0.6, 0.01) var judgment_vapor_burst_duration := 0.28
@export var judgment_vapor_burst_size := 3.6
@export var anchor_impact_frame := 7
@export var ghostship_impact_frame := 9
@export var impact_shockwave_opacity := 0.55
@export var judgment_camera_shake_duration := 0.20
@export var judgment_camera_shake_strength := 0.09
@export var ghostship_camera_shake_duration := 0.36
@export var ghostship_camera_shake_strength := 0.105

@export_group("Skill 5 - 七海霸权")
@export var ghostship_damage := 350.0
@export var ghostship_radius := 5.2
@export var ghostship_stun_duration := 1.2
@export var rum_duration := 5.0
@export var rum_speed_bonus := 0.20
@export var seven_seas_cooldown := 120.0

@export_group("Passive - 坚忍")
@export var passive_lockout_duration := 8.0
@export var passive_regen_period := 5.0
@export var passive_regen_ratio_per_5 := 0.015
@export var passive_early_level_increment := 0.002
@export var passive_mid_level_increment := 0.008
@export var passive_late_level_increment := 0.004

@onready var fighter: CharacterBody3D = get_parent() as CharacterBody3D
@onready var character_frames: AnimatedSprite3D = fighter.get_node("CharacterFrames") as AnimatedSprite3D
@onready var jolly_roger: AnimatedSprite3D = $JollyRoger
@onready var ocean_storm: AnimatedSprite3D = $OceanStorm
@onready var anchor_effect: AnimatedSprite3D = $Anchor
@onready var ghostship: AnimatedSprite3D = $Ghostship
@onready var perseverance_front: AnimatedSprite3D = $PerseveranceFront
@onready var perseverance_hip: AnimatedSprite3D = $PerseveranceHip
@onready var jolly_audio: AudioStreamPlayer3D = $JollyRogerAudio
@onready var ocean_audio: AudioStreamPlayer3D = $OceanStormAudio
@onready var anchor_audio: AudioStreamPlayer3D = $AnchorAudio
@onready var ghostship_audio: AudioStreamPlayer3D = $GhostshipAudio

var target: CharacterBody3D
var is_casting := false
var current_skill := 0
var breaker_timer := 0.0
var breaker_empowered_attack := false
var breaker_afterimages: Array[Sprite3D] = []
var breaker_afterimage_ages: Array[float] = []
var breaker_afterimage_cursor := 0
var breaker_afterimage_capture_count := 0
var super_armor_outline: Node3D
var impact_shockwaves: Array[MeshInstance3D] = []
var impact_shockwave_ages: Array[float] = []
var impact_shockwave_lifetimes: Array[float] = []
var impact_shockwave_cursor := 0
var impact_shockwave_emit_count := 0
var anchor_last_impact_frame := -1
var ghostship_last_impact_frame := -1
var ghostship_last_scheduled_impact_time := 0.0
var ghostship_buff_audio_delay := 0.15
var ghostship_last_scheduled_buff_audio_delay := 0.0
var impact_camera: Camera3D
var impact_camera_base_h_offset := 0.0
var impact_camera_base_v_offset := 0.0
var impact_shake_elapsed := 0.0
var impact_shake_duration := 0.0
var impact_shake_strength := 0.0
var impact_debris: CPUParticles3D
var impact_debris_burst_count := 0
var ghostship_blue_burst: CPUParticles3D
var ghostship_white_burst: CPUParticles3D
var ghostship_impact_burst_count := 0
var anchor_impact_position := Vector3.ZERO
var anchor_position_locked := false
var anchor_rebound_lift := 0.0
var anchor_rebound_tween: Tween
var anchor_tail_active := false
var anchor_tail_elapsed := 0.0
var water_vapor_burst: MeshInstance3D
var water_vapor_burst_active := false
var water_vapor_burst_elapsed := 0.0
var water_vapor_mist: CPUParticles3D
var water_vapor_burst_count := 0
var black_sail_timer := 0.0
var black_sail_guard_timer := 0.0
var normal_shield := 0.0
var black_sail_guard_shield_remaining := 0.0
var courage_stacks := 0
var courage_kill_ledger: Dictionary[int, WeakRef] = {}
var rum_timer := 0.0
var delayed_damage_pool := 0.0
var rum_settlement_pending := false
var rum_triangles: CPUParticles3D
var rum_afterimages: Array[Node3D] = []
var ocean_storm_loop_active := false
var ocean_storm_loop_elapsed := 0.0
var ocean_storm_loop_frame_count := 8
var current_health := 1000.0
var max_health := 1000.0
var current_level := 1
var passive_damage_lockout_remaining := 0.0
var passive_recovery_active := false
var passive_recovery_activation_count := 0
var passive_vfx_opacity := 0.70
var passive_vfx_fade_in := 0.30
var passive_vfx_fade_out := 0.50
var passive_vfx_frame_rate := 6.0
var passive_vfx_alpha := 0.0
var passive_vfx_should_show := false
var perseverance_motes: GPUParticles3D
var perseverance_mote_material: StandardMaterial3D
var slow_multiplier := 1.0
var demo_timer := 0.5
var next_demo_skill := SKILL_BREAKER
var cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var cast_counts := [0, 0, 0, 0, 0, 0]
var damage_event_count := 0
var combat_database: CombatDatabase
var garen_definition: UnitDefinition
var skill_definitions: Dictionary = {}
var black_sail_rum_cleanse_ratio := 0.30
var skill_ranks: Dictionary[int, int] = {SKILL_BREAKER: 1, SKILL_BLACK_SAIL: 1, SKILL_OCEAN_STORM: 1, SKILL_TYRANT_JUDGMENT: 1, SKILL_SEVEN_SEAS: 1}
var ocean_storm_hit_counts: Dictionary[int, int] = {}
var audio_cue_play_counts: Dictionary[StringName, int] = {}


func _ready() -> void:
	_apply_combat_data()
	_build_breaker_afterimage_pool()
	_build_super_armor_outline()
	_build_impact_shockwave_pool()
	_build_impact_debris()
	_build_ghostship_impact_bursts()
	_build_water_vapor_burst()
	_build_rum_visuals()
	_build_perseverance_motes()
	character_frames.frame_changed.connect(_capture_breaker_afterimage)
	for effect: AnimatedSprite3D in [jolly_roger, ocean_storm, anchor_effect, ghostship]:
		if effect.material_override != null:
			effect.material_override = effect.material_override.duplicate()
			if effect.material_override is ShaderMaterial:
				var effect_material := effect.material_override as ShaderMaterial
				effect_material.set_shader_parameter(
					&"show_over_models", effect.no_depth_test
				)
				_configure_inward_canvas_edge(effect, effect_material)
		effect.frame_changed.connect(_sync_vfx_frame.bind(effect))
		effect.frame_changed.connect(_handle_impact_vfx_frame.bind(effect))
		effect.animation_changed.connect(_sync_vfx_frame.bind(effect))
		effect.sprite_frames_changed.connect(_sync_vfx_frame.bind(effect))
		_sync_vfx_frame(effect)
		effect.visible = false
	anchor_effect.top_level = true
	ghostship.top_level = true
	anchor_effect.animation_finished.connect(_on_anchor_animation_finished)
	for effect: AnimatedSprite3D in _perseverance_vfx():
		effect.visible = false
		effect.modulate.a = 0.0
		effect.play(effect.animation)
		_apply_sprite_asset_profile(effect, _perseverance_asset_id(effect))


func _process(delta: float) -> void:
	_update_breaker_afterimages(delta)
	_update_ocean_storm_animation_loop(delta)
	if super_armor_outline != null:
		super_armor_outline.set_active(has_super_armor())
	_update_impact_shockwaves(delta)
	_update_impact_camera_shake(delta)
	_update_anchor_tail_dissolve(delta)
	_update_water_vapor_burst(delta)
	_update_rum_visuals()
	_update_timers(delta)
	_update_rum_damage(delta)
	_update_perseverance(delta)
	_update_perseverance_vfx(delta)
	if anchor_effect.visible:
		if anchor_position_locked:
			anchor_effect.global_position = anchor_impact_position + Vector3.UP * anchor_rebound_lift
		elif is_instance_valid(target):
			anchor_effect.global_position = target.global_position
	if not automatic_demo or is_casting or not is_instance_valid(target):
		return
	demo_timer -= delta
	if demo_timer > 0.0:
		return
	if fighter.has_method("can_start_skill") and not bool(fighter.call("can_start_skill")):
		return
	try_begin_demo_skill()


func set_target(next_target: CharacterBody3D) -> void:
	target = next_target


func begin_skill(skill_index: int, skill_target: CharacterBody3D) -> bool:
	if skill_index < SKILL_BREAKER or skill_index > SKILL_SEVEN_SEAS:
		return false
	if cooldowns[skill_index] > 0.0 or not is_instance_valid(skill_target):
		return false
	target = skill_target
	# W is instant and intentionally does not take the cast lock: it can be
	# activated during E without cancelling the spin.
	if skill_index == SKILL_BLACK_SAIL:
		cast_counts[skill_index] += 1
		cooldowns[skill_index] = _get_cooldown(skill_index)
		_cast_black_sail()
		demo_timer = demo_gap
		return true
	if is_casting:
		return false
	is_casting = true
	current_skill = skill_index
	cast_counts[skill_index] += 1
	cooldowns[skill_index] = _get_cooldown(skill_index)
	_cast_skill_async(skill_index)
	return true


func try_begin_demo_skill() -> bool:
	if not automatic_demo or is_casting or demo_timer > 0.0 or not is_instance_valid(target):
		return false
	# A hero-owned selector turns a reusable subclass archetype into a concrete
	# decision. Once a selector is present it is authoritative: falling back to
	# the old carousel when it returns "no cast" would reintroduce the long-R-CD
	# lock that this system replaces.
	if fighter != null and fighter.has_method("select_ai_skill"):
		var selected_skill := int(fighter.call("select_ai_skill"))
		if selected_skill > 0:
			return try_begin_ai_skill(selected_skill)
		return false
	if cooldowns[next_demo_skill] > 0.0 or not _skill_in_range(next_demo_skill):
		return false
	var started := begin_skill(next_demo_skill, target)
	if started:
		next_demo_skill = next_demo_skill % SKILL_SEVEN_SEAS + 1
	return started


func try_begin_ai_skill(skill_index: int) -> bool:
	if not automatic_demo or is_casting or demo_timer > 0.0 or not is_instance_valid(target):
		return false
	if skill_index < SKILL_BREAKER or skill_index > SKILL_SEVEN_SEAS:
		return false
	if cooldowns[skill_index] > 0.0 or not _skill_in_range(skill_index):
		return false
	return begin_skill(skill_index, target)


func get_move_speed_multiplier() -> float:
	var multiplier := slow_multiplier
	if breaker_timer > 0.0:
		multiplier *= 1.0 + breaker_speed_bonus
	if rum_timer > 0.0:
		multiplier *= 1.0 + rum_speed_bonus
	return multiplier


func get_run_animation() -> StringName:
	if breaker_timer > 0.0:
		var breaker := _definition(SKILL_BREAKER)
		if breaker != null and not breaker.movement_animation_name.is_empty():
			return breaker.movement_animation_name
		return &"run_spell"
	return &"run"


func allows_movement_while_casting() -> bool:
	return is_casting and current_skill == SKILL_OCEAN_STORM


func has_super_armor() -> bool:
	return is_casting and current_skill == SKILL_OCEAN_STORM


func preserves_character_animation() -> bool:
	# E owns the character animation for its full channel. Movement and retargeting
	# remain available, but AI locomotion states must not replace spell3 with run.
	return is_casting and current_skill == SKILL_OCEAN_STORM


func get_normal_shield() -> float:
	return normal_shield


func get_courage_resistance_bonus() -> float:
	return float(courage_stacks) * courage_resistance_per_stack


func get_effective_armor() -> float:
	var base_armor := garen_definition.armor if garen_definition != null else 38.0
	return base_armor + get_courage_resistance_bonus()


func get_effective_magic_resistance() -> float:
	var base_resistance := garen_definition.magic_resistance if garen_definition != null else 32.0
	return base_resistance + get_courage_resistance_bonus()


func register_courage_kill(target_actor: CharacterBody3D) -> void:
	if not is_instance_valid(target_actor):
		return
	if target_actor.has_method("is_courage_stack_eligible") and not bool(target_actor.call("is_courage_stack_eligible")):
		return
	if target_actor.has_method("is_targetable") and bool(target_actor.call("is_targetable")):
		return
	var target_id := target_actor.get_instance_id()
	if courage_kill_ledger.has(target_id):
		return
	courage_kill_ledger[target_id] = weakref(target_actor)
	courage_stacks = mini(courage_max_stacks, courage_stacks + 1)


func should_use_breaker_attack() -> bool:
	return breaker_empowered_attack and breaker_timer > 0.0


func get_skill_rank(skill_slot: int) -> int:
	return int(skill_ranks.get(skill_slot, 1))


func resolve_breaker_attack(skill_target: CharacterBody3D) -> void:
	_register_damage_source(skill_target)
	if not should_use_breaker_attack():
		return
	breaker_empowered_attack = false
	var attack_damage := garen_definition.attack_damage if garen_definition != null else 69.0
	var bonus_damage := breaker_damage + attack_damage * breaker_damage_coefficient
	if skill_target.has_method("receive_breaker_attack"):
		skill_target.call("receive_breaker_attack", attack_damage, bonus_damage, fighter.global_position, &"breaker_hit")
	else:
		# Compatibility path for future targets that have not implemented compound hits yet.
		if skill_target.has_method("receive_hit"):
			skill_target.call("receive_hit", fighter.global_position, &"spell1")
		if skill_target.has_method("receive_skill_damage"):
			skill_target.call("receive_skill_damage", bonus_damage, "破舰额外伤害", false, fighter.global_position, &"physical", &"breaker_hit")
		skill_target.call("receive_skill_damage", bonus_damage, "破舰额外伤害", false, fighter.global_position, &"physical", &"breaker_hit")
	if skill_target.has_method("apply_silence"):
		skill_target.call("apply_silence", breaker_silence_duration)
	register_courage_kill(skill_target)
	damage_event_count += 1


func _build_breaker_afterimage_pool() -> void:
	var pool_size := clampi(breaker_afterimage_count, 2, 3)
	for index: int in range(pool_size):
		var afterimage := Sprite3D.new()
		afterimage.name = "BreakerAfterimage%d" % index
		afterimage.visible = false
		afterimage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		afterimage.transparent = true
		afterimage.shaded = false
		afterimage.render_priority = maxi(-128, character_frames.render_priority - 1)
		var afterimage_material := ShaderMaterial.new()
		afterimage_material.shader = BREAKER_AFTERIMAGE_SHADER
		afterimage_material.set_shader_parameter(&"ocean_tint", Color(
			breaker_afterimage_color.r,
			breaker_afterimage_color.g,
			breaker_afterimage_color.b,
			breaker_afterimage_alpha
		))
		afterimage.material_override = afterimage_material
		add_child(afterimage)
		afterimage.top_level = true
		breaker_afterimages.append(afterimage)
		breaker_afterimage_ages.append(breaker_afterimage_lifetime)


func _build_super_armor_outline() -> void:
	super_armor_outline = SUPER_ARMOR_OUTLINE.new()
	super_armor_outline.name = "SuperArmorOutline"
	add_child(super_armor_outline)
	var profile := combat_database.get_asset_profile(&"super_armor_outline_glow") if combat_database != null else null
	var red := Color.from_string(
		String(combat_database.get_rule(&"presentation.super_armor_outline_red", "ff3020ff")) if combat_database != null else "ff3020ff",
		Color(1.0, 0.19, 0.13, 1.0)
	)
	var gold := Color.from_string(
		String(combat_database.get_rule(&"presentation.super_armor_outline_gold", "ffd45cff")) if combat_database != null else "ffd45cff",
		Color(1.0, 0.83, 0.36, 1.0)
	)
	super_armor_outline.configure(
		character_frames,
		profile,
		red,
		gold,
		_rule_float(&"presentation.super_armor_outline_width", 2.5),
		_rule_float(&"presentation.super_armor_outline_glow", 1.4),
		-1.0,
		Vector2.ZERO,
		_rule_float(&"presentation.outline_alpha_threshold", 0.35)
	)


func _capture_breaker_afterimage() -> void:
	if breaker_afterimages.is_empty() or not _should_capture_breaker_afterimage():
		return
	var frame_texture := character_frames.sprite_frames.get_frame_texture(
		character_frames.animation, character_frames.frame
	)
	if frame_texture == null:
		return
	var afterimage := breaker_afterimages[breaker_afterimage_cursor]
	afterimage.texture = frame_texture
	var afterimage_material := afterimage.material_override as ShaderMaterial
	if afterimage_material != null:
		afterimage_material.set_shader_parameter(&"frame_texture", frame_texture)
		afterimage_material.set_shader_parameter(&"ocean_tint", Color(
			breaker_afterimage_color.r,
			breaker_afterimage_color.g,
			breaker_afterimage_color.b,
			breaker_afterimage_alpha
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
	breaker_afterimage_ages[breaker_afterimage_cursor] = 0.0
	breaker_afterimage_cursor = (breaker_afterimage_cursor + 1) % breaker_afterimages.size()
	breaker_afterimage_capture_count += 1


func _should_capture_breaker_afterimage() -> bool:
	if breaker_timer <= 0.0 or character_frames.sprite_frames == null:
		return false
	var definition := _definition(SKILL_BREAKER)
	var run_animation := definition.movement_animation_name if definition != null else &"run_spell"
	var attack_animation := definition.empowered_animation_name if definition != null else &"spell1"
	return character_frames.animation == run_animation or character_frames.animation == attack_animation


func _update_breaker_afterimages(delta: float) -> void:
	var lifetime := maxf(breaker_afterimage_lifetime, 0.01)
	for index: int in range(breaker_afterimages.size()):
		var afterimage := breaker_afterimages[index]
		if not afterimage.visible:
			continue
		breaker_afterimage_ages[index] += delta
		var progress := clampf(breaker_afterimage_ages[index] / lifetime, 0.0, 1.0)
		if progress >= 1.0:
			afterimage.visible = false
			afterimage.texture = null
			continue
		var fade := 1.0 - progress
		var material := afterimage.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"ocean_tint", Color(
				breaker_afterimage_color.r,
				breaker_afterimage_color.g,
				breaker_afterimage_color.b,
				breaker_afterimage_alpha * fade * fade
			))


func _build_impact_shockwave_pool() -> void:
	var pool_size := clampi(impact_shockwave_pool_size, 1, 3)
	for index: int in range(pool_size):
		var shockwave := MeshInstance3D.new()
		shockwave.name = "ImpactShockwave%d" % index
		shockwave.visible = false
		shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		shockwave.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = IMPACT_SHOCKWAVE_SHADER
		material.render_priority = 3
		shockwave.material_override = material
		add_child(shockwave)
		shockwave.top_level = true
		impact_shockwaves.append(shockwave)
		impact_shockwave_ages.append(impact_shockwave_lifetime)
		impact_shockwave_lifetimes.append(impact_shockwave_lifetime)


func _build_impact_debris() -> void:
	var profile := combat_database.get_particle_profile(&"judgment_debris_small") if combat_database != null else null
	impact_debris = CPUParticles3D.new()
	impact_debris.name = "ImpactDebris"
	impact_debris.emitting = false
	impact_debris.amount = profile.amount if profile != null else 22
	impact_debris.lifetime = profile.lifetime if profile != null else 0.46
	impact_debris.one_shot = true
	impact_debris.explosiveness = 1.0
	impact_debris.randomness = profile.randomness if profile != null else 0.48
	impact_debris.local_coords = false
	impact_debris.direction = Vector3(0.0, 0.62, 0.0)
	impact_debris.spread = profile.spread if profile != null else 74.0
	impact_debris.gravity = profile.gravity if profile != null else Vector3(0.0, -7.5, 0.0)
	impact_debris.initial_velocity_min = profile.velocity_min if profile != null else 2.2
	impact_debris.initial_velocity_max = profile.velocity_max if profile != null else 4.9
	impact_debris.angular_velocity_min = profile.angular_velocity_min if profile != null else -620.0
	impact_debris.angular_velocity_max = profile.angular_velocity_max if profile != null else 620.0
	impact_debris.scale_amount_min = profile.scale_min if profile != null else 0.55
	impact_debris.scale_amount_max = profile.scale_max if profile != null else 1.35
	var color_ramp := Gradient.new()
	color_ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.72, 1.0])
	color_ramp.colors = PackedColorArray([
		profile.gradient_start if profile != null else Color(0.88, 0.98, 1.0, 0.95),
		profile.gradient_mid if profile != null else Color(0.26, 0.78, 1.0, 0.90),
		profile.gradient_late if profile != null else Color(0.08, 0.35, 0.52, 0.42),
		profile.gradient_end if profile != null else Color(0.02, 0.10, 0.16, 0.0),
	])
	impact_debris.color_ramp = color_ramp
	var debris_material := StandardMaterial3D.new()
	debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debris_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debris_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	debris_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	debris_material.vertex_color_use_as_albedo = true
	debris_material.albedo_color = Color.WHITE
	debris_material.emission_enabled = true
	debris_material.emission = profile.emission_color if profile != null else Color(0.12, 0.62, 0.92, 1.0)
	debris_material.emission_energy_multiplier = profile.emission_energy if profile != null else 1.35
	var debris_mesh := QuadMesh.new()
	debris_mesh.size = profile.mesh_size if profile != null else Vector2(0.20, 0.038)
	debris_mesh.material = debris_material
	impact_debris.mesh = debris_mesh
	add_child(impact_debris)
	impact_debris.top_level = true


func _build_ghostship_impact_bursts() -> void:
	ghostship_blue_burst = _build_ghostship_impact_particle_burst(
		"GhostshipImpactBlueBurst", &"ghostship_impact_blue"
	)
	ghostship_white_burst = _build_ghostship_impact_particle_burst(
		"GhostshipImpactWhiteBurst", &"ghostship_impact_white"
	)


func _build_ghostship_impact_particle_burst(node_name: String, profile_id: StringName) -> CPUParticles3D:
	var profile := combat_database.get_particle_profile(profile_id) if combat_database != null else null
	var burst := CPUParticles3D.new()
	burst.name = node_name
	burst.emitting = false
	burst.amount = profile.amount if profile != null else 28
	burst.lifetime = profile.lifetime if profile != null else 0.32
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.randomness = profile.randomness if profile != null else 0.42
	burst.local_coords = false
	burst.direction = Vector3(0.0, 0.58, 0.0)
	burst.spread = profile.spread if profile != null else 128.0
	burst.gravity = profile.gravity if profile != null else Vector3(0.0, -4.5, 0.0)
	burst.initial_velocity_min = profile.velocity_min if profile != null else 4.0
	burst.initial_velocity_max = profile.velocity_max if profile != null else 8.0
	burst.angular_velocity_min = profile.angular_velocity_min if profile != null else -540.0
	burst.angular_velocity_max = profile.angular_velocity_max if profile != null else 540.0
	burst.scale_amount_min = profile.scale_min if profile != null else 0.45
	burst.scale_amount_max = profile.scale_max if profile != null else 1.45
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.54, 1.0])
	ramp.colors = PackedColorArray([
		profile.gradient_start if profile != null else Color(0.15, 0.82, 1.0, 1.0),
		profile.gradient_mid if profile != null else Color(0.80, 0.97, 1.0, 0.92),
		profile.gradient_late if profile != null else Color(0.24, 0.70, 1.0, 0.36),
		profile.gradient_end if profile != null else Color(0.03, 0.18, 0.38, 0.0),
	])
	burst.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = profile.emission_color if profile != null else Color(0.16, 0.76, 1.0, 1.0)
	material.emission_energy_multiplier = profile.emission_energy if profile != null else 2.0
	var mesh := QuadMesh.new()
	mesh.size = profile.mesh_size if profile != null else Vector2(0.18, 0.06)
	mesh.material = material
	burst.mesh = mesh
	add_child(burst)
	burst.top_level = true
	return burst


func _build_rum_visuals() -> void:
	var profile := combat_database.get_particle_profile(&"seven_seas_rum_triangles") if combat_database != null else null
	rum_triangles = CPUParticles3D.new()
	rum_triangles.name = "RumAmberTriangles"
	rum_triangles.emitting = false
	rum_triangles.amount = profile.amount if profile != null else 14
	rum_triangles.lifetime = profile.lifetime if profile != null else 1.15
	rum_triangles.randomness = profile.randomness if profile != null else 0.40
	rum_triangles.local_coords = true
	rum_triangles.position = Vector3(0.0, 0.82, 0.0)
	rum_triangles.direction = Vector3(0.0, 1.0, 0.0)
	rum_triangles.spread = profile.spread if profile != null else 28.0
	rum_triangles.gravity = profile.gravity if profile != null else Vector3(0.0, 0.16, 0.0)
	rum_triangles.initial_velocity_min = profile.velocity_min if profile != null else 0.16
	rum_triangles.initial_velocity_max = profile.velocity_max if profile != null else 0.42
	rum_triangles.angular_velocity_min = profile.angular_velocity_min if profile != null else -34.0
	rum_triangles.angular_velocity_max = profile.angular_velocity_max if profile != null else 34.0
	rum_triangles.scale_amount_min = profile.scale_min if profile != null else 0.48
	rum_triangles.scale_amount_max = profile.scale_max if profile != null else 1.05
	var triangle_ramp := Gradient.new()
	triangle_ramp.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	triangle_ramp.colors = PackedColorArray([
		profile.gradient_start if profile != null else Color(0.86, 0.64, 0.25, 0.26),
		profile.gradient_mid if profile != null else Color(1.0, 0.83, 0.52, 0.18),
		profile.gradient_end if profile != null else Color(0.32, 0.13, 0.02, 0.0),
	])
	rum_triangles.color_ramp = triangle_ramp
	var triangle_material := StandardMaterial3D.new()
	triangle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	triangle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	triangle_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	triangle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	triangle_material.vertex_color_use_as_albedo = true
	triangle_material.emission_enabled = true
	triangle_material.emission = profile.emission_color if profile != null else Color(0.82, 0.48, 0.12, 1.0)
	triangle_material.emission_energy_multiplier = profile.emission_energy if profile != null else 0.8
	var triangle_mesh := PrismMesh.new()
	triangle_mesh.size = Vector3(0.09, 0.09, 0.02)
	triangle_mesh.material = triangle_material
	rum_triangles.mesh = triangle_mesh
	add_child(rum_triangles)
	for frame_offset: int in [1, 2]:
		var afterimage := SUPER_ARMOR_AFTERIMAGE.new()
		afterimage.name = "RumAfterimage%d" % frame_offset
		add_child(afterimage)
		afterimage.configure(
			character_frames, null, Color(0.88, 0.53, 0.16, 1.0), frame_offset, 0.018
		)
		rum_afterimages.append(afterimage)


func _update_rum_visuals() -> void:
	var active := rum_timer > 0.0
	if is_instance_valid(rum_triangles):
		if active and not rum_triangles.emitting:
			rum_triangles.restart()
			rum_triangles.emitting = true
		elif not active:
			rum_triangles.emitting = false
	for afterimage: Node3D in rum_afterimages:
		if afterimage.has_method("set_active"):
			afterimage.call("set_active", active)


func _emit_ghostship_impact_bursts(position: Vector3) -> void:
	for burst: CPUParticles3D in [ghostship_blue_burst, ghostship_white_burst]:
		if not is_instance_valid(burst):
			continue
		burst.global_position = position + Vector3.UP * 0.30
		burst.restart()
		burst.emitting = true
	ghostship_impact_burst_count += 1


func _build_water_vapor_burst() -> void:
	var mist_profile := combat_database.get_particle_profile(&"judgment_vapor_mist") if combat_database != null else null
	water_vapor_burst = MeshInstance3D.new()
	water_vapor_burst.name = "WaterVaporBurst"
	water_vapor_burst.visible = false
	water_vapor_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var vapor_mesh := SphereMesh.new()
	vapor_mesh.radius = 0.5
	vapor_mesh.height = 1.0
	vapor_mesh.radial_segments = 24
	vapor_mesh.rings = 12
	water_vapor_burst.mesh = vapor_mesh
	var vapor_material := ShaderMaterial.new()
	vapor_material.shader = WATER_VAPOR_BURST_SHADER
	vapor_material.render_priority = 3
	water_vapor_burst.material_override = vapor_material
	add_child(water_vapor_burst)
	water_vapor_burst.top_level = true

	water_vapor_mist = CPUParticles3D.new()
	water_vapor_mist.name = "WaterVaporMist"
	water_vapor_mist.emitting = false
	water_vapor_mist.amount = mist_profile.amount if mist_profile != null else 34
	water_vapor_mist.lifetime = mist_profile.lifetime if mist_profile != null else 0.34
	water_vapor_mist.one_shot = true
	water_vapor_mist.explosiveness = 1.0
	water_vapor_mist.randomness = mist_profile.randomness if mist_profile != null else 0.38
	water_vapor_mist.local_coords = false
	water_vapor_mist.direction = Vector3(0.0, 0.30, 0.0)
	water_vapor_mist.spread = mist_profile.spread if mist_profile != null else 92.0
	water_vapor_mist.gravity = mist_profile.gravity if mist_profile != null else Vector3(0.0, -3.2, 0.0)
	water_vapor_mist.initial_velocity_min = mist_profile.velocity_min if mist_profile != null else 3.2
	water_vapor_mist.initial_velocity_max = mist_profile.velocity_max if mist_profile != null else 6.8
	water_vapor_mist.scale_amount_min = mist_profile.scale_min if mist_profile != null else 0.45
	water_vapor_mist.scale_amount_max = mist_profile.scale_max if mist_profile != null else 1.25
	var mist_ramp := Gradient.new()
	mist_ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.48, 1.0])
	mist_ramp.colors = PackedColorArray([
		mist_profile.gradient_start if mist_profile != null else Color(0.90, 0.99, 1.0, 0.78),
		mist_profile.gradient_mid if mist_profile != null else Color(0.34, 0.82, 1.0, 0.68),
		mist_profile.gradient_late if mist_profile != null else Color(0.10, 0.45, 0.68, 0.30),
		mist_profile.gradient_end if mist_profile != null else Color(0.04, 0.16, 0.24, 0.0),
	])
	water_vapor_mist.color_ramp = mist_ramp
	var mist_mesh := QuadMesh.new()
	mist_mesh.size = mist_profile.mesh_size if mist_profile != null else Vector2(0.38, 0.24)
	var mist_texture_gradient := Gradient.new()
	mist_texture_gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	mist_texture_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(0.52, 0.88, 1.0, 0.58),
		Color(0.20, 0.62, 0.82, 0.0),
	])
	var mist_texture := GradientTexture2D.new()
	mist_texture.width = 64
	mist_texture.height = 64
	mist_texture.gradient = mist_texture_gradient
	mist_texture.fill = GradientTexture2D.FILL_RADIAL
	mist_texture.fill_from = Vector2(0.5, 0.5)
	mist_texture.fill_to = Vector2(1.0, 0.5)
	var mist_material := StandardMaterial3D.new()
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist_material.vertex_color_use_as_albedo = true
	mist_material.albedo_texture = mist_texture
	mist_material.render_priority = 4
	mist_mesh.material = mist_material
	water_vapor_mist.mesh = mist_mesh
	add_child(water_vapor_mist)
	water_vapor_mist.top_level = true


func _emit_impact_debris(position: Vector3, large_burst: bool) -> void:
	if not is_instance_valid(impact_debris):
		return
	impact_debris.global_position = position + Vector3.UP * 0.16
	var profile_id := &"judgment_debris_large" if large_burst else &"judgment_debris_small"
	var profile := combat_database.get_particle_profile(profile_id) if combat_database != null else null
	impact_debris.amount = profile.amount if profile != null else (32 if large_burst else 22)
	impact_debris.initial_velocity_min = profile.velocity_min if profile != null else (2.8 if large_burst else 2.2)
	impact_debris.initial_velocity_max = profile.velocity_max if profile != null else (6.2 if large_burst else 4.9)
	impact_debris.spread = profile.spread if profile != null else (88.0 if large_burst else 74.0)
	impact_debris.restart()
	impact_debris.emitting = true
	impact_debris_burst_count += 1


func _emit_water_vapor_burst(position: Vector3) -> void:
	if not is_instance_valid(water_vapor_burst) or not is_instance_valid(water_vapor_mist):
		return
	water_vapor_burst_active = true
	water_vapor_burst_elapsed = 0.0
	water_vapor_burst.global_position = position + Vector3.UP * 0.34
	water_vapor_burst.scale = Vector3(0.35, 0.10, 0.35)
	water_vapor_burst.visible = true
	var vapor_material := water_vapor_burst.material_override as ShaderMaterial
	if vapor_material != null:
		vapor_material.set_shader_parameter(&"progress", 0.0)
	water_vapor_mist.global_position = position + Vector3.UP * 0.26
	water_vapor_mist.speed_scale = 1.0
	water_vapor_mist.restart()
	water_vapor_mist.emitting = true
	water_vapor_burst_count += 1


func _update_water_vapor_burst(delta: float) -> void:
	if not water_vapor_burst_active or not is_instance_valid(water_vapor_burst):
		return
	water_vapor_burst_elapsed += delta
	var progress := clampf(
		water_vapor_burst_elapsed / maxf(judgment_vapor_burst_duration, 0.01), 0.0, 1.0
	)
	if progress >= 1.0:
		water_vapor_burst_active = false
		water_vapor_burst.visible = false
		return
	var expansion := 1.0
	if progress < 0.42:
		var burst_t := progress / 0.42
		var back_t := burst_t - 1.0
		# Back-out curve: rapid expansion with a brief size overshoot.
		expansion = 1.0 + 2.70 * back_t * back_t * back_t + 1.70 * back_t * back_t
	elif progress < 0.62:
		# Elastic recoil after the initial pressure release.
		expansion = lerpf(1.0, 0.86, (progress - 0.42) / 0.20)
	else:
		# A small secondary opening keeps the collapse organic as it fades.
		expansion = lerpf(0.86, 1.06, (progress - 0.62) / 0.38)
	water_vapor_burst.scale = Vector3(
		lerpf(0.35, judgment_vapor_burst_size, expansion),
		lerpf(0.10, judgment_vapor_burst_size * 0.38, expansion),
		lerpf(0.35, judgment_vapor_burst_size * 0.62, expansion)
	)
	var vapor_material := water_vapor_burst.material_override as ShaderMaterial
	if vapor_material != null:
		vapor_material.set_shader_parameter(&"progress", progress)


func _handle_impact_vfx_frame(effect: AnimatedSprite3D) -> void:
	# Design frame numbers are one-based: Anchor 8-12, Ghostship 10-12.
	if effect == anchor_effect and effect.visible and effect.frame == anchor_impact_frame:
		if anchor_last_impact_frame == effect.frame:
			return
		anchor_last_impact_frame = effect.frame
		_emit_impact_shockwave(
			effect.global_position + Vector3.UP * 0.55,
			judgment_shockwave_size,
			judgment_distortion_strength,
			impact_shockwave_lifetime
		)
		if effect.frame == anchor_impact_frame:
			_start_anchor_rebound(effect.global_position)
			_emit_water_vapor_burst(effect.global_position)
			_emit_impact_debris(effect.global_position, false)
			_start_impact_camera_shake(judgment_camera_shake_duration, judgment_camera_shake_strength)
	elif effect == ghostship and effect.visible and effect.frame == ghostship_impact_frame:
		if ghostship_last_impact_frame == effect.frame:
			return
		ghostship_last_impact_frame = effect.frame
		_emit_impact_shockwave(
			effect.global_position + Vector3.UP * 0.75,
			ghostship_shockwave_size,
			ghostship_distortion_strength,
			impact_shockwave_lifetime * 1.12
		)
		if effect.frame == ghostship_impact_frame:
			_emit_impact_debris(effect.global_position, true)
			_emit_ghostship_impact_bursts(effect.global_position)
			_start_impact_camera_shake(ghostship_camera_shake_duration, ghostship_camera_shake_strength)


func _emit_impact_shockwave(position: Vector3, size: float, strength: float, lifetime: float) -> void:
	if impact_shockwaves.is_empty():
		return
	var shockwave := impact_shockwaves[impact_shockwave_cursor]
	shockwave.global_position = position
	# Heavy impacts spread along the floor as a pressure sheet, not a UI-like circle.
	shockwave.scale = Vector3(size, size * 0.48, 1.0)
	var material := shockwave.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"progress", 0.0)
		material.set_shader_parameter(&"distortion_strength", strength)
		material.set_shader_parameter(&"opacity", impact_shockwave_opacity)
	shockwave.visible = true
	impact_shockwave_ages[impact_shockwave_cursor] = 0.0
	impact_shockwave_lifetimes[impact_shockwave_cursor] = maxf(lifetime, 0.01)
	impact_shockwave_cursor = (impact_shockwave_cursor + 1) % impact_shockwaves.size()
	impact_shockwave_emit_count += 1


func _update_impact_shockwaves(delta: float) -> void:
	for index: int in range(impact_shockwaves.size()):
		var shockwave := impact_shockwaves[index]
		if not shockwave.visible:
			continue
		impact_shockwave_ages[index] += delta
		var progress := clampf(
			impact_shockwave_ages[index] / impact_shockwave_lifetimes[index], 0.0, 1.0
		)
		if progress >= 1.0:
			shockwave.visible = false
			continue
		var material := shockwave.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"progress", progress)
			material.set_shader_parameter(&"opacity", impact_shockwave_opacity * (1.0 - progress))


func _start_impact_camera_shake(duration: float, strength: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if impact_camera != camera or impact_shake_duration <= 0.0:
		impact_camera = camera
		impact_camera_base_h_offset = camera.h_offset
		impact_camera_base_v_offset = camera.v_offset
	impact_shake_elapsed = 0.0
	impact_shake_duration = maxf(impact_shake_duration, duration)
	impact_shake_strength = maxf(impact_shake_strength, strength)


func _update_impact_camera_shake(delta: float) -> void:
	if impact_shake_duration <= 0.0 or not is_instance_valid(impact_camera):
		return
	impact_shake_elapsed += delta
	var progress := clampf(impact_shake_elapsed / impact_shake_duration, 0.0, 1.0)
	if progress >= 1.0:
		impact_camera.h_offset = impact_camera_base_h_offset
		impact_camera.v_offset = impact_camera_base_v_offset
		impact_shake_duration = 0.0
		impact_shake_strength = 0.0
		return
	var envelope := (1.0 - progress) * (1.0 - progress)
	var phase := impact_shake_elapsed * 92.0
	impact_camera.h_offset = impact_camera_base_h_offset + sin(phase) * impact_shake_strength * envelope
	impact_camera.v_offset = impact_camera_base_v_offset + cos(phase * 1.37) * impact_shake_strength * 0.62 * envelope


func _start_anchor_rebound(impact_position: Vector3) -> void:
	anchor_position_locked = true
	anchor_impact_position = impact_position
	anchor_rebound_lift = 0.0
	if anchor_rebound_tween != null and anchor_rebound_tween.is_valid():
		anchor_rebound_tween.kill()
	anchor_rebound_tween = create_tween()
	anchor_rebound_tween.set_trans(Tween.TRANS_QUAD)
	anchor_rebound_tween.tween_property(
		self, "anchor_rebound_lift", judgment_rebound_height, judgment_rebound_up_duration
	).set_ease(Tween.EASE_OUT)
	anchor_rebound_tween.tween_property(
		self, "anchor_rebound_lift", judgment_rebound_height * 0.22, judgment_rebound_down_duration
	).set_ease(Tween.EASE_IN)


func _update_anchor_tail_dissolve(delta: float) -> void:
	var material := anchor_effect.material_override as ShaderMaterial
	if material == null:
		return
	if not anchor_effect.visible:
		material.set_shader_parameter(&"tail_dissolve", 0.0)
		return
	if not anchor_tail_active:
		material.set_shader_parameter(&"tail_dissolve", 0.0)
		return
	anchor_tail_elapsed += delta
	var dissolve_elapsed := maxf(anchor_tail_elapsed - judgment_tail_hold_duration, 0.0)
	var tail_progress := clampf(dissolve_elapsed / maxf(judgment_tail_dissolve_duration, 0.01), 0.0, 1.0)
	var eased_progress := smoothstep(0.0, 1.0, tail_progress)
	material.set_shader_parameter(&"tail_dissolve", eased_progress)
	if tail_progress >= 1.0:
		_finish_anchor_tail()


func _on_anchor_animation_finished() -> void:
	if not anchor_effect.visible:
		return
	anchor_tail_active = true
	anchor_tail_elapsed = 0.0
	anchor_effect.speed_scale = 1.0
	anchor_effect.pause()


func _finish_anchor_tail() -> void:
	anchor_tail_active = false
	anchor_tail_elapsed = 0.0
	anchor_effect.visible = false
	anchor_effect.stop()
	anchor_effect.speed_scale = 1.0
	anchor_position_locked = false
	anchor_rebound_lift = 0.0
	if anchor_rebound_tween != null and anchor_rebound_tween.is_valid():
		anchor_rebound_tween.kill()
	var material := anchor_effect.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"tail_dissolve", 0.0)


func receive_incoming_damage(amount: float, damage_type: StringName = &"physical", is_critical := false) -> void:
	var resolved := CombatMath.resolve_damage(amount, damage_type, get_effective_armor(), get_effective_magic_resistance(), combat_database)
	if black_sail_timer > 0.0 and damage_type != &"true":
		var reduction_cap := float(combat_database.get_rule(&"damage.reduction_cap", 0.90)) if combat_database != null else 0.90
		resolved *= 1.0 - clampf(black_sail_damage_reduction, 0.0, reduction_cap)
	var shield_absorbed := minf(normal_shield, resolved)
	normal_shield = maxf(0.0, normal_shield - shield_absorbed)
	black_sail_guard_shield_remaining = maxf(0.0, black_sail_guard_shield_remaining - shield_absorbed)
	var health_damage := maxf(0.0, resolved - shield_absorbed)
	if rum_timer > 0.0:
		var delayed_portion := health_damage * 0.5
		delayed_damage_pool += delayed_portion
		current_health = maxf(0.0, current_health - (health_damage - delayed_portion))
		rum_settlement_pending = delayed_damage_pool > 0.0
	else:
		current_health = maxf(0.0, current_health - health_damage)
	if resolved > 0.0 and fighter != null and fighter.has_method("present_resolved_damage"):
		fighter.call("present_resolved_damage", resolved, damage_type, is_critical)
	if resolved > 0.0:
		passive_damage_lockout_remaining = passive_lockout_duration
		passive_recovery_active = false


func get_perseverance_regen_ratio_per_5(level := current_level) -> float:
	var resolved_level := clampi(level, 1, int(combat_database.get_rule(&"progression.level_cap", 30)) if combat_database != null else 30)
	var early_levels := mini(maxi(resolved_level - 1, 0), 5)
	var middle_levels := mini(maxi(resolved_level - 6, 0), 7)
	var late_levels := maxi(resolved_level - 13, 0)
	return passive_regen_ratio_per_5 \
		+ passive_early_level_increment * float(early_levels) \
		+ passive_mid_level_increment * float(middle_levels) \
		+ passive_late_level_increment * float(late_levels)


func _update_perseverance(delta: float) -> void:
	if current_health <= 0.0:
		passive_recovery_active = false
		passive_vfx_should_show = false
		return
	if passive_damage_lockout_remaining > 0.0:
		passive_damage_lockout_remaining = maxf(0.0, passive_damage_lockout_remaining - delta)
		passive_recovery_active = false
		passive_vfx_should_show = false
		return
	if current_health >= max_health:
		passive_recovery_active = false
		# Presentation follows P readiness, not the small amount of missing health.
		# Otherwise a full-health player in the training scene never exposes the
		# passive's three-layer VFX, even though P is available.
		passive_vfx_should_show = true
		return
	if not passive_recovery_active:
		passive_recovery_active = true
		passive_vfx_should_show = true
		passive_recovery_activation_count += 1
		play_audio_cue(&"garen_passive_recovery_activate", fighter.global_position, 1.0)
	var period := maxf(passive_regen_period, 0.01)
	var healed := max_health * get_perseverance_regen_ratio_per_5() * delta / period
	current_health = minf(max_health, current_health + healed)


func _update_perseverance_vfx(delta: float) -> void:
	var fade_duration := passive_vfx_fade_in if passive_vfx_should_show else passive_vfx_fade_out
	var target_alpha := 1.0 if passive_vfx_should_show else 0.0
	passive_vfx_alpha = move_toward(passive_vfx_alpha, target_alpha, delta / maxf(fade_duration, 0.01))
	for effect: AnimatedSprite3D in _perseverance_vfx():
		if passive_vfx_should_show and not effect.visible:
			effect.visible = true
			effect.play(effect.animation)
		effect.modulate.a = passive_vfx_opacity * _perseverance_profile_opacity(effect) * passive_vfx_alpha
		if not passive_vfx_should_show and is_zero_approx(passive_vfx_alpha):
			effect.visible = false
			effect.pause()
	_update_perseverance_motes()


func _perseverance_vfx() -> Array[AnimatedSprite3D]:
	return [perseverance_front, perseverance_hip]


func _perseverance_asset_id(effect: AnimatedSprite3D) -> StringName:
	if effect == perseverance_front:
		return &"garen_perseverance_front"
	return &"garen_perseverance_hip"


func _perseverance_profile_opacity(effect: AnimatedSprite3D) -> float:
	if combat_database == null:
		return 1.0
	var profile := combat_database.get_asset_profile(_perseverance_asset_id(effect))
	return profile.opacity if profile != null else 1.0


func _build_perseverance_motes() -> void:
	var profile := combat_database.get_particle_profile(&"garen_perseverance_motes") if combat_database != null else null
	var asset_profile := combat_database.get_asset_profile(&"garen_perseverance_motes") if combat_database != null else null
	perseverance_motes = GPUParticles3D.new()
	perseverance_motes.name = "PerseveranceMotes"
	perseverance_motes.emitting = false
	perseverance_motes.amount = profile.amount if profile != null else 14
	perseverance_motes.lifetime = profile.lifetime if profile != null else 2.6
	perseverance_motes.randomness = profile.randomness if profile != null else 0.35
	perseverance_motes.local_coords = true
	perseverance_motes.visibility_aabb = AABB(Vector3(-1.1, -0.1, -0.9), Vector3(2.2, 3.2, 1.8))
	perseverance_motes.position = asset_profile.local_position if asset_profile != null else Vector3(0.08, 0.36, 0.10)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.48, 0.05, 0.30)
	process.direction = Vector3.UP
	process.spread = profile.spread if profile != null else 28.0
	process.gravity = profile.gravity if profile != null else Vector3(0.0, 0.08, 0.0)
	process.initial_velocity_min = profile.velocity_min if profile != null else 0.10
	process.initial_velocity_max = profile.velocity_max if profile != null else 0.25
	process.angular_velocity_min = profile.angular_velocity_min if profile != null else -18.0
	process.angular_velocity_max = profile.angular_velocity_max if profile != null else 18.0
	process.scale_min = profile.scale_min if profile != null else 0.65
	process.scale_max = profile.scale_max if profile != null else 1.15
	perseverance_motes.process_material = process
	var color_ramp := Gradient.new()
	color_ramp.offsets = PackedFloat32Array([0.0, 0.30, 0.78, 1.0])
	color_ramp.colors = PackedColorArray([
		profile.gradient_start if profile != null else Color(0.85, 1.0, 0.90, 0.50),
		profile.gradient_mid if profile != null else Color(0.56, 1.0, 0.65, 0.42),
		profile.gradient_late if profile != null else Color(0.30, 0.85, 0.47, 0.22),
		profile.gradient_end if profile != null else Color(0.16, 0.42, 0.20, 0.0),
	])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = color_ramp
	process.color_ramp = ramp_texture
	var mote_mesh := QuadMesh.new()
	mote_mesh.size = profile.mesh_size if profile != null else Vector2(0.07, 0.11)
	perseverance_mote_material = StandardMaterial3D.new()
	perseverance_mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	perseverance_mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	perseverance_mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	perseverance_mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	perseverance_mote_material.no_depth_test = asset_profile.no_depth_test if asset_profile != null else true
	perseverance_mote_material.render_priority = asset_profile.render_priority if asset_profile != null else 2
	perseverance_mote_material.vertex_color_use_as_albedo = true
	perseverance_mote_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	perseverance_mote_material.emission_enabled = true
	perseverance_mote_material.emission = profile.emission_color if profile != null else Color(0.50, 1.0, 0.61, 1.0)
	perseverance_mote_material.emission_energy_multiplier = profile.emission_energy if profile != null else 0.7
	mote_mesh.material = perseverance_mote_material
	perseverance_motes.draw_pass_1 = mote_mesh
	add_child(perseverance_motes)


func _update_perseverance_motes() -> void:
	if not is_instance_valid(perseverance_motes):
		return
	if passive_vfx_should_show and not perseverance_motes.emitting:
		perseverance_motes.emitting = true
		perseverance_motes.restart()
	if perseverance_mote_material != null:
		perseverance_mote_material.albedo_color.a = passive_vfx_alpha
	if not passive_vfx_should_show and is_zero_approx(passive_vfx_alpha):
		perseverance_motes.emitting = false


func get_control_duration_multiplier() -> float:
	return 1.0 - black_sail_tenacity if black_sail_guard_timer > 0.0 else 1.0


func activate_black_sail_defenses() -> void:
	black_sail_timer = black_sail_duration
	black_sail_guard_timer = black_sail_guard_duration
	black_sail_guard_shield_remaining = black_sail_shield + _bonus_health() * black_sail_shield_bonus_health_ratio
	normal_shield += black_sail_guard_shield_remaining
	if rum_timer > 0.0:
		delayed_damage_pool *= 1.0 - black_sail_rum_cleanse_ratio


func _bonus_health() -> float:
	if combat_database == null or garen_definition == null:
		return 0.0
	return combat_database.get_unit_stat_value(garen_definition.id, &"bonus_health", current_level)


func apply_seven_seas_rum(duration: float, move_speed_bonus: float) -> void:
	rum_timer = maxf(rum_timer, duration)
	rum_speed_bonus = maxf(rum_speed_bonus, move_speed_bonus)


func calculate_judgment_damage(target_max_health: float, target_health_ratio: float) -> float:
	var missing_ratio := 1.0 - clampf(target_health_ratio, 0.0, 1.0)
	return judgment_base_damage + maxf(target_max_health, 1.0) * judgment_missing_health_damage * missing_ratio


func prepare_ghostship_direction(destination: Vector3) -> float:
	var horizontal_direction := signf(destination.x - fighter.global_position.x)
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0
	ghostship.flip_h = horizontal_direction < 0.0
	var definition := _definition(SKILL_SEVEN_SEAS)
	var start_offset := definition.travel_start_offset if definition != null else 2.2
	ghostship.global_position = fighter.global_position - Vector3(horizontal_direction * start_offset, 0.0, 0.0)
	return horizontal_direction


func _cast_skill_async(skill_index: int) -> void:
	match skill_index:
		SKILL_BREAKER:
			await _cast_breaker()
		SKILL_BLACK_SAIL:
			await _cast_black_sail()
		SKILL_OCEAN_STORM:
			await _cast_ocean_storm()
		SKILL_TYRANT_JUDGMENT:
			await _cast_tyrant_judgment()
		SKILL_SEVEN_SEAS:
			await _cast_seven_seas()
	is_casting = false
	current_skill = 0
	demo_timer = demo_gap


func _cast_breaker() -> void:
	slow_multiplier = 1.0
	breaker_timer = breaker_duration
	breaker_empowered_attack = true
	play_audio_cue(_skill_audio_profile(SKILL_BREAKER, &"garen_q_cast"), fighter.global_position, 1.0)
	character_frames.play(_skill_windup_animation(SKILL_BREAKER, &"channel_wndup"))
	await get_tree().create_timer(_skill_float(SKILL_BREAKER, "cast_time", 0.16)).timeout


func _cast_black_sail() -> void:
	jolly_roger.visible = true
	jolly_roger.play(jolly_roger.animation)
	jolly_audio.play()
	activate_black_sail_defenses()


func _cast_ocean_storm() -> void:
	var animation := _skill_animation(SKILL_OCEAN_STORM, &"spell3")
	character_frames.play(animation)
	character_frames.pause()
	character_frames.frame = 0
	ocean_storm_loop_elapsed = 0.0
	ocean_storm_loop_active = true
	ocean_storm.visible = true
	ocean_storm.play(ocean_storm.animation)
	ocean_audio.play()
	ocean_storm_hit_counts.clear()
	var spins := _ocean_storm_spin_count()
	var interval := ocean_storm_duration / maxf(float(spins), 1.0)
	var elapsed := 0.0
	while elapsed < ocean_storm_duration:
		await get_tree().create_timer(interval).timeout
		elapsed += interval
		resolve_ocean_storm_tick()
	ocean_storm_loop_active = false
	character_frames.play(animation)
	character_frames.frame = mini(ocean_storm_loop_frame_count, character_frames.sprite_frames.get_frame_count(animation) - 1)
	ocean_storm.visible = false
	ocean_storm.stop()
	ocean_audio.stop()


func _update_ocean_storm_animation_loop(delta: float) -> void:
	if not ocean_storm_loop_active or character_frames.sprite_frames == null:
		return
	var animation := _skill_animation(SKILL_OCEAN_STORM, &"spell3")
	var available_frames := character_frames.sprite_frames.get_frame_count(animation)
	if available_frames <= 0:
		return
	if character_frames.animation != animation:
		character_frames.play(animation)
		character_frames.pause()
	ocean_storm_loop_elapsed += delta
	var frame_count := mini(ocean_storm_loop_frame_count, available_frames)
	var frame_rate := maxf(character_frames.sprite_frames.get_animation_speed(animation), 0.01)
	character_frames.frame = posmod(floori(ocean_storm_loop_elapsed * frame_rate), frame_count)


func _cast_tyrant_judgment() -> void:
	anchor_last_impact_frame = -1
	anchor_tail_active = false
	anchor_tail_elapsed = 0.0
	anchor_position_locked = false
	anchor_rebound_lift = 0.0
	if anchor_rebound_tween != null and anchor_rebound_tween.is_valid():
		anchor_rebound_tween.kill()
	anchor_effect.speed_scale = 1.0
	var anchor_material := anchor_effect.material_override as ShaderMaterial
	if anchor_material != null:
		anchor_material.set_shader_parameter(&"tail_dissolve", 0.0)
	character_frames.play(_skill_animation(SKILL_TYRANT_JUDGMENT, &"spell4"))
	anchor_effect.global_position = target.global_position
	play_audio_cue(&"garen_r_buff_activate", target.global_position, 1.0)
	anchor_effect.visible = true
	anchor_effect.play(anchor_effect.animation)
	anchor_audio.play()
	await get_tree().create_timer(_skill_float(SKILL_TYRANT_JUDGMENT, "cast_time", 0.28)).timeout
	if is_instance_valid(target) and target.has_method("receive_skill_damage"):
		_register_damage_source(target)
		var health_ratio := float(target.call("get_health_ratio")) if target.has_method("get_health_ratio") else 1.0
		var target_max_health := float(target.get("max_health"))
		var damage := calculate_judgment_damage(target_max_health, health_ratio)
		target.call("receive_skill_damage", damage, "暴君审判", false, fighter.global_position, &"true", &"judgment_hit")
		register_courage_kill(target)
		damage_event_count += 1
	await get_tree().create_timer(_skill_float(SKILL_TYRANT_JUDGMENT, "recovery_time", 0.35)).timeout


func _cast_seven_seas() -> void:
	ghostship_last_impact_frame = -1
	_request_awakening_cutin(SKILL_SEVEN_SEAS)
	character_frames.play(_skill_animation(SKILL_SEVEN_SEAS, &"taunt"))
	# This is a ground-targeted area skill. The AI chooses the target's position
	# at cast time, but the area does not continue tracking that character.
	var area_center := target.global_position if is_instance_valid(target) else fighter.global_position
	prepare_ghostship_direction(area_center)
	ghostship.visible = true
	ghostship.play(ghostship.animation)
	ghostship_audio.play(0.0)
	ghostship_last_scheduled_buff_audio_delay = ghostship_buff_audio_delay
	play_audio_cue_delayed(&"garen_r_buff_activate", fighter.global_position, ghostship_buff_audio_delay, 1.0)
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var impact_time := _skill_float(SKILL_SEVEN_SEAS, "cast_time", 1.05)
	var seven_seas := _definition(SKILL_SEVEN_SEAS)
	var travel_duration := seven_seas.travel_duration if seven_seas != null else impact_time + 0.1
	ghostship_last_scheduled_impact_time = travel_duration
	travel.tween_property(ghostship, "global_position", area_center, travel_duration)
	var path_start := ghostship.global_position
	var sample_count := maxi(1, ceili(travel_duration / 0.08))
	for sample_index: int in range(sample_count):
		var previous_progress := float(sample_index) / float(sample_count)
		var progress := float(sample_index + 1) / float(sample_count)
		_apply_rum_to_allied_heroes_in_path(
			path_start.lerp(area_center, previous_progress),
			path_start.lerp(area_center, progress)
		)
		await get_tree().create_timer(travel_duration / float(sample_count)).timeout
	resolve_ghostship_impact(area_center)
	await get_tree().create_timer(_skill_float(SKILL_SEVEN_SEAS, "recovery_time", 0.65)).timeout
	ghostship.visible = false
	ghostship.stop()


func _request_awakening_cutin(skill_index: int) -> void:
	var definition := _definition(skill_index)
	if definition == null or not definition.tags.has(&"awakening"):
		return
	var manager := get_node_or_null("/root/AwakeningCutIn")
	if manager == null or not manager.has_method("request_skill"):
		return
	manager.call("request_skill", definition.id, {"source": fighter})


func resolve_ocean_storm_tick() -> int:
	var enemies := _get_enemy_targets_in_radius(fighter.global_position, ocean_storm_radius)
	enemies.sort_custom(func(a: CharacterBody3D, b: CharacterBody3D) -> bool: return fighter.global_position.distance_squared_to(a.global_position) < fighter.global_position.distance_squared_to(b.global_position))
	var hit_targets := 0
	var total_ad := garen_definition.attack_damage if garen_definition != null else 69.0
	var base_damage := ocean_storm_damage + total_ad * ocean_storm_damage_coefficient
	var nearest_multiplier := _rule_float(&"garen.ocean_storm.nearest_damage_multiplier", 1.25)
	var shred_hits := int(_rule_float(&"garen.ocean_storm.armor_shred_hits", 6.0))
	var shred_ratio := _rule_float(&"garen.ocean_storm.armor_shred_ratio", 0.25)
	var shred_duration := _rule_float(&"garen.ocean_storm.armor_shred_duration", 6.0)
	for index: int in enemies.size():
		var enemy := enemies[index]
		if enemy.has_method("receive_skill_damage"):
			_register_damage_source(enemy)
			var damage := base_damage * (nearest_multiplier if index == 0 else 1.0)
			enemy.call("receive_skill_damage", damage, "翻江倒海", true, fighter.global_position, &"physical", &"ocean_hit")
			var target_id := enemy.get_instance_id()
			var hit_count := int(ocean_storm_hit_counts.get(target_id, 0)) + 1
			ocean_storm_hit_counts[target_id] = hit_count
			if shred_hits > 0 and hit_count >= shred_hits and hit_count % shred_hits == 0 and enemy.has_method("apply_armor_shred"):
				enemy.call("apply_armor_shred", shred_duration, shred_ratio)
			register_courage_kill(enemy)
			damage_event_count += 1
			hit_targets += 1
	return hit_targets


func _ocean_storm_spin_count() -> int:
	var base_spins := int(_rule_float(&"garen.ocean_storm.base_spins", 7.0))
	# Equipment-derived bonus attack speed will populate this term once that system exists.
	var bonus_attack_speed := 0.0
	var per_spin := _rule_float(&"garen.ocean_storm.bonus_attack_speed_per_spin", 0.25)
	return base_spins + floori(bonus_attack_speed / maxf(per_spin, 0.01))


func resolve_ghostship_impact(area_center: Vector3) -> int:
	var hit_targets := 0
	for enemy: CharacterBody3D in _get_enemy_targets_in_radius(area_center, ghostship_radius):
		if enemy.has_method("receive_skill_damage"):
			_register_damage_source(enemy)
			enemy.call("receive_skill_damage", ghostship_damage, "七海霸权", false, fighter.global_position, &"magic", &"ghostship_hit")
		if enemy.has_method("apply_stun"):
			enemy.call("apply_stun", ghostship_stun_duration)
		register_courage_kill(enemy)
		damage_event_count += 1
		hit_targets += 1
	return hit_targets


func _apply_rum_to_allied_heroes_in_path(path_start: Vector3, path_end: Vector3) -> void:
	for candidate_node: Node in get_tree().get_nodes_in_group(&"hero_actor"):
		var ally := candidate_node as CharacterBody3D
		if not is_instance_valid(ally) or not _is_friendly_hero(ally):
			continue
		if not _is_within_ship_path(ally.global_position, path_start, path_end, 1.15):
			continue
		if ally == fighter:
			apply_seven_seas_rum(rum_duration, rum_speed_bonus)
		elif ally.has_method("apply_seven_seas_rum"):
			ally.call("apply_seven_seas_rum", rum_duration, rum_speed_bonus)


func _is_friendly_hero(candidate: CharacterBody3D) -> bool:
	var fighter_team := StringName(fighter.call("get_team")) if fighter.has_method("get_team") else &"friendly"
	return not candidate.has_method("get_team") or StringName(candidate.call("get_team")) == fighter_team


func _is_within_ship_path(point: Vector3, path_start: Vector3, path_end: Vector3, radius: float) -> bool:
	var start := Vector2(path_start.x, path_start.z)
	var end := Vector2(path_end.x, path_end.z)
	var sample := Vector2(point.x, point.z)
	var segment := end - start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return sample.distance_to(start) <= radius
	var progress := clampf((sample - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return sample.distance_to(start.lerp(end, progress)) <= radius


func _get_enemy_targets_in_radius(area_center: Vector3, radius: float) -> Array[CharacterBody3D]:
	var enemies: Array[CharacterBody3D] = []
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
			continue
		var fighter_team := StringName(fighter.call("get_team")) if fighter.has_method("get_team") else &"friendly"
		if candidate.has_method("is_enemy_of") and not bool(candidate.call("is_enemy_of", fighter_team)):
			continue
		var horizontal_offset := candidate.global_position - area_center
		horizontal_offset.y = 0.0
		if horizontal_offset.length() <= radius:
			enemies.append(candidate)
	return enemies


func _register_damage_source(target_actor: CharacterBody3D) -> void:
	if target_actor.has_method("register_damage_source"):
		var fighter_team := StringName(fighter.call("get_team")) if fighter.has_method("get_team") else &"friendly"
		target_actor.call("register_damage_source", fighter.global_position, fighter_team)


func _update_timers(delta: float) -> void:
	for index: int in range(SKILL_BREAKER, SKILL_SEVEN_SEAS + 1):
		cooldowns[index] = maxf(0.0, cooldowns[index] - delta)
	breaker_timer = maxf(0.0, breaker_timer - delta)
	if breaker_timer <= 0.0:
		breaker_empowered_attack = false
	var had_black_sail := black_sail_timer > 0.0
	black_sail_timer = maxf(0.0, black_sail_timer - delta)
	black_sail_guard_timer = maxf(0.0, black_sail_guard_timer - delta)
	if black_sail_guard_timer <= 0.0 and black_sail_guard_shield_remaining > 0.0:
		normal_shield = maxf(0.0, normal_shield - black_sail_guard_shield_remaining)
		black_sail_guard_shield_remaining = 0.0
	jolly_roger.visible = black_sail_timer > 0.0
	if had_black_sail and black_sail_timer <= 0.0:
		jolly_roger.visible = false
		jolly_roger.stop()
		jolly_audio.stop()
	var had_rum := rum_timer > 0.0
	rum_timer = maxf(0.0, rum_timer - delta)
	if had_rum and rum_timer <= 0.0 and rum_settlement_pending:
		# Rum's postponed half resolves only when the buff ends, and can never kill.
		current_health = maxf(1.0, current_health - delayed_damage_pool)
		delayed_damage_pool = 0.0
		rum_settlement_pending = false
	for target_id: int in courage_kill_ledger.keys():
		var tracked: Object = courage_kill_ledger[target_id].get_ref()
		if tracked == null or (tracked.has_method("is_targetable") and bool(tracked.call("is_targetable"))):
			courage_kill_ledger.erase(target_id)


func _update_rum_damage(_delta: float) -> void:
	# Settlement is intentionally delayed until the Rum buff expires; see _update_timers.
	pass


func _sync_vfx_frame(effect: AnimatedSprite3D) -> void:
	if effect.material_override == null or effect.sprite_frames == null:
		return
	var material := effect.material_override as ShaderMaterial
	if material == null:
		return
	var frame_texture := effect.sprite_frames.get_frame_texture(effect.animation, effect.frame)
	if frame_texture != null:
		material.set_shader_parameter(&"frame_texture", frame_texture)
		material.set_shader_parameter(&"frame_uv_rect", _frame_uv_rect(frame_texture))


func _configure_inward_canvas_edge(effect: AnimatedSprite3D, material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"canvas_inward_base", 0.0)
	material.set_shader_parameter(&"canvas_inward_warp", 0.0)
	material.set_shader_parameter(&"canvas_inward_softness", 0.04)
	material.set_shader_parameter(&"canvas_inward_frequency", 4.0)
	if effect == anchor_effect:
		material.set_shader_parameter(&"canvas_inward_base", 0.025)
		material.set_shader_parameter(&"canvas_inward_warp", 0.055)
		material.set_shader_parameter(&"canvas_inward_softness", 0.04)
		material.set_shader_parameter(&"canvas_inward_frequency", 4.8)
	elif effect == ghostship:
		material.set_shader_parameter(&"canvas_inward_base", 0.04)
		material.set_shader_parameter(&"canvas_inward_warp", 0.085)
		material.set_shader_parameter(&"canvas_inward_softness", 0.045)
		material.set_shader_parameter(&"canvas_inward_frequency", 4.0)


func _frame_uv_rect(frame_texture: Texture2D) -> Vector4:
	if frame_texture is AtlasTexture:
		var atlas_texture := frame_texture as AtlasTexture
		if atlas_texture.atlas != null:
			var atlas_size := Vector2(atlas_texture.atlas.get_size())
			if atlas_size.x > 0.0 and atlas_size.y > 0.0:
				var region := atlas_texture.region
				return Vector4(
					region.position.x / atlas_size.x,
					region.position.y / atlas_size.y,
					region.size.x / atlas_size.x,
					region.size.y / atlas_size.y
				)
	return Vector4(0.0, 0.0, 1.0, 1.0)


func _skill_in_range(skill_index: int) -> bool:
	if not is_instance_valid(target):
		return false
	var distance := fighter.global_position.distance_to(target.global_position)
	match skill_index:
		SKILL_OCEAN_STORM:
			return distance <= ocean_storm_radius
		SKILL_TYRANT_JUDGMENT:
			return distance <= _skill_float(SKILL_TYRANT_JUDGMENT, "cast_range", 4.0)
		SKILL_SEVEN_SEAS:
			return distance <= _skill_float(SKILL_SEVEN_SEAS, "cast_range", 7.5)
		_:
			return true


func _get_cooldown(skill_index: int) -> float:
	var base_cooldown := 0.0
	match skill_index:
		SKILL_BREAKER:
			base_cooldown = breaker_cooldown
		SKILL_BLACK_SAIL:
			base_cooldown = black_sail_cooldown
		SKILL_OCEAN_STORM:
			base_cooldown = ocean_storm_cooldown
		SKILL_TYRANT_JUDGMENT:
			base_cooldown = judgment_cooldown
		SKILL_SEVEN_SEAS:
			base_cooldown = seven_seas_cooldown
	if combat_database != null and garen_definition != null:
		return CombatMath.cooldown_with_haste(base_cooldown, garen_definition.ability_haste, combat_database)
	return base_cooldown


func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		push_warning("Combat database is unavailable; using inspector fallback values")
		return
	garen_definition = combat_database.get_unit(&"garen")
	if garen_definition != null:
		max_health = garen_definition.max_health
		current_health = max_health
		current_level = garen_definition.level
		var ai := combat_database.get_ai_profile(garen_definition.ai_profile_id)
		if ai != null:
			demo_gap = ai.demo_skill_gap
	for slot: int in range(SKILL_BREAKER, SKILL_SEVEN_SEAS + 1):
		skill_definitions[slot] = combat_database.get_skill_by_slot(&"garen", slot)

	var breaker := _definition(SKILL_BREAKER)
	var perseverance := combat_database.get_skill(&"garen_perseverance")
	var perseverance_effect := _effect(&"perseverance_regen")
	passive_lockout_duration = _rule_float(&"garen.perseverance.lockout_duration", passive_lockout_duration)
	passive_regen_period = _rule_float(&"garen.perseverance.period", passive_regen_period)
	passive_regen_ratio_per_5 = perseverance_effect.base_value if perseverance_effect != null else passive_regen_ratio_per_5
	passive_early_level_increment = _rule_float(&"garen.perseverance.early_level_increment", passive_early_level_increment)
	passive_mid_level_increment = _rule_float(&"garen.perseverance.mid_level_increment", passive_mid_level_increment)
	passive_late_level_increment = _rule_float(&"garen.perseverance.late_level_increment", passive_late_level_increment)
	passive_vfx_opacity = _rule_float(&"presentation.perseverance_vfx_opacity", passive_vfx_opacity)
	passive_vfx_fade_in = _rule_float(&"presentation.perseverance_vfx_fade_in", passive_vfx_fade_in)
	passive_vfx_fade_out = _rule_float(&"presentation.perseverance_vfx_fade_out", passive_vfx_fade_out)
	passive_vfx_frame_rate = _rule_float(&"presentation.perseverance_vfx_frame_rate", passive_vfx_frame_rate)
	if perseverance != null:
		passive_regen_period = perseverance.tick_interval if perseverance.tick_interval > 0.0 else passive_regen_period
	var breaker_buff := combat_database.get_buff(&"breaker_speed")
	var breaker_damage_effect := _effect(&"breaker_damage")
	var breaker_silence_effect := _effect(&"breaker_silence")
	var breaker_rank: int = int(skill_ranks.get(SKILL_BREAKER, 1))
	var breaker_rank_data := combat_database.get_skill_rank(&"garen_breaker", breaker_rank)
	var breaker_damage_rank := combat_database.get_skill_effect_rank(&"breaker_damage", breaker_rank)
	breaker_duration = breaker_rank_data.duration if breaker_rank_data != null else (breaker_buff.duration if breaker_buff != null else breaker_duration)
	breaker_speed_bonus = _modifier_value(&"breaker_speed", &"move_speed", breaker_speed_bonus)
	breaker_damage = breaker_damage_rank.base_value if breaker_damage_rank != null else (breaker_damage_effect.base_value if breaker_damage_effect != null else breaker_damage)
	breaker_damage_coefficient = breaker_damage_rank.scaling_coefficient if breaker_damage_rank != null else (breaker_damage_effect.scaling_coefficient if breaker_damage_effect != null else breaker_damage_coefficient)
	breaker_silence_duration = breaker_silence_effect.control_duration if breaker_silence_effect != null else breaker_silence_duration
	breaker_cooldown = breaker_rank_data.cooldown if breaker_rank_data != null else (breaker.cooldown if breaker != null else breaker_cooldown)

	var black_sail := _definition(SKILL_BLACK_SAIL)
	var black_sail_buff := combat_database.get_buff(&"black_sail")
	var black_sail_rank := get_skill_rank(SKILL_BLACK_SAIL)
	var black_sail_rank_data := combat_database.get_skill_rank(&"garen_black_sail", black_sail_rank)
	var reduction_rank := combat_database.get_skill_effect_rank(&"black_sail_damage_reduction", black_sail_rank)
	var shield_rank := combat_database.get_skill_effect_rank(&"black_sail_shield", black_sail_rank)
	var tenacity_rank := combat_database.get_skill_effect_rank(&"black_sail_tenacity", black_sail_rank)
	black_sail_duration = black_sail_rank_data.duration if black_sail_rank_data != null else (black_sail_buff.duration if black_sail_buff != null else black_sail_duration)
	black_sail_damage_reduction = reduction_rank.base_value if reduction_rank != null else black_sail_damage_reduction
	black_sail_shield = shield_rank.base_value if shield_rank != null else black_sail_shield
	black_sail_shield_bonus_health_ratio = shield_rank.scaling_coefficient if shield_rank != null else black_sail_shield_bonus_health_ratio
	black_sail_tenacity = tenacity_rank.base_value if tenacity_rank != null else black_sail_tenacity
	black_sail_guard_duration = _rule_float(&"garen.black_sail.guard_duration", black_sail_guard_duration)
	courage_max_stacks = int(_rule_float(&"garen.courage.max_stacks", float(courage_max_stacks)))
	courage_resistance_per_stack = _rule_float(&"garen.courage.resistance_per_stack", courage_resistance_per_stack)
	var rum_cleanse_effect := _effect(&"black_sail_rum_cleanse")
	black_sail_rum_cleanse_ratio = rum_cleanse_effect.base_value if rum_cleanse_effect != null else black_sail_rum_cleanse_ratio
	black_sail_cooldown = black_sail_rank_data.cooldown if black_sail_rank_data != null else (black_sail.cooldown if black_sail != null else black_sail_cooldown)

	var ocean := _definition(SKILL_OCEAN_STORM)
	var ocean_effect := _effect(&"ocean_damage")
	var ocean_rank := get_skill_rank(SKILL_OCEAN_STORM)
	var ocean_rank_data := combat_database.get_skill_rank(&"garen_ocean_storm", ocean_rank)
	var ocean_damage_rank := combat_database.get_skill_effect_rank(&"ocean_damage", ocean_rank)
	if ocean != null:
		ocean_storm_duration = ocean_rank_data.duration if ocean_rank_data != null else ocean.duration
		ocean_storm_tick = ocean_rank_data.tick_interval if ocean_rank_data != null else ocean.tick_interval
		ocean_storm_radius = ocean_rank_data.radius if ocean_rank_data != null else ocean.radius
		ocean_storm_cooldown = ocean_rank_data.cooldown if ocean_rank_data != null else ocean.cooldown
	ocean_storm_damage = ocean_damage_rank.base_value if ocean_damage_rank != null else (ocean_effect.base_value if ocean_effect != null else ocean_storm_damage)
	ocean_storm_damage_coefficient = ocean_damage_rank.scaling_coefficient if ocean_damage_rank != null else (ocean_effect.scaling_coefficient if ocean_effect != null else ocean_storm_damage_coefficient)
	ocean_storm_loop_frame_count = int(_rule_float(&"garen.ocean_storm.loop_frame_count", float(ocean_storm_loop_frame_count)))

	var judgment := _definition(SKILL_TYRANT_JUDGMENT)
	var judgment_effect := _effect(&"judgment_damage")
	var judgment_rank := get_skill_rank(SKILL_TYRANT_JUDGMENT)
	var judgment_rank_data := combat_database.get_skill_rank(&"garen_tyrant_judgment", judgment_rank)
	var judgment_damage_rank := combat_database.get_skill_effect_rank(&"judgment_damage", judgment_rank)
	judgment_cooldown = judgment_rank_data.cooldown if judgment_rank_data != null else (judgment.cooldown if judgment != null else judgment_cooldown)
	if judgment_effect != null:
		judgment_base_damage = judgment_damage_rank.base_value if judgment_damage_rank != null else judgment_effect.base_value
		judgment_missing_health_damage = judgment_damage_rank.target_missing_health_coefficient if judgment_damage_rank != null else judgment_effect.target_missing_health_coefficient

	var seven_seas := _definition(SKILL_SEVEN_SEAS)
	var seven_damage := _effect(&"seven_seas_damage")
	var seven_stun := _effect(&"seven_seas_stun")
	var seven_rum := _effect(&"seven_seas_rum")
	var rum_buff := combat_database.get_buff(&"seven_seas_rum")
	var seven_rank := get_skill_rank(SKILL_SEVEN_SEAS)
	var seven_rank_data := combat_database.get_skill_rank(&"garen_seven_seas", seven_rank)
	var seven_damage_rank := combat_database.get_skill_effect_rank(&"seven_seas_damage", seven_rank)
	var seven_rum_rank := combat_database.get_skill_effect_rank(&"seven_seas_rum", seven_rank)
	if seven_seas != null:
		ghostship_radius = seven_rank_data.radius if seven_rank_data != null else seven_seas.radius
		seven_seas_cooldown = seven_rank_data.cooldown if seven_rank_data != null else seven_seas.cooldown
	ghostship_damage = seven_damage_rank.base_value if seven_damage_rank != null else (seven_damage.base_value if seven_damage != null else ghostship_damage)
	ghostship_stun_duration = seven_stun.control_duration if seven_stun != null else ghostship_stun_duration
	rum_duration = seven_rum_rank.base_value if seven_rum_rank != null else (seven_rum.base_value if seven_rum != null else (rum_buff.duration if rum_buff != null else rum_duration))
	rum_speed_bonus = seven_rum_rank.scaling_coefficient if seven_rum_rank != null else (seven_rum.scaling_coefficient if seven_rum != null else rum_speed_bonus)

	breaker_afterimage_count = int(combat_database.get_rule(&"presentation.breaker_afterimage_count", breaker_afterimage_count))
	breaker_afterimage_lifetime = _rule_float(&"presentation.breaker_afterimage_lifetime", breaker_afterimage_lifetime)
	breaker_afterimage_alpha = _rule_float(&"presentation.breaker_afterimage_alpha", breaker_afterimage_alpha)
	breaker_afterimage_color = Color.from_string(
		String(combat_database.get_rule(&"presentation.breaker_afterimage_color", breaker_afterimage_color.to_html())),
		breaker_afterimage_color
	)
	impact_shockwave_pool_size = int(combat_database.get_rule(&"presentation.impact_shockwave_pool_size", impact_shockwave_pool_size))
	impact_shockwave_lifetime = _rule_float(&"presentation.impact_shockwave_lifetime", impact_shockwave_lifetime)
	impact_shockwave_opacity = _rule_float(&"presentation.impact_shockwave_opacity", impact_shockwave_opacity)
	anchor_impact_frame = int(combat_database.get_rule(&"presentation.judgment_impact_frame", anchor_impact_frame))
	ghostship_impact_frame = int(combat_database.get_rule(&"presentation.ghostship_impact_frame", ghostship_impact_frame))
	judgment_distortion_strength = _rule_float(&"presentation.judgment_distortion_strength", judgment_distortion_strength)
	ghostship_distortion_strength = _rule_float(&"presentation.ghostship_distortion_strength", ghostship_distortion_strength)
	judgment_shockwave_size = _rule_float(&"presentation.judgment_shockwave_size", judgment_shockwave_size)
	ghostship_shockwave_size = _rule_float(&"presentation.ghostship_shockwave_size", ghostship_shockwave_size)
	judgment_rebound_height = _rule_float(&"presentation.judgment_rebound_height", judgment_rebound_height)
	judgment_rebound_up_duration = _rule_float(&"presentation.judgment_rebound_up_duration", judgment_rebound_up_duration)
	judgment_rebound_down_duration = _rule_float(&"presentation.judgment_rebound_down_duration", judgment_rebound_down_duration)
	judgment_tail_hold_duration = _rule_float(&"presentation.judgment_tail_hold_duration", judgment_tail_hold_duration)
	judgment_tail_dissolve_duration = _rule_float(&"presentation.judgment_tail_fade_duration", judgment_tail_dissolve_duration)
	judgment_vapor_burst_duration = _rule_float(&"presentation.judgment_vapor_duration", judgment_vapor_burst_duration)
	judgment_vapor_burst_size = _rule_float(&"presentation.judgment_vapor_size", judgment_vapor_burst_size)
	judgment_camera_shake_duration = _rule_float(&"presentation.judgment_camera_shake_duration", judgment_camera_shake_duration)
	judgment_camera_shake_strength = _rule_float(&"presentation.judgment_camera_shake_strength", judgment_camera_shake_strength)
	ghostship_camera_shake_duration = _rule_float(&"presentation.ghostship_camera_shake_duration", ghostship_camera_shake_duration)
	ghostship_camera_shake_strength = _rule_float(&"presentation.ghostship_camera_shake_strength", ghostship_camera_shake_strength)
	ghostship_buff_audio_delay = _rule_float(&"presentation.seven_seas_buff_audio_delay", ghostship_buff_audio_delay)

	_apply_asset_profile(jolly_roger, jolly_audio, &"jolly_roger", _skill_audio_profile(SKILL_BLACK_SAIL, &"garen_w_cast"))
	_apply_asset_profile(ocean_storm, ocean_audio, &"ocean_storm", _skill_audio_profile(SKILL_OCEAN_STORM, &"garen_e_cast"))
	_apply_asset_profile(anchor_effect, anchor_audio, &"anchor", _skill_audio_profile(SKILL_TYRANT_JUDGMENT, &"garen_r_cast"))
	_apply_asset_profile(ghostship, ghostship_audio, &"ghostship", &"ghostship_audio")


func _definition(skill_index: int) -> SkillDefinition:
	return skill_definitions.get(skill_index) as SkillDefinition


func _skill_audio_profile(skill_index: int, fallback: StringName) -> StringName:
	var definition := _definition(skill_index)
	return definition.audio_profile_id if definition != null and not definition.audio_profile_id.is_empty() else fallback


func play_audio_cue(profile_id: StringName, world_position: Vector3, pitch_scale: float = 1.0) -> AudioStreamPlayer3D:
	if combat_database == null or profile_id.is_empty():
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "AudioCue_%s" % String(profile_id)
	add_child(player)
	player.top_level = true
	player.global_position = world_position
	if CombatAudio.configure_player(player, combat_database, profile_id) == null:
		player.queue_free()
		return null
	player.pitch_scale = pitch_scale if pitch_scale > 0.0 else 1.0
	player.finished.connect(player.queue_free)
	player.play()
	audio_cue_play_counts[profile_id] = audio_cue_play_counts.get(profile_id, 0) + 1
	return player


func play_audio_cue_delayed(
	profile_id: StringName,
	world_position: Vector3,
	delay: float,
	pitch_scale: float = 1.0
) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	play_audio_cue(profile_id, world_position, pitch_scale)


func _effect(effect_id: StringName) -> SkillEffectDefinition:
	if combat_database == null:
		return null
	for definition: SkillEffectDefinition in combat_database.skill_effects:
		if definition.id == effect_id:
			return definition
	return null


func _modifier_value(buff_id: StringName, stat_id: StringName, fallback: float) -> float:
	var modifier := combat_database.get_buff_modifier(buff_id, stat_id) if combat_database != null else null
	return modifier.value if modifier != null else fallback


func _skill_animation(skill_index: int, fallback: StringName) -> StringName:
	var definition := _definition(skill_index)
	return definition.animation_name if definition != null and not definition.animation_name.is_empty() else fallback


func _skill_windup_animation(skill_index: int, fallback: StringName) -> StringName:
	var definition := _definition(skill_index)
	return definition.windup_animation_name if definition != null and not definition.windup_animation_name.is_empty() else fallback


func _skill_float(skill_index: int, property_name: StringName, fallback: float) -> float:
	var definition := _definition(skill_index)
	return float(definition.get(property_name)) if definition != null else fallback


func _rule_float(rule_id: StringName, fallback: float) -> float:
	return float(combat_database.get_rule(rule_id, fallback)) if combat_database != null else fallback


func _apply_asset_profile(effect: AnimatedSprite3D, audio: AudioStreamPlayer3D, effect_id: StringName, audio_id: StringName) -> void:
	var profile := combat_database.get_asset_profile(effect_id)
	if profile != null:
		var frames := load(profile.resource_file) as SpriteFrames
		if frames != null:
			effect.sprite_frames = frames
		effect.animation = profile.animation_name
		effect.scale = profile.scale
		effect.offset = profile.offset
		effect.pixel_size = profile.pixel_size
		effect.render_priority = profile.render_priority
		effect.no_depth_test = profile.no_depth_test
		if not profile.shader_material_path.is_empty():
			var material := load(profile.shader_material_path) as Material
			if material != null:
				effect.material_override = material.duplicate()
	var audio_profile := combat_database.get_asset_profile(audio_id)
	if audio_profile != null:
		var stream := load(audio_profile.audio_path) as AudioStream
		if stream != null:
			audio.stream = stream
		audio.volume_db = audio_profile.volume_db
		audio.max_distance = audio_profile.max_distance


func _apply_sprite_asset_profile(effect: AnimatedSprite3D, asset_id: StringName) -> void:
	if combat_database == null:
		return
	var profile := combat_database.get_asset_profile(asset_id)
	if profile == null:
		return
	var frames := load(profile.resource_file) as SpriteFrames
	if frames != null:
		effect.sprite_frames = frames
	effect.animation = profile.animation_name
	effect.position = profile.local_position
	effect.scale = profile.scale
	effect.offset = profile.offset
	effect.pixel_size = profile.pixel_size
	if effect.sprite_frames != null:
		var source_frame_rate := effect.sprite_frames.get_animation_speed(effect.animation)
		effect.speed_scale = passive_vfx_frame_rate / maxf(source_frame_rate, 0.01)
	effect.render_priority = profile.render_priority
	effect.no_depth_test = profile.no_depth_test
