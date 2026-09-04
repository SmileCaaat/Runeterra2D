extends SceneTree

var player: CharacterBody3D
var dummy: CharacterBody3D
var frames: AnimatedSprite3D
var start_player := Vector3.ZERO
var start_dummy := Vector3.ZERO
var observed := {}
var elapsed := 0.0
var expected_sprite_offset := Vector2.ZERO
var initial_sprite_offset := Vector2.ZERO
var anchor_setup_ok := false


func _initialize() -> void:
	var packed := load("res://DNF_Style_Prototype.tscn") as PackedScene
	if packed == null:
		push_error("Prototype scene failed to load")
		quit(1)
		return

	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	player = scene.get_node("Characters/Player") as CharacterBody3D
	dummy = scene.get_node("Characters/EnemyTargetDummy1") as CharacterBody3D
	frames = player.get_node("CharacterFrames") as AnimatedSprite3D
	expected_sprite_offset = _read_expected_sprite_offset()
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
	# W is intentionally reactive and a passive training target cannot reduce
	# Garen below the juggernaut defense threshold. The remaining casts prove
	# that the selector progresses through pressure, execute and awakening
	# conditions without a fixed Q/W/E/R/T carousel.
	var selector_casts_ok := int(skill_casts[1]) > 0 and int(skill_casts[3]) > 0
	selector_casts_ok = selector_casts_ok and int(skill_casts[4]) > 0 and int(skill_casts[5]) > 0
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
	initial_sprite_offset = player.get("unflipped_sprite_offset") as Vector2
	anchor_setup_ok = initial_sprite_offset.is_equal_approx(expected_sprite_offset)
	var anchor_x := absf(frames.offset.x)
	player.call("_face_direction", Vector3.LEFT)
	var left_flip_ok := frames.flip_h and is_equal_approx(frames.offset.x, -anchor_x)
	left_flip_ok = left_flip_ok and is_equal_approx(frames.offset.y, expected_sprite_offset.y)
	player.call("_face_direction", Vector3.RIGHT)
	var right_flip_ok := not frames.flip_h and is_equal_approx(frames.offset.x, anchor_x)
	right_flip_ok = right_flip_ok and is_equal_approx(frames.offset.y, expected_sprite_offset.y)
	print("COMBAT library=%d/%d vfx=%d/%d animations=%s skills=%s hits=%d bursts=%d audio=%d/%d player_moved=%.2f dummy_moved=%.2f separation=%.2f anchor=%s/%s anchor_meta=%s flip_anchor=%s/%s" % [
		library.get_animation_names().size(), total_frames, vfx_frames.get_animation_names().size(), vfx_total_frames,
		observed.keys(), skill_casts, hit_count, particle_bursts, attack_sounds, hit_sounds, player_distance, dummy_distance,
		player.global_position.distance_to(dummy.global_position), initial_sprite_offset, expected_sprite_offset,
		anchor_setup_ok, left_flip_ok, right_flip_ok,
	])

	var passed := library.get_animation_names().size() == 22 and total_frames == 278
	passed = passed and observed.has("run") and observed.has("attack1")
	passed = passed and observed.has("attack2") and observed.has("attack3")
	# The static training dummy may still travel briefly under configured hit
	# knockback while the AI is actively attacking. Its return-home controller
	# must keep that combat displacement bounded instead of treating it as wander.
	passed = passed and hit_count >= 3 and player_distance > 0.5 and dummy_distance <= 0.75
	passed = passed and particle_bursts == hit_count
	passed = passed and attack_audio.stream != null and hit_audio.stream != null
	passed = passed and attack_sounds > 0 and hit_sounds == hit_count
	passed = passed and selector_casts_ok and vfx_frames.get_animation_names().size() == 4 and vfx_total_frames == 76
	passed = passed and is_zero_approx(float(skill_controller.call("get_courage_resistance_bonus")))
	passed = passed and anchor_setup_ok and left_flip_ok and right_flip_ok
	if not passed:
		push_error("Combat workflow verification failed")
	quit(0 if passed else 2)
	return true


func _read_expected_sprite_offset() -> Vector2:
	var json_path := "res://assets/characters/rogue_admiral_garen/idle1/spritesheet.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return Vector2.INF
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return Vector2.INF
	var meta: Dictionary = (parsed as Dictionary).get("meta", {})
	var canvas: Dictionary = meta.get("canvas", {})
	var width := float(canvas.get("width", 0.0))
	var height := float(canvas.get("height", 0.0))
	var origin_x := float(canvas.get("originPixelX", width * 0.5))
	var origin_y := float(canvas.get("originPixelY", height))
	return Vector2(width * 0.5 - origin_x, origin_y - height * 0.5)
