extends SceneTree

class QueryUnit:
	extends CharacterBody3D
	var team: StringName = &"friendly"
	var targetable := true

	func get_team() -> StringName:
		return team

	func is_enemy_of(other_team: StringName) -> bool:
		return team != other_team

	func is_targetable() -> bool:
		return targetable


func _initialize() -> void:
	await process_frame
	var source := _unit(&"friendly", Vector3.ZERO)
	var ally := _unit(&"friendly", Vector3(1.0, 0.0, 0.0))
	var near_enemy := _unit(&"enemy", Vector3(2.0, 0.0, 0.0))
	var far_enemy := _unit(&"enemy", Vector3(4.0, 0.0, 0.0))
	var relations_ok := CombatTargetQuery.matches_relation(source, near_enemy, "hostile") \
		and CombatTargetQuery.matches_relation(source, ally, "friendly") \
		and CombatTargetQuery.matches_relation(source, source, "self_or_friendly") \
		and not CombatTargetQuery.matches_relation(source, ally, "hostile")
	var spatial_ok := CombatTargetQuery.nearest_hostile(self, source, source.global_position, INF, false) == near_enemy \
		and CombatTargetQuery.hostiles_in_radius(self, source, source.global_position, 3.0).size() == 1 \
		and CombatTargetQuery.first_hostile_in_facing_arc(self, source, source.global_position, Vector3.RIGHT, 5.0, 0.15) == near_enemy \
		and CombatTargetQuery.first_hostile_on_segment(self, source, Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.3) == near_enemy
	near_enemy.targetable = false
	var excluded_ok := CombatTargetQuery.nearest_hostile(self, source, source.global_position, INF, false) == far_enemy \
		and CombatTargetQuery.first_hostile_on_segment(self, source, Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.3) == far_enemy
	print("COMBAT_TARGET_QUERY relations=%s spatial=%s excluded=%s" % [relations_ok, spatial_ok, excluded_ok])
	for unit in [source, ally, near_enemy, far_enemy]:
		unit.queue_free()
	quit(0 if relations_ok and spatial_ok and excluded_ok else 1)


func _unit(team: StringName, position: Vector3) -> QueryUnit:
	var unit := QueryUnit.new()
	unit.team = team
	root.add_child(unit)
	unit.global_position = position
	unit.add_to_group(&"combat_target")
	return unit
