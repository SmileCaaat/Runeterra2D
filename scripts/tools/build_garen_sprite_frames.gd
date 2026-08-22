extends SceneTree

const SHEETS_ROOT := "res://assets/characters/rogue_admiral_garen"
const OUTPUT_PATH := SHEETS_ROOT + "/garen_sprite_frames.tres"
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
	var result := _build_library()
	if result != OK:
		quit(1)
		return
	quit(0)


func _build_library() -> Error:
	var animation_names := _find_animation_names()
	if animation_names.is_empty():
		push_error("No animation folders found in %s" % SHEETS_ROOT)
		return ERR_DOES_NOT_EXIST

	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0

	for animation_name_string in animation_names:
		var animation_name := StringName(animation_name_string)
		var folder := SHEETS_ROOT.path_join(animation_name_string)
		var data := _read_json(folder.path_join("spritesheet.json"))
		var atlas := load(folder.path_join("spritesheet.png")) as Texture2D
		if data.is_empty() or atlas == null:
			push_error("Skipped invalid animation: %s" % animation_name_string)
			continue

		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, 10.0)
		library.set_animation_loop(animation_name, LOOPED.has(animation_name_string))

		var entries: Array[Dictionary] = []
		var frame_map: Dictionary = data.get("frames", {})
		for frame_key: String in frame_map:
			entries.append(frame_map[frame_key] as Dictionary)
		entries.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("sourceFrameIndex", 0)) < int(b.get("sourceFrameIndex", 0))
		)

		for entry: Dictionary in entries:
			var rect_data: Dictionary = entry.get("frame", {})
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = atlas
			frame_texture.region = Rect2(
				float(rect_data.get("x", 0)),
				float(rect_data.get("y", 0)),
				float(rect_data.get("w", 0)),
				float(rect_data.get("h", 0)),
			)
			var duration_scale := float(entry.get("duration", 100)) / 100.0
			library.add_frame(animation_name, frame_texture, duration_scale)
			total_frames += 1

	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		return save_error

	print("Built %d animations / %d frames -> %s" % [
		library.get_animation_names().size(), total_frames, OUTPUT_PATH
	])
	return OK


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
