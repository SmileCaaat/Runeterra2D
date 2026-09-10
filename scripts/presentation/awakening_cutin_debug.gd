extends Control

## Standalone harness for Awakening Cut-In mask / crop / multi-slot layout / voice.
## Run this scene directly. It does not use the AwakeningCutIn autoload.

const LAYER_SCENE := preload("res://scenes/ui/awakening_cutin/awakening_cutin_layer.tscn")
const CutInLook = preload("res://scripts/presentation/awakening_cutin_look.gd")
const GAREN_ID := &"garen_seven_seas_awaken"
const RYZE_ID := &"ryze_desperate_power_awaken"

const FILTER_LABELS := ["无", "电影感", "冷色", "暖色", "水墨", "色散"]
const GRADIENT_LABELS := ["无渐变", "左→右", "上→下", "沿斜切"]

var _layer: AwakeningCutInManager
var _status: Label
var _scale_slider: HSlider
var _offset_x_slider: HSlider
var _offset_y_slider: HSlider
var _slant_slider: HSlider
var _panel_w_slider: HSlider
var _panel_h_slider: HSlider
var _panel_alpha_slider: HSlider
var _edge_fade_slider: HSlider
var _grad_start_slider: HSlider
var _grad_end_slider: HSlider
var _filter_strength_slider: HSlider
var _vignette_slider: HSlider
var _sat_slider: HSlider
var _contrast_slider: HSlider
var _brightness_slider: HSlider
var _theme_mix_slider: HSlider
var _stripe_slider: HSlider
var _glow_slider: HSlider
var _darken_slider: HSlider
var _gradient_mode: OptionButton
var _filter_mode: OptionButton
var _voice_db_slider: HSlider
var _mute_voice: CheckBox
var _static_mode: CheckBox
var _voice_label: Label
var _last_static_ids: Array[StringName] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_layer = LAYER_SCENE.instantiate() as AwakeningCutInManager
	_layer.name = "DebugCutInLayer"
	# Keep below the debug toolbar CanvasLayer so controls stay visible/clickable.
	_layer.layer = 40
	add_child(_layer)
	_build_toolbar()
	_status.text = "先点角色按钮。勾选常态显示=定格；可调框体尺寸/透明度/渐变/滤镜。"


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.14, 0.20, 0.27, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var safe := ColorRect.new()
	safe.name = "CombatSafeHint"
	safe.anchor_left = 0.25
	safe.anchor_top = 0.22
	safe.anchor_right = 0.75
	safe.anchor_bottom = 0.78
	safe.offset_left = 0.0
	safe.offset_top = 0.0
	safe.offset_right = 0.0
	safe.offset_bottom = 0.0
	safe.color = Color(0.18, 0.42, 0.28, 0.22)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var safe_label := Label.new()
	safe_label.text = "中央战斗安全区示意（约勿长期遮死）"
	safe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	safe_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_label.add_theme_font_size_override("font_size", 18)
	safe_label.modulate = Color(0.75, 0.95, 0.82, 0.85)
	safe.add_child(safe_label)


