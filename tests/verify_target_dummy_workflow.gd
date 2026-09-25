extends SceneTree


func _initialize() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	if packed == null:
		push_error("Could not load training scene")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	await process_frame

	var characters := scene.get_node("Characters")
	var enemy_one := characters.get_node("EnemyTargetDummy1") as CharacterBody3D
	var enemy_two := characters.get_node("EnemyTargetDummy2") as CharacterBody3D
	var friendly_one := characters.get_node("FriendlyTargetDummy1") as CharacterBody3D
	var friendly_two := characters.get_node("FriendlyTargetDummy2") as CharacterBody3D
	var fighter := characters.get_node("Player") as CharacterBody3D
	var dummies := [enemy_one, enemy_two, friendly_one, friendly_two]
	var roster_ok := true
	for dummy: CharacterBody3D in dummies:
		roster_ok = roster_ok and dummy != null and dummy.is_in_group(&"training_dummy")
	roster_ok = roster_ok and enemy_one.is_in_group(&"enemy_actor") and enemy_two.is_in_group(&"enemy_actor")
	roster_ok = roster_ok and friendly_one.is_in_group(&"friendly_actor") and friendly_two.is_in_group(&"friendly_actor")
	roster_ok = roster_ok and String(enemy_one.get("team")) == "enemy" and String(friendly_one.get("team")) == "friendly"

	var enemy_presenter := enemy_one.get_node("ModelPresenter") as Node3D
	var friendly_presenter := friendly_one.get_node("ModelPresenter") as Node3D
	var enemy_model := enemy_presenter.get_node("RedModel") as Node3D
	var enemy_hidden_model := enemy_presenter.get_node("BlueModel") as Node3D
	var friendly_model := friendly_presenter.get_node("BlueModel") as Node3D
	var friendly_hidden_model := friendly_presenter.get_node("RedModel") as Node3D
	var animation_ok := enemy_model != null and friendly_model != null
	animation_ok = animation_ok and bool(enemy_model.visible) and not bool(enemy_hidden_model.visible)
	animation_ok = animation_ok and bool(friendly_model.visible) and not bool(friendly_hidden_model.visible)
	animation_ok = animation_ok and StringName(enemy_model.get("current_animation")) == &"spawn"
	animation_ok = animation_ok and StringName(friendly_model.get("current_animation")) == &"spawn"
	var depth_sort_ok := enemy_presenter.is_in_group(&"depth_sort_body") and friendly_presenter.is_in_group(&"depth_sort_body")
	var enemy_readability := enemy_one.get_node("UnitReadability")
	var friendly_readability := friendly_one.get_node("UnitReadability")
	var shadow := enemy_one.get_node("GroundShadow") as Sprite3D
	var outline_highlight := enemy_one.get_node("OutlineHighlight") as Node3D
	var visual_ok := shadow.visible and shadow.no_depth_test
	visual_ok = visual_ok and outline_highlight != null and (outline_highlight.get("_pairs") as Array).size() > 0
	visual_ok = visual_ok and not enemy_readability.has_node("MaskOutline") and not enemy_readability.has_node("OutlineGlow")
	visual_ok = visual_ok and not friendly_readability.has_node("MaskOutline") and not friendly_readability.has_node("OutlineGlow")
	enemy_readability.call("refresh_team_visuals")
	friendly_readability.call("refresh_team_visuals")
	var enemy_ring := enemy_readability.get_node_or_null("TeamGroundRing") as Sprite3D
	var friendly_ring := friendly_readability.get_node_or_null("TeamGroundRing") as Sprite3D
	visual_ok = visual_ok and enemy_ring != null and friendly_ring != null
	visual_ok = visual_ok and enemy_ring.visible and friendly_ring.visible
	visual_ok = visual_ok and enemy_ring.modulate.r > enemy_ring.modulate.g
	visual_ok = visual_ok and friendly_ring.modulate.b > friendly_ring.modulate.r

	var stats_ok := is_equal_approx(float(enemy_one.get("max_health")), 1000.0)
	stats_ok = stats_ok and is_equal_approx(float(enemy_one.get("attack_speed")), 0.66)
	stats_ok = stats_ok and is_equal_approx(float(enemy_one.get("attack_range")), 1.75)
	stats_ok = stats_ok and is_equal_approx(float(enemy_one.get("move_speed")), 3.70)
	stats_ok = stats_ok and is_equal_approx(float(enemy_one.get("gameplay_radius")), 0.65)
	stats_ok = stats_ok and is_equal_approx(float(enemy_one.get("pathing_radius")), 0.30)
	var template_ok := fighter.has_method("present_resolved_damage") and enemy_one.has_method("present_resolved_damage")
	template_ok = template_ok and fighter.call("get_instance_template_id") == &"hero"
	template_ok = template_ok and enemy_one.call("get_instance_template_id") == &"monster"

	var home := enemy_one.global_position
	var static_ok := true
	for index: int in range(12):
		enemy_one.call("_physics_process", 1.0 / 60.0)
	static_ok = static_ok and enemy_one.global_position.distance_to(home) < 0.02

	enemy_one.call("receive_skill_damage", 100.0, "TEST", false, home - Vector3.RIGHT, &"physical", &"basic_melee")
	enemy_one.call("_physics_process", 1.0 / 60.0)
	var metrics := enemy_one.call("get_damage_metrics") as Dictionary
	var metrics_ok := is_equal_approx(float(enemy_one.get("current_health")), 900.0)
	metrics_ok = metrics_ok and is_equal_approx(float(metrics.get("total_damage", 0.0)), 100.0)
	metrics_ok = metrics_ok and is_equal_approx(float(metrics.get("last_damage_tick", 0.0)), 100.0)
	visual_ok = visual_ok and not enemy_model.scale.is_equal_approx(Vector3.ONE)
	visual_ok = visual_ok and is_equal_approx(enemy_model.rotation.y, -PI * 0.5) and float(enemy_one.get("facing_timer")) > 2.9
	enemy_one.call("_physics_process", 3.1)
	metrics = enemy_one.call("get_damage_metrics") as Dictionary
	metrics_ok = metrics_ok and is_equal_approx(float(enemy_one.get("current_health")), 1000.0)
	metrics_ok = metrics_ok and is_zero_approx(float(metrics.get("total_damage", -1.0)))
	enemy_one.call("receive_skill_damage", 1.0, "FACE", false, home + Vector3.RIGHT, &"physical", &"basic_melee")
	visual_ok = visual_ok and is_equal_approx(enemy_model.rotation.y, PI * 0.5)
	enemy_one.call("_physics_process", 3.1)

	enemy_one.global_position = home + Vector3.RIGHT * 1.2
	for index: int in range(180):
		enemy_one.call("_physics_process", 1.0 / 60.0)
	var return_offset := enemy_one.global_position - home
	var return_ok := Vector2(return_offset.x, return_offset.z).length() <= 0.12

	enemy_one.call("receive_skill_damage", 2000.0, "LETHAL", false, home - Vector3.RIGHT, &"magic", &"basic_melee")
	var death_ok := bool(enemy_one.get("is_dead")) and is_zero_approx(float(enemy_one.get("current_health")))
	death_ok = death_ok and StringName(enemy_model.get("current_animation")) == &"death"
	death_ok = death_ok and not enemy_one.get_node("DummyStateLabel").visible
	death_ok = death_ok and not shadow.visible
	death_ok = death_ok and not enemy_one.is_in_group(&"enemy_actor")
	death_ok = death_ok and not bool(enemy_one.call("is_targetable"))
	fighter.call("_physics_process", 1.0 / 60.0)
	death_ok = death_ok and fighter.get("target") == enemy_two
	enemy_one.call("_physics_process", 3.1)
	death_ok = death_ok and not bool(enemy_one.get("is_dead"))
	death_ok = death_ok and is_equal_approx(float(enemy_one.get("current_health")), 1000.0)
	death_ok = death_ok and int(enemy_one.get("respawn_count")) == 1
	death_ok = death_ok and enemy_one.global_position.is_equal_approx(home)
	death_ok = death_ok and StringName(enemy_model.get("current_animation")) == &"spawn"
	death_ok = death_ok and enemy_one.get_node("DummyStateLabel").visible
	death_ok = death_ok and shadow.visible
	death_ok = death_ok and enemy_one.is_in_group(&"enemy_actor")

	print("TARGET_DUMMY roster=%s animation=%s depth_sort=%s visual=%s stats=%s template=%s static=%s metrics=%s return=%s death=%s" % [
		roster_ok, animation_ok, depth_sort_ok, visual_ok, stats_ok, template_ok, static_ok, metrics_ok, return_ok, death_ok,
	])
	var passed := roster_ok and animation_ok and depth_sort_ok and visual_ok and stats_ok and template_ok and static_ok and metrics_ok and return_ok and death_ok
	if not passed:
		push_error("Target Dummy workflow verification failed")
	quit(0 if passed else 2)
