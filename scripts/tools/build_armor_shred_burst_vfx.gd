extends SceneTree

const SOURCE_ROOT := "res://assets/vfx/status/armor_shred"
const OUTPUT_PATH := SOURCE_ROOT + "/armor_shred_burst_frames.tres"


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.clear_all()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(&"burst")
	frames.set_animation_speed(&"burst", 15.0)
	frames.set_animation_loop(&"burst", false)
	var names: Array[String] = []
	for name: String in DirAccess.get_files_at(SOURCE_ROOT):
		if name.get_extension().to_lower() == "png":
			names.append(name)
	names.sort_custom(func(a: String, b: String) -> bool: return a.get_basename().to_int() < b.get_basename().to_int())
	for name: String in names:
		var texture := load(SOURCE_ROOT.path_join(name)) as Texture2D
		if texture == null:
			push_error("Missing armor shred frame: %s" % name)
			quit(1)
			return
		frames.add_frame(&"burst", texture)
	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Could not save armor shred frames: %s" % error_string(error))
		quit(1)
		return
	print("Built armor shred burst: %d frames" % names.size())
	quit()
