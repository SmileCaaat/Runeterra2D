extends CanvasLayer

## Training-only roster selector.  The model reserves five active slots for
## each faction; checkboxes expose the two hero types currently authored.
const MAX_TEAM_SLOTS := 5
const RYZE_SCENE := preload("res://scenes/units/ryze.tscn")

signal roster_changed(team: StringName, heroes: Array[StringName])

var roster := {&"friendly": [], &"enemy": []}
var controls: Dictionary = {}
var _syncing_controls := false


func _ready() -> void:
	layer = 30
	_build_panel()
	set_roster(&"friendly", [&"garen"])
	set_roster(&"enemy", [])


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


func _build_panel() -> void:
	var root_host := Control.new()
	root_host.name = "RosterHudRoot"
	root_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_host)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_END
	margin.offset_left = -336.0
	margin.offset_top = 18.0
	margin.offset_right = -18.0
	margin.offset_bottom = 286.0
	root_host.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	margin.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := Label.new()
	title.text = "训练场编队"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "每方最多 5 名 · 当前英雄：盖伦 / 瑞兹"
	subtitle.modulate = Color(0.72, 0.78, 0.9)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	root.add_child(columns)
	for team: StringName in [&"friendly", &"enemy"]:
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(side)
		var heading := Label.new()
		heading.text = "蓝方" if team == &"friendly" else "红方"
		heading.modulate = Color(0.35, 0.78, 1.0) if team == &"friendly" else Color(1.0, 0.42, 0.42)
		heading.add_theme_font_size_override("font_size", 17)
		side.add_child(heading)
		var count := Label.new()
		count.name = "Count"
		count.modulate = Color(0.82, 0.82, 0.86)
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
	root.add_child(slots)


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
		existing.set("enabled", true)
		existing.global_position = Vector3(-5.5, 0.0, -1.9) if team == &"friendly" else Vector3(5.5, 0.0, 1.9)
		if existing.has_method("_configure_team_groups"):
			existing.call("_configure_team_groups")
	elif existing != null:
		existing.queue_free()
	if team == &"friendly":
		var player := characters.get_node_or_null("Player") as Node3D
		if player != null:
			_set_combatant_active(player, heroes.has(&"garen"))
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
				red_garen.set("team", "enemy")
				red_garen.set("target_path", NodePath("../FriendlyTargetDummy1"))
				red_garen.global_position = Vector3(5.5, 0.0, -1.9)
		elif red_garen != null:
			red_garen.queue_free()


func _set_combatant_active(combatant: Node3D, active: bool) -> void:
	# A roster checkbox changes combat participation, not just presentation.
	combatant.visible = active
	combatant.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var skill_controller := combatant.get_node_or_null("SkillController")
	if skill_controller != null:
		skill_controller.set("automatic_demo", active)
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


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.13, 0.92)
	style.border_color = Color(0.26, 0.45, 0.72, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
