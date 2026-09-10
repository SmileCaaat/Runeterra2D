class_name BattleHUD
extends CanvasLayer

## Split-layout battle HUD.
## Window stays 16:9. Bottom band is exclusive HUD; combat renders only above it
## via a shared-world SubViewport so GroundEdgeFront is never covered.

const BASE_HUD_HEIGHT_RATIO := 0.22
const HUD_HEIGHT_RATIO := BASE_HUD_HEIGHT_RATIO * 0.6 ## 0.132 of window height
## Derived combat band aspect inside a 16:9 window: (16/9) / (1 - HUD_HEIGHT_RATIO) ≈ 2.048
const COMBAT_ASPECT := (16.0 / 9.0) / (1.0 - HUD_HEIGHT_RATIO)
const TEAM_SLOT_COUNT := 5
const SKILL_KEYS: Array[String] = ["Q", "W", "E", "R", "T"]
const EQUIP_SLOT_COUNT := 6
const SLOT_GAP := 4 ## Match QWERT skill spacing; keep C cluster compact.
const EQUIP_SLOT_PX := 36

const TEAM_HEROES := [
	{"name": "盖伦", "short": "盖", "role": "前排 / 战士", "hp": 0.86, "mp": 0.42, "alive": true},
	{"name": "瑞兹", "short": "瑞", "role": "法术 / 控制", "hp": 0.74, "mp": 0.69, "alive": true},
	{"name": "锐雯", "short": "锐", "role": "近战 / 爆发", "hp": 0.91, "mp": 0.55, "alive": true},
	{"name": "贾克斯", "short": "贾", "role": "战士 / 持续", "hp": 0.68, "mp": 0.31, "alive": true},
	{"name": "娑娜", "short": "娑", "role": "辅助 / 回复", "hp": 0.63, "mp": 0.82, "alive": true},
]

var _selected_index := 0
var _team_slots: Array[Control] = []
var _portrait_label: Label
var _name_label: Label
var _level_label: Label
var _role_label: Label
var _hp_fill: ColorRect
var _mp_fill: ColorRect
var _hp_text: Label
var _mp_text: Label
var _skill_slots: Array[Control] = []
var _roster_panel: TrainingRosterPanel
var _source_camera: Camera3D
var _proxy_camera: Camera3D
var _combat_viewport: SubViewport
var _audio_listener: AudioListener3D


func _ready() -> void:
	layer = 20
	_build()
	_select_hero(0, false)
	call_deferred(&"_bind_combat_camera")


func _process(_delta: float) -> void:
	_sync_combat_camera()


func get_roster_panel() -> TrainingRosterPanel:
	return _roster_panel


func get_bottom_hud() -> Control:
	return get_node("HUDRoot/BottomHUD") as Control


func get_debug_drawer() -> Control:
	return get_node("HUDRoot/DebugDrawer") as Control


func get_combat_viewport_container() -> SubViewportContainer:
	return get_node("HUDRoot/CombatViewportContainer") as SubViewportContainer


func get_combat_aspect() -> float:
	return COMBAT_ASPECT


func get_hud_height_ratio() -> float:
	return HUD_HEIGHT_RATIO


