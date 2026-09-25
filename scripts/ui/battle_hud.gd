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
var _selected_index := 0
var _selected_hero: Node3D
var _team_slots: Array[Control] = []
var _team_heroes: Array[Node3D] = []
var _team_slot_row: HBoxContainer
var _team_hint: Label
var _portrait_texture: TextureRect
var _portrait_fallback_label: Label
var _name_label: Label
var _level_label: Label
var _role_label: Label
var _hp_fill: ColorRect
var _mp_fill: ColorRect
var _hp_text: Label
var _mp_text: Label
var _skill_slots: Array[Control] = []
var _skill_icons: Array[TextureRect] = []
var _skill_glyphs: Array[Label] = []
var _skill_cooldown_masks: Array[ColorRect] = []
var _skill_cooldown_labels: Array[Label] = []
var _portrait_texture_cache: Dictionary = {}
var _roster_panel: TrainingRosterPanel
var _source_camera: Camera3D
var _proxy_camera: Camera3D
var _combat_viewport: SubViewport
var _audio_listener: AudioListener3D
var _metrics_mode: StringName = &"damage"
var _metrics_rows: VBoxContainer
var _metrics_summary: Label
var _metrics_refresh_timer := 0.0
var _hero_refresh_timer := 0.0


func _ready() -> void:
	layer = 20
	_build()
	if _roster_panel != null and _roster_panel.roster_changed.is_connected(_on_roster_changed) == false:
		_roster_panel.roster_changed.connect(_on_roster_changed)
	_refresh_team_roster()
	var combat_stats := get_node_or_null("/root/CombatStats")
	if combat_stats != null and combat_stats.has_signal("updated"):
		combat_stats.connect("updated", _refresh_combat_metrics)
	_refresh_combat_metrics()
	call_deferred(&"_bind_combat_camera")


func _process(_delta: float) -> void:
	_sync_combat_camera()
	_metrics_refresh_timer -= _delta
	if _metrics_refresh_timer <= 0.0:
		_metrics_refresh_timer = 0.25
		_refresh_combat_metrics()
	_hero_refresh_timer -= _delta
	if _hero_refresh_timer <= 0.0:
		_hero_refresh_timer = 0.1
		_update_team_health_bars()
		_update_current_hero_data()


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
	_team_hint = team_panel.get_node("Margin/VBox/Header/Subtitle") as Label
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
	sub.name = "Subtitle"
	sub.text = subtitle
	sub.modulate = Color(1, 1, 1, 0.67)
	sub.add_theme_font_size_override("font_size", 9)
	header.add_child(sub)
	return panel


func _build_team_slots(parent: VBoxContainer) -> void:
	_team_slot_row = HBoxContainer.new()
	_team_slot_row.name = "HeroSlots"
	_team_slot_row.add_theme_constant_override("separation", 4)
	_team_slot_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_team_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(_team_slot_row)


