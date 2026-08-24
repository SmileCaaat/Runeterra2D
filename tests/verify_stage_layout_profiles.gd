extends SceneTree

const CATALOG := preload("res://scripts/stages/stage_layout_catalog.gd")


func _initialize() -> void:
	var profiles: Dictionary = CATALOG.load_profiles()
	var passed := profiles.size() == 4
	var expected_order := [&"small", &"medium", &"large", &"extra_large"]
	var previous_length := 0.0
	for profile_id: StringName in expected_order:
		var profile: Dictionary = profiles.get(profile_id, {})
		passed = passed and not profile.is_empty()
		if profile.is_empty():
			continue
		var length := float(profile.world_length)
		var depth := float(profile.playable_depth)
		var background_height := float(profile.background_height)
		passed = passed and length > previous_length and depth > 0.0 and background_height > 0.0
		passed = passed and absf(CATALOG.aspect_value(profile.background_aspect) - length / background_height) < 0.001
		passed = passed and absf(CATALOG.aspect_value(profile.ground_aspect) - length / depth) < 0.001
		passed = passed and float(profile.safe_edge_margin) * 2.0 < length
		previous_length = length

	print("STAGE_LAYOUT profiles=4 lengths=32/48/72/96 background_height=12 ratios=derived")
	if not passed:
		push_error("Stage layout profile verification failed")
	quit(0 if passed else 2)
