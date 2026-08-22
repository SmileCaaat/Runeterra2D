class_name CombatData
extends RefCounted

const DATABASE_PATH := "res://data/generated/combat_database.tres"
static var _database: CombatDatabase


static func database() -> CombatDatabase:
	if _database == null:
		_database = load(DATABASE_PATH) as CombatDatabase
		if _database != null:
			_database.rebuild_indexes()
	return _database


static func reload() -> CombatDatabase:
	_database = ResourceLoader.load(DATABASE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as CombatDatabase
	if _database != null:
		_database.rebuild_indexes()
	return _database
