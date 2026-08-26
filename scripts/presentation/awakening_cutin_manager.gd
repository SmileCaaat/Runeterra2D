class_name AwakeningCutInManager
extends CanvasLayer

const MAX_SLOTS := 4
const BATCH_WINDOW := 0.10
const DARKEN_ALPHA := 0.38

@onready var darken: ColorRect = $Overlay/BackgroundDarken
@onready var slot_root: Control = $Overlay/Slots
@onready var voice_player: AudioStreamPlayer = $VoicePlayer

var pending_requests: Array[Dictionary] = []
var active_slots: Array[AwakeningCutInSlot] = []
var slots: Array[AwakeningCutInSlot] = []
var batch_remaining := 0.0
var request_sequence := 0
var voice_play_count := 0
var voice_suppressed_count := 0
var rejected_request_count := 0
var _darken_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child: Node in slot_root.get_children():
		var slot := child as AwakeningCutInSlot
		if slot == null:
			continue
		slots.append(slot)
		slot.playback_finished.connect(_on_slot_finished)
	darken.color.a = 0.0
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if pending_requests.is_empty():
		return
	batch_remaining -= delta
	if batch_remaining <= 0.0:
		_flush_pending_requests()


func request_skill(skill_id: StringName, context: Dictionary = {}) -> bool:
	var database := CombatData.database()
	if database == null:
		return false
	var profile := database.get_awakening_cutin_profile_for_skill(skill_id)
	if profile == null:
		return false
	return request_cutin(profile, context)


func request_cutin(profile: AwakeningCutInProfileDefinition, context: Dictionary = {}) -> bool:
	if profile == null:
		return false
	request_sequence += 1
	pending_requests.append({
		"profile": profile,
		"context": context.duplicate(),
		"sequence": request_sequence,
	})
	if pending_requests.size() == 1:
		batch_remaining = BATCH_WINDOW
	return true


func _flush_pending_requests() -> void:
	if pending_requests.is_empty():
		return
	pending_requests.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["sequence"]) < int(b["sequence"])
	)
	var accepted: Array[Dictionary] = []
	for request: Dictionary in pending_requests:
		var slot := _next_free_slot()
		if slot == null:
			rejected_request_count += 1
			continue
		var profile := request["profile"] as AwakeningCutInProfileDefinition
		active_slots.append(slot)
		accepted.append(request)
		slot.play_profile(profile, Rect2(0.0, 0.0, 1.0, 1.0), _is_right_entry(profile), int(request["sequence"]))
	pending_requests.clear()
	batch_remaining = 0.0
	if accepted.is_empty():
		return
	_refresh_layouts()
	_show_darken()
	_try_play_first_voice(accepted[0])


func _next_free_slot() -> AwakeningCutInSlot:
	for slot: AwakeningCutInSlot in slots:
		if not active_slots.has(slot) and slot.current_profile == null:
			return slot
	return null


func _refresh_layouts() -> void:
	active_slots.sort_custom(
		func(a: AwakeningCutInSlot, b: AwakeningCutInSlot) -> bool:
			return a.request_sequence < b.request_sequence
	)
	var count := active_slots.size()
	for index: int in range(count):
		var slot := active_slots[index]
		slot.apply_layout(_layout_rect(index, count, slot.current_profile), true)


func _layout_rect(index: int, count: int, profile: AwakeningCutInProfileDefinition) -> Rect2:
	match count:
		1:
			return Rect2(0.38, 0.08, 0.60, 0.84) if _is_right_entry(profile) else Rect2(0.02, 0.08, 0.60, 0.84)
		2:
			return Rect2(0.49, 0.07, 0.49, 0.86) if index == 1 else Rect2(0.02, 0.07, 0.49, 0.86)
		3:
			if index == 0:
				return Rect2(0.02, 0.06, 0.54, 0.88)
			return Rect2(0.53, 0.51 if index == 2 else 0.06, 0.45, 0.43)
		_:
			var column := index % 2
			var row := floori(float(index) / 2.0)
			return Rect2(0.02 + column * 0.49, 0.06 + row * 0.45, 0.47, 0.43)


func _is_right_entry(profile: AwakeningCutInProfileDefinition) -> bool:
	return profile != null and profile.faction == "enemy"


func _try_play_first_voice(request: Dictionary) -> void:
	if voice_player.playing:
		voice_suppressed_count += 1
		return
	var profile := request["profile"] as AwakeningCutInProfileDefinition
	if profile.audio_path.is_empty():
		return
	var stream := load(profile.audio_path) as AudioStream
	if stream == null:
		return
	voice_player.stream = stream
	voice_player.volume_db = profile.voice_volume_db
	voice_player.play()
	voice_play_count += 1


func _on_slot_finished(slot: AwakeningCutInSlot) -> void:
	active_slots.erase(slot)
	if active_slots.is_empty():
		_hide_darken()
	else:
		_refresh_layouts()


func _show_darken() -> void:
	_tween_darken(DARKEN_ALPHA, 0.10)


func _hide_darken() -> void:
	_tween_darken(0.0, 0.12)


func _tween_darken(alpha: float, duration: float) -> void:
	if _darken_tween != null and _darken_tween.is_valid():
		_darken_tween.kill()
	_darken_tween = create_tween()
	_darken_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_darken_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_darken_tween.tween_property(darken, "color:a", alpha, duration)
