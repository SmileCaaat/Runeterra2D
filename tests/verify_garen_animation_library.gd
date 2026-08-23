extends SceneTree

const SHEETS_ROOT := "res://assets/characters/rogue_admiral_garen"
const LIBRARY_PATH := SHEETS_ROOT + "/garen_sprite_frames.tres"
const EXPECTED_ANIMATIONS := 22
const EXPECTED_FRAMES := 289
const LOOPED := {
	"channel": true,
	"dance_base": true,
	"idle1": true,
	"idle2": true,
	"idle3": true,
	"run": true,
	"run_spell": true,
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
	var reference_canvas := Vector4.ZERO
	var canvas_was_set := false
	var canvas_ok := true

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
		if not canvas_was_set:
			reference_canvas = canvas_signature
			canvas_was_set = true
		elif not canvas_signature.is_equal_approx(reference_canvas):
			push_error("Canvas anchor mismatch for %s: %s != %s" % [
				animation_name_string, canvas_signature, reference_canvas,
			])
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
			push_error("Missing animation: %s" % animation_name_string)
			passed = false
			continue

		var frame_count := library.get_frame_count(animation_name)
		total_frames += frame_count
		if frame_count != entries.size():
			push_error("Frame count mismatch for %s: %d != %d" % [
				animation_name_string, frame_count, entries.size(),
			])
			passed = false

		var expected_loop := LOOPED.has(animation_name_string)
		if library.get_animation_loop(animation_name) != expected_loop:
			push_error("Loop rule mismatch for %s" % animation_name_string)
			passed = false

		var animation_speed := library.get_animation_speed(animation_name)
		if not is_equal_approx(animation_speed, 10.0):
			push_error("Animation speed mismatch for %s: %f" % [animation_name_string, animation_speed])
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
				push_error("Atlas region mismatch for %s frame %d" % [animation_name_string, frame_index])
				passed = false

			var duration_ms := int(entry.get("duration", 100))
			var expected_duration_weight := float(duration_ms) / 100.0
			var actual_duration_weight := library.get_frame_duration(animation_name, frame_index)
			if not is_equal_approx(actual_duration_weight, expected_duration_weight):
				push_error("Frame duration mismatch for %s frame %d: %f != %f" % [
					animation_name_string, frame_index, actual_duration_weight, expected_duration_weight,
				])
				passed = false
			total_json_duration_ms += duration_ms
			total_library_duration_ms += actual_duration_weight / animation_speed * 1000.0

	passed = passed and total_frames == EXPECTED_FRAMES
	passed = passed and is_equal_approx(total_library_duration_ms, float(total_json_duration_ms))
	passed = passed and canvas_ok
	print("GAREN_ANIMATIONS animations=%d frames=%d duration_ms=%d canvas=%s regions=%s timing=%s loops=%s" % [
		animation_names.size(), total_frames, total_json_duration_ms,
		canvas_ok, passed, passed, passed,
	])
	if not passed:
		push_error("Garen animation library verification failed")
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
