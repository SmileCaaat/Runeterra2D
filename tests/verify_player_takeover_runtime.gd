extends SceneTree

const COORDINATOR := preload("res://scripts/combat/battle_control_coordinator.gd")

var failures: Array[String] = []
var checks := 0
var stage: Node3D
var hud: BattleHUD
var coordinator: COORDINATOR
var garen: HeroInstance
var ryze: HeroInstance
var enemy: HeroInstance
var roster: TrainingRosterPanel


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	stage = load("res://DNF_Style_Prototype.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	await process_frame
	hud = stage.get_node("BattleHUD")
	coordinator = stage.get_node("BattleControlCoordinator")
	roster = hud.get_roster_panel()
	roster.set_training_units({&"friendly_dummy": false, &"enemy_dummy": false, &"scuttle": false})
	roster.set_roster(&"friendly", [&"garen", &"ryze"])
	roster.set_roster(&"enemy", [&"garen", &"ryze"])
	await process_frame
	garen = stage.get_node("Characters/Player")
	ryze = stage.get_node("Characters/RosterRyzeBlue")
	enemy = stage.get_node("Characters/RosterGarenRed")
	for hero: Node in get_nodes_in_group(&"hero_actor"):
		hero.set_physics_process(false)
		var hero_skills := hero.get_node_or_null("SkillController")
		if hero_skills != null:
			hero_skills.set("automatic_demo", false)
	coordinator.set_physics_process(false)
	_check(not garen.is_player_controlled() and not ryze.is_player_controlled() and coordinator.manual_hero == null, "default AI")
	hud.select_hero(0)
	_check(hud.get_selected_hero() == garen, "focus Garen")
	coordinator.toggle_control()
	_check(garen.is_player_controlled() and coordinator.manual_hero == garen, "toggle player")
	garen.set_player_move_input(Vector2.RIGHT)
	hud.select_next_hero()
	_check(not garen.is_player_controlled() and garen.player_move_input == Vector2.ZERO and not ryze.is_player_controlled(), "switch releases without takeover")
	coordinator.toggle_control()
	_check(ryze.is_player_controlled() and not garen.is_player_controlled(), "only one manual")
	_check(hud.get("_control_mode_label").text == "MANUAL", "manual badge signal")
	coordinator.toggle_control()
	_check(hud.get("_control_mode_label").text == "AUTO" and float(ryze.get("ai_decision_timer")) == 0.0, "auto badge and immediate re-evaluation")
	var event := InputEventAction.new()
	event.action = &"battle_hero_1"
	event.pressed = true
	coordinator._unhandled_input(event)
	_check(hud.get_selected_hero() == garen, "F1 selection action")
	event.action = &"battle_hero_cycle"
	coordinator._input(event)
	_check(hud.get_selected_hero() == ryze, "Tab selection action")
	hud._on_team_slot_gui_input(_mouse_click(), 0)
	_check(hud.get_selected_hero() == garen, "mouse selection")
	_check(InputMap.action_get_events(&"battle_move_left")[0].physical_keycode == KEY_LEFT and InputMap.action_get_events(&"battle_hero_1")[0].physical_keycode == KEY_F1 and InputMap.action_get_events(&"battle_hero_cycle")[0].physical_keycode == KEY_TAB, "InputMap key codes")
	await _hero_tests()
	await _ryze_tests()
	await _integration_tests()
	hud.select_hero(1)
	coordinator._ensure_manual_control()
	roster.set_roster(&"friendly", [&"garen"])
	await process_frame
	coordinator._validate_runtime_refs()
	_check(coordinator.manual_hero == null and hud.get_selected_hero() == garen, "roster removal")
	print("PLAYER_TAKEOVER checks=%d failures=%s" % [checks, failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _hero_tests() -> void:
	hud.select_hero(0)
	coordinator.toggle_control()
	var skills := garen.get_node("SkillController")
	garen.set("target", enemy)
	await _wait_garen_idle()
	garen.global_position = Vector3.ZERO
	enemy.global_position = Vector3(-1.0, 0.0, 0.0)
	stage.get_node("Characters/RosterRyzeRed").global_position = Vector3(-12.0, 0.0, 2.0)
	garen.set_physics_process(true)
	garen.set_player_move_input(Vector2(1, 1).normalized())
	await _frames(12)
	_check(garen.position.x > 0.05 and garen.position.z > 0.05, "Garen X/Z movement")
	garen.set_player_move_input(Vector2.ZERO)
	await _frames(20)
	_check(Vector2(garen.velocity.x, garen.velocity.z).length() < 0.01, "Garen stops")
	garen.apply_root(1.0)
	var root_position := garen.global_position
	garen.set_player_move_input(Vector2.RIGHT)
	await _frames(10)
	_check(Vector2(garen.position.x - root_position.x, garen.position.z - root_position.z).length() < 0.01, "Garen root")
	garen.set("_root_timer", 0.0)
	garen.set_player_move_input(Vector2.ZERO)
	garen.global_position = Vector3.ZERO
	garen.velocity = Vector3.ZERO
	_check(garen.request_player_basic_attack(), "Garen basic")
	_check(not garen.request_player_skill(&"q"), "Garen attack lock")
	await _wait_garen_idle()
	for slot: StringName in [&"q", &"w", &"e", &"r", &"t"]:
		enemy.call("revive_for_training")
		enemy.global_position = garen.global_position + Vector3(-1, 0, 0)
		var index := [&"q", &"w", &"e", &"r", &"t"].find(slot) + 1
		(skills.get("cooldowns") as Array)[index] = 0.0
		var previous_count := int(skills.get("cast_counts")[index])
		var manual_skill_started := garen.request_player_skill(slot)
		_check(manual_skill_started, "Garen skill " + slot)
		_check(int(skills.get("cast_counts")[index]) == previous_count + 1 and not garen.request_player_skill(slot), "Garen one start/CD " + slot)
		if slot == &"e":
			(skills.get("cooldowns") as Array)[2] = 0.0
			_check(garen.request_player_skill(&"w") and int(skills.get("current_skill")) == 3 and bool(skills.get("is_casting")), "W during E")
			var start_x := garen.position.x
			garen.set_player_move_input(Vector2.RIGHT)
			await _frames(12)
			_check(garen.position.x > start_x + 0.05, "E follows player away from target")
			garen.set_player_move_input(Vector2.ZERO)
			var cd := float(skills.get("cooldowns")[3])
			coordinator.toggle_control()
			_check(bool(skills.get("is_casting")) and int(skills.get("current_skill")) == 3 and float(skills.get("cooldowns")[3]) == cd, "release preserves E")
			coordinator.toggle_control()
			_check(bool(skills.get("is_casting")) and int(skills.get("current_skill")) == 3, "takeover preserves E")
		await _wait_garen_idle()
	await _garen_empty_target_tests()
	skills.set("silence_timer", 1.0)
	(skills.get("cooldowns") as Array)[1] = 0.0
	(skills.get("cooldowns") as Array)[2] = 0.0
	_check(not garen.request_player_skill(&"q") and garen.request_player_skill(&"w"), "Black Sail silence exception")
	skills.set("silence_timer", 0.0)
	coordinator.toggle_control()
	_check(garen.get("ai_decision") == null and float(garen.get("ai_decision_timer")) == 0.0, "Garen release invalidates")
	await _frames(3)
	_check(float(garen.get("ai_decision_timer")) > 0.0 or garen.get("state") == 2 or bool(skills.get("is_casting")), "Garen resumes fresh AI")
	garen.set_physics_process(false)


func _garen_empty_target_tests() -> void:
	var hidden_foes := _hide_enemy_targets()
	var skills := garen.get_node("SkillController")
	garen.global_position = Vector3.ZERO
	garen.velocity = Vector3.ZERO
	garen.player_facing_direction = Vector2.RIGHT
	var health_before := float(enemy.get("current_health"))
	_check(garen.request_player_basic_attack(Vector2.RIGHT), "Garen manual basic starts with no enemy")
	await _wait_garen_idle()
	_check(bool(garen.get("attack_hit_sent")) and float(enemy.get("current_health")) == health_before, "Garen manual basic whiffs with no enemy")
	for slot: StringName in [&"q", &"w", &"e"]:
		var index := [&"q", &"w", &"e"].find(slot) + 1
		(skills.get("cooldowns") as Array)[index] = 0.0
		var cast_count := int(skills.get("cast_counts")[index])
		_check(garen.request_player_skill(slot), "Garen %s starts without target" % slot)
		_check(int(skills.get("cast_counts")[index]) == cast_count + 1, "Garen %s counted without target" % slot)
		await _wait_garen_idle()
	(skills.get("cooldowns") as Array)[4] = 0.0
	_check(not garen.request_player_skill(&"r"), "Garen unit R still requires target")
	(skills.get("cooldowns") as Array)[5] = 0.0
	var facing_before := garen.player_facing_direction
	_check(garen.request_player_skill(&"t", Vector2.DOWN), "Garen ground T starts without target")
	_check(garen.player_facing_direction == Vector2.DOWN and facing_before == Vector2.RIGHT, "Garen ground T uses player aim")
	await _wait_garen_idle()
	var ghostship := skills.get("ghostship") as AnimatedSprite3D
	_check(ghostship != null and ghostship.global_position.z > 0.1, "Garen ground T lands along aim")
	_restore_targets(hidden_foes)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _ryze_tests() -> void:
	hud.select_hero(1)
	coordinator._ensure_manual_control()
	for hero: Node in get_nodes_in_group(&"hero_actor"):
		var hero_skills := hero.get_node_or_null("SkillController")
		if hero_skills != null:
			hero_skills.set("automatic_demo", false)
	var cooldowns: Dictionary = ryze.get("cooldowns")
	ryze.set_physics_process(true)
	await _wait_ryze_idle()
	enemy.call("revive_for_training")
	ryze.call("revive_for_training")
	ryze.set("target", enemy)
	ryze.global_position = Vector3.ZERO
	garen.global_position = Vector3(-12, 0, -2)
	enemy.global_position = Vector3(-2, 0, 0)
	ryze.set_player_move_input(Vector2(1, 1).normalized())
	await _frames(10)
	_check(ryze.position.x > 0.05 and ryze.position.z > 0.05, "Ryze X/Z movement")
	ryze.set_player_move_input(Vector2.ZERO)
	await _frames(2)
	_check(ryze.velocity.is_zero_approx(), "Ryze stops")
	ryze.apply_root(1.0)
	var root_position := ryze.global_position
	ryze.set_player_move_input(Vector2.RIGHT)
	await _frames(10)
	_check(ryze.position.distance_to(root_position) < 0.01, "Ryze root")
	cooldowns[&"r"] = 0.0
	_check(not ryze.request_player_skill(&"r", Vector2.RIGHT) and float(cooldowns[&"r"]) == 0.0, "Root rejects manual R")
	ryze.set("_root_timer", 0.0)
	ryze.set_player_move_input(Vector2.ZERO)
	for slot: StringName in [&"q", &"w", &"e", &"t"]:
		enemy.call("revive_for_training")
		enemy.global_position = ryze.global_position + Vector3(-2, 0, 0)
		cooldowns[slot] = 0.0
		_check(ryze.request_player_skill(slot) and float(cooldowns[slot]) > 0.0, "Ryze skill " + slot)
		_check(not ryze.request_player_skill(slot), "Ryze lock/CD " + slot)
		if slot == &"q":
			var lock := float(ryze.get("action_lock"))
			var cd := float(cooldowns[slot])
			hud.select_hero(0)
			_check(not ryze.is_player_controlled() and float(ryze.get("action_lock")) == lock and float(cooldowns[slot]) == cd, "switch preserves Ryze action")
			hud.select_hero(1)
			coordinator._ensure_manual_control()
			_check(float(ryze.get("action_lock")) == lock, "takeover preserves Ryze action")
		await _wait_ryze_idle()
	await _ryze_empty_target_tests()
	ryze.set("silence_timer", 2.0)
	for slot: StringName in [&"q", &"w", &"e", &"r", &"t"]:
		cooldowns[slot] = 0.0
		_check(not ryze.request_player_skill(slot, Vector2.RIGHT), "silence blocks " + slot)
	var silent_x := ryze.position.x
	ryze.set_player_move_input(Vector2.RIGHT)
	await _frames(6)
	_check(ryze.position.x > silent_x, "silence permits movement")
	ryze.set_player_move_input(Vector2.ZERO)
	_check(ryze.request_player_basic_attack(), "silence permits basic")
	await _wait_ryze_idle()
	ryze.set("silence_timer", 0.0)
	cooldowns[&"r"] = 0.0
	ryze.global_position = Vector3.ZERO
	garen.global_position = Vector3(1, 0, 1)
	var model := ryze.get_node("RyzeModel")
	var original_speed := float(model.get("animation_speed_scale"))
	_check(ryze.request_player_skill(&"r", Vector2.RIGHT), "manual directional R starts")
	var r_cd := float(cooldowns[&"r"])
	hud.select_hero(0)
	_check(not ryze.is_player_controlled() and float(ryze.get("action_lock")) > 0.0 and float(cooldowns[&"r"]) == r_cd, "R survives switch")
	hud.select_hero(1)
	coordinator._ensure_manual_control()
	await create_timer(0.65).timeout
	_check(ryze.position.x < 0.1, "R retains channel")
	await create_timer(0.32).timeout
	_check(absf(ryze.position.x - 8.0) < 0.1 and absf(garen.position.x - 9.0) < 0.1, "R 8m destination and ally transport")
	_check(is_equal_approx(float(model.get("animation_speed_scale")), original_speed) and float(ryze.get("super_armor_timer")) == 0.0, "R restores speed without armor")
	await _wait_ryze_idle()
	ryze.global_position = Vector3(13, 0, 0)
	cooldowns[&"r"] = 0.0
	_check(ryze.request_player_skill(&"r", Vector2.RIGHT), "R clamped start")
	# The channel timer resolves on an idle frame; the physics action lock can
	# reach zero one frame earlier, so wait for the actual landing before checking it.
	var arena_edge := (ryze.get("arena_max") as Vector2).x
	var landing_frames := 0
	while absf(ryze.position.x - arena_edge) >= 0.02 and landing_frames < 180:
		await physics_frame
		landing_frames += 1
	await _wait_ryze_idle()
	_check(absf(ryze.position.x - arena_edge) < 0.02, "R arena clamp (x=%.3f, max=%.3f)" % [ryze.position.x, arena_edge])
	coordinator.toggle_control()
	_check(ryze.get("ai_decision") == null and float(ryze.get("ai_decision_timer")) == 0.0, "Ryze release invalidates")
	await _frames(3)
	_check(ryze.get("ai_decision") != null or float(ryze.get("action_lock")) > 0.0, "Ryze fresh AI")
	ryze.set_physics_process(false)


func _ryze_empty_target_tests() -> void:
	var hidden_foes := _hide_enemy_targets()
	var cooldowns: Dictionary = ryze.get("cooldowns")
	ryze.call("revive_for_training")
	ryze.global_position = Vector3.ZERO
	ryze.player_facing_direction = Vector2.RIGHT
	ryze.set("target", null)
	ryze.set("_faces_left", false)
	ryze.set("_root_timer", 0.0)
	var enemy_health := float(enemy.get("current_health"))
	_check(ryze.request_player_basic_attack(Vector2.RIGHT), "Ryze manual basic starts with no target")
	_check(await _wait_for_manual_projectile(), "Ryze manual basic emits directional projectile without target")
	await _wait_ryze_idle()
	await _frames(32)
	_check(float(enemy.get("current_health")) == enemy_health, "Ryze manual basic flies and misses with no target")
	cooldowns[&"q"] = 0.0
	_check(ryze.request_player_skill(&"q", Vector2.RIGHT), "Ryze directional Q starts with no target")
	_check(not bool(ryze.get("_faces_left")), "Ryze Q does not face empty auto target")
	_check(await _wait_for_manual_projectile(), "Ryze Q emits directional projectile without target")
	await _wait_ryze_idle()
	await _frames(32)
	_check(float(enemy.get("current_health")) == enemy_health, "Ryze directional Q flies and misses with no target")
	for slot: StringName in [&"w", &"e"]:
		cooldowns[slot] = 0.0
		_check(not ryze.request_player_skill(slot), "Ryze %s still requires unit target" % slot)
	cooldowns[&"t"] = 0.0
	_check(ryze.request_player_skill(&"t"), "Ryze self T starts with no target")
	await _wait_ryze_idle()
	cooldowns[&"r"] = 0.0
	_check(ryze.request_player_skill(&"r", Vector2.RIGHT), "Ryze ground R starts with no target")
	await create_timer(1.05).timeout
	_check(absf(ryze.position.x - 8.0) < 0.1, "Ryze ground R travels along aim without target")
	await _wait_ryze_idle()
	ryze.set("desperate_timer", 0.0)
	ryze.set("supercharged_casts", 0)
	ryze.set("supercharged_timer", 0.0)
	_restore_targets(hidden_foes)

	ryze.global_position = Vector3.ZERO
	ryze.set("_faces_left", false)
	enemy.call("revive_for_training")
	var red_ryze := stage.get_node("Characters/RosterRyzeRed") as CharacterBody3D
	red_ryze.call("revive_for_training")
	enemy.global_position = Vector3(-2.0, 0.0, 0.0)
	red_ryze.global_position = Vector3(10.0, 0.0, 0.0)
	ryze.set("target", enemy)
	cooldowns[&"w"] = 0.0
	_check(ryze.request_player_skill(&"w"), "Ryze unit W may face its target")
	_check(bool(ryze.get("_faces_left")), "Ryze unit W corrects facing at cast time")
	await _wait_ryze_idle()
	cooldowns[&"q"] = 0.0
	enemy_health = float(enemy.get("current_health"))
	_check(ryze.request_player_skill(&"q"), "Ryze Q fires along stored facing while auto target is behind")
	_check(not bool(ryze.get("_faces_left")), "Ryze directional Q preserves player facing")
	await _wait_ryze_idle()
	await _frames(10)
	_check(float(enemy.get("current_health")) == enemy_health, "Ryze Q does not curve back to auto target")

	ryze.global_position = Vector3.ZERO
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	red_ryze.global_position = Vector3(4.0, 0.0, 0.0)
	cooldowns[&"q"] = 0.0
	var second_health := float(red_ryze.get("current_health"))
	_check(ryze.request_player_skill(&"q", Vector2.RIGHT), "Ryze manual Q starts first-hit sweep")
	await _wait_ryze_idle()
	await _frames(10)
	_check(float(enemy.get("current_health")) < enemy_health and float(red_ryze.get("current_health")) == second_health, "Ryze manual Q hits first enemy on line")

	ryze.global_position = Vector3.ZERO
	enemy.global_position = Vector3(2.0, 0.0, 0.0)
	red_ryze.global_position = Vector3(4.0, 0.0, 0.0)
	var basic_health := float(enemy.get("current_health"))
	var second_basic_health := float(red_ryze.get("current_health"))
	_check(ryze.request_player_basic_attack(Vector2.RIGHT), "Ryze manual basic starts directional sweep")
	await _wait_ryze_idle()
	await _frames(10)
	_check(float(enemy.get("current_health")) < basic_health and float(red_ryze.get("current_health")) == second_basic_health, "Ryze manual basic hits first enemy on line")


func _hide_enemy_targets() -> Array[Node]:
	var hidden: Array[Node] = []
	for candidate: Node in get_nodes_in_group(&"combat_target"):
		if candidate.has_method("get_team") and String(candidate.call("get_team")) != String(garen.call("get_team")):
			candidate.remove_from_group(&"combat_target")
			hidden.append(candidate)
	return hidden


func _restore_targets(hidden: Array[Node]) -> void:
	for candidate: Node in hidden:
		if is_instance_valid(candidate) and not candidate.is_in_group(&"combat_target"):
			candidate.add_to_group(&"combat_target")


func _wait_for_manual_projectile() -> bool:
	for _frame in 90:
		if not get_nodes_in_group(&"ryze_directional_projectile").is_empty():
			return true
		await physics_frame
	return false


func _integration_tests() -> void:
	# The real training scene contains blue/red Garen + Ryze throughout.
	_check(get_nodes_in_group(&"hero_actor").size() == 4, "2v2 roster")
	garen.call("revive_for_training")
	enemy.call("revive_for_training")
	garen.global_position = Vector3.ZERO
	enemy.global_position = Vector3(-1, 0, 0)
	garen.set("target", enemy)
	hud.select_hero(0)
	_check(bool(garen.get_node("OutlineHighlight").call("is_selected")) and not bool(ryze.get_node("OutlineHighlight").call("is_selected")), "focus outline Garen")
	hud.select_hero(1)
	_check(bool(ryze.get_node("OutlineHighlight").call("is_selected")) and not bool(garen.get_node("OutlineHighlight").call("is_selected")), "focus outline Ryze")
	_check(garen.get_node("UnitReadability").visible and ryze.get_node("UnitReadability").visible, "team indicators retained")
	hud.select_hero(0)
	Input.action_press(&"battle_move_right")
	coordinator._physics_process(0.016)
	_check(garen.is_player_controlled() and garen.player_move_input.x > 0.0, "movement soft takeover same tick")
	hud.select_hero(1)
	coordinator._physics_process(0.016)
	_check(not ryze.is_player_controlled(), "held movement cannot seize newly focused hero")
	Input.action_release(&"battle_move_right")
	coordinator._physics_process(0.016)
	ryze.set("action_lock", 0.0)
	ryze.set("arcane_stacks", 0)
	ryze.set("supercharged_casts", 0)
	ryze.set("supercharged_timer", 0.0)
	ryze.set("desperate_timer", 0.0)
	ryze.set("target", enemy)
	ryze.global_position = Vector3(2, 0, 0)
	(ryze.get("cooldowns") as Dictionary)[&"q"] = 0.0
	var event := InputEventAction.new()
	event.action = &"battle_skill_q"
	event.pressed = true
	coordinator._unhandled_input(event)
	_check(ryze.is_player_controlled() and float(ryze.get("cooldowns")[&"q"]) > 0.0, "skill soft takeover same event")
	var echo_key := InputEventKey.new()
	echo_key.physical_keycode = KEY_Q
	echo_key.pressed = true
	echo_key.echo = true
	var cd := float(ryze.get("cooldowns")[&"q"])
	coordinator._unhandled_input(echo_key)
	_check(float(ryze.get("cooldowns")[&"q"]) == cd, "keyboard echo ignored")
	ryze.call("receive_skill_damage", 99999.0, "takeover death", false, Vector3.ZERO, &"true")
	coordinator._validate_runtime_refs()
	_check(coordinator.manual_hero == null and not ryze.is_player_controlled(), "death releases authority")
	hud.select_hero(0)
	_check(coordinator._ensure_manual_control(), "living teammate controllable after death")
	ryze.call("revive_for_training")
	_check(not ryze.is_player_controlled(), "revive remains AI")
	hud.select_hero(1)
	coordinator._ensure_manual_control()
	ryze.queue_free()
	await process_frame
	coordinator._validate_runtime_refs()
	_check(not coordinator._ensure_manual_control(), "freed focus cannot take control")
	hud.set("_hero_refresh_timer", 0.0)
	await process_frame
	_check(coordinator.manual_hero == null and hud.get_selected_hero() == garen, "freed focused hero falls back")
	roster.set_roster(&"friendly", [&"garen", &"ryze"])
	await process_frame
	ryze = stage.get_node("Characters/RosterRyzeBlue")
	ryze.set_physics_process(false)


func _wait_ryze_idle() -> void:
	var ticks := 0
	while float(ryze.get("action_lock")) > 0.0 and ticks < 600:
		await physics_frame
		ticks += 1
	_check(ticks < 600, "Ryze action finishes")


func _wait_garen_idle() -> void:
	var ticks := 0
	while (bool(garen.get_node("SkillController").get("is_casting")) or int(garen.get("state")) == 2) and ticks < 600:
		await physics_frame
		ticks += 1
	_check(ticks < 600, "Garen action finishes")


func _mouse_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures.append(description)
		push_error(description)
