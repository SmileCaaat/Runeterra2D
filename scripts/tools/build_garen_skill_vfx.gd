extends SceneTree

const SOURCE_ROOT := "res://assets/vfx/garen_skills"
const OUTPUT_PATH := SOURCE_ROOT + "/garen_skill_vfx_frames.tres"
const LOOPED := {"spell2_JollyRoger": true, "spell3_OceanStorm": true}


func _initialize() -> void:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0
	var directories := DirAccess.get_directories_at(SOURCE_ROOT)
	directories.sort()

	for folder_name: String in directories:
		var folder := SOURCE_ROOT.path_join(folder_name)
		var data := _read_json(folder.path_join("spritesheet.json"))
		var atlas := load(folder.path_join("spritesheet.png")) as Texture2D
		if data.is_empty() or atlas == null:
			push_error("Invalid skill VFX folder: %s" % folder_name)
			continue

		var animation_name := StringName(folder_name)
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, 24.0)
		library.set_animation_loop(animation_name, LOOPED.has(folder_name))
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
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.filter_clip = true
			texture.region = Rect2(
				float(rect_data.get("x", 0)), float(rect_data.get("y", 0)),
				float(rect_data.get("w", 0)), float(rect_data.get("h", 0)),
			)
			var frame_seconds := float(entry.get("duration", 100)) / 1000.0
			library.add_frame(animation_name, texture, frame_seconds * 24.0)
			total_frames += 1

	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save skill VFX library: %s" % error_string(save_error))
		quit(1)
		return
	print("Built %d skill VFX animations / %d frames -> %s" % [
		library.get_animation_names().size(), total_frames, OUTPUT_PATH,
	])
	quit(0)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
