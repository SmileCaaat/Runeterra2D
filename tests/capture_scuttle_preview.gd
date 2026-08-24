extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var scene := load("res://DNF_Style_Prototype.tscn") as PackedScene
	var root := scene.instantiate()
	get_root().add_child(root)
	var spawner := root.get_node("Characters/ScuttleCrabSpawner")
	spawner.set("spawn_timer", 0.0)
	spawner.call("_process", 0.01)
	await create_timer(0.35).timeout
	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_root().get_texture().get_image()
	var error := image.save_png(output_dir.path_join("scuttle_preview.png"))
	print("SCUTTLE_PREVIEW error=%s" % error_string(error))
	var crab := spawner.get("active_crab") as CharacterBody3D
	crab.call("register_damage_source", Vector3(-3, 0, 0), &"friendly")
	crab.call("receive_skill_damage", 999999.0, "CAPTURE", false, Vector3(-3, 0, 0), &"physical", &"basic_melee")
	await create_timer(1.0).timeout
	await process_frame
	await process_frame
	var zones := get_nodes_in_group(&"scuttle_speed_zone")
	var fallback_zone := root.get_node_or_null("Characters/ScuttleSpeedZone")
	print("SCUTTLE_ZONE_CAPTURE count=%d position=%s visible=%s" % [
		zones.size(),
		zones[0].global_position if not zones.is_empty() else (fallback_zone.global_position if fallback_zone != null else Vector3.ZERO),
		zones[0].get_node("TintedDisc").is_visible_in_tree() if not zones.is_empty() else (fallback_zone.get_node("TintedDisc").is_visible_in_tree() if fallback_zone != null else false),
	])
	var zone_image := get_root().get_texture().get_image()
	zone_image.save_png(output_dir.path_join("scuttle_speed_zone_preview.png"))
	root.queue_free()
	quit(0)
