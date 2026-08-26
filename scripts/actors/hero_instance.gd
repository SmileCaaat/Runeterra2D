class_name HeroInstance
extends "res://scripts/actors/combat_unit_instance.gd"


func bind_hero_instance(database: CombatDatabase, definition: UnitDefinition) -> void:
	bind_combat_instance(database, definition)
	add_to_group(&"hero_actor")
