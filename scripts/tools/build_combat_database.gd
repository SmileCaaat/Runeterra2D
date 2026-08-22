extends SceneTree

const BuilderScript = preload("res://scripts/data/combat_data_builder.gd")


func _initialize() -> void:
	var builder = BuilderScript.new()
	var result: Dictionary = builder.build()
	for warning: String in result.warnings:
		print("COMBAT_DATA WARNING: %s" % warning)
	for error: String in result.errors:
		push_error("COMBAT_DATA: %s" % error)
	if result.success:
		var database := result.database as Resource
		var unit_stats: Array = database.get("unit_stats")
		print("COMBAT_DATA built rules=%d stats=%d units=%d unit_stats=%d skills=%d effects=%d buffs=%d modifiers=%d hits=%d events=%d assets=%d particles=%d ai=%d digest=%s" % [
			(database.get("rules") as Array).size(), (database.get("stats") as Array).size(),
			(database.get("units") as Array).size(), unit_stats.size(), (database.get("skills") as Array).size(),
			(database.get("skill_effects") as Array).size(), (database.get("buffs") as Array).size(),
			(database.get("buff_modifiers") as Array).size(), (database.get("hit_profiles") as Array).size(),
			(database.get("animation_events") as Array).size(), (database.get("asset_profiles") as Array).size(),
			(database.get("particle_profiles") as Array).size(), (database.get("ai_profiles") as Array).size(),
			String(database.get("source_digest")).left(12),
		])
	quit(0 if result.success else 2)
