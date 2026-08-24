class_name StageLayoutCatalog
extends RefCounted

const SOURCE_PATH := "res://data/source/stage_layout_profiles.csv"


static func load_profiles() -> Dictionary[StringName, Dictionary]:
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var headers := file.get_csv_line()
	var profiles: Dictionary[StringName, Dictionary] = {}
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.is_empty() or values[0].strip_edges().is_empty():
			continue
		var row := {}
		for index: int in range(mini(headers.size(), values.size())):
			row[headers[index]] = values[index]
		var profile_id := StringName(String(row.get("profile_id", "")))
		profiles[profile_id] = {
			"id": profile_id,
			"display_name": String(row.get("display_name", "")),
			"world_length": float(row.get("world_length", 0.0)),
			"playable_depth": float(row.get("playable_depth", 0.0)),
			"background_height": float(row.get("background_height", 0.0)),
			"background_aspect": String(row.get("background_aspect", "")),
			"ground_aspect": String(row.get("ground_aspect", "")),
			"safe_edge_margin": float(row.get("safe_edge_margin", 0.0)),
			"recommended_background_pixels": String(row.get("recommended_background_pixels", "")),
			"recommended_ground_pixels": String(row.get("recommended_ground_pixels", "")),
		}
	return profiles


static func aspect_value(aspect: String) -> float:
	var parts := aspect.split(":")
	if parts.size() != 2:
		return 0.0
	var denominator := float(parts[1])
	return float(parts[0]) / denominator if not is_zero_approx(denominator) else 0.0
