extends SceneTree

const SOURCE_ROOT := "res://assets/vfx/garen_perseverance"
const OUTPUT_PATH := SOURCE_ROOT + "/garen_perseverance_frames.tres"
const ANIMATIONS := [&"slow1", &"hip"]


func _initialize() -> void:
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	var total_frames := 0
	for animation_name: StringName in ANIMATIONS:
		var files: Array[String] = []
		for file_name: String in DirAccess.get_files_at(SOURCE_ROOT.path_join(String(animation_name))):
			if file_name.get_extension().to_lower() == "png":
				files.append(file_name)
		files.sort_custom(func(a: String, b: String) -> bool: return a.get_basename().to_int() < b.get_basename().to_int())
		if files.is_empty():
			push_error("No PNG frames found for %s" % animation_name)
			quit(1)
			return
		library.add_animation(animation_name)
		library.set_animation_speed(animation_name, 12.0)
		library.set_animation_loop(animation_name, true)
		for file_name: String in files:
			var frame := load(SOURCE_ROOT.path_join(String(animation_name)).path_join(file_name)) as Texture2D
			if frame == null:
				push_error("Cannot load passive VFX frame: %s" % file_name)
				quit(1)
				return
			library.add_frame(animation_name, frame)
			total_frames += 1
	var save_error := ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save passive VFX library: %s" % error_string(save_error))
		quit(1)
		return
	print("Built Perseverance VFX: %d animations / %d frames" % [ANIMATIONS.size(), total_frames])
	quit()