func _make_team_slot(hero: Node3D, index: int, seat: Control) -> PanelContainer:
	var frame := AspectRatioContainer.new()
	frame.name = "HeroSlotFrame%d" % (index + 1)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.ratio = 1.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	seat.add_child(frame)

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
	var avatar := TextureRect.new()
	avatar.name = "HeroAvatar"
	avatar.custom_minimum_size = Vector2(52, 52)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.clip_contents = true
	avatar.texture = _hero_portrait(hero)
	inner.add_child(avatar)
	var name_label := Label.new()
	name_label.text = _hero_display_name(hero)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.clip_text = true
	inner.add_child(name_label)
	var hp_track := ColorRect.new()
	hp_track.name = "HeroHpTrack"
	hp_track.custom_minimum_size = Vector2(0, 4)
	hp_track.color = Color(0, 0, 0, 0.38)
	hp_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(hp_track)
	var hp_fill := ColorRect.new()
	hp_fill.name = "MiniHpFill"
	hp_fill.color = Color(0.35, 0.87, 0.56)
	hp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	hp_fill.anchor_right = _health_ratio(hero)
	hp_track.add_child(hp_fill)
	return slot


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
	_portrait_texture = TextureRect.new()
	_portrait_texture.name = "PortraitTexture"
	_portrait_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_texture.clip_contents = true
	portrait.add_child(_portrait_texture)
	_portrait_fallback_label = Label.new()
	_portrait_fallback_label.name = "PortraitFallback"
	_portrait_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_fallback_label.add_theme_font_size_override("font_size", 20)
	_portrait_fallback_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(_portrait_fallback_label)

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
	_skill_icons.clear()
	_skill_glyphs.clear()
	_skill_cooldown_masks.clear()
	_skill_cooldown_labels.clear()
	for index in SKILL_KEYS.size():
		var key: String = SKILL_KEYS[index]
		var frame := AspectRatioContainer.new()
		frame.name = "SkillFrame%s" % key
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.ratio = 1.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
		skills.add_child(frame)

		var slot := PanelContainer.new()
		slot.name = "SkillSlot%s" % key
		slot.add_theme_stylebox_override("panel", _skill_style())
		frame.add_child(slot)

		var stack := Control.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(stack)
		var icon := TextureRect.new()
		icon.name = "SkillIcon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
		_skill_icons.append(icon)
		var glyph := Label.new()
		glyph.name = "SkillGlyph"
		glyph.text = key
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 16)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(glyph)
		_skill_glyphs.append(glyph)
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
		var mask := ColorRect.new()
		mask.name = "CooldownMask"
		mask.color = Color(0.02, 0.04, 0.06, 0.68)
		mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mask.visible = false
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(mask)
		_skill_cooldown_masks.append(mask)
		var cd := Label.new()
		cd.name = "CooldownLabel"
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.add_theme_font_size_override("font_size", 11)
		cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd.visible = false
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(cd)
		_skill_cooldown_labels.append(cd)
		_skill_slots.append(slot)


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
	var tabs := HBoxContainer.new()
	tabs.name = "MetricTabs"
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	for tab: Array in [["伤害", &"damage"], ["治疗", &"healing"], ["Buff", &"buff"]]:
		var button := Button.new()
		button.text = String(tab[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 22
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_set_metrics_mode.bind(StringName(tab[1])))
		tabs.add_child(button)
	_metrics_summary = Label.new()
	_metrics_summary.name = "EncounterSummary"
	_metrics_summary.add_theme_font_size_override("font_size", 10)
	_metrics_summary.modulate = Color(0.78, 0.88, 0.91)
	body.add_child(_metrics_summary)
	var scroll := ScrollContainer.new()
	scroll.name = "MetricRowsScroll"
	scroll.custom_minimum_size = Vector2(0, 118)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_metrics_rows = VBoxContainer.new()
	_metrics_rows.name = "MetricRows"
	_metrics_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metrics_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(_metrics_rows)
	var reset := Button.new()
	reset.name = "ResetEncounterStats"
	reset.text = "重置本场统计"
	reset.custom_minimum_size.y = 21
	reset.add_theme_font_size_override("font_size", 9)
	reset.pressed.connect(_reset_combat_metrics)
	body.add_child(reset)


func _set_metrics_mode(mode: StringName) -> void:
	_metrics_mode = mode
	_refresh_combat_metrics()


func _reset_combat_metrics() -> void:
	var combat_stats := get_node_or_null("/root/CombatStats")
	if combat_stats != null:
		combat_stats.call("reset_encounter")


func _refresh_combat_metrics() -> void:
	if _metrics_rows == null or _metrics_summary == null:
		return
	for child: Node in _metrics_rows.get_children():
		_metrics_rows.remove_child(child)
		child.queue_free()
	var combat_stats := get_node_or_null("/root/CombatStats")
	if combat_stats == null:
		_metrics_summary.text = "战斗事件统计不可用"
		return
	if _metrics_mode == &"buff":
		var buff_data: Dictionary = combat_stats.call("buff_uptime_snapshot")
		var buffs: Array = buff_data.rows
		var encounter_seconds := maxf(float(buff_data.elapsed), 0.1)
		_metrics_summary.text = "Buff 覆盖时间 · 本场 %.0f 秒" % encounter_seconds
		if buffs.is_empty():
			_add_empty_metric_row("等待 Buff 事件…")
			return
		for buff: Dictionary in buffs:
			var uptime := minf(1.0, float(buff.seconds) / encounter_seconds)
			var buff_parts := String(buff.name).split(":", false, 1)
			var owner_name := String(buff_parts[1]) if buff_parts.size() > 1 else ""
			var buff_name := String(buff_parts[0])
			buff_name = buff_name.replace("breaker_speed", "破舰强化")
			buff_name = buff_name.replace("black_sail", "黑帆守护")
			buff_name = buff_name.replace("seven_seas_rum", "七海酒桶")
			_add_metric_entry("%s · %s" % [owner_name, buff_name], "覆盖 %.1f 秒" % float(buff.seconds), Color(0.76, 0.63, 1.0), "%.0f%%" % (uptime * 100.0), uptime, Color(0.70, 0.49, 0.96))
		return
	var snapshot: Dictionary = combat_stats.call("snapshot", _metrics_mode)
	var rows: Array = snapshot.rows
	var total := 0.0
	var window_total := 0.0
	for row: Dictionary in rows:
		total += float(row.total)
		window_total += float(row.window)
	var rate_label := "DPS" if _metrics_mode == &"damage" else "HPS"
	var unit_label := "总伤害" if _metrics_mode == &"damage" else "有效治疗"
	_metrics_summary.text = "%s %.0f · 10 秒 %.0f · 战斗 %.0f 秒" % [unit_label, total, window_total, float(snapshot.elapsed)]
	if rows.is_empty():
		_add_empty_metric_row("等待战斗事件…")
		return
	for row: Dictionary in rows:
		var actions: Dictionary = row.actions
		var top_action := ""
		var top_value := -1.0
		for action: String in actions:
			if float(actions[action]) > top_value:
				top_value = float(actions[action])
				top_action = action
		var share := float(row.total) / maxf(total, 1.0)
		if top_action.begins_with("attack"):
			top_action = "普攻"
		var detail := "%s · %d 次 · 占比 %.0f%%" % [top_action, int(row.events), share * 100.0]
		var value_text := "%.0f · %s %.0f" % [float(row.total), rate_label, float(row.rate)]
		var title_color := _team_color(String(row.team))
		var metric_color := Color(0.24, 0.76, 0.96) if _metrics_mode == &"damage" else Color(0.27, 0.86, 0.58)
		_add_metric_entry(String(row.name), detail, title_color, value_text, share, metric_color, _team_display_name(String(row.team)))


func _add_empty_metric_row(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(0.63, 0.69, 0.73)
	_metrics_rows.add_child(label)


func _team_color(team: String) -> Color:
	if team == "friendly":
		return Color(0.50, 0.83, 1.0)
	if team == "enemy":
		return Color(1.0, 0.53, 0.46)
	return Color(0.88, 0.80, 0.53)


func _team_display_name(team: String) -> String:
	match team:
		"friendly": return "蓝方"
		"enemy": return "红方"
		"neutral": return "中立"
	return "阵营未知"


func _add_metric_entry(title: String, detail: String, accent: Color, value_text := "", progress := -1.0, progress_color := Color.WHITE, tooltip := "") -> void:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 1)
	_metrics_rows.add_child(entry)
	var header := HBoxContainer.new()
	entry.add_child(header)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.modulate = accent
	title_label.tooltip_text = tooltip
	header.add_child(title_label)
	if not value_text.is_empty():
		var value := Label.new()
		value.text = value_text
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = 138
		value.add_theme_font_size_override("font_size", 10)
		header.add_child(value)
	if progress >= 0.0:
		var bar := ProgressBar.new()
		bar.name = "ContributionBar"
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = clampf(progress * 100.0, 0.0, 100.0)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.01, 0.025, 0.04, 0.9)
		track.content_margin_left = 0.0
		track.content_margin_right = 0.0
		track.content_margin_top = 0.0
		track.content_margin_bottom = 0.0
		track.set_corner_radius_all(3)
		var fill := StyleBoxFlat.new()
		fill.bg_color = progress_color
		fill.content_margin_left = 0.0
		fill.content_margin_right = 0.0
		fill.content_margin_top = 0.0
		fill.content_margin_bottom = 0.0
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", track)
		bar.add_theme_stylebox_override("fill", fill)
		entry.add_child(bar)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 8)
	detail_label.modulate = Color(0.69, 0.75, 0.78)
	entry.add_child(detail_label)


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


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode < KEY_F1 or event.keycode > KEY_F5:
		return
	var index := int(event.keycode) - int(KEY_F1)
	if index < _team_heroes.size():
		_select_hero(index, true)


