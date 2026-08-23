extends Node3D

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
@export var breaker_silence_duration := 1.5
@export var breaker_cooldown := 6.0

@export_group("Skill 2 - 黑帆")
@export var black_sail_duration := 4.0
@export var black_sail_damage_reduction := 0.30
@export var black_sail_control_reduction := 0.30
@export var passive_resistance_bonus := 0.20
@export var black_sail_cooldown := 10.0

@export_group("Skill 3 - 翻江倒海")
@export var ocean_storm_duration := 3.0
@export var ocean_storm_tick := 0.5
@export var ocean_storm_radius := 2.6
@export var ocean_storm_damage := 48.0
@export var ocean_storm_cooldown := 8.0

@export_group("Skill 4 - 暴君审判")
@export var judgment_base_damage := 130.0
@export var judgment_missing_health_damage := 260.0
@export var judgment_cooldown := 11.0

@export_group("Skill 5 - 七海霸权")
@export var ghostship_damage := 180.0
@export var ghostship_radius := 3.0
@export var ghostship_stun_duration := 2.0
@export var rum_duration := 10.0
@export var seven_seas_cooldown := 18.0

@onready var fighter: CharacterBody3D = get_parent() as CharacterBody3D
@onready var character_frames: AnimatedSprite3D = fighter.get_node("CharacterFrames") as AnimatedSprite3D
@onready var jolly_roger: AnimatedSprite3D = $JollyRoger
@onready var ocean_storm: AnimatedSprite3D = $OceanStorm
@onready var anchor_effect: AnimatedSprite3D = $Anchor
@onready var ghostship: AnimatedSprite3D = $Ghostship
@onready var jolly_audio: AudioStreamPlayer3D = $JollyRogerAudio
@onready var ocean_audio: AudioStreamPlayer3D = $OceanStormAudio
@onready var anchor_audio: AudioStreamPlayer3D = $AnchorAudio
@onready var ghostship_audio: AudioStreamPlayer3D = $GhostshipAudio

var target: CharacterBody3D
var is_casting := false
var current_skill := 0
var breaker_timer := 0.0
var breaker_empowered_attack := false
var black_sail_timer := 0.0
var rum_timer := 0.0
var delayed_damage_pool := 0.0
var current_health := 1000.0
var max_health := 1000.0
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


func _ready() -> void:
	_apply_combat_data()
	for effect: AnimatedSprite3D in [jolly_roger, ocean_storm, anchor_effect, ghostship]:
		if effect.material_override != null:
			effect.material_override = effect.material_override.duplicate()
			if effect.material_override is ShaderMaterial:
				(effect.material_override as ShaderMaterial).set_shader_parameter(
					&"show_over_models", effect.no_depth_test
				)
		effect.visible = false
	anchor_effect.top_level = true
	ghostship.top_level = true


func _process(delta: float) -> void:
	_update_timers(delta)
	_update_rum_damage(delta)
	_sync_vfx_frame_textures()
	if anchor_effect.visible and is_instance_valid(target):
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
	if is_casting or skill_index < SKILL_BREAKER or skill_index > SKILL_SEVEN_SEAS:
		return false
	if cooldowns[skill_index] > 0.0 or not is_instance_valid(skill_target):
		return false
	target = skill_target
	is_casting = true
	current_skill = skill_index
	cast_counts[skill_index] += 1
	cooldowns[skill_index] = _get_cooldown(skill_index)
	_cast_skill_async(skill_index)
	return true


func try_begin_demo_skill() -> bool:
	if not automatic_demo or is_casting or demo_timer > 0.0 or not is_instance_valid(target):
		return false
	if cooldowns[next_demo_skill] > 0.0 or not _skill_in_range(next_demo_skill):
		return false
	var started := begin_skill(next_demo_skill, target)
	if started:
		next_demo_skill = next_demo_skill % SKILL_SEVEN_SEAS + 1
	return started


func get_move_speed_multiplier() -> float:
	var multiplier := slow_multiplier
	if breaker_timer > 0.0:
		multiplier *= 1.0 + breaker_speed_bonus
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


