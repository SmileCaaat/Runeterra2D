class_name TrainingRosterPanel
extends VBoxContainer

## Training-only roster selector embedded in BattleHUD Training Tools.
## Reserves five active slots per faction; checkboxes expose authored heroes.

const MAX_TEAM_SLOTS := 5
const RYZE_SCENE := preload("res://scenes/units/ryze.tscn")

signal roster_changed(team: StringName, heroes: Array[StringName])

var roster := {&"friendly": [], &"enemy": []}
var training_units := {&"friendly_dummy": true, &"enemy_dummy": true, &"scuttle": true}
var controls: Dictionary = {}
var _syncing_controls := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_content()
	set_roster(&"friendly", [&"garen"])
	set_roster(&"enemy", [])
	set_training_units(training_units)


func set_roster(team: StringName, heroes: Array[StringName]) -> void:
	var clean: Array[StringName] = []
	for hero: StringName in heroes:
		if hero in [&"garen", &"ryze"] and not clean.has(hero) and clean.size() < MAX_TEAM_SLOTS:
			clean.append(hero)
	roster[team] = clean
	_syncing_controls = true
	for hero: StringName in [&"garen", &"ryze"]:
		var box := controls.get("%s/%s" % [team, hero]) as CheckBox
		if box != null:
			box.button_pressed = clean.has(hero)
	_syncing_controls = false
	_update_summary(team)
	_sync_runtime_roster(team)
	roster_changed.emit(team, clean)


func _build_content() -> void:
	var title := Label.new()
	title.text = "训练场编队"
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "每方最多 5 名 · 当前英雄：盖伦 / 瑞兹"
	subtitle.modulate = Color(0.72, 0.78, 0.9)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	for team: StringName in [&"friendly", &"enemy"]:
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(side)
		var heading := Label.new()
		heading.text = "蓝方" if team == &"friendly" else "红方"
		heading.modulate = Color(0.35, 0.78, 1.0) if team == &"friendly" else Color(1.0, 0.42, 0.42)
		heading.add_theme_font_size_override("font_size", 13)
		side.add_child(heading)
		var count := Label.new()
		count.name = "Count"
		count.modulate = Color(0.82, 0.82, 0.86)
		count.add_theme_font_size_override("font_size", 11)
		side.add_child(count)
		for hero: StringName in [&"garen", &"ryze"]:
			var box := CheckBox.new()
			box.text = "盖伦" if hero == &"garen" else "瑞兹"
			box.tooltip_text = "加入%s预留的 5 个英雄槽之一" % ("蓝方" if team == &"friendly" else "红方")
			box.toggled.connect(_on_hero_toggled.bind(team, hero))
			side.add_child(box)
			controls["%s/%s" % [team, hero]] = box
		controls["%s/count" % team] = count
	var slots := Label.new()
	slots.text = "槽位预留：① ② ③ ④ ⑤"
	slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots.modulate = Color(0.64, 0.69, 0.8)
	slots.add_theme_font_size_override("font_size", 11)
	add_child(slots)
	var divider := HSeparator.new()
	add_child(divider)
	var targets_title := Label.new()
	targets_title.text = "训练目标"
	targets_title.add_theme_font_size_override("font_size", 13)
	targets_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(targets_title)
	var targets := HBoxContainer.new()
	targets.alignment = BoxContainer.ALIGNMENT_CENTER
	targets.add_theme_constant_override("separation", 10)
	add_child(targets)
	for unit_id: StringName in [&"friendly_dummy", &"enemy_dummy", &"scuttle"]:
		var box := CheckBox.new()
		box.text = {
			&"friendly_dummy": "蓝方木桩",
			&"enemy_dummy": "红方木桩",
			&"scuttle": "迅捷蟹",
		}.get(unit_id, String(unit_id))
		box.tooltip_text = "切换训练场中的%s" % box.text
		box.toggled.connect(_on_training_unit_toggled.bind(unit_id))
		targets.add_child(box)
		controls["unit/%s" % unit_id] = box


func _on_hero_toggled(pressed: bool, team: StringName, hero: StringName) -> void:
	if _syncing_controls:
		return
	var next: Array[StringName] = roster.get(team, []).duplicate()
	if pressed and not next.has(hero):
		if next.size() >= MAX_TEAM_SLOTS:
			var box := controls.get("%s/%s" % [team, hero]) as CheckBox
			if box != null:
				box.button_pressed = false
			return
		next.append(hero)
	elif not pressed:
		next.erase(hero)
	set_roster(team, next)


func set_training_units(next_units: Dictionary) -> void:
	for unit_id: StringName in training_units.keys():
		training_units[unit_id] = bool(next_units.get(unit_id, training_units[unit_id]))
		var box := controls.get("unit/%s" % unit_id) as CheckBox
		if box != null:
			box.button_pressed = training_units[unit_id]
	_sync_runtime_training_units()


func _on_training_unit_toggled(pressed: bool, unit_id: StringName) -> void:
	if _syncing_controls:
		return
	training_units[unit_id] = pressed
	_sync_runtime_training_units()


