extends SceneTree

const SHEETS_ROOT := "res://assets/characters/rune_mage_ryze"
const OUTPUT_PATH := SHEETS_ROOT + "/ryze_sprite_frames.tres"
const LOOPED := {
	"channel": true,
	"idle": true,
	"run": true,
	"run_spell": true,
}


func _initialize() -> void:
	var library := _build_library()
	if library == null:
		quit(1)
		return
	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		quit(1)
		return
	print("Built %d Ryze character animations / %d frames -> %s" % [
		library.get_animation_names().size(), _frame_total(library), OUTPUT_PATH,
	])
	quit(0)


func _build_library() -> SpriteFrames:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var animation_names := DirAccess.get_directories_at(SHEETS_ROOT)
	animation_names.sort()
	for animation_name_string: String in animation_names:
		var folder := SHEETS_ROOT.path_join(animation_name_string)
		var data := _read_json(folder.path_join("spritesheet.json"))
		var atlas := load(folder.path_join("spritesheet.png")) as Texture2D
		if data.is_empty() or atlas == null:
			continue
		var animation_name := StringName(animation_name_string)
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, 10.0)
		library.set_animation_loop(animation_name, LOOPED.has(animation_name_string))
		var entries: Array[Dictionary] = []
		for frame_key: String in (data.get("frames", {}) as Dictionary):
			entries.append((data.frames as Dictionary)[frame_key] as Dictionary)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("sourceFrameIndex", 0)) < int(b.get("sourceFrameIndex", 0))
		)
		for entry: Dictionary in entries:
			var rect := entry.get("frame", {}) as Dictionary
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = atlas
			frame_texture.region = Rect2(
				float(rect.get("x", 0)), float(rect.get("y", 0)),
				float(rect.get("w", 0)), float(rect.get("h", 0)),
			)
			library.add_frame(animation_name, frame_texture, float(entry.get("duration", 100)) / 100.0)
	return library


func _frame_total(library: SpriteFrames) -> int:
	var total := 0
	for animation_name: StringName in library.get_animation_names():
		total += library.get_frame_count(animation_name)
	return total


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