func should_use_breaker_attack() -> bool:
	return breaker_empowered_attack and breaker_timer > 0.0


func resolve_breaker_attack(skill_target: CharacterBody3D) -> void:
	if not should_use_breaker_attack():
		return
	breaker_empowered_attack = false
	if skill_target.has_method("receive_skill_damage"):
		skill_target.call("receive_skill_damage", breaker_damage, "破舰", true, fighter.global_position, &"physical", &"breaker_hit")
	if skill_target.has_method("apply_silence"):
		skill_target.call("apply_silence", breaker_silence_duration)
	damage_event_count += 1


func receive_incoming_damage(amount: float) -> void:
	var resolved := amount
	if black_sail_timer > 0.0:
		var reduction_cap := float(combat_database.get_rule(&"damage.reduction_cap", 0.90)) if combat_database != null else 0.90
		resolved *= 1.0 - clampf(black_sail_damage_reduction, 0.0, reduction_cap)
	if rum_timer > 0.0:
		delayed_damage_pool += resolved
	else:
		current_health = maxf(0.0, current_health - resolved)


func get_control_duration_multiplier() -> float:
	return 1.0 - black_sail_control_reduction if black_sail_timer > 0.0 else 1.0


func get_passive_armor_multiplier() -> float:
	return 1.0 + passive_resistance_bonus


func activate_black_sail_defenses() -> void:
	black_sail_timer = black_sail_duration
	if rum_timer > 0.0:
		delayed_damage_pool *= 1.0 - black_sail_rum_cleanse_ratio


func calculate_judgment_damage(target_health_ratio: float) -> float:
	return judgment_base_damage + judgment_missing_health_damage * (1.0 - clampf(target_health_ratio, 0.0, 1.0))


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
	character_frames.play(_skill_windup_animation(SKILL_BREAKER, &"channel_wndup"))
	await get_tree().create_timer(_skill_float(SKILL_BREAKER, "cast_time", 0.16)).timeout


func _cast_black_sail() -> void:
	character_frames.animation = _skill_windup_animation(SKILL_BLACK_SAIL, &"channel_wndup")
	character_frames.frame = 0
	character_frames.pause()
	await get_tree().create_timer(_skill_float(SKILL_BLACK_SAIL, "cast_time", 0.16)).timeout
	character_frames.animation = _skill_animation(SKILL_BLACK_SAIL, &"channel")
	character_frames.frame = 0
	character_frames.pause()
	jolly_roger.visible = true
	jolly_roger.play(jolly_roger.animation)
	jolly_audio.play()
	activate_black_sail_defenses()
	await get_tree().create_timer(_skill_float(SKILL_BLACK_SAIL, "recovery_time", 0.24)).timeout


func _cast_ocean_storm() -> void:
	var animation := _skill_animation(SKILL_OCEAN_STORM, &"spell3")
	character_frames.play(animation)
	ocean_storm.visible = true
	ocean_storm.play(ocean_storm.animation)
	ocean_audio.play()
	var elapsed := 0.0
	while elapsed < ocean_storm_duration:
		await get_tree().create_timer(ocean_storm_tick).timeout
		elapsed += ocean_storm_tick
		if not character_frames.is_playing():
			character_frames.play(animation)
		if is_instance_valid(target) and fighter.global_position.distance_to(target.global_position) <= ocean_storm_radius:
			if target.has_method("receive_skill_damage"):
				target.call("receive_skill_damage", ocean_storm_damage, "翻江倒海", true, fighter.global_position, &"physical", &"ocean_hit")
			damage_event_count += 1
	ocean_storm.visible = false
	ocean_storm.stop()
	ocean_audio.stop()