func _build_toolbar() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "DebugToolbarLayer"
	hud_layer.layer = 100
	add_child(hud_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.42
	panel.anchor_bottom = 1.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.offset_right = -6.0
	panel.offset_bottom = -10.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.96)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 6)
	scroll.add_child(root)

	var title := Label.new()
	title.text = "Awakening Cut-In Debug · 框体 / 透明度 / 滤镜"
	title.add_theme_font_size_override("font_size", 15)
	root.add_child(title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	root.add_child(mode_row)
	_static_mode = CheckBox.new()
	_static_mode.text = "常态显示（定格即时生效）"
	_static_mode.button_pressed = true
	_static_mode.toggled.connect(_on_static_mode_toggled)
	mode_row.add_child(_static_mode)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	_add_button(row, "盖伦", func() -> void: _trigger_ids([GAREN_ID]))
	_add_button(row, "瑞兹", func() -> void: _trigger_ids([RYZE_ID]))
	_add_button(row, "双人", func() -> void: _trigger_ids([GAREN_ID, RYZE_ID]))
	_add_button(row, "三人", func() -> void: _trigger_ids([GAREN_ID, RYZE_ID, GAREN_ID]))
	_add_button(row, "四人", func() -> void: _trigger_ids([GAREN_ID, RYZE_ID, GAREN_ID, RYZE_ID]))
	_add_button(row, "停止", func() -> void: _stop_all())

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 6)
	root.add_child(audio_row)
	_mute_voice = CheckBox.new()
	_mute_voice.text = "静音语音"
	_mute_voice.button_pressed = true
	_mute_voice.toggled.connect(func(pressed: bool) -> void: _apply_voice_output(pressed))
	audio_row.add_child(_mute_voice)
	_add_button(audio_row, "盖伦语音", func() -> void: _play_voice_only(GAREN_ID))
	_add_button(audio_row, "瑞兹语音", func() -> void: _play_voice_only(RYZE_ID))
	_add_button(audio_row, "停语音", func() -> void: _stop_voice())
	_voice_db_slider = _add_slider(audio_row, "语音 dB", -24.0, 6.0, 0.0)
	_voice_db_slider.value_changed.connect(func(_v: float) -> void: _sync_live_voice_volume())
	_voice_label = Label.new()
	_voice_label.add_theme_font_size_override("font_size", 11)
	_voice_label.modulate = Color(0.85, 0.9, 0.95)
	_voice_label.custom_minimum_size = Vector2(180, 0)
	audio_row.add_child(_voice_label)
	_refresh_voice_label()

	_section(root, "立绘裁切")
	var tune := _grid_row(root)
	_scale_slider = _add_slider(tune, "立绘缩放", 0.4, 2.2, CutInLook.PORTRAIT_SCALE)
	_offset_x_slider = _add_slider(tune, "偏移X", -0.35, 0.35, CutInLook.PORTRAIT_OFFSET.x)
	_offset_y_slider = _add_slider(tune, "偏移Y", -0.35, 0.35, CutInLook.PORTRAIT_OFFSET.y)
	_slant_slider = _add_slider(tune, "斜切", -0.55, 0.55, CutInLook.SLANT)

	_section(root, "框体尺寸 / 背景压暗")
	var frame := _grid_row(root)
	_panel_w_slider = _add_slider(frame, "框宽倍率", 0.45, 1.35, CutInLook.PANEL_SCALE.x)
	_panel_h_slider = _add_slider(frame, "框高倍率", 0.45, 1.35, CutInLook.PANEL_SCALE.y)
	_darken_slider = _add_slider(frame, "背景压暗α", 0.0, 0.85, CutInLook.DARKEN_ALPHA)

	_section(root, "透明度 / 边缘渐隐 / 渐变α")
	var alpha_row := _grid_row(root)
	_panel_alpha_slider = _add_slider(alpha_row, "整体透明度", 0.15, 1.0, CutInLook.GLOBAL_ALPHA)
	_edge_fade_slider = _add_slider(alpha_row, "边缘渐隐", 0.0, 0.35, CutInLook.EDGE_FADE)
	_grad_start_slider = _add_slider(alpha_row, "渐变α起点", 0.0, 1.0, CutInLook.GRADIENT_ALPHA_START)
	_grad_end_slider = _add_slider(alpha_row, "渐变α终点", 0.0, 1.0, CutInLook.GRADIENT_ALPHA_END)

	var mode_opts := HBoxContainer.new()
	mode_opts.add_theme_constant_override("separation", 10)
	root.add_child(mode_opts)
	_gradient_mode = _add_option(mode_opts, "渐变方向", GRADIENT_LABELS, CutInLook.GRADIENT_MODE)
	_filter_mode = _add_option(mode_opts, "滤镜", FILTER_LABELS, CutInLook.FILTER_MODE)

	_section(root, "滤镜 / Shader 观感")
	var look := _grid_row(root)
	_filter_strength_slider = _add_slider(look, "滤镜强度", 0.0, 1.0, CutInLook.FILTER_STRENGTH)
	_vignette_slider = _add_slider(look, "暗角", 0.0, 1.0, CutInLook.VIGNETTE_STRENGTH)
	_sat_slider = _add_slider(look, "饱和度", 0.0, 2.0, CutInLook.SATURATION)
	_contrast_slider = _add_slider(look, "对比度", 0.2, 2.0, CutInLook.CONTRAST)
	var look2 := _grid_row(root)
	_brightness_slider = _add_slider(look2, "亮度", -0.35, 0.35, CutInLook.BRIGHTNESS)
	_theme_mix_slider = _add_slider(look2, "主题色混入", 0.0, 0.8, CutInLook.THEME_MIX)
	_stripe_slider = _add_slider(look2, "扫描线", 0.0, 0.25, CutInLook.STRIPE_AMOUNT)
	_glow_slider = _add_slider(look2, "边缘光", 0.0, 2.0, CutInLook.EDGE_GLOW_AMOUNT)

	var apply_row := HBoxContainer.new()
	apply_row.add_theme_constant_override("separation", 8)
	root.add_child(apply_row)
	_add_button(apply_row, "应用到当前槽", func() -> void: _apply_tune_to_active())
	_add_button(apply_row, "重置观感", func() -> void: _reset_look_defaults())

	for slider: HSlider in [
		_scale_slider, _offset_x_slider, _offset_y_slider, _slant_slider,
		_panel_w_slider, _panel_h_slider, _panel_alpha_slider, _edge_fade_slider,
		_grad_start_slider, _grad_end_slider, _filter_strength_slider, _vignette_slider,
		_sat_slider, _contrast_slider, _brightness_slider, _theme_mix_slider,
		_stripe_slider, _glow_slider, _darken_slider,
	]:
		slider.value_changed.connect(func(_v: float) -> void: _on_tune_slider_changed())
	_gradient_mode.item_selected.connect(func(_i: int) -> void: _on_tune_slider_changed())
	_filter_mode.item_selected.connect(func(_i: int) -> void: _on_tune_slider_changed())

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(0.82, 0.88, 0.94)
	root.add_child(_status)


