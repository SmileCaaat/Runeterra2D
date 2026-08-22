extends SceneTree

var player: CharacterBody3D
var dummy: CharacterBody3D
var frames: AnimatedSprite3D
var start_player := Vector3.ZERO
var start_dummy := Vector3.ZERO
var observed := {}
var elapsed := 0.0


func _initialize() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	if packed == null:
		push_error("Prototype scene failed to load")
		quit(1)
		return

	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	player = scene.get_node("Characters/Player") as CharacterBody3D
	dummy = scene.get_node("Characters/EnemyPlaceholder") as CharacterBody3D
	frames = player.get_node("CharacterFrames") as AnimatedSprite3D
	start_player = player.position
	start_dummy = dummy.position


func _process(delta: float) -> bool:
	if frames == null:
		return false
	elapsed += delta
	observed[String(frames.animation)] = true
	if elapsed < 18.0:
		return false

	var hit_count := int(dummy.get("hit_count"))
	var hit_particles := dummy.get_node("HitSparkParticles") as CPUParticles3D
	var particle_bursts := int(hit_particles.get("burst_count"))
	var attack_audio := player.get_node("AttackAudio") as AudioStreamPlayer3D
	var hit_audio := dummy.get_node("HitAudio") as AudioStreamPlayer3D
	var attack_sounds := int(player.get("attack_sound_count"))
	var hit_sounds := int(dummy.get("hit_sound_count"))
	var skill_controller := player.get_node("SkillController")
	var skill_casts: Array = skill_controller.get("cast_counts") as Array
	var all_skills_cast := true
	for skill_index: int in range(1, 6):
		all_skills_cast = all_skills_cast and int(skill_casts[skill_index]) > 0
	var vfx_frames := (skill_controller.get_node("JollyRoger") as AnimatedSprite3D).sprite_frames
	var vfx_total_frames := 0
	for animation_name: StringName in vfx_frames.get_animation_names():
		vfx_total_frames += vfx_frames.get_frame_count(animation_name)
	var player_distance := start_player.distance_to(player.global_position)
	var dummy_distance := start_dummy.distance_to(dummy.global_position)
	var library := frames.sprite_frames
	var total_frames := 0
	for animation_name: StringName in library.get_animation_names():
		total_frames += library.get_frame_count(animation_name)
	var anchor_x := absf(frames.offset.x)
	player.call("_face_direction", Vector3.LEFT)
	var left_flip_ok := frames.flip_h and is_equal_approx(frames.offset.x, -anchor_x)
	player.call("_face_direction", Vector3.RIGHT)
	var right_flip_ok := not frames.flip_h and is_equal_approx(frames.offset.x, anchor_x)
	print("COMBAT library=%d/%d vfx=%d/%d animations=%s skills=%s hits=%d bursts=%d audio=%d/%d player_moved=%.2f dummy_moved=%.2f separation=%.2f flip_anchor=%s/%s" % [
		library.get_animation_names().size(), total_frames, vfx_frames.get_animation_names().size(), vfx_total_frames,
		observed.keys(), skill_casts, hit_count, particle_bursts, attack_sounds, hit_sounds, player_distance, dummy_distance,
		player.global_position.distance_to(dummy.global_position), left_flip_ok, right_flip_ok,
	])

	var passed := library.get_animation_names().size() == 22 and total_frames == 289
	passed = passed and observed.has("run") and observed.has("attack1")
	passed = passed and observed.has("attack2") and observed.has("attack3")
	passed = passed and hit_count >= 3 and player_distance > 0.5 and dummy_distance > 0.2
	passed = passed and particle_bursts == hit_count
	passed = passed and attack_audio.stream != null and hit_audio.stream != null
	passed = passed and attack_sounds > 0 and hit_sounds == hit_count
	passed = passed and all_skills_cast and vfx_frames.get_animation_names().size() == 4 and vfx_total_frames == 71
	passed = passed and is_equal_approx(float(skill_controller.call("get_passive_armor_multiplier")), 1.2)
	passed = passed and left_flip_ok and right_flip_ok
	if not passed:
		push_error("Combat workflow verification failed")
	quit(0 if passed else 2)
	return true
