extends SceneTree

const SOURCE_ROOT := "res://assets/monsters/target_dummy"
const OUTPUT_PATH := SOURCE_ROOT + "/target_dummy_sprite_frames.tres"
const ANIMATIONS := [&"idle", &"hurt", &"death", &"spawn"]
const LOOPED := {&"idle": true}
const PLAYBACK_FPS := 12.0


func _initialize() -> void:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0

	for animation_name: StringName in ANIMATIONS:
		var folder := SOURCE_ROOT.path_join(String(animation_name))
		var runtime_manifest_path := folder.path_join("runtime_manifest.json")
		var use_runtime_atlas := FileAccess.file_exists(runtime_manifest_path)
		var data := _read_json(runtime_manifest_path if use_runtime_atlas else folder.path_join("spritesheet.json"))
		var atlas_path := folder.path_join("runtime_atlas.png" if use_runtime_atlas else "spritesheet.png")
		var atlas := load(atlas_path) as Texture2D
		if data.is_empty() or atlas == null:
			push_error("Invalid Target Dummy animation: %s" % animation_name)
			quit(1)
			return
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, PLAYBACK_FPS)
		library.set_animation_loop(animation_name, LOOPED.has(animation_name))
		var entries: Array[Dictionary] = []
		var runtime_frames: Variant = data.get("frames", [])
		if runtime_frames is Array:
			for entry_variant: Variant in runtime_frames:
				entries.append(entry_variant as Dictionary)
		else:
			var frame_map := runtime_frames as Dictionary
			for frame_key: String in frame_map:
				entries.append(frame_map[frame_key] as Dictionary)
		entries.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("sourceFrameIndex", 0)) < int(b.get("sourceFrameIndex", 0))
		)
		for entry: Dictionary in entries:
			var rect_data: Dictionary = entry.get("region", entry.get("frame", {}))
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.filter_clip = true
			texture.region = Rect2(
				float(rect_data.get("x", 0)), float(rect_data.get("y", 0)),
				float(rect_data.get("w", 0)), float(rect_data.get("h", 0)),
			)
			var margin_data: Dictionary = entry.get("margin", {})
			if not margin_data.is_empty():
				texture.margin = Rect2(
					float(margin_data.get("x", 0)), float(margin_data.get("y", 0)),
					float(margin_data.get("w", 0)), float(margin_data.get("h", 0)),
				)
			var frame_seconds := float(entry.get("duration", 83)) / 1000.0
			library.add_frame(animation_name, texture, frame_seconds * PLAYBACK_FPS)
			total_frames += 1

	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save Target Dummy SpriteFrames: %s" % error_string(save_error))
		quit(1)
		return
	print("Built Target Dummy: %d animations / %d frames -> %s" % [
		library.get_animation_names().size(), total_frames, OUTPUT_PATH,
	])
	quit(0)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
