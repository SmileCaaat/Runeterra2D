class_name FloatingDamageNumbers
extends Node3D

# A small, pooled Sprite3D combat-text renderer.  The supplied sheets are
# deliberately treated as an atlas: no font resource or dynamic text texture
# is created during combat.
const COLOR_SHEET_PATH := "res://assets/ui/combat/brush_damage1.png"
const MISS_SHEET_PATH := "res://assets/ui/combat/brush_damage.png"

const DIGIT_COLUMNS := 10
const DIGIT_ROWS := 4
const DIGIT_CELL_SIZE := Vector2(100.0, 133.0)
const MISS_REGION := Rect2(0.0, 532.0, 300.0, 135.0)

var _database: CombatDatabase
var _entries: Array[DamageEntry] = []
# DamageEntry owns its own RNG; the outer class does not need one.


static func get_or_create(host: Node3D, database: CombatDatabase = null) -> FloatingDamageNumbers:
	var existing := host.get_node_or_null("FloatingDamageNumbers") as FloatingDamageNumbers
	if existing != null:
		if database != null:
			existing.configure(database)
		return existing
	var component := FloatingDamageNumbers.new()
	component.name = "FloatingDamageNumbers"
	host.add_child(component)
	component.configure(database)
	return component


func configure(database: CombatDatabase) -> void:
	_database = database
	_ensure_pool()


func show_damage(amount: float, damage_type: StringName, is_critical := false) -> void:
	_ensure_pool()
	var entry := _acquire_entry()
	entry.show_number(maxi(0, roundi(amount)), _row_for_damage_type(damage_type), is_critical, _settings())


func show_miss() -> void:
	_ensure_pool()
	_acquire_entry().show_miss(_settings())


func _ensure_pool() -> void:
	var desired := int(_rule(&"presentation.damage_number_pool_size", 18))
	while _entries.size() < desired:
		var entry := DamageEntry.new()
		entry.name = "DamageEntry%d" % _entries.size()
		entry.configure(_load_sheet(COLOR_SHEET_PATH), _load_sheet(MISS_SHEET_PATH))
		add_child(entry)
		_entries.append(entry)


func _acquire_entry() -> DamageEntry:
	for entry: DamageEntry in _entries:
		if not entry.active:
			return entry
	var oldest := _entries[0]
	for entry: DamageEntry in _entries:
		if entry.age > oldest.age:
			oldest = entry
	return oldest


func _row_for_damage_type(damage_type: StringName) -> int:
	match damage_type:
		&"physical": return 2 # brush_damage1 third row: orange.
		&"magic": return 3 # brush_damage1 fourth row: blue.
		&"true": return 0 # brush_damage1 first row: white.
		_: return 0


func _settings() -> Dictionary:
	return {
		"pixel_size": float(_rule(&"presentation.damage_number_pixel_size", 0.004)),
		"height": float(_rule(&"presentation.damage_number_height", 1.75)),
		"duration": float(_rule(&"presentation.damage_number_duration", 0.42)),
		"rise_distance": float(_rule(&"presentation.damage_number_rise_distance", 0.48)),
		"normal_scale": float(_rule(&"presentation.damage_number_normal_scale", 1.0)),
		"critical_scale": float(_rule(&"presentation.damage_number_critical_scale", 1.42)),
		"critical_punch": float(_rule(&"presentation.damage_number_critical_punch", 0.24)),
		"lateral_jitter": float(_rule(&"presentation.damage_number_lateral_jitter", 0.16)),
	}


func _rule(id: StringName, fallback: Variant) -> Variant:
	return _database.get_rule(id, fallback) if _database != null else fallback


func _load_sheet(path: String) -> Texture2D:
	# Loading from an Image keeps this lightweight atlas usable immediately after
	# an external PNG replacement, without depending on an editor reimport pass.
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null


