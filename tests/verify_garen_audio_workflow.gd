extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("Characters/Player") as CharacterBody3D
	var frames := player.get_node("CharacterFrames") as AnimatedSprite3D
	var attack_audio := player.get_node("AttackAudio") as AudioStreamPlayer3D
	var skills := player.get_node("SkillController")
	player.set_physics_process(false)
	skills.set("automatic_demo", false)
	var database := CombatData.database()
	var passed := database != null

	var expected_cast_files := {
		&"attack1": "basic_attack_cast_1.ogg",
		&"attack2": "basic_attack_cast_2.ogg",
		&"attack3": "crit_attack_cast.ogg",
	}
	for animation: StringName in expected_cast_files:
		frames.play(animation)
		frames.pause()
		frames.frame = 0
		(player.get("attack_audio_events_sent") as Dictionary).clear()
		var count_before := int(player.get("attack_sound_count"))
		player.call("_check_attack_audio")
		passed = passed and int(player.get("attack_sound_count")) == count_before
		var event := database.get_animation_event(&"garen", animation, "audio")
		var frame_count := frames.sprite_frames.get_frame_count(animation)
		frames.frame = ceili(event.timing_value * float(frame_count - 1))
		player.call("_check_attack_audio")
		passed = passed and int(player.get("attack_sound_count")) == count_before + 1
		passed = passed and attack_audio.stream != null
		passed = passed and attack_audio.stream.resource_path.ends_with(expected_cast_files[animation])
		passed = passed and attack_audio.max_distance >= 40.0
		passed = passed and attack_audio.stream.get_length() > 0.05
		attack_audio.stop()

	frames.play(&"spell1")
	frames.pause()
	frames.frame = 0
	(player.get("attack_audio_events_sent") as Dictionary).clear()
	var q_count_before := int(player.get("attack_sound_count"))
	var q_events := database.get_animation_events(&"garen", &"spell1", "audio")
	frames.frame = ceili(q_events[0].timing_value * float(frames.sprite_frames.get_frame_count(&"spell1") - 1))
	player.call("_check_attack_audio")
	passed = passed and int(player.get("attack_sound_count")) == q_count_before + 2
	passed = passed and attack_audio.stream.resource_path.ends_with("q_attack_cast_1.ogg")
	var cue_counts := skills.get("audio_cue_play_counts") as Dictionary
	passed = passed and int(cue_counts.get(&"garen_q_attack_cast_2", 0)) == 1

	for profile_id: StringName in [
		&"garen_q_cast", &"garen_w_cast", &"garen_e_cast", &"garen_e_hit",
		&"garen_r_buff_activate", &"garen_r_cast", &"garen_r_hit",
		&"garen_passive_recovery_activate",
	]:
		var profile := database.get_asset_profile(profile_id)
		var stream: AudioStream
		if profile != null:
			stream = load(profile.audio_path) as AudioStream
		passed = passed and profile != null and stream != null and stream.get_length() > 0.05
		passed = passed and profile.max_distance >= 40.0

	var ghostship_profile := database.get_asset_profile(&"ghostship_audio")
	var seven_seas := database.get_skill(&"garen_seven_seas")
	var ghostship_hit := database.get_hit_profile(&"ghostship_hit")
	passed = passed and ghostship_profile != null and is_equal_approx(ghostship_profile.volume_db, 5.0)
	passed = passed and ghostship_profile.max_distance >= 44.0
	passed = passed and ghostship_hit != null and ghostship_hit.hit_audio_profile_id == &"garen_basic_hit_wood"
	passed = passed and CombatAudio.resolve_surface_audio(ghostship_hit.hit_audio_profile_id, &"wood", false) == &"garen_basic_hit_wood"
	passed = passed and CombatAudio.resolve_surface_audio(ghostship_hit.hit_audio_profile_id, &"flesh", false) == &"garen_basic_hit_flesh"
	passed = passed and seven_seas != null and is_equal_approx(seven_seas.travel_duration, 1.35)
	var seven_seas_effects := database.get_skill_effects(&"garen_seven_seas", "on_impact")
	passed = passed and seven_seas_effects.size() == 3
	for effect: SkillEffectDefinition in seven_seas_effects:
		passed = passed and is_equal_approx(effect.delay, 1.35)

	passed = passed and is_equal_approx(float(database.get_rule(&"presentation.seven_seas_buff_audio_delay", 0.0)), 0.15)

	print("GAREN_AUDIO attacks=%s q_layers=%d qwer=true passive_registered=true attenuation=true ghost_impact=1.35 ghost_volume=5db ghost_buff_delay=0.15 ghost_hit=basic_surface" % [
		expected_cast_files.keys(), q_events.size(),
	])
	scene.queue_free()
	if not passed:
		push_error("Garen audio workflow verification failed")
	quit(0 if passed else 2)
