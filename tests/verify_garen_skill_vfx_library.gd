extends SceneTree

const SHEETS_ROOT := "res://assets/vfx/garen_skills"
const LIBRARY_PATH := SHEETS_ROOT + "/garen_skill_vfx_frames.tres"
const EXPECTED_ANIMATIONS := 4
const EXPECTED_FRAMES := 76
const LOOPED := {
	"spell2_JollyRoger": true,
	"spell3_OceanStorm": true,
}


func _initialize() -> void:
	var library := load(LIBRARY_PATH) as SpriteFrames
	if library == null:
		push_error("Could not load %s" % LIBRARY_PATH)
		quit(1)
		return

	var animation_names := _find_animation_names()
	var passed := animation_names.size() == EXPECTED_ANIMATIONS
	passed = passed and library.get_animation_names().size() == EXPECTED_ANIMATIONS
	var total_frames := 0
	var total_json_duration_ms := 0
	var total_library_duration_ms := 0.0
	var canvas_ok := true
	var filter_clip_ok := true

	for animation_name_string: String in animation_names:
		var animation_name := StringName(animation_name_string)
		var json_path := SHEETS_ROOT.path_join(animation_name_string).path_join("spritesheet.json")
		var data := _read_json(json_path)
		var meta: Dictionary = data.get("meta", {})
		var canvas: Dictionary = meta.get("canvas", {})
		var canvas_signature := Vector4(
			float(canvas.get("width", 0.0)),
			float(canvas.get("height", 0.0)),
			float(canvas.get("originPixelX", 0.0)),
			float(canvas.get("originPixelY", 0.0)),
		)
		if canvas_signature.x <= 0.0 or canvas_signature.y <= 0.0:
			push_error("Skill VFX canvas is invalid for %s: %s" % [animation_name_string, canvas_signature])
			canvas_ok = false

		var entries: Array[Dictionary] = []
		var frame_map: Dictionary = data.get("frames", {})
		for frame_key: String in frame_map:
			entries.append(frame_map[frame_key] as Dictionary)
		entries.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("sourceFrameIndex", 0)) < int(b.get("sourceFrameIndex", 0))
		)

		if not library.has_animation(animation_name):
			push_error("Missing skill VFX animation: %s" % animation_name_string)
			passed = false
			continue

		var frame_count := library.get_frame_count(animation_name)
		total_frames += frame_count
		if frame_count != entries.size():
			push_error("Skill VFX frame count mismatch for %s" % animation_name_string)
			passed = false

		var expected_loop := LOOPED.has(animation_name_string)
		if library.get_animation_loop(animation_name) != expected_loop:
			push_error("Skill VFX loop rule mismatch for %s" % animation_name_string)
			passed = false

		var animation_speed := library.get_animation_speed(animation_name)
		if not is_equal_approx(animation_speed, 24.0):
			push_error("Skill VFX speed mismatch for %s" % animation_name_string)
			passed = false

		for frame_index: int in mini(frame_count, entries.size()):
			var entry := entries[frame_index]
			var rect_data: Dictionary = entry.get("frame", {})
			var expected_region := Rect2(
				float(rect_data.get("x", 0)),
				float(rect_data.get("y", 0)),
				float(rect_data.get("w", 0)),
				float(rect_data.get("h", 0)),
			)
			var frame_texture := library.get_frame_texture(animation_name, frame_index) as AtlasTexture
			if frame_texture == null or not frame_texture.region.is_equal_approx(expected_region):
				push_error("Skill VFX atlas region mismatch for %s frame %d" % [animation_name_string, frame_index])
				passed = false
			if frame_texture == null or not frame_texture.filter_clip:
				filter_clip_ok = false

			var duration_ms := int(entry.get("duration", 100))
			var expected_duration_weight := float(duration_ms) / 1000.0 * 24.0
			var actual_duration_weight := library.get_frame_duration(animation_name, frame_index)
			if not is_equal_approx(actual_duration_weight, expected_duration_weight):
				push_error("Skill VFX duration mismatch for %s frame %d" % [animation_name_string, frame_index])
				passed = false
			total_json_duration_ms += duration_ms
			total_library_duration_ms += actual_duration_weight / animation_speed * 1000.0

	passed = passed and total_frames == EXPECTED_FRAMES
	passed = passed and is_equal_approx(total_library_duration_ms, float(total_json_duration_ms))
	passed = passed and canvas_ok and filter_clip_ok
	print("GAREN_SKILL_VFX animations=%d frames=%d duration_ms=%d canvas=%s regions=%s timing=%s loops=%s filter=%s" % [
		animation_names.size(), total_frames, total_json_duration_ms,
		canvas_ok, passed, passed, passed, filter_clip_ok,
	])
	if not passed:
		push_error("Garen skill VFX library verification failed")
	quit(0 if passed else 2)


func _find_animation_names() -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(SHEETS_ROOT)
	if directory == null:
		return result
	for name: String in directory.get_directories():
		var folder := SHEETS_ROOT.path_join(name)
		if FileAccess.file_exists(folder.path_join("spritesheet.json")) \
			and FileAccess.file_exists(folder.path_join("spritesheet.png")):
			result.append(name)
	result.sort()
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
