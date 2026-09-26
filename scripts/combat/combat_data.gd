class_name CombatData
extends RefCounted

const DATABASE_PATH := "res://data/generated/combat_database.tres"
static var _database: CombatDatabase
static var _missing_reported := false


static func database() -> CombatDatabase:
	if _database == null:
		_database = load(DATABASE_PATH) as CombatDatabase
		if _database != null:
			_database.rebuild_indexes()
		elif not _missing_reported:
			push_error("Required combat database is missing: %s. Build data before running gameplay." % DATABASE_PATH)
			_missing_reported = true
	return _database


static func reload() -> CombatDatabase:
	_database = ResourceLoader.load(DATABASE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as CombatDatabase
	if _database != null:
		_database.rebuild_indexes()
	return _database