func _cast_tyrant_judgment() -> void:
	character_frames.play(_skill_animation(SKILL_TYRANT_JUDGMENT, &"spell4"))
	anchor_effect.global_position = target.global_position
	anchor_effect.visible = true
	anchor_effect.play(anchor_effect.animation)
	anchor_audio.play()
	await get_tree().create_timer(_skill_float(SKILL_TYRANT_JUDGMENT, "cast_time", 0.28)).timeout
	if is_instance_valid(target) and target.has_method("receive_skill_damage"):
		var missing_ratio := 0.0
		if target.has_method("get_health_ratio"):
			missing_ratio = 1.0 - float(target.call("get_health_ratio"))
		var damage := calculate_judgment_damage(1.0 - missing_ratio)
		target.call("receive_skill_damage", damage, "暴君审判", false, fighter.global_position, &"magic", &"judgment_hit")
		damage_event_count += 1
	await get_tree().create_timer(_skill_float(SKILL_TYRANT_JUDGMENT, "recovery_time", 0.35)).timeout
	anchor_effect.visible = false
	anchor_effect.stop()
	anchor_audio.stop()


func _cast_seven_seas() -> void:
	character_frames.play(_skill_animation(SKILL_SEVEN_SEAS, &"taunt"))
	# This is a ground-targeted area skill. The AI chooses the target's position
	# at cast time, but the area does not continue tracking that character.
	var area_center := target.global_position if is_instance_valid(target) else fighter.global_position
	prepare_ghostship_direction(area_center)
	ghostship.visible = true
	ghostship.play(ghostship.animation)
	ghostship_audio.play()
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var impact_time := _skill_float(SKILL_SEVEN_SEAS, "cast_time", 1.05)
	var seven_seas := _definition(SKILL_SEVEN_SEAS)
	var travel_duration := seven_seas.travel_duration if seven_seas != null else impact_time + 0.1
	travel.tween_property(ghostship, "global_position", area_center, travel_duration)
	await get_tree().create_timer(impact_time).timeout
	if is_instance_valid(target) and area_center.distance_to(target.global_position) <= ghostship_radius:
		if target.has_method("receive_skill_damage"):
			target.call("receive_skill_damage", ghostship_damage, "七海霸权", false, fighter.global_position, &"physical", &"ghostship_hit")
		if target.has_method("apply_stun"):
			target.call("apply_stun", ghostship_stun_duration)
		damage_event_count += 1
	rum_timer = rum_duration
	await get_tree().create_timer(_skill_float(SKILL_SEVEN_SEAS, "recovery_time", 0.65)).timeout
	ghostship.visible = false
	ghostship.stop()
	ghostship_audio.stop()


func _update_timers(delta: float) -> void:
	for index: int in range(SKILL_BREAKER, SKILL_SEVEN_SEAS + 1):
		cooldowns[index] = maxf(0.0, cooldowns[index] - delta)
	breaker_timer = maxf(0.0, breaker_timer - delta)
	if breaker_timer <= 0.0:
		breaker_empowered_attack = false
	var had_black_sail := black_sail_timer > 0.0
	black_sail_timer = maxf(0.0, black_sail_timer - delta)
	jolly_roger.visible = black_sail_timer > 0.0
	if had_black_sail and black_sail_timer <= 0.0:
		jolly_roger.visible = false
		jolly_roger.stop()
		jolly_audio.stop()
	rum_timer = maxf(0.0, rum_timer - delta)


func _update_rum_damage(delta: float) -> void:
	if rum_timer <= 0.0 or delayed_damage_pool <= 0.0:
		return
	var applied := minf(delayed_damage_pool, delayed_damage_pool * delta / maxf(rum_timer, delta))
	delayed_damage_pool -= applied
	current_health = maxf(1.0, current_health - applied)


