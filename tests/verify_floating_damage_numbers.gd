extends SceneTree

const FloatingDamageNumbersScript = preload("res://scripts/presentation/floating_damage_numbers.gd")


func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var numbers := FloatingDamageNumbersScript.get_or_create(host) as FloatingDamageNumbers
	numbers.show_damage(123.0, &"physical", false)
	var entry := numbers.get_node("DamageEntry0") as Node3D
	var physical_glyph := entry.get_node("Glyph0") as Sprite3D
	var physical_atlas := physical_glyph.texture as AtlasTexture
	var physical_ok := physical_atlas != null and physical_atlas.region.position.is_equal_approx(Vector2(100.0, 266.0))

	numbers.show_damage(456.0, &"magic", true)
	var magic_entry := numbers.get_node("DamageEntry1") as Node3D
	var magic_glyph := magic_entry.get_node("Glyph0") as Sprite3D
	var magic_atlas := magic_glyph.texture as AtlasTexture
	var magic_ok := magic_atlas != null and magic_atlas.region.position.is_equal_approx(Vector2(400.0, 399.0))
	magic_entry.call("_process", 0.04)
	var critical_ok := magic_entry.scale.x > entry.scale.x and magic_glyph.no_depth_test

	numbers.show_damage(789.0, &"true", false)
	var true_entry := numbers.get_node("DamageEntry2") as Node3D
	var true_glyph := true_entry.get_node("Glyph0") as Sprite3D
	var true_atlas := true_glyph.texture as AtlasTexture
	var true_ok := true_atlas != null and true_atlas.region.position.is_equal_approx(Vector2(700.0, 0.0))

	numbers.show_miss()
	var miss_entry := numbers.get_node("DamageEntry3") as Node3D
	var miss_glyph := miss_entry.get_node("Glyph0") as Sprite3D
	var miss_atlas := miss_glyph.texture as AtlasTexture
	var miss_ok := miss_atlas != null and miss_atlas.region == Rect2(0.0, 532.0, 300.0, 135.0)

	print("FLOATING_DAMAGE_NUMBERS physical=%s magic=%s true=%s critical=%s miss=%s" % [physical_ok, magic_ok, true_ok, critical_ok, miss_ok])
	quit(0 if physical_ok and magic_ok and true_ok and critical_ok and miss_ok else 2)
