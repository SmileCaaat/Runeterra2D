extends SceneTree

const BuilderScript = preload("res://scripts/data/combat_data_builder.gd")


func _initialize() -> void:
	var result: Dictionary = BuilderScript.new().build("res://data/source", "user://hero_ai_taxonomy_test.tres")
	var database := result.database as CombatDatabase
	var garen := database.get_unit(&"garen") if database != null else null
	var fighter := database.get_hero_class(&"fighter") if database != null else null
	var juggernaut := database.get_hero_subclass(&"juggernaut") if database != null else null
	var archetype := database.get_ai_archetype(&"juggernaut_pressure") if database != null else null
	var profile := database.get_ai_profile(&"garen_demo") if database != null else null
	var valid := bool(result.success) and garen != null and fighter != null and juggernaut != null and archetype != null and profile != null
	valid = valid and garen.class_id == &"fighter" and garen.subclass_id == &"juggernaut"
	valid = valid and juggernaut.get("class_id") == &"fighter" and juggernaut.get("ai_archetype_id") == &"juggernaut_pressure"
	valid = valid and profile.archetype_id == &"juggernaut_pressure" and archetype.get("decision_mode") == "melee_pressure"
	valid = valid and is_equal_approx(float(archetype.get("engage_distance")), 2.4)
	valid = valid and is_equal_approx(float(archetype.get("execute_health_ratio")), 0.33)
	print("HERO_AI_TAXONOMY valid=%s class=%s subclass=%s archetype=%s mode=%s" % [
		valid, garen.class_id if garen != null else &"", garen.subclass_id if garen != null else &"",
		profile.archetype_id if profile != null else &"", archetype.get("decision_mode") if archetype != null else "",
	])
	quit(0 if valid else 2)