func _sync_vfx_frame_textures() -> void:
	for effect: AnimatedSprite3D in [jolly_roger, ocean_storm, anchor_effect, ghostship]:
		if not effect.visible or effect.material_override == null:
			continue
		var material := effect.material_override as ShaderMaterial
		if material == null or effect.sprite_frames == null:
			continue
		var frame_texture := effect.sprite_frames.get_frame_texture(effect.animation, effect.frame)
		if frame_texture != null:
			material.set_shader_parameter(&"frame_texture", frame_texture)
			material.set_shader_parameter(&"frame_uv_rect", _frame_uv_rect(frame_texture))


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
		var ai := combat_database.get_ai_profile(garen_definition.ai_profile_id)
		if ai != null:
			demo_gap = ai.demo_skill_gap
	for slot: int in range(SKILL_BREAKER, SKILL_SEVEN_SEAS + 1):
		skill_definitions[slot] = combat_database.get_skill_by_slot(&"garen", slot)

	var breaker := _definition(SKILL_BREAKER)
	var breaker_buff := combat_database.get_buff(&"breaker_speed")
	var breaker_damage_effect := _effect(&"breaker_damage")
	var breaker_silence_effect := _effect(&"breaker_silence")
	breaker_duration = breaker_buff.duration if breaker_buff != null else breaker_duration
	breaker_speed_bonus = _modifier_value(&"breaker_speed", &"move_speed", breaker_speed_bonus)
	breaker_damage = breaker_damage_effect.base_value if breaker_damage_effect != null else breaker_damage
	breaker_silence_duration = breaker_silence_effect.control_duration if breaker_silence_effect != null else breaker_silence_duration
	breaker_cooldown = breaker.cooldown if breaker != null else breaker_cooldown

	var black_sail := _definition(SKILL_BLACK_SAIL)
	var black_sail_buff := combat_database.get_buff(&"black_sail")
	black_sail_duration = black_sail_buff.duration if black_sail_buff != null else black_sail_duration
	black_sail_damage_reduction = 1.0 - _modifier_value(&"black_sail", &"damage_taken", 1.0 - black_sail_damage_reduction)
	black_sail_control_reduction = 1.0 - _modifier_value(&"black_sail", &"control_duration", 1.0 - black_sail_control_reduction)
	passive_resistance_bonus = _modifier_value(&"black_sail_passive", &"armor", passive_resistance_bonus)
	var rum_cleanse_effect := _effect(&"black_sail_rum_cleanse")
	black_sail_rum_cleanse_ratio = rum_cleanse_effect.base_value if rum_cleanse_effect != null else black_sail_rum_cleanse_ratio
	black_sail_cooldown = black_sail.cooldown if black_sail != null else black_sail_cooldown

	var ocean := _definition(SKILL_OCEAN_STORM)
	var ocean_effect := _effect(&"ocean_damage")
	if ocean != null:
		ocean_storm_duration = ocean.duration
		ocean_storm_tick = ocean.tick_interval
		ocean_storm_radius = ocean.radius
		ocean_storm_cooldown = ocean.cooldown
	ocean_storm_damage = ocean_effect.base_value if ocean_effect != null else ocean_storm_damage

	var judgment := _definition(SKILL_TYRANT_JUDGMENT)
	var judgment_effect := _effect(&"judgment_damage")
	judgment_cooldown = judgment.cooldown if judgment != null else judgment_cooldown
	if judgment_effect != null:
		judgment_base_damage = judgment_effect.base_value
		judgment_missing_health_damage = judgment_effect.target_missing_health_coefficient

	var seven_seas := _definition(SKILL_SEVEN_SEAS)
	var seven_damage := _effect(&"seven_seas_damage")
	var seven_stun := _effect(&"seven_seas_stun")
	var rum_buff := combat_database.get_buff(&"seven_seas_rum")
	if seven_seas != null:
		ghostship_radius = seven_seas.radius
		seven_seas_cooldown = seven_seas.cooldown
	ghostship_damage = seven_damage.base_value if seven_damage != null else ghostship_damage
	ghostship_stun_duration = seven_stun.control_duration if seven_stun != null else ghostship_stun_duration
	rum_duration = rum_buff.duration if rum_buff != null else rum_duration

	_apply_asset_profile(jolly_roger, jolly_audio, &"jolly_roger", &"jolly_roger_audio")
	_apply_asset_profile(ocean_storm, ocean_audio, &"ocean_storm", &"ocean_storm_audio")
	_apply_asset_profile(anchor_effect, anchor_audio, &"anchor", &"anchor_audio")
	_apply_asset_profile(ghostship, ghostship_audio, &"ghostship", &"ghostship_audio")


func _definition(skill_index: int) -> SkillDefinition:
	return skill_definitions.get(skill_index) as SkillDefinition


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