func _section(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(0.7, 0.85, 1.0)
	parent.add_child(label)


func _grid_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _add_slider(parent: Control, title: String, min_value: float, max_value: float, value: float) -> HSlider:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01 if absf(max_value - min_value) <= 2.5 else 0.1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider)
	return slider


func _add_option(parent: Control, title: String, items: PackedStringArray, selected: int) -> OptionButton:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	box.add_child(option)
	return option


func _look_overrides_from_ui() -> Dictionary:
	return {
		"global_alpha": float(_panel_alpha_slider.value),
		"edge_fade": float(_edge_fade_slider.value),
		"gradient_alpha_start": float(_grad_start_slider.value),
		"gradient_alpha_end": float(_grad_end_slider.value),
		"gradient_mode": int(_gradient_mode.selected),
		"filter_mode": int(_filter_mode.selected),
		"filter_strength": float(_filter_strength_slider.value),
		"vignette_strength": float(_vignette_slider.value),
		"saturation": float(_sat_slider.value),
		"contrast": float(_contrast_slider.value),
		"brightness": float(_brightness_slider.value),
		"theme_mix": float(_theme_mix_slider.value),
		"stripe_amount": float(_stripe_slider.value),
		"edge_glow_amount": float(_glow_slider.value),
	}


func _reset_look_defaults() -> void:
	_panel_w_slider.value = CutInLook.PANEL_SCALE.x
	_panel_h_slider.value = CutInLook.PANEL_SCALE.y
	_panel_alpha_slider.value = CutInLook.GLOBAL_ALPHA
	_edge_fade_slider.value = CutInLook.EDGE_FADE
	_grad_start_slider.value = CutInLook.GRADIENT_ALPHA_START
	_grad_end_slider.value = CutInLook.GRADIENT_ALPHA_END
	_gradient_mode.select(CutInLook.GRADIENT_MODE)
	_filter_mode.select(CutInLook.FILTER_MODE)
	_filter_strength_slider.value = CutInLook.FILTER_STRENGTH
	_vignette_slider.value = CutInLook.VIGNETTE_STRENGTH
	_sat_slider.value = CutInLook.SATURATION
	_contrast_slider.value = CutInLook.CONTRAST
	_brightness_slider.value = CutInLook.BRIGHTNESS
	_theme_mix_slider.value = CutInLook.THEME_MIX
	_stripe_slider.value = CutInLook.STRIPE_AMOUNT
	_glow_slider.value = CutInLook.EDGE_GLOW_AMOUNT
	_darken_slider.value = CutInLook.DARKEN_ALPHA
	_scale_slider.value = CutInLook.PORTRAIT_SCALE
	_offset_x_slider.value = CutInLook.PORTRAIT_OFFSET.x
	_offset_y_slider.value = CutInLook.PORTRAIT_OFFSET.y
	_slant_slider.value = CutInLook.SLANT
	_apply_tune_to_active()
	_status.text = "已恢复 canonical look（AwakeningCutInLook）。"


