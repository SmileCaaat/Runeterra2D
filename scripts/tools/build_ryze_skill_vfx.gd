extends SceneTree

const SOURCE_ROOT := "res://assets/vfx/ryze_skills"
const OUTPUT_PATH := SOURCE_ROOT + "/ryze_skill_vfx_frames.tres"
const LOOPED := {"W_loop": true, "Ryze_Shield": true}


func _initialize() -> void:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0
	var folders := DirAccess.get_directories_at(SOURCE_ROOT)
	folders.sort()
	for folder_name: String in folders:
		var folder := SOURCE_ROOT.path_join(folder_name)
		if not FileAccess.file_exists(folder.path_join("spritesheet.json")) \
				or not FileAccess.file_exists(folder.path_join("spritesheet.png")):
			continue
		var data := _read_json(folder.path_join("spritesheet.json"))
		var atlas := load(folder.path_join("spritesheet.png")) as Texture2D
		if data.is_empty() or atlas == null:
			continue
		var animation_name := StringName(folder_name)
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, 24.0)
		library.set_animation_loop(animation_name, LOOPED.has(folder_name))
		var entries: Array[Dictionary] = []
		var raw_frames: Variant = data.get("frames", null)
		if raw_frames is Dictionary:
			for frame_key: String in raw_frames:
				entries.append(raw_frames[frame_key] as Dictionary)
		elif raw_frames is Array:
			for raw_entry: Variant in raw_frames:
				if raw_entry is Dictionary:
					entries.append(raw_entry)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("sourceFrameIndex", a.get("index", 0))) < int(b.get("sourceFrameIndex", b.get("index", 0)))
		)
		for entry: Dictionary in entries:
			var rect := entry.get("frame", {}) as Dictionary
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = atlas
			frame_texture.filter_clip = true
			frame_texture.region = Rect2(
				float(rect.get("x", 0)), float(rect.get("y", 0)),
				float(rect.get("w", 0)), float(rect.get("h", 0)),
			)
			var duration_ms := float(entry.get("duration", entry.get("duration_ms", data.get("duration_ms", 100))))
			library.add_frame(animation_name, frame_texture, duration_ms / 1000.0 * 24.0)
			total_frames += 1
	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		quit(1)
		return
	print("Built %d Ryze skill VFX animations / %d frames -> %s" % [
		library.get_animation_names().size(), total_frames, OUTPUT_PATH,
	])
	quit(0)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
