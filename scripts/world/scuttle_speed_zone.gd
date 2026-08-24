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
@onready var shrine: MeshInstance3D = $TintedDisc
var owner_team: StringName = &"friendly"
var remaining := 10.0
var affected: Array[Node3D] = []
var breathing_elapsed := 0.0
var fade_elapsed := 0.0
var shrine_material: ShaderMaterial
var combat_database: CombatDatabase

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

func _rule_float(rule_id: StringName, fallback: float) -> float:
	return float(combat_database.get_rule(rule_id, fallback)) if combat_database != null else fallback

func _physics_process(delta: float) -> void:
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