func _sync_runtime_roster(team: StringName) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var characters := current_scene.get_node_or_null("Characters") as Node3D
	if characters == null:
		return
	var heroes: Array[StringName] = roster.get(team, [])
	var ryze_name := "RosterRyzeBlue" if team == &"friendly" else "RosterRyzeRed"
	var existing := characters.get_node_or_null(ryze_name) as Node3D
	if heroes.has(&"ryze"):
		if existing == null:
			existing = RYZE_SCENE.instantiate() as Node3D
			existing.name = ryze_name
			characters.add_child(existing)
		existing.set("team", String(team))
		if existing.has_method("revive_for_training"):
			existing.call("revive_for_training")
		else:
			existing.set("enabled", true)
			existing.set("is_dead", false)
			if float(existing.get("max_health")) > 0.0:
				existing.set("current_health", existing.get("max_health"))
			if not existing.is_in_group(&"combat_target"):
				existing.add_to_group(&"combat_target")
		existing.global_position = Vector3(-5.5, 0.0, -1.9) if team == &"friendly" else Vector3(5.5, 0.0, 1.9)
		if existing.has_method("_configure_team_groups"):
			existing.call("_configure_team_groups")
	elif existing != null:
		existing.queue_free()
	if team == &"friendly":
		var player := characters.get_node_or_null("Player") as Node3D
		if player != null:
			_set_combatant_active(player, heroes.has(&"garen"))
			if heroes.has(&"garen") and player.has_method("_configure_team_groups"):
				player.set("team", "friendly")
				player.call("_configure_team_groups")
	else:
		var red_garen := characters.get_node_or_null("RosterGarenRed") as CharacterBody3D
		if heroes.has(&"garen"):
			if red_garen == null:
				var source := characters.get_node_or_null("Player") as CharacterBody3D
				if source != null:
					red_garen = source.duplicate() as CharacterBody3D
					red_garen.name = "RosterGarenRed"
					characters.add_child(red_garen)
			if red_garen != null:
				_prepare_red_garen(red_garen)
		elif red_garen != null:
			red_garen.queue_free()
	_retarget_roster_combatants(characters)


func _sync_runtime_training_units() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var characters := current_scene.get_node_or_null("Characters") as Node3D
	if characters == null:
		return
	_set_training_targets_active(characters, [&"FriendlyTargetDummy1", &"FriendlyTargetDummy2"], bool(training_units[&"friendly_dummy"]))
	_set_training_targets_active(characters, [&"EnemyTargetDummy1", &"EnemyTargetDummy2"], bool(training_units[&"enemy_dummy"]))
	var scuttle_spawner := characters.get_node_or_null("ScuttleCrabSpawner")
	if scuttle_spawner != null and scuttle_spawner.has_method("set_training_enabled"):
		scuttle_spawner.call("set_training_enabled", bool(training_units[&"scuttle"]))
	_retarget_roster_combatants(characters)


func _set_training_targets_active(characters: Node3D, target_names: Array[StringName], active: bool) -> void:
	for target_name: StringName in target_names:
		var target := characters.get_node_or_null(NodePath(target_name)) as Node3D
		if target == null:
			continue
		if active and bool(target.get("is_dead")) and target.has_method("_respawn"):
			target.call("_respawn")
		_set_combatant_active(target, active)


func _prepare_red_garen(red_garen: CharacterBody3D) -> void:
	red_garen.set("team", "enemy")
	red_garen.set("target_path", NodePath())
	red_garen.set("target", null)
	red_garen.global_position = Vector3(5.5, 0.0, -1.9)
	red_garen.remove_from_group(&"player_actor")
	red_garen.add_to_group(&"combat_target")
	if red_garen.has_method("_configure_team_groups"):
		red_garen.call("_configure_team_groups")
	_set_combatant_active(red_garen, true)
	var skill_controller := red_garen.get_node_or_null("SkillController")
	if skill_controller != null:
		_set_legacy_demo_ai(red_garen, true)
		skill_controller.set("is_casting", false)
		var max_hp := float(skill_controller.get("max_health"))
		skill_controller.set("current_health", max_hp)


func _retarget_roster_combatants(characters: Node3D) -> void:
	for child: Node in characters.get_children():
		if child.has_method("force_retarget_hostile"):
			child.call("force_retarget_hostile")

func _set_legacy_demo_ai(combatant: Node3D, active: bool) -> void:
	var skill_controller := combatant.get_node_or_null("SkillController")
	if skill_controller == null:
		return
	var hero_brain_owned := combatant.has_method("uses_hero_brain") and bool(combatant.call("uses_hero_brain"))
	skill_controller.set("automatic_demo", active and not hero_brain_owned)


func _set_combatant_active(combatant: Node3D, active: bool) -> void:
	combatant.visible = active
	combatant.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active and combatant.has_method("revive_for_training"):
		combatant.call("revive_for_training")
	elif active:
		if not combatant.is_in_group(&"combat_target"):
			combatant.add_to_group(&"combat_target")
		if combatant.has_method("_configure_team_groups"):
			combatant.call("_configure_team_groups")
	elif combatant.is_in_group(&"combat_target"):
		combatant.remove_from_group(&"combat_target")
	var skill_controller := combatant.get_node_or_null("SkillController")
	if skill_controller != null:
		_set_legacy_demo_ai(combatant, active)
		if not active:
			skill_controller.set("is_casting", false)
	for child: Node in _all_descendants(combatant):
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			(child as Node).call("stop")
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not active)


func _all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _update_summary(team: StringName) -> void:
	var count := controls.get("%s/count" % team) as Label
	if count != null:
		count.text = "%d / %d 个出战槽位" % [roster.get(team, []).size(), MAX_TEAM_SLOTS]
