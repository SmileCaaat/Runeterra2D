@tool
extends AnimatedSprite3D

## Builds SpriteFrames from the fixed-cell JSON sheets exported by
## XSXB Frame Tuner Lite. The JSON canvas origin is treated as the
## character's ground contact point, so differently shaped frames do not
## make the character slide or bounce.

@export_dir var sheets_root := "res://assets/characters/rogue_admiral_garen"
@export var imported_animations := PackedStringArray([
	"attack1", "attack2", "attack3", "channel", "channel_wndup", "dance",
	"dance_base", "death", "hit", "idle1", "idle2", "idle3", "joke",
	"laugh", "recall", "respawn", "run", "run_spell", "spell1", "spell3",
	"spell4", "taunt",
])
@export var looped_animations := PackedStringArray([
	"channel", "dance_base", "idle1", "idle2", "idle3", "run", "run_spell",
])
@export var default_animation: StringName = &"idle1"
@export_range(0.0001, 0.02, 0.0001) var world_units_per_pixel := 0.0024
@export var autoplay_default := true
@export var rebuild_now := false:
	set(value):
		rebuild_now = false
		if value:
			call_deferred("_rebuild_sprite_frames")


func _ready() -> void:
	call_deferred("_ensure_sprite_frames")


func _ensure_sprite_frames() -> void:
	if sprite_frames == null:
		_rebuild_sprite_frames()
		return
	if not sprite_frames.has_animation(default_animation):
		_rebuild_sprite_frames()
		return
	if sprite_frames.get_frame_count(default_animation) == 0:
		_rebuild_sprite_frames()


func _rebuild_sprite_frames() -> void:
	var built_frames := SpriteFrames.new()
	built_frames.clear_all()
	var anchor_was_set := false

	for animation_name_string in imported_animations:
		var animation_name := StringName(animation_name_string)
		var sheet_dir := sheets_root.path_join(animation_name_string)
		var json_path := sheet_dir.path_join("spritesheet.json")
		var texture_path := sheet_dir.path_join("spritesheet.png")
		var data := _read_json_dictionary(json_path)
		if data.is_empty():
			continue

		var atlas_image := load(texture_path) as Texture2D
		if atlas_image == null:
			push_error("Could not load spritesheet texture: %s" % texture_path)
			continue

		built_frames.add_animation(animation_name)
		built_frames.set_animation_speed(animation_name, 10.0)
		built_frames.set_animation_loop(animation_name, looped_animations.has(animation_name_string))

		var ordered_entries: Array[Dictionary] = []
		var frame_map: Dictionary = data.get("frames", {})
		for frame_key in frame_map:
			var entry: Dictionary = frame_map[frame_key]
			ordered_entries.append(entry)
		ordered_entries.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("sourceFrameIndex", 0)) < int(b.get("sourceFrameIndex", 0))
		)

		for entry in ordered_entries:
			var frame_rect: Dictionary = entry.get("frame", {})
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = atlas_image
			atlas_frame.region = Rect2(
				float(frame_rect.get("x", 0)),
				float(frame_rect.get("y", 0)),
				float(frame_rect.get("w", 0)),
				float(frame_rect.get("h", 0)),
			)
			var duration_scale := float(entry.get("duration", 100)) / 100.0
			built_frames.add_frame(animation_name, atlas_frame, duration_scale)

		if not anchor_was_set:
			_apply_canvas_anchor(data)
			anchor_was_set = true

	if built_frames.get_animation_names().is_empty():
		push_error("No sprite animations were built from %s" % sheets_root)
		return

	sprite_frames = built_frames
	pixel_size = world_units_per_pixel
	animation = default_animation
	frame = 0
	if autoplay_default:
		play(default_animation)


func _apply_canvas_anchor(data: Dictionary) -> void:
	var meta: Dictionary = data.get("meta", {})
	var canvas: Dictionary = meta.get("canvas", {})
	var canvas_width := float(canvas.get("width", 0))
	var canvas_height := float(canvas.get("height", 0))
	var origin_x := float(canvas.get("originPixelX", canvas_width * 0.5))
	var origin_y := float(canvas.get("originPixelY", canvas_height))
	offset = Vector2(canvas_width * 0.5 - origin_x, origin_y - canvas_height * 0.5)


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open spritesheet JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid spritesheet JSON: %s" % path)
		return {}
	return parsed as Dictionary