func _on_static_mode_toggled(pressed: bool) -> void:
	if pressed:
		_mute_voice.button_pressed = true
		_apply_voice_output(true)
		_status.text = "已开启常态显示：点角色按钮后定格，拖滑条即时改裁切与观感。"
	else:
		_clear_cutin_visuals()
		_status.text = "已关闭常态显示并清掉定格。再点角色按钮将播放完整进场/退场动画。"


func _trigger_ids(profile_ids: Array[StringName]) -> void:
	if _static_mode.button_pressed:
		_show_static_ids(profile_ids)
	else:
		_play_ids(profile_ids)


func _show_static_ids(profile_ids: Array[StringName]) -> void:
	_last_static_ids = profile_ids.duplicate()
	_stop_voice()
	_sync_panel_scale_and_darken()
	var profiles := _build_tuned_profiles(profile_ids)
	if profiles.is_empty():
		return
	_layer.preview_static(profiles)
	_apply_look_to_active_slots()
	var names: PackedStringArray = []
	for profile: AwakeningCutInProfileDefinition in profiles:
		names.append(profile.display_name)
	_status.text = "常态显示 %d 人：%s。可调框体/透明度/渐变/滤镜。" % [profiles.size(), ", ".join(names)]


func _play_ids(profile_ids: Array[StringName]) -> void:
	_stop_all()
	_apply_voice_output(_mute_voice.button_pressed)
	_sync_panel_scale_and_darken()
	var profiles := _build_tuned_profiles(profile_ids)
	if profiles.is_empty():
		return
	var overrides := _look_overrides_from_ui()
	for slot: AwakeningCutInSlot in _layer.slots:
		slot.set_look_overrides(overrides)
	var names: PackedStringArray = []
	var first_voice := ""
	for tuned: AwakeningCutInProfileDefinition in profiles:
		_layer.request_cutin(tuned)
		names.append(tuned.display_name)
		if first_voice.is_empty() and not tuned.audio_path.is_empty():
			first_voice = "%s（%s）" % [tuned.display_name, tuned.audio_path.get_file()]
	await get_tree().create_timer(0.12).timeout
	_apply_look_to_active_slots()
	_refresh_voice_label()
	var voice_note := "静音中"
	if not _mute_voice.button_pressed:
		voice_note = "应播首条语音：%s；播放中=%s；抑制=%d" % [
			first_voice if not first_voice.is_empty() else "无",
			str(_layer.voice_player.playing),
			_layer.voice_suppressed_count,
		]
	_status.text = "动画播放 %d 人批次：%s。%s" % [profiles.size(), ", ".join(names), voice_note]


func _build_tuned_profiles(profile_ids: Array[StringName]) -> Array[AwakeningCutInProfileDefinition]:
	var database := CombatData.database()
	var result: Array[AwakeningCutInProfileDefinition] = []
	if database == null:
		_status.text = "无法读取 CombatData.database()，请先确保配表可构建。"
		return result
	for profile_id: StringName in profile_ids:
		var profile := database.get_awakening_cutin_profile(profile_id)
		if profile == null:
			_status.text = "缺少 profile：%s" % String(profile_id)
			return []
		var tuned := profile.duplicate(true) as AwakeningCutInProfileDefinition
		_write_sliders_into(tuned)
		result.append(tuned)
	return result


func _write_sliders_into(profile: AwakeningCutInProfileDefinition) -> void:
	profile.portrait_scale = float(_scale_slider.value)
	profile.portrait_offset = Vector2(float(_offset_x_slider.value), float(_offset_y_slider.value))
	profile.slant = float(_slant_slider.value)
	profile.voice_volume_db = float(_voice_db_slider.value)


func _sync_panel_scale_and_darken() -> void:
	_layer.debug_panel_scale = Vector2(float(_panel_w_slider.value), float(_panel_h_slider.value))
	_layer.debug_darken_alpha = float(_darken_slider.value)
	if not _layer.active_slots.is_empty() and _layer.darken.color.a > 0.001:
		_layer.darken.color.a = float(_darken_slider.value)


