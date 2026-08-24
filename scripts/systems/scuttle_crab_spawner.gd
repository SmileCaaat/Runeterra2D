extends Node3D

@export_enum("training", "pvp", "pve", "disabled") var scene_mode := "training"
@export var enabled_modes := PackedStringArray(["training", "pvp"])
@export var first_spawn_delay := 25.0
@export var respawn_delay := 25.0
@export var path_local_points := PackedVector3Array([Vector3(-4.5, 0, 0), Vector3(0, 0, -1.8), Vector3(4.5, 0, 0), Vector3(0, 0, 1.8)])
@export var crab_scene: PackedScene
@export var speed_zone_scene: PackedScene

var spawn_timer := 25.0
var active_crab: CharacterBody3D
var first_spawn_done := false
var respawn_counting := false
var combat_database: CombatDatabase

func _ready() -> void:
	combat_database = CombatData.database()
	if combat_database != null:
		first_spawn_delay = float(combat_database.get_rule(&"scuttle.first_spawn_delay", first_spawn_delay))
		respawn_delay = float(combat_database.get_rule(&"scuttle.respawn_delay", respawn_delay))
	spawn_timer = first_spawn_delay

func _process(delta: float) -> void:
	if not enabled_modes.has(scene_mode): return
	if respawn_counting or not first_spawn_done:
		spawn_timer -= delta
	if is_instance_valid(active_crab): return
	if spawn_timer <= 0.0: _spawn_crab()

func _spawn_crab() -> void:
	if crab_scene == null: return
	active_crab = crab_scene.instantiate() as CharacterBody3D
	active_crab.set("level", _average_hero_level())
	active_crab.set("first_spawn_form", not first_spawn_done)
	get_parent().add_child(active_crab)
	active_crab.global_position = global_position
	var route := PackedVector3Array()
	for point: Vector3 in path_local_points: route.append(global_position + point)
	active_crab.call("configure_route", route, global_position)
	active_crab.connect("defeated", _on_crab_defeated)
	active_crab.connect("return_completed", _on_crab_return_completed)
	first_spawn_done = true
	respawn_counting = false

func _on_crab_defeated(_killer_team: StringName) -> void:
	spawn_timer = respawn_delay
	respawn_counting = true

func _on_crab_return_completed(killer_team: StringName) -> void:
	active_crab = null
	if speed_zone_scene != null:
		var zone := speed_zone_scene.instantiate() as Area3D
		get_parent().add_child(zone)
		zone.global_position = global_position + Vector3.UP * 0.025
		zone.call("configure", killer_team)

func _average_hero_level() -> int:
	var total := 0
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(&"hero_actor"):
		var hero_level: Variant = node.get("level")
		total += int(hero_level) if hero_level != null else 1
		count += 1
	return maxi(1, roundi(float(total) / maxf(count, 1)))
