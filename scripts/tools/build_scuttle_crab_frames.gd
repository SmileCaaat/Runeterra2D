extends SceneTree

const SOURCE_ROOT := "res://assets/monsters/scuttle_crab"
const OUTPUT_PATH := SOURCE_ROOT + "/scuttle_crab_sprite_frames.tres"
const ANIMATIONS := [&"idle", &"run", &"hurt", &"dash", &"spawn"]
const LOOPED := {&"idle": true, &"run": true, &"dash": true}
const PLAYBACK_FPS := 12.0

func _initialize() -> void:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0
	for animation_name: StringName in ANIMATIONS:
		var folder := SOURCE_ROOT.path_join(String(animation_name))
		var data := _read_json(folder.path_join("runtime_manifest.json"))
		var atlas := load(folder.path_join("runtime_atlas.png")) as Texture2D
		if data.is_empty() or atlas == null:
			push_error("Invalid Scuttle Crab animation: %s" % animation_name)
			quit(1)
			return
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, PLAYBACK_FPS)
		library.set_animation_loop(animation_name, LOOPED.has(animation_name))
		var entries: Array[Dictionary] = []
		for entry_variant: Variant in data.get("frames", []):
			entries.append(entry_variant as Dictionary)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sourceFrameIndex) < int(b.sourceFrameIndex))
		for entry: Dictionary in entries:
			var rect: Dictionary = entry.region
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.filter_clip = true
			texture.region = Rect2(rect.x, rect.y, rect.w, rect.h)
			var margin: Dictionary = entry.margin
			texture.margin = Rect2(margin.x, margin.y, margin.w, margin.h)
			library.add_frame(animation_name, texture, float(entry.get("duration", 83)) / 1000.0 * PLAYBACK_FPS)
			total_frames += 1
	var error := ResourceSaver.save(library, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save Scuttle Crab SpriteFrames: %s" % error_string(error))
		quit(1)
		return
	print("Built Scuttle Crab: %d animations / %d frames" % [library.get_animation_names().size(), total_frames])
	quit(0)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed as Dictionary if parsed is Dictionary else {}