func _on_roster_changed(team: StringName, _heroes: Array[StringName]) -> void:
	if team == &"friendly":
		_refresh_team_roster()


func _refresh_team_roster() -> void:
	var previously_selected := _selected_hero
	_team_heroes = _get_friendly_roster_heroes()
	for child: Node in _team_slot_row.get_children():
		_team_slot_row.remove_child(child)
		child.queue_free()
	_team_slots.clear()
	for index in TEAM_SLOT_COUNT:
		var seat := Control.new()
		seat.name = "HeroSeat%d" % (index + 1)
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat.size_flags_vertical = Control.SIZE_EXPAND_FILL
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_team_slot_row.add_child(seat)
		if index < _team_heroes.size():
			_team_slots.append(_make_team_slot(_team_heroes[index], index, seat))
	if _team_heroes.is_empty():
		_selected_hero = null
		_selected_index = 0
		_update_current_hero_data()
		return
	_selected_index = _team_heroes.find(previously_selected) if _team_heroes.has(previously_selected) else 0
	_select_hero(_selected_index, false)
	_update_team_health_bars()


func _get_friendly_roster_heroes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _roster_panel == null or get_tree().current_scene == null:
		return result
	var characters := get_tree().current_scene.get_node_or_null("Characters")
	if characters == null:
		return result
	var roster_ids: Array = _roster_panel.roster.get(&"friendly", [])
	for hero_id: StringName in roster_ids:
		for candidate: Node in characters.get_children():
			if not candidate is Node3D or not candidate.has_method("get_combat_unit_definition"):
				continue
			var definition := candidate.call("get_combat_unit_definition") as UnitDefinition
			if definition != null and definition.id == hero_id and candidate.is_inside_tree() and not candidate.is_queued_for_deletion():
				result.append(candidate as Node3D)
				break
	return result


