extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var scene := load("res://DNF_Style_Prototype.tscn") as PackedScene
	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	var spawner := root.get_node("Characters/ScuttleCrabSpawner")
	spawner.set("spawn_timer", 0.0)
	spawner.call("_process", 0.01)
	await process_frame
	var crab := spawner.get("active_crab") as CharacterBody3D
	_assert(crab != null, "crab should spawn")
	_assert(crab.is_in_group(&"neutral_actor"), "crab should be neutral")
	_assert(crab.is_in_group(&"combat_target"), "crab should be targetable")
	_assert(is_equal_approx(float(crab.get("calm_move_speed")), 1.55), "calm speed")
	_assert(is_equal_approx(float(crab.get("combat_move_speed")), 2.55), "combat speed")
	_assert(is_equal_approx(float(crab.get("dash_move_speed")), 7.5), "dash speed comes from unit stats")
	_assert(is_equal_approx(float(crab.get("flee_duration")), 3.0), "flee duration comes from combat rules")
	var route: PackedVector3Array = crab.get("path_points")
	var segment_midpoint := route[0].lerp(route[1], 0.5)
	crab.global_position = segment_midpoint
	var projected_point: Vector3 = crab.call("_nearest_path_point")
	_assert(Vector2(projected_point.x - segment_midpoint.x, projected_point.z - segment_midpoint.z).length() < 0.001, "path deviation uses segments instead of vertices")
	crab.global_position = Vector3(12.0, 0.0, 3.0)
	crab.call("_physics_process", 0.05)
	var return_velocity: Vector3 = crab.velocity
	var expected_return: Vector3 = (Vector3(spawner.global_position) - crab.global_position).normalized()
	_assert(Vector2(return_velocity.x, return_velocity.z).dot(Vector2(expected_return.x, expected_return.z)) > 0.0, "off-path dash returns to navigation origin")
	_assert(bool(crab.get("returning_to_navigation_origin")), "navigation return is latched")
	crab.call("_trigger_flee", Vector3(20.0, 0.0, 3.0))
	_assert(is_zero_approx(float(crab.get("flee_timer"))), "damage cannot restart flee during latched return")
	crab.global_position = spawner.global_position
	crab.call("_physics_process", 0.05)
	_assert(not bool(crab.get("returning_to_navigation_origin")), "return latch clears only at navigation origin")
	var death_start := Vector3(spawner.global_position) + Vector3(5.0, 0.0, 2.0)
	crab.global_position = death_start
	var death_arrival_positions: Array[Vector3] = []
	crab.return_completed.connect(
		func(_team: StringName) -> void: death_arrival_positions.append(crab.global_position)
	)
	var readability := crab.get_node("UnitReadability")
	_assert(not (crab.get_node("Frames") as AnimatedSprite3D).no_depth_test, "unit body respects ground depth")
	_assert(not readability.has_node("MaskOutline") and not readability.has_node("OutlineGlow"), "neutral unit has no faction outline")
	crab.call("register_damage_source", Vector3(-3, 0, 0), &"friendly")
	crab.call("receive_skill_damage", 999999.0, "TEST", false, Vector3(-3, 0, 0), &"physical", &"basic_melee")
	_assert(not crab.is_in_group(&"combat_target"), "dead crab exits targeting immediately")
	_assert(Vector3(crab.get("spawn_position")).is_equal_approx(Vector3(spawner.global_position)), "death return anchor is the concrete spawn point")
	await create_timer(1.5).timeout
	_assert(death_arrival_positions.size() == 1, "death return completes from an off-center death position")
	_assert(Vector2(
		death_arrival_positions[0].x - spawner.global_position.x,
		death_arrival_positions[0].z - spawner.global_position.z,
	).length() <= 0.001, "dead crab reaches the scene-center spawn point before dissolving")
	var zones := get_nodes_in_group(&"scuttle_speed_zone")
	var zone: Area3D
	if zones.is_empty():
		zone = root.get_node_or_null("Characters/ScuttleSpeedZone") as Area3D
	else:
		zone = zones[0] as Area3D
	_assert(zone != null, "speed zone should appear after return and dissolve")
	var intro := zone.get_node("ActivationSequence") as AnimatedSprite3D
	var intro_audio := zone.get_node("ActivationAudio") as AudioStreamPlayer3D
	var motes := zone.get_node("GreenOrbitMotes") as GPUParticles3D
	_assert(intro.visible and intro.animation == &"activate", "speed shrine intro plays flat on the ground before activation")
	_assert(intro_audio.stream.resource_path.ends_with("Holy Missile.wav"), "speed shrine intro uses Holy Missile audio")
	_assert(motes.emitting and is_equal_approx(motes.speed_scale, 2.4), "green ring particles run fast during intro")
	await create_timer(0.5).timeout
	_assert(bool(zone.get("zone_active")), "speed zone activates after the six-frame intro")
	_assert(not intro.visible, "intro sequence hides when the persistent shrine appears")
	_assert(is_equal_approx(motes.speed_scale, 0.65), "green ring particles slow down after activation")
	_assert(not (zone.get_node("Collision") as CollisionShape3D).disabled, "speed zone collision enables only after intro")
	zone.set("breathing_elapsed", 0.0)
	zone.set("fade_elapsed", float(zone.get("fade_in_duration")))
	zone.call("_update_shrine_visual", 0.0)
	var shrine := zone.get_node("TintedDisc") as MeshInstance3D
	var shrine_material := shrine.material_override as ShaderMaterial
	_assert(is_equal_approx(shrine.scale.x, 1.0), "shrine starts breathing at 100 percent scale")
	_assert(is_equal_approx(float(shrine_material.get_shader_parameter(&"opacity")), 0.60), "shrine opacity is 60 percent at full scale")
	zone.set("breathing_elapsed", 2.5)
	zone.call("_update_shrine_visual", 0.0)
	_assert(is_equal_approx(shrine.scale.x, 0.8), "shrine reaches 80 percent scale at half cycle")
	_assert(is_equal_approx(float(shrine_material.get_shader_parameter(&"opacity")), 0.30), "shrine opacity is 30 percent at minimum scale")
	var rotation_before := shrine.rotation.y
	zone.call("_update_shrine_visual", 0.25)
	_assert(not is_equal_approx(shrine.rotation.y, rotation_before), "speed shrine rotates continuously")
	var player := root.get_node("Characters/Player") as CharacterBody3D
	player.global_position = zone.global_position
	await physics_frame
	await physics_frame
	_assert(is_equal_approx(float(player.call("_external_move_speed_multiplier")), 1.3), "killer team receives 30 percent speed")
	var respawn_remaining := float(spawner.get("spawn_timer"))
	_assert(respawn_remaining > 22.5 and respawn_remaining < 24.0, "25 second respawn timer starts at kill and continues during the return")
	print("SCUTTLE_CRAB spawn=true neutral=true patrol=true flee=true death_return=true dissolve=true zone=true buff=true")
	root.queue_free()
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition: return
	push_error("SCUTTLE TEST FAILED: %s" % message)
	quit(1)
