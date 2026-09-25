class_name HeroHitFeedback3D
extends Node3D

## Receiver-side 3D hit read. Heroes retain their active state-machine pose;
## this supplies the spark, flesh impact sound, and a small decaying shake.

const HIT_SPARK_PARTICLES := preload("res://scripts/vfx/hit_spark_particles.gd")

@export var model_node_name: StringName
@export_range(0.04, 0.25, 0.01) var shake_duration := 0.11
@export_range(0.005, 0.12, 0.005) var shake_distance := 0.028

var combat_database: CombatDatabase
var hit_count := 0

var _model: Node3D
var _hit_particles: Node
var _hit_audio: AudioStreamPlayer3D
var _random := RandomNumberGenerator.new()
var _base_model_position := Vector3.ZERO
var _shake_elapsed := 0.0
var _shake_direction := 1.0


func configure(database: CombatDatabase, target_model_node_name: StringName) -> void:
	combat_database = database
	model_node_name = target_model_node_name
	_resolve_model()


func _ready() -> void:
	_random.randomize()
	_resolve_model()
	_ensure_effect_nodes()


func _exit_tree() -> void:
	_restore_model_position()


func _process(delta: float) -> void:
	if _shake_elapsed >= shake_duration:
		return
	_shake_elapsed = minf(_shake_elapsed + delta, shake_duration)
	var remaining := 1.0 - _shake_elapsed / maxf(shake_duration, 0.001)
	# Positional, rather than rotational, so this never fights 3D facing.
	var wave := sin(_shake_elapsed / maxf(shake_duration, 0.001) * TAU * 2.0)
	if _model != null:
		_model.position = _base_model_position + Vector3(wave * remaining * shake_distance * _shake_direction, 0.0, 0.0)
	if _shake_elapsed >= shake_duration:
		_restore_model_position()


func play_hit(attacker_position: Vector3, hit_profile_id: StringName, is_critical: bool = false) -> void:
	_resolve_model()
	_ensure_effect_nodes()
	var away := global_position - attacker_position
	away.y = 0.0
	if away.length_squared() <= 0.0001:
		away = Vector3.RIGHT
	else:
		away = away.normalized()
	var contact := global_position + Vector3.UP * 1.05 + away * 0.12
	if _hit_particles != null and _hit_particles.has_method(&"burst"):
		_hit_particles.call(&"burst", contact, away, is_critical, hit_profile_id)
	var hit_profile := combat_database.get_hit_profile(hit_profile_id) if combat_database != null else null
	if _hit_audio != null and hit_profile != null:
		CombatAudio.play_hit(_hit_audio, combat_database, hit_profile, &"flesh", is_critical, _random)
	_shake_elapsed = 0.0
	_shake_direction = -1.0 if away.x < 0.0 else 1.0
	hit_count += 1


func _resolve_model() -> void:
	var actor := get_parent() as CharacterBody3D
	if actor == null or model_node_name.is_empty():
		return
	var candidate := actor.get_node_or_null(NodePath(String(model_node_name))) as Node3D
	if candidate != _model:
		_restore_model_position()
		_model = candidate
		if _model != null:
			_base_model_position = _model.position


func _ensure_effect_nodes() -> void:
	if _hit_particles == null:
		_hit_particles = HIT_SPARK_PARTICLES.new()
		_hit_particles.name = "HitSparkParticles"
		add_child(_hit_particles)
	if _hit_audio == null:
		_hit_audio = AudioStreamPlayer3D.new()
		_hit_audio.name = "HitAudio"
		_hit_audio.max_distance = 20.0
		add_child(_hit_audio)


func _restore_model_position() -> void:
	if _model != null and is_instance_valid(_model):
		_model.position = _base_model_position
