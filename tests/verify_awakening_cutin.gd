extends SceneTree

const BuilderScript = preload("res://scripts/data/combat_data_builder.gd")


func _initialize() -> void:
	var build_result: Dictionary = BuilderScript.new().build("res://data/source", "user://awakening_cutin_database_test.tres")
	if not bool(build_result.success):
		for error: String in build_result.errors:
			push_error(error)
		quit(2)
		return
	var database := build_result.database as CombatDatabase
	var profile := database.get_awakening_cutin_profile_for_skill(&"garen_seven_seas")
	var data_ok := profile != null
	data_ok = data_ok and profile.skill_id == &"garen_seven_seas"
	data_ok = data_ok and profile.faction == "friendly" and profile.primary
	data_ok = data_ok and profile.total_duration() > 0.5
	data_ok = data_ok and FileAccess.file_exists(profile.portrait_path)
	data_ok = data_ok and FileAccess.file_exists(profile.audio_path)

	var layer := root.get_node_or_null("AwakeningCutIn") as AwakeningCutInManager
	if layer == null:
		push_error("AwakeningCutIn autoload is unavailable")
		quit(2)
		return
	var first_ok := layer.request_cutin(profile)
	await create_timer(0.12).timeout
	var first_voice_ok := layer.voice_play_count == 1 and layer.active_slots.size() == 1
	var second_ok := layer.request_cutin(profile)
	await create_timer(0.12).timeout
	var exclusivity_ok := layer.voice_play_count == 1 and layer.voice_suppressed_count == 1
	var pool_ok := layer.active_slots.size() == 2 and layer.slots.size() == 4

	var passed := data_ok and first_ok and second_ok and first_voice_ok and exclusivity_ok and pool_ok
	print("AWAKENING_CUTIN data=%s first=%s voice=%s exclusive=%s pool=%s" % [
		data_ok, first_ok, first_voice_ok, exclusivity_ok, pool_ok,
	])
	layer.voice_player.stop()
	for slot: AwakeningCutInSlot in layer.slots:
		slot.stop_immediately()
	layer.pending_requests.clear()
	layer.active_slots.clear()
	await process_frame
	quit(0 if passed else 2)