func _build() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var combat_host := SubViewportContainer.new()
	combat_host.name = "CombatViewportContainer"
	combat_host.set_anchor(SIDE_LEFT, 0.0)
	combat_host.set_anchor(SIDE_RIGHT, 1.0)
	combat_host.set_anchor(SIDE_TOP, 0.0)
	combat_host.set_anchor(SIDE_BOTTOM, 1.0 - HUD_HEIGHT_RATIO)
	combat_host.offset_left = 0.0
	combat_host.offset_right = 0.0
	combat_host.offset_top = 0.0
	combat_host.offset_bottom = 0.0
	combat_host.stretch = true
	combat_host.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(combat_host)

	_combat_viewport = SubViewport.new()
	_combat_viewport.name = "CombatViewport"
	_combat_viewport.transparent_bg = false
	_combat_viewport.handle_input_locally = true
	_combat_viewport.physics_object_picking = true
	_combat_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	combat_host.add_child(_combat_viewport)

	_proxy_camera = Camera3D.new()
	_proxy_camera.name = "CombatCamera"
	_proxy_camera.current = true
	_combat_viewport.add_child(_proxy_camera)

	var bottom := Control.new()
	bottom.name = "BottomHUD"
	bottom.set_anchor(SIDE_LEFT, 0.0)
	bottom.set_anchor(SIDE_RIGHT, 1.0)
	bottom.set_anchor(SIDE_TOP, 1.0 - HUD_HEIGHT_RATIO)
	bottom.set_anchor(SIDE_BOTTOM, 1.0)
	bottom.offset_left = 0.0
	bottom.offset_right = 0.0
	bottom.offset_top = 0.0
	bottom.offset_bottom = 0.0
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bottom)

	var body := PanelContainer.new()
	body.name = "BottomBody"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_stylebox_override("panel", _bottom_style())
	bottom.add_child(body)

	var columns := HBoxContainer.new()
	columns.name = "ABCColumns"
	columns.add_theme_constant_override("separation", 6)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var team_panel := _make_section_panel("TeamPanel", "A · 我方队伍", "F1–F5", Color(0.21, 0.44, 0.57, 0.96))
	team_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_panel.size_flags_stretch_ratio = 0.31
	columns.add_child(team_panel)
	_build_team_slots(team_panel.get_node("Margin/VBox") as VBoxContainer)

	var hero_panel := _make_section_panel("CurrentHeroPanel", "B · 当前英雄", "HP / MP / QWERT", Color(0.40, 0.33, 0.49, 0.96))
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.size_flags_stretch_ratio = 0.43
	columns.add_child(hero_panel)
	_build_current_hero(hero_panel.get_node("Margin/VBox") as VBoxContainer)

	var equip_panel := _make_section_panel("EquipmentPanel", "C · 装备", "1–6 / G", Color(0.49, 0.39, 0.22, 0.96))
	equip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_panel.size_flags_stretch_ratio = 0.26
	columns.add_child(equip_panel)
	_build_equipment(equip_panel.get_node("Margin/VBox") as VBoxContainer)

	var debug := VBoxContainer.new()
	debug.name = "DebugDrawer"
	debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug.grow_vertical = Control.GROW_DIRECTION_END
	debug.offset_left = -320.0
	debug.offset_top = 10.0
	debug.offset_right = -10.0
	debug.offset_bottom = 360.0
	debug.add_theme_constant_override("separation", 5)
	debug.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(debug)

	_add_debug_panel(debug, "CombatMetricsPanel", "Combat Metrics", false, _build_metrics_body)
	_add_debug_panel(debug, "TrainingToolsPanel", "Training Tools", true, _build_training_body)
	_add_debug_panel(debug, "AIDebugPanel", "AI / Hitbox Debug", true, _build_ai_body)


func _bind_combat_camera() -> void:
	var stage := get_tree().current_scene
	if stage == null:
		stage = get_parent()
	if stage == null:
		return
	_source_camera = stage.get_node_or_null("CameraRig/DNFCamera") as Camera3D
	if _source_camera == null:
		return
	# Combat draws in the SubViewport, but AudioStreamPlayer3D nodes live in the
	# main scene tree. Godot only hears them through the root viewport listener,
	# so keep DNFCamera current for audio, disable root 3D draw, and prevent the
	# SubViewport camera from stealing the 3D listener.
	var root_viewport := get_viewport()
	root_viewport.disable_3d = true
	root_viewport.audio_listener_enable_3d = true
	_combat_viewport.audio_listener_enable_3d = false
	_combat_viewport.audio_listener_enable_2d = false
	_source_camera.current = true
	_ensure_audio_listener()
	_combat_viewport.world_3d = root_viewport.world_3d
	_copy_camera_settings()
	_sync_combat_camera()


func _ensure_audio_listener() -> void:
	if _source_camera == null:
		return
	_audio_listener = _source_camera.get_node_or_null("CombatAudioListener") as AudioListener3D
	if _audio_listener == null:
		_audio_listener = AudioListener3D.new()
		_audio_listener.name = "CombatAudioListener"
		_source_camera.add_child(_audio_listener)
	_audio_listener.make_current()


func _exit_tree() -> void:
	var root_viewport := get_viewport()
	if root_viewport != null:
		root_viewport.disable_3d = false


func _copy_camera_settings() -> void:
	if _source_camera == null or _proxy_camera == null:
		return
	_proxy_camera.projection = _source_camera.projection
	_proxy_camera.size = _source_camera.size
	_proxy_camera.keep_aspect = _source_camera.keep_aspect
	_proxy_camera.near = _source_camera.near
	_proxy_camera.far = _source_camera.far
	_proxy_camera.fov = _source_camera.fov
	_proxy_camera.current = true


func _sync_combat_camera() -> void:
	if _source_camera == null or _proxy_camera == null:
		return
	# Proxy camera lives under SubViewport (not in the 3D tree); local transform
	# is interpreted as the world view transform for the shared World3D.
	_proxy_camera.transform = _source_camera.global_transform
	if not is_equal_approx(_proxy_camera.size, _source_camera.size):
		_proxy_camera.size = _source_camera.size