class DamageEntry extends Node3D:
	var active := false
	var age := 0.0
	var _duration := 0.42
	var _rise_distance := 0.48
	var _critical := false
	var _base_scale := 1.0
	var _critical_punch := 0.24
	var _lateral_velocity := 0.0
	var _height := 1.75
	var _glyphs: Array[Sprite3D] = []
	var _color_sheet: Texture2D
	var _miss_sheet: Texture2D
	var _random := RandomNumberGenerator.new()

	func configure(color_sheet: Texture2D, miss_sheet: Texture2D) -> void:
		_color_sheet = color_sheet
		_miss_sheet = miss_sheet
		_random.seed = 20260826 + get_instance_id()
		visible = false
		for index: int in range(7):
			var glyph := Sprite3D.new()
			glyph.name = "Glyph%d" % index
			glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			glyph.no_depth_test = true
			glyph.render_priority = 120
			glyph.shaded = false
			glyph.visible = false
			add_child(glyph)
			_glyphs.append(glyph)

	func show_number(value: int, row: int, is_critical: bool, settings: Dictionary) -> void:
		var characters := str(value)
		_start(is_critical, settings)
		var pixel_size := float(settings.pixel_size)
		var spacing := DIGIT_CELL_SIZE.x * pixel_size * 0.87
		var total_width := (characters.length() - 1) * spacing
		for glyph_index: int in _glyphs.size():
			var glyph := _glyphs[glyph_index]
			glyph.visible = glyph_index < characters.length()
			if not glyph.visible:
				continue
			var digit := int(characters.substr(glyph_index, 1))
			glyph.texture = _atlas(_color_sheet, Rect2(digit * DIGIT_CELL_SIZE.x, row * DIGIT_CELL_SIZE.y, DIGIT_CELL_SIZE.x, DIGIT_CELL_SIZE.y))
			glyph.pixel_size = pixel_size
			glyph.position = Vector3(glyph_index * spacing - total_width * 0.5, 0.0, 0.0)

	func show_miss(settings: Dictionary) -> void:
		_start(false, settings)
		for glyph_index: int in _glyphs.size():
			var glyph := _glyphs[glyph_index]
			glyph.visible = glyph_index == 0
			if glyph.visible:
				glyph.texture = _atlas(_miss_sheet, MISS_REGION)
				glyph.pixel_size = float(settings.pixel_size)
				glyph.position = Vector3.ZERO

	func _start(is_critical: bool, settings: Dictionary) -> void:
		active = true
		visible = true
		age = 0.0
		_critical = is_critical
		_duration = float(settings.duration)
		_rise_distance = float(settings.rise_distance)
		_base_scale = float(settings.critical_scale if is_critical else settings.normal_scale)
		_critical_punch = float(settings.critical_punch)
		_lateral_velocity = _random.randf_range(-float(settings.lateral_jitter), float(settings.lateral_jitter))
		_height = float(settings.height)
		position = Vector3(0.0, _height, 0.08)
		scale = Vector3.ONE * (0.72 if is_critical else 0.88)
		_set_alpha(1.0)

	func _process(delta: float) -> void:
		if not active:
			return
		age += delta
		var progress := clampf(age / maxf(_duration, 0.01), 0.0, 1.0)
		position.x += _lateral_velocity * delta
		position.y = _height
		for glyph: Sprite3D in _glyphs:
			if glyph.visible:
				glyph.position.y = progress * _rise_distance
		var intro := clampf(progress / 0.16, 0.0, 1.0)
		var punch := 1.0
		if _critical:
			punch += sin(intro * PI) * _critical_punch
		scale = Vector3.ONE * _base_scale * lerpf(0.72 if _critical else 0.88, 1.0, intro) * punch
		_set_alpha(1.0 - smoothstep(0.62, 1.0, progress))
		if progress >= 1.0:
			active = false
			visible = false

	func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		return atlas

	func _set_alpha(alpha: float) -> void:
		for glyph: Sprite3D in _glyphs:
			glyph.modulate = Color(1.0, 1.0, 1.0, alpha)