func _select_hero(index: int, _announce: bool) -> void:
	if _team_heroes.is_empty():
		return
	_selected_index = clampi(index, 0, _team_heroes.size() - 1)
	_selected_hero = _team_heroes[_selected_index]
	for slot_index in _team_slots.size():
		var slot := _team_slots[slot_index]
		slot.add_theme_stylebox_override("panel", _slot_style(slot_index == _selected_index))
	_update_current_hero_data()


func _update_current_hero_data() -> void:
	if not is_instance_valid(_selected_hero):
		_portrait_texture.texture = null
		_portrait_fallback_label.text = "—"
		_name_label.text = "无出战英雄"
		_level_label.text = ""
		_role_label.text = "请在训练编队中启用英雄"
		_hp_fill.get_parent().visible = false
		_mp_fill.get_parent().visible = false
		_update_skill_bar()
		return
	var portrait := _hero_portrait(_selected_hero)
	_portrait_texture.texture = portrait
	_portrait_fallback_label.text = "" if portrait != null else _hero_short_name(_selected_hero)
	_name_label.text = _hero_display_name(_selected_hero)
	_role_label.text = _hero_role_text(_selected_hero)
	var level := 1
	if _has_property(_selected_hero, &"level"):
		level = int(_selected_hero.get("level"))
	elif _has_property(_selected_hero, &"current_level"):
		level = int(_selected_hero.get("current_level"))
	_level_label.text = "Lv. %d" % maxi(level, 1)
	var max_health := float(_selected_hero.get("max_health")) if _has_property(_selected_hero, &"max_health") else 0.0
	var current_health := float(_selected_hero.get("current_health")) if _has_property(_selected_hero, &"current_health") else max_health
	_hp_fill.get_parent().visible = max_health > 0.0
	if max_health > 0.0:
		_hp_fill.anchor_right = clampf(current_health / max_health, 0.0, 1.0)
		_hp_text.text = "HP %d / %d" % [roundi(maxf(current_health, 0.0)), roundi(max_health)]
	var current_mana_property := &"current_mana" if _has_property(_selected_hero, &"current_mana") else &"current_mp"
	var max_mana_property := &"max_mana" if _has_property(_selected_hero, &"max_mana") else &"max_mp"
	var has_mana := _has_property(_selected_hero, current_mana_property) and _has_property(_selected_hero, max_mana_property)
	var max_mana := float(_selected_hero.get(max_mana_property)) if has_mana else 0.0
	_mp_fill.get_parent().visible = has_mana and max_mana > 0.0
	if has_mana and max_mana > 0.0:
		var current_mana := float(_selected_hero.get(current_mana_property))
		_mp_fill.anchor_right = clampf(current_mana / max_mana, 0.0, 1.0)
		_mp_text.text = "MP %d / %d" % [roundi(maxf(current_mana, 0.0)), roundi(max_mana)]
	_update_skill_bar()