func _make_section_panel(panel_name: String, title: String, subtitle: String, fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_style(fill))
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var sub := Label.new()
	sub.text = subtitle
	sub.modulate = Color(1, 1, 1, 0.67)
	sub.add_theme_font_size_override("font_size", 9)
	header.add_child(sub)
	return panel


func _build_team_slots(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "HeroSlots"
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	_team_slots.clear()
	for index in TEAM_SLOT_COUNT:
		var hero: Dictionary = TEAM_HEROES[index]
		var frame := AspectRatioContainer.new()
		frame.name = "HeroSlotFrame%d" % (index + 1)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.ratio = 1.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
		frame.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
		frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
		row.add_child(frame)

		var slot := PanelContainer.new()
		slot.name = "HeroSlot%d" % (index + 1)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _slot_style(false))
		slot.gui_input.connect(_on_team_slot_gui_input.bind(index))
		frame.add_child(slot)

		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 2)
		slot.add_child(inner)
		var top := HBoxContainer.new()
		inner.add_child(top)
		var idx := Label.new()
		idx.text = "%02d" % (index + 1)
		idx.add_theme_font_size_override("font_size", 8)
		idx.modulate = Color(1, 1, 1, 0.75)
		idx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(idx)
		var key := Label.new()
		key.text = "F%d" % (index + 1)
		key.add_theme_font_size_override("font_size", 8)
		key.modulate = Color(0.84, 0.95, 1.0, 0.9)
		top.add_child(key)
		var avatar := PanelContainer.new()
		avatar.custom_minimum_size = Vector2(28, 28)
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		avatar.add_theme_stylebox_override("panel", _avatar_style())
		inner.add_child(avatar)
		var avatar_label := Label.new()
		avatar_label.text = String(hero["short"])
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar_label.add_theme_font_size_override("font_size", 13)
		avatar.add_child(avatar_label)
		var hp_track := ColorRect.new()
		hp_track.custom_minimum_size = Vector2(0, 4)
		hp_track.color = Color(0, 0, 0, 0.38)
		hp_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(hp_track)
		var hp_fill := ColorRect.new()
		hp_fill.name = "MiniHpFill"
		hp_fill.color = Color(0.35, 0.87, 0.56)
		hp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		hp_fill.anchor_right = float(hero["hp"])
		hp_track.add_child(hp_fill)
		_team_slots.append(slot)


func _build_current_hero(parent: VBoxContainer) -> void:
	var content := HBoxContainer.new()
	content.name = "SelectedContent"
	content.add_theme_constant_override("separation", 6)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(content)

	var portrait_frame := AspectRatioContainer.new()
	portrait_frame.name = "HeroPortraitFrame"
	portrait_frame.ratio = 1.0
	portrait_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	portrait_frame.custom_minimum_size = Vector2(56, 56)
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(portrait_frame)
	var portrait := PanelContainer.new()
	portrait.name = "HeroPortrait"
	portrait.add_theme_stylebox_override("panel", _slot_style(false))
	portrait_frame.add_child(portrait)
	_portrait_label = Label.new()
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 20)
	_portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(_portrait_label)

	var info := VBoxContainer.new()
	info.name = "NameLevel"
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 0.85
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(info)
	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)
	_level_label = Label.new()
	_level_label.text = "Lv. 12"
	_level_label.add_theme_font_size_override("font_size", 10)
	name_row.add_child(_level_label)
	_role_label = Label.new()
	_role_label.add_theme_font_size_override("font_size", 9)
	_role_label.modulate = Color(0.84, 0.80, 0.89)
	info.add_child(_role_label)
	_hp_fill = _make_resource_bar(info, "HPBar", Color(0.35, 0.87, 0.56))
	_hp_text = _hp_fill.get_parent().get_node("Label") as Label
	_mp_fill = _make_resource_bar(info, "MPBar", Color(0.35, 0.68, 1.0))
	_mp_text = _mp_fill.get_parent().get_node("Label") as Label

	var status_row := HBoxContainer.new()
	status_row.name = "BuffDebuffRow"
	status_row.add_theme_constant_override("separation", 3)
	info.add_child(status_row)
	var buff_box := HBoxContainer.new()
	buff_box.name = "BuffContainer"
	buff_box.add_theme_constant_override("separation", 2)
	status_row.add_child(buff_box)
	_add_status_chip(buff_box, "↑", Color(0.25, 0.50, 0.32, 0.85))
	_add_status_chip(buff_box, "✦", Color(0.25, 0.50, 0.32, 0.85))
	var debuff_box := HBoxContainer.new()
	debuff_box.name = "DebuffContainer"
	debuff_box.add_theme_constant_override("separation", 2)
	status_row.add_child(debuff_box)
	_add_status_chip(debuff_box, "↓", Color(0.55, 0.27, 0.29, 0.85))
	_add_status_chip(debuff_box, "·", Color(0.12, 0.12, 0.14, 0.55))

	var skills := HBoxContainer.new()
	skills.name = "SkillContainer"
	skills.add_theme_constant_override("separation", SLOT_GAP)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills.size_flags_stretch_ratio = 1.15
	skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(skills)
	_skill_slots.clear()
	var cooling := {1: "2.4", 3: "7.8"}
	for index in SKILL_KEYS.size():
		var key: String = SKILL_KEYS[index]
		var frame := AspectRatioContainer.new()
		frame.name = "SkillFrame%s" % key
		frame.ratio = 1.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skills.add_child(frame)
		var skill := PanelContainer.new()
		skill.name = "SkillSlot%s" % key
		skill.add_theme_stylebox_override("panel", _skill_style())
		frame.add_child(skill)
		var stack := Control.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		skill.add_child(stack)
		var glyph := Label.new()
		glyph.text = key
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 16)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(glyph)
		var key_badge := Label.new()
		key_badge.text = key
		key_badge.add_theme_font_size_override("font_size", 8)
		key_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		key_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		key_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		key_badge.offset_left = -14.0
		key_badge.offset_top = -12.0
		key_badge.offset_right = -2.0
		key_badge.offset_bottom = -1.0
		stack.add_child(key_badge)
		if cooling.has(index):
			var mask := ColorRect.new()
			mask.name = "CooldownMask"
			mask.color = Color(0.02, 0.04, 0.06, 0.63)
			mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stack.add_child(mask)
			var cd := Label.new()
			cd.name = "CooldownLabel"
			cd.text = String(cooling[index])
			cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cd.add_theme_font_size_override("font_size", 11)
			cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stack.add_child(cd)
		_skill_slots.append(skill)