func _apply_look_to_active_slots() -> void:
	var overrides := _look_overrides_from_ui()
	for slot: AwakeningCutInSlot in _layer.active_slots:
		slot.set_look_overrides(overrides)


func _on_tune_slider_changed() -> void:
	_sync_panel_scale_and_darken()
	if _static_mode.button_pressed and not _layer.active_slots.is_empty():
		_apply_tune_to_active(false)
	elif not _layer.active_slots.is_empty():
		_layer.refresh_active_layouts(false)
		_apply_look_to_active_slots()


func _play_voice_only(profile_id: StringName) -> void:
	_stop_voice()
	if _mute_voice.button_pressed:
		_mute_voice.button_pressed = false
		_apply_voice_output(false)
	var database := CombatData.database()
	if database == null:
		_status.text = "无法读取 CombatData.database()。"
		return
	var profile := database.get_awakening_cutin_profile(profile_id)
	if profile == null or profile.audio_path.is_empty():
		_status.text = "该 profile 没有 audio_path。"
		return
	var stream := load(profile.audio_path) as AudioStream
	if stream == null:
		_status.text = "语音加载失败：%s" % profile.audio_path
		return
	_layer.voice_player.stream = stream
	_layer.voice_player.volume_db = float(_voice_db_slider.value)
	_layer.voice_player.play()
	_layer.voice_play_count += 1
	_refresh_voice_label()
	_status.text = "只播语音：%s · %s · %.1f dB" % [profile.display_name, profile.audio_path.get_file(), float(_voice_db_slider.value)]


func _apply_tune_to_active(announce := true) -> void:
	_sync_panel_scale_and_darken()
	_layer.refresh_active_layouts(false)
	var count := 0
	var overrides := _look_overrides_from_ui()
	for slot: AwakeningCutInSlot in _layer.active_slots:
		if slot.current_profile == null:
			continue
		_write_sliders_into(slot.current_profile)
		slot.set_look_overrides(overrides)
		slot.refresh_profile_visuals(slot.current_profile.faction == "enemy")
		count += 1
	_sync_live_voice_volume()
	if announce:
		_status.text = "已应用裁切/框体/透明度/滤镜到 %d 个活动槽。" % count


func _apply_voice_output(muted: bool) -> void:
	if _layer == null or _layer.voice_player == null:
		return
	if muted:
		_layer.voice_player.volume_db = -80.0
		if _layer.voice_player.playing:
			_layer.voice_player.stop()
	else:
		_layer.voice_player.volume_db = float(_voice_db_slider.value)
	_refresh_voice_label()


func _sync_live_voice_volume() -> void:
	if _layer == null or _layer.voice_player == null:
		return
	if _mute_voice.button_pressed:
		_layer.voice_player.volume_db = -80.0
	else:
		_layer.voice_player.volume_db = float(_voice_db_slider.value)
	_refresh_voice_label()


func _refresh_voice_label() -> void:
	if _voice_label == null or _layer == null:
		return
	var playing := _layer.voice_player != null and _layer.voice_player.playing
	var stream_name := "-"
	if _layer.voice_player != null and _layer.voice_player.stream != null:
		stream_name = str(_layer.voice_player.stream.resource_path.get_file())
	_voice_label.text = "状态：%s | 文件：%s | 已播%d 抑制%d" % [
		"播放中" if playing else "空闲",
		stream_name,
		_layer.voice_play_count,
		_layer.voice_suppressed_count,
	]


func _stop_voice() -> void:
	if _layer.voice_player.playing:
		_layer.voice_player.stop()
	_refresh_voice_label()


func _stop_all() -> void:
	_clear_cutin_visuals()
	_stop_voice()
	_status.text = "已停止全部 Cut-In。"
	_refresh_voice_label()


func _clear_cutin_visuals() -> void:
	_layer.preview_static([])
	_layer.active_slots.clear()
	_layer.pending_requests.clear()
	_layer.batch_remaining = 0.0
	for slot: AwakeningCutInSlot in _layer.slots:
		slot.stop_immediately()
	_layer.darken.color.a = 0.0


func _process(_delta: float) -> void:
	if _voice_label != null:
		_refresh_voice_label()
