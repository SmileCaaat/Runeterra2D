class_name MonsterInstance
extends "res://scripts/actors/combat_unit_instance.gd"


func bind_monster_instance(database: CombatDatabase, definition: UnitDefinition) -> void:
	bind_combat_instance(database, definition)
	add_to_group(&"combat_target")