func _build_equipment(parent: VBoxContainer) -> void:
	# Left-aligned compact cluster (same inner margin as A via section Margin=6).
	# Row1: 1 2 3 G   Row2: 4 5 6    Right half reserved for hero attrs.
	var content := HBoxContainer.new()
	content.name = "EquipContent"
	content.add_theme_constant_override("separation", SLOT_GAP)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(content)

	var cluster := VBoxContainer.new()
	cluster.name = "EquipCluster"
	cluster.add_theme_constant_override("separation", SLOT_GAP)
	cluster.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cluster.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(cluster)

	var row1 := HBoxContainer.new()
	row1.name = "EquipRow1"
	row1.add_theme_constant_override("separation", SLOT_GAP)
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	cluster.add_child(row1)
	for index in 3:
		row1.add_child(_make_equipment_slot(index + 1, "装", str(index + 1), false))
	row1.add_child(_make_equipment_slot(0, "特", "G", true))

	var row2 := HBoxContainer.new()
	row2.name = "EquipRow2"
	row2.add_theme_constant_override("separation", SLOT_GAP)
	row2.alignment = BoxContainer.ALIGNMENT_BEGIN
	cluster.add_child(row2)
	for index in range(3, 6):
		row2.add_child(_make_equipment_slot(index + 1, "装", str(index + 1), false))

	var attrs := PanelContainer.new()
	attrs.name = "AttrReserve"
	attrs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attrs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attrs.add_theme_stylebox_override("panel", _attr_reserve_style())
	content.add_child(attrs)
	var attrs_label := Label.new()
	attrs_label.name = "AttrPlaceholder"
	attrs_label.text = "属性"
	attrs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attrs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attrs_label.add_theme_font_size_override("font_size", 11)
	attrs_label.modulate = Color(1, 1, 1, 0.35)
	attrs.add_child(attrs_label)


func _make_equipment_slot(index: int, glyph: String, key_text: String, is_special: bool) -> AspectRatioContainer:
	var frame := AspectRatioContainer.new()
	frame.name = "SpecialFrame" if is_special else ("EquipFrame%d" % index)
	frame.ratio = 1.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.custom_minimum_size = Vector2(EQUIP_SLOT_PX, EQUIP_SLOT_PX)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var slot := PanelContainer.new()
	slot.name = "SpecialEquipmentSlot" if is_special else ("EquipmentSlot%d" % index)
	slot.add_theme_stylebox_override("panel", _special_style() if is_special else _slot_style(false))
	frame.add_child(slot)

	var label := Label.new()
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	slot.add_child(label)

	var key := Label.new()
	key.text = key_text
	key.add_theme_font_size_override("font_size", 8)
	key.modulate = Color(0.96, 0.89, 0.74)
	key.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	key.grow_vertical = Control.GROW_DIRECTION_BEGIN
	key.offset_left = -12.0
	key.offset_top = -12.0
	key.offset_right = -2.0
	key.offset_bottom = -1.0
	slot.add_child(key)
	return frame


