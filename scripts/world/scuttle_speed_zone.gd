extends Area3D

@export var duration := 10.0
@export var move_speed_multiplier := 1.30
@export var radius := 2.6
@export var fade_in_duration := 0.45
@export var breathing_period := 5.0
@export var rotation_period := 8.0
@export var maximum_scale := 1.0
@export var minimum_scale := 0.8
@export_range(0.0, 1.0, 0.01) var maximum_opacity := 0.60
@export_range(0.0, 1.0, 0.01) var minimum_opacity := 0.30
@export var intro_duration := 0.72
@export var particle_intro_speed := 2.4
@export var particle_active_speed := 0.65
@export var loot_environment_horizontal_scale := 9.3
@onready var shrine: MeshInstance3D = $TintedDisc
@onready var intro: AnimatedSprite3D = $ActivationSequence
@onready var intro_audio: AudioStreamPlayer3D = $ActivationAudio
@onready var orbit_motes: GPUParticles3D = $GreenOrbitMotes
@onready var loot_environment_overlay: Node3D = $LootEnvironmentOverlay
@onready var collision: CollisionShape3D = $Collision
var owner_team: StringName = &"friendly"
var remaining := 10.0
var affected: Array[Node3D] = []
var breathing_elapsed := 0.0
var fade_elapsed := 0.0
var shrine_material: ShaderMaterial
var combat_database: CombatDatabase
var zone_active := false

func _ready() -> void:
	_apply_combat_data()
	remaining = duration
	shrine_material = shrine.material_override as ShaderMaterial
	if shrine_material == null and shrine.mesh != null:
		shrine_material = shrine.mesh.material as ShaderMaterial
	if shrine_material != null:
		shrine_material = shrine_material.duplicate() as ShaderMaterial
		shrine.material_override = shrine_material
		shrine_material.set_shader_parameter(&"opacity", 0.0)
	_configure_particles()
	collision.disabled = true
	intro.visible = true
	intro.speed_scale = 0.72 / maxf(intro_duration, 0.01)
	intro.play(&"activate")
	intro_audio.play()
	loot_environment_overlay.visible = false
	orbit_motes.speed_scale = particle_intro_speed
	orbit_motes.emitting = true
	orbit_motes.restart()
	intro.animation_finished.connect(_activate_zone)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func configure(killer_team: StringName) -> void:
	owner_team = killer_team

func _apply_combat_data() -> void:
	combat_database = CombatData.database()
	if combat_database == null:
		return
	var buff := combat_database.get_buff(&"scuttle_speed_zone")
	if buff != null:
		duration = buff.duration
	var modifier := combat_database.get_buff_modifier(&"scuttle_speed_zone", &"move_speed")
	if modifier != null:
		move_speed_multiplier = 1.0 + modifier.value if modifier.operation == "add_percent" else modifier.value
	radius = _rule_float(&"scuttle.speed_zone_radius", radius)
	fade_in_duration = _rule_float(&"scuttle.speed_zone_fade_in", fade_in_duration)
	breathing_period = _rule_float(&"scuttle.speed_zone_breath_period", breathing_period)
	rotation_period = _rule_float(&"scuttle.speed_zone_rotation_period", rotation_period)
	maximum_scale = _rule_float(&"scuttle.speed_zone_scale_max", maximum_scale)
	minimum_scale = _rule_float(&"scuttle.speed_zone_scale_min", minimum_scale)
	maximum_opacity = _rule_float(&"scuttle.speed_zone_opacity_max", maximum_opacity)
	minimum_opacity = _rule_float(&"scuttle.speed_zone_opacity_min", minimum_opacity)
	intro_duration = _rule_float(&"scuttle.speed_zone_intro_duration", intro_duration)
	particle_intro_speed = _rule_float(&"scuttle.speed_zone_particle_intro_speed", particle_intro_speed)
	particle_active_speed = _rule_float(&"scuttle.speed_zone_particle_active_speed", particle_active_speed)
	loot_environment_horizontal_scale = _rule_float(&"scuttle.speed_zone_overlay_horizontal_scale", loot_environment_horizontal_scale)
	loot_environment_overlay.scale = Vector3(loot_environment_horizontal_scale, 1.0, loot_environment_horizontal_scale)

