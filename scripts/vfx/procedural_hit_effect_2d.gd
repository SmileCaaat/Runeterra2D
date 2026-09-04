class_name ProceduralHitEffect2D
extends Node2D

const HIT_TEXTURES := preload("res://scripts/vfx/procedural_hit_textures.gd")
const SHOCKWAVE_SCRIPT := preload("res://scripts/vfx/procedural_shockwave_2d.gd")
const COMBO_RING_SCENE := preload("res://addons/vfx_library/effects/combo_ring.tscn")
const WATER_SPLASH_SCENE := preload("res://addons/vfx_library/effects/water_splash.tscn")

var profile: Variant
var flash: Sprite2D
var shockwave: Node2D
var burst_particles: GPUParticles2D
var spark_particles: GPUParticles2D
var dust_particles: GPUParticles2D
var debris_particles: GPUParticles2D
var combo_ring: CPUParticles2D
var water_splash: CPUParticles2D
var flash_elapsed := 0.0
var flash_active := false


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	flash = Sprite2D.new()
	flash.texture = HIT_TEXTURES.soft_circle()
	flash.material = additive
	flash.visible = false
	add_child(flash)

	burst_particles = _make_emitter(HIT_TEXTURES.soft_circle(), additive)
	spark_particles = _make_emitter(HIT_TEXTURES.spark_strip(), additive)
	dust_particles = _make_emitter(HIT_TEXTURES.soft_circle(), additive)
	debris_particles = _make_emitter(HIT_TEXTURES.debris_square(), additive)
	combo_ring = COMBO_RING_SCENE.instantiate() as CPUParticles2D
	combo_ring.name = "LibraryComboRing"
	combo_ring.position = Vector2.ZERO
	combo_ring.emitting = false
	add_child(combo_ring)
	water_splash = WATER_SPLASH_SCENE.instantiate() as CPUParticles2D
	water_splash.name = "LibraryWaterSplash"
	water_splash.position = Vector2.ZERO
	water_splash.emitting = false
	add_child(water_splash)

	shockwave = SHOCKWAVE_SCRIPT.new() as Node2D
	shockwave.material = additive
	shockwave.visible = false
	add_child(shockwave)


func play(effect_profile: Variant, attack_direction: Vector2) -> void:
	profile = effect_profile
	var direction := attack_direction.normalized() if not attack_direction.is_zero_approx() else Vector2.RIGHT

	_configure_emitter(burst_particles, profile.burst_amount, profile.duration * 0.72, 180.0,
		profile.burst_speed, Vector2.ZERO, profile.burst_scale, 0.0)
	_configure_emitter(spark_particles, profile.spark_amount, profile.duration * 0.66, profile.spark_spread,
		profile.spark_speed, Vector2.ZERO, profile.spark_scale, 0.0)
	_configure_emitter(dust_particles, profile.dust_amount, profile.duration, 58.0,
		profile.dust_speed, Vector2(0.0, profile.dust_gravity), Vector2(0.65, 1.45), -90.0)
	_configure_emitter(debris_particles, profile.debris_amount, profile.duration, 135.0,
		profile.debris_speed, Vector2(0.0, profile.debris_gravity), Vector2(0.45, 0.9), 0.0)

	spark_particles.rotation = direction.angle()
	burst_particles.rotation = direction.angle()
	debris_particles.rotation = direction.angle()
	for emitter: GPUParticles2D in [burst_particles, spark_particles, dust_particles, debris_particles]:
		emitter.restart()
		emitter.emitting = true

	flash.modulate = profile.core_color
	flash.scale = Vector2.ONE * 0.18
	flash.visible = true
	flash_elapsed = 0.0
	flash_active = true
	shockwave.play(profile)
	_play_library_overlay(StringName(profile.id))


func _process(delta: float) -> void:
	if not flash_active or profile == null:
		return
	flash_elapsed += delta
	var t := clampf(flash_elapsed / maxf(profile.flash_duration, 0.01), 0.0, 1.0)
	var punch := sin(t * PI) * 0.22
	flash.scale = Vector2.ONE * lerpf(0.18, profile.flash_scale, sqrt(t)) * (1.0 + punch)
	flash.modulate.a = pow(1.0 - t, 1.8)
	if t >= 1.0:
		flash_active = false
		flash.visible = false


func _make_emitter(texture: Texture2D, canvas_material: CanvasItemMaterial) -> GPUParticles2D:
	var emitter := GPUParticles2D.new()
	emitter.texture = texture
	emitter.material = canvas_material
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.randomness = 0.35
	emitter.emitting = false
	add_child(emitter)
	return emitter


func _play_library_overlay(profile_id: StringName) -> void:
	if profile_id in [&"slash", &"heavy", &"critical"]:
		combo_ring.amount = int(_library_rule(&"presentation.library_combo_ring_amount", combo_ring.amount))
		combo_ring.lifetime = _library_rule(&"presentation.library_combo_ring_lifetime", combo_ring.lifetime)
		combo_ring.scale = Vector2.ONE * _library_rule(&"presentation.library_combo_ring_scale", 1.0)
		combo_ring.restart()
		combo_ring.emitting = true
	if profile_id in [&"true_damage", &"magic"]:
		water_splash.amount = int(_library_rule(&"presentation.library_water_splash_amount", water_splash.amount))
		water_splash.lifetime = _library_rule(&"presentation.library_water_splash_lifetime", water_splash.lifetime)
		water_splash.scale = Vector2.ONE * _library_rule(&"presentation.library_water_splash_scale", 1.0)
		water_splash.restart()
		water_splash.emitting = true


func _library_rule(rule_id: StringName, fallback: float) -> float:
	var database := CombatData.database()
	return float(database.get_rule(rule_id, fallback)) if database != null else fallback


func _configure_emitter(
	emitter: GPUParticles2D,
	amount: int,
	lifetime: float,
	spread: float,
	speed: Vector2,
	gravity: Vector2,
	scale_range: Vector2,
	direction_degrees: float
) -> void:
	emitter.amount = maxi(amount, 1)
	emitter.lifetime = maxf(lifetime, 0.05)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(cos(deg_to_rad(direction_degrees)), sin(deg_to_rad(direction_degrees)), 0.0)
	material.spread = spread
	material.initial_velocity_min = speed.x
	material.initial_velocity_max = speed.y
	material.gravity = Vector3(gravity.x, gravity.y, 0.0)
	material.scale_min = scale_range.x
	material.scale_max = scale_range.y
	material.angular_velocity_min = -420.0
	material.angular_velocity_max = 420.0
	material.color_ramp = _color_ramp(profile.core_color, profile.hot_color, profile.fade_color)
	material.scale_curve = _scale_curve()
	emitter.process_material = material


func _color_ramp(start: Color, middle: Color, finish: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.72, 1.0])
	gradient.colors = PackedColorArray([start, start, middle, finish])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.25
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.10, 1.15))
	curve.add_point(Vector2(0.58, 0.82))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
