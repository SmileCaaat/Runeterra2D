class_name BattleControlCoordinator
extends Node

@export_node_path("BattleHUD") var battle_hud_path := NodePath("../BattleHUD")
var battle_hud: BattleHUD
var focused_hero: HeroInstance
var manual_hero: HeroInstance
var _wait_for_movement_release := false


func _ready() -> void:
	process_physics_priority = -10
	battle_hud = get_node(battle_hud_path) as BattleHUD
	if not battle_hud.is_node_ready():
		await battle_hud.ready
	battle_hud.selected_hero_changed.connect(_on_selected_hero_changed)
	focused_hero = battle_hud.get_selected_hero()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_wait_for_movement_release = true
		if is_instance_valid(manual_hero):
			manual_hero.set_player_move_input(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	_validate_runtime_refs()
	var direction := _movement_input()
	if _text_input_focused():
		direction = Vector2.ZERO
	if _wait_for_movement_release:
		_wait_for_movement_release = not direction.is_zero_approx()
		direction = Vector2.ZERO
	if not direction.is_zero_approx():
		_ensure_manual_control()
	if is_instance_valid(manual_hero):
		manual_hero.set_player_move_input(direction)


func _input(event: InputEvent) -> void:
	# Reserve Tab for hero cycling before Control's default focus navigation.
	if not _text_input_focused() and event.is_action_pressed(&"battle_hero_cycle", false):
		battle_hud.select_next_hero()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _text_input_focused() or event.is_echo():
		return
	for index in 5:
		if event.is_action_pressed(StringName("battle_hero_%d" % (index + 1))):
			battle_hud.select_hero(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"battle_toggle_auto"):
		toggle_control()
	elif event.is_action_pressed(&"battle_basic_attack"):
		if _ensure_manual_control():
			manual_hero.request_player_basic_attack(_movement_input())
	else:
		for slot: StringName in [&"q", &"w", &"e", &"r", &"t"]:
			if event.is_action_pressed(StringName("battle_skill_" + slot)):
				if _ensure_manual_control():
					manual_hero.request_player_skill(slot, _movement_input())
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func toggle_control() -> void:
	_validate_runtime_refs()
	if is_instance_valid(manual_hero) and manual_hero == focused_hero:
		_release_manual_control()
		_wait_for_movement_release = true
	else:
		_ensure_manual_control()


func _on_selected_hero_changed(hero: HeroInstance, _index: int) -> void:
	if is_instance_valid(manual_hero) and manual_hero != hero:
		_release_manual_control()
	focused_hero = hero
	_wait_for_movement_release = not _movement_input().is_zero_approx()


func _ensure_manual_control() -> bool:
	if not _can_control(focused_hero):
		return false
	if manual_hero == focused_hero and focused_hero.is_player_controlled():
		return true
	_release_manual_control()
	manual_hero = focused_hero
	manual_hero.set_control_authority(HeroInstance.ControlAuthority.PLAYER)
	return true


func _release_manual_control() -> void:
	if is_instance_valid(manual_hero):
		manual_hero.set_player_move_input(Vector2.ZERO)
		manual_hero.set_control_authority(HeroInstance.ControlAuthority.AI)
	manual_hero = null


func _can_control(hero: Variant) -> bool:
	# A freed Object must reach this validity check before any subclass cast.
	return is_instance_valid(hero) and hero is HeroInstance and not hero.is_queued_for_deletion() and hero.is_inside_tree() and hero.supports_player_control() and battle_hud.get_friendly_heroes().has(hero) and hero.is_in_group(&"friendly_actor") and hero.has_method("is_targetable") and bool(hero.call("is_targetable"))


func _validate_runtime_refs() -> void:
	if not is_instance_valid(manual_hero):
		manual_hero = null
	elif not _can_control(manual_hero) or not manual_hero.is_player_controlled():
		_release_manual_control()
	if not is_instance_valid(focused_hero):
		focused_hero = battle_hud.get_selected_hero()


func _movement_input() -> Vector2:
	return Input.get_vector(&"battle_move_left", &"battle_move_right", &"battle_move_up", &"battle_move_down")


func _text_input_focused() -> bool:
	var control := get_viewport().gui_get_focus_owner()
	return control is LineEdit or control is TextEdit