func _add_debug_panel(parent: VBoxContainer, panel_name: String, title: String, collapsed: bool, body_builder: Callable) -> void:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.add_theme_stylebox_override("panel", _debug_style())
	parent.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	var head := Button.new()
	head.name = "Header"
	head.text = "%s    %s" % [title, "⌄" if collapsed else "⌃"]
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_font_size_override("font_size", 11)
	vbox.add_child(head)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 3)
	body.visible = not collapsed
	vbox.add_child(body)
	body_builder.call(body)
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = "%s    %s" % [title, "⌄" if not body.visible else "⌃"]
	)


func _build_metrics_body(body: VBoxContainer) -> void:
	_add_metric_row(body, "DPS", "12,486", true)
	_add_metric_row(body, "HPS", "1,940", true)
	_add_metric_row(body, "Damage Taken", "3,208", false)
	_add_metric_row(body, "Crit Rate", "26.4%", false)
	_add_metric_row(body, "Buff Uptime", "84.1%", false)


func _build_training_body(body: VBoxContainer) -> void:
	_add_metric_row(body, "Dummy HP", "∞", false)
	_add_metric_row(body, "Infinite MP", "ON", false)
	_add_metric_row(body, "Clear Cooldown", "READY", false)
	var separator := HSeparator.new()
	body.add_child(separator)
	_roster_panel = TrainingRosterPanel.new()
	_roster_panel.name = "TrainingRosterPanel"
	body.add_child(_roster_panel)


func _build_ai_body(body: VBoxContainer) -> void:
	_add_metric_row(body, "AI State", "Combat", false)
	_add_metric_row(body, "Hitbox View", "OFF", false)
	_add_metric_row(body, "Collision View", "OFF", false)


func _add_metric_row(parent: VBoxContainer, label_text: String, value_text: String, good: bool) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.78, 0.84, 0.82)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 10)
	value.modulate = Color(0.62, 0.91, 0.74) if good else Color(1, 1, 1)
	row.add_child(value)


func _make_resource_bar(parent: VBoxContainer, bar_name: String, fill_color: Color) -> ColorRect:
	var track := ColorRect.new()
	track.name = bar_name
	track.custom_minimum_size = Vector2(0, 12)
	track.color = Color(0, 0, 0, 0.32)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = fill_color
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = 0.5
	track.add_child(fill)
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(label)
	return fill


func _add_status_chip(parent: HBoxContainer, text: String, color: Color) -> void:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(14, 14)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.2)
	chip.add_theme_stylebox_override("panel", style)
	parent.add_child(chip)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	chip.add_child(label)


func _on_team_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hero(index, true)


func _select_hero(index: int, _announce: bool) -> void:
	_selected_index = clampi(index, 0, TEAM_HEROES.size() - 1)
	for slot_index in _team_slots.size():
		var slot := _team_slots[slot_index]
		slot.add_theme_stylebox_override("panel", _slot_style(slot_index == _selected_index))
	var hero: Dictionary = TEAM_HEROES[_selected_index]
	_portrait_label.text = String(hero["short"])
	_name_label.text = String(hero["name"])
	_role_label.text = String(hero["role"])
	_hp_fill.anchor_right = float(hero["hp"])
	_mp_fill.anchor_right = float(hero["mp"])
	_hp_text.text = "HP %d%%" % int(round(float(hero["hp"]) * 100.0))
	_mp_text.text = "MP %d%%" % int(round(float(hero["mp"]) * 100.0))


func _bottom_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 1.0)
	style.border_color = Color(1, 1, 1, 0.10)
	style.border_width_top = 1
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _section_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.82, 0.90, 0.97, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _slot_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.07, 0.35)
	style.border_color = Color(1, 1, 1, 0.76) if selected else Color(1, 1, 1, 0.24)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _avatar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.10)
	style.border_color = Color(1, 1, 1, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	return style


func _skill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.45, 0.34, 0.20, 0.86)
	style.border_color = Color(1, 1, 1, 0.23)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _special_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.41, 0.34, 0.55, 0.55)
	style.border_color = Color(0.86, 0.79, 1.0, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _attr_reserve_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	style.border_color = Color(1, 1, 1, 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _debug_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.11, 0.09, 0.84)
	style.border_color = Color(0.70, 0.86, 0.80, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 6
	return style