func _configure_particles() -> void:
	var material := orbit_motes.process_material as ParticleProcessMaterial
	if material == null:
		return
	material = material.duplicate() as ParticleProcessMaterial
	orbit_motes.process_material = material
	material.emission_ring_radius = _rule_float(&"scuttle.speed_zone_particle_ring_radius", material.emission_ring_radius)
	material.emission_ring_inner_radius = _rule_float(&"scuttle.speed_zone_particle_ring_inner_radius", material.emission_ring_inner_radius)
	var orbit_speed := _rule_float(&"scuttle.speed_zone_particle_orbit_speed", material.orbit_velocity_min)
	material.orbit_velocity_min = orbit_speed
	material.orbit_velocity_max = orbit_speed + 0.10
	var profile := combat_database.get_particle_profile(&"scuttle_speed_zone_motes") if combat_database != null else null
	if profile == null:
		return
	orbit_motes.amount = profile.amount
	orbit_motes.lifetime = profile.lifetime
	orbit_motes.randomness = profile.randomness
	material.spread = profile.spread
	material.gravity = profile.gravity
	material.initial_velocity_min = profile.velocity_min
	material.initial_velocity_max = profile.velocity_max
	material.angular_velocity_min = profile.angular_velocity_min
	material.angular_velocity_max = profile.angular_velocity_max
	material.scale_min = profile.scale_min
	material.scale_max = profile.scale_max

func _activate_zone() -> void:
	if zone_active:
		return
	zone_active = true
	intro.visible = false
	loot_environment_overlay.visible = true
	if loot_environment_overlay.has_method(&"restart_vfx"):
		loot_environment_overlay.call(&"restart_vfx")
	remaining = duration
	fade_elapsed = 0.0
	collision.set_deferred(&"disabled", false)
	orbit_motes.speed_scale = particle_active_speed

func _rule_float(rule_id: StringName, fallback: float) -> float:
	return float(combat_database.get_rule(rule_id, fallback)) if combat_database != null else fallback

func _physics_process(delta: float) -> void:
	if not zone_active:
		return
	remaining -= delta
	_update_shrine_visual(delta)
	for node: Node in get_tree().get_nodes_in_group(&"hero_actor"):
		var hero := node as Node3D
		if hero == null:
			continue
		var offset := hero.global_position - global_position
		offset.y = 0.0
		if offset.length() <= radius:
			_apply(hero)
		else:
			_clear(hero)
	if remaining <= 0.0:
		for hero: Node3D in affected.duplicate():
			_clear(hero)
		queue_free()

func _update_shrine_visual(delta: float) -> void:
	breathing_elapsed = fmod(breathing_elapsed + delta, maxf(breathing_period, 0.001))
	shrine.rotation.y = fmod(shrine.rotation.y + TAU * delta / maxf(rotation_period, 0.001), TAU)
	fade_elapsed = minf(fade_in_duration, fade_elapsed + delta)
	var phase := breathing_elapsed / maxf(breathing_period, 0.001)
	var linear_pulse := phase * 2.0 if phase <= 0.5 else (1.0 - phase) * 2.0
	var visual_scale := lerpf(maximum_scale, minimum_scale, linear_pulse)
	shrine.scale = Vector3(visual_scale, 1.0, visual_scale)
	var breathing_opacity := lerpf(maximum_opacity, minimum_opacity, linear_pulse)
	var fade_weight := clampf(fade_elapsed / maxf(fade_in_duration, 0.001), 0.0, 1.0)
	if shrine_material != null:
		shrine_material.set_shader_parameter(&"opacity", breathing_opacity * fade_weight)

func _on_body_entered(body: Node3D) -> void:
	_apply(body)

func _on_body_exited(body: Node3D) -> void:
	_clear(body)

func _apply(body: Node3D) -> void:
	if not body.is_in_group(&"hero_actor"):
		return
	if body.has_method("get_team") and StringName(body.call("get_team")) != owner_team:
		return
	if body.has_method("set_external_move_speed_modifier"):
		body.call("set_external_move_speed_modifier", &"scuttle_zone", move_speed_multiplier)
		if not affected.has(body):
			affected.append(body)

func _clear(body: Node3D) -> void:
	if not affected.has(body):
		return
	if is_instance_valid(body) and body.has_method("clear_external_move_speed_modifier"):
		body.call("clear_external_move_speed_modifier", &"scuttle_zone")
	affected.erase(body)