func _update_skill_bar() -> void:
	var database := CombatData.database()
	var unit_definition := _hero_unit_definition(_selected_hero)
	for index in _skill_icons.size():
		var skill_slot := StringName(SKILL_KEYS[index].to_lower())
		var skill: SkillDefinition
		if database != null and unit_definition != null:
			for skill_id: StringName in unit_definition.skill_ids:
				var candidate := database.get_skill(skill_id)
				if candidate != null and candidate.source_slot == skill_slot:
					skill = candidate
					break
		var icon: Texture2D
		if database != null and skill != null and not skill.icon_profile_id.is_empty():
			var icon_profile := database.get_asset_profile(skill.icon_profile_id)
			if icon_profile != null and icon_profile.asset_type == "skill_icon" and ResourceLoader.exists(icon_profile.resource_file):
				icon = load(icon_profile.resource_file) as Texture2D
		_skill_icons[index].texture = icon
		_skill_icons[index].visible = icon != null
		_skill_glyphs[index].visible = icon == null
		var skill_name := skill.display_name if skill != null else SKILL_KEYS[index]
		var cooldown: Dictionary = _selected_hero.call("get_skill_cooldown_state", skill_slot) if is_instance_valid(_selected_hero) and _selected_hero.has_method("get_skill_cooldown_state") else {}
		var remaining := maxf(float(cooldown.get("remaining", 0.0)), 0.0)
		var total := maxf(float(cooldown.get("total", 0.0)), 0.0)
		var cooling := remaining > 0.05
		_skill_cooldown_masks[index].visible = cooling
		_skill_cooldown_labels[index].visible = cooling
		_skill_cooldown_labels[index].text = _format_cooldown(remaining)
		_skill_slots[index].tooltip_text = "%s  %s\n冷却：%.1f 秒%s" % [SKILL_KEYS[index], skill_name, total, "（冷却中）" if cooling else "（就绪）"]


func _format_cooldown(seconds: float) -> String:
	var remaining := ceili(seconds)
	if remaining >= 60:
		return "%d:%02d" % [floori(float(remaining) / 60.0), remaining % 60]
	return str(remaining)


func _update_team_health_bars() -> void:
	for index in mini(_team_heroes.size(), _team_slots.size()):
		var fill := _team_slots[index].find_child("MiniHpFill", true, false) as ColorRect
		if fill != null:
			fill.anchor_right = _health_ratio(_team_heroes[index])


func _health_ratio(hero: Node) -> float:
	if not is_instance_valid(hero) or not _has_property(hero, &"max_health") or not _has_property(hero, &"current_health"):
		return 0.0
	var maximum := float(hero.get("max_health"))
	return clampf(float(hero.get("current_health")) / maxf(maximum, 1.0), 0.0, 1.0)


func _hero_unit_definition(hero: Node) -> UnitDefinition:
	if not is_instance_valid(hero) or not hero.has_method("get_combat_unit_definition"):
		return null
	return hero.call("get_combat_unit_definition") as UnitDefinition


func _hero_portrait(hero: Node) -> Texture2D:
	var unit_definition := _hero_unit_definition(hero)
	if unit_definition == null or unit_definition.portrait_profile_id.is_empty():
		return null
	if _portrait_texture_cache.has(unit_definition.portrait_profile_id):
		return _portrait_texture_cache[unit_definition.portrait_profile_id] as Texture2D
	var database := CombatData.database()
	if database == null:
		return null
	var profile := database.get_asset_profile(unit_definition.portrait_profile_id)
	if profile == null or profile.asset_type != "hero_portrait" or not ResourceLoader.exists(profile.resource_file):
		return null
	var texture := load(profile.resource_file) as Texture2D
	if texture != null:
		_portrait_texture_cache[unit_definition.portrait_profile_id] = texture
	return texture


func _hero_role_text(hero: Node) -> String:
	var definition := _hero_unit_definition(hero)
	if definition == null:
		return "英雄"
	var database := CombatData.database()
	if database == null:
		return String(definition.role)
	var hero_class := database.get_hero_class(definition.class_id)
	if hero_class != null:
		return String(hero_class.get("display_name"))
	return String(definition.role)


func _hero_display_name(hero: Node) -> String:
	if hero != null and hero.has_method("get_display_name"):
		return String(hero.call("get_display_name"))
	return String(hero.name) if hero != null else "未知英雄"


func _hero_short_name(hero: Node) -> String:
	var display_name := _hero_display_name(hero)
	return display_name.substr(0, 1) if not display_name.is_empty() else "?"


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false


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
