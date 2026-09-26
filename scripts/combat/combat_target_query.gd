class_name CombatTargetQuery
extends RefCounted

## Shared combat target semantics. All spatial checks use the ground X/Z plane;
## disabled training units are excluded by the combat_target group.
static func matches_relation(source: Node3D, candidate: Variant, relation: String) -> bool:
	if source == null or not is_instance_valid(source) or not is_instance_valid(candidate) or not (candidate is CharacterBody3D):
		return false
	if candidate == source:
		return relation in ["self_or_friendly", "any"]
	if not candidate.is_in_group(&"combat_target"):
		return false
	if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
		return false
	if relation == "any":
		return true
	if relation == "none" or not source.has_method("get_team"):
		return false
	var source_team := StringName(source.call("get_team"))
	var hostile := false
	if candidate.has_method("is_enemy_of"):
		hostile = bool(candidate.call("is_enemy_of", source_team))
	elif candidate.has_method("get_team"):
		hostile = StringName(candidate.call("get_team")) != source_team
	else:
		return false
	if relation == "hostile":
		return hostile
	return not hostile and relation in ["friendly", "self_or_friendly"]


static func nearest_hostile(tree: SceneTree, source: Node3D, origin: Vector3, max_range := INF, prefer_hero := false) -> CharacterBody3D:
	var closest: CharacterBody3D
	var closest_hero: CharacterBody3D
	var best_distance := INF
	var best_hero_distance := INF
	for candidate_node: Node in tree.get_nodes_in_group(&"combat_target"):
		if not matches_relation(source, candidate_node, "hostile"):
			continue
		var candidate := candidate_node as CharacterBody3D
		var offset := Vector2(candidate.global_position.x - origin.x, candidate.global_position.z - origin.z)
		var distance_squared := offset.length_squared()
		if distance_squared > max_range * max_range:
			continue
		if distance_squared < best_distance:
			closest = candidate
			best_distance = distance_squared
		if prefer_hero and candidate.is_in_group(&"hero_actor") and distance_squared < best_hero_distance:
			closest_hero = candidate
			best_hero_distance = distance_squared
	return closest_hero if closest_hero != null else closest


static func hostiles_in_radius(tree: SceneTree, source: Node3D, center: Vector3, radius: float) -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	var radius_squared := radius * radius
	for candidate_node: Node in tree.get_nodes_in_group(&"combat_target"):
		if not matches_relation(source, candidate_node, "hostile"):
			continue
		var candidate := candidate_node as CharacterBody3D
		var offset := Vector2(candidate.global_position.x - center.x, candidate.global_position.z - center.z)
		if offset.length_squared() <= radius_squared:
			result.append(candidate)
	return result


static func first_hostile_on_segment(tree: SceneTree, source: Node3D, from: Vector3, to: Vector3, hit_radius: float, contact_point: Callable = Callable()) -> CharacterBody3D:
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var segment := end - start
	var length_squared := segment.length_squared()
	var best_progress := INF
	var best: CharacterBody3D
	for candidate_node: Node in tree.get_nodes_in_group(&"combat_target"):
		if not matches_relation(source, candidate_node, "hostile"):
			continue
		var candidate := candidate_node as CharacterBody3D
		var contact: Vector3 = contact_point.call(candidate) if contact_point.is_valid() else candidate.global_position
		var point := Vector2(contact.x, contact.z)
		var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0001 else 0.0
		if start.lerp(end, progress).distance_to(point) > hit_radius:
			continue
		if progress < best_progress:
			best = candidate
			best_progress = progress
	return best


static func first_hostile_in_facing_arc(tree: SceneTree, source: Node3D, origin: Vector3, facing: Vector3, radius: float, minimum_dot: float) -> CharacterBody3D:
	var facing_planar := Vector2(facing.x, facing.z)
	if facing_planar.length_squared() <= 0.0001:
		return null
	facing_planar = facing_planar.normalized()
	var closest: CharacterBody3D
	var best_distance := INF
	for candidate_node: Node in tree.get_nodes_in_group(&"combat_target"):
		if not matches_relation(source, candidate_node, "hostile"):
			continue
		var candidate := candidate_node as CharacterBody3D
		var offset := Vector2(candidate.global_position.x - origin.x, candidate.global_position.z - origin.z)
		var distance := offset.length()
		if distance > radius or (distance > 0.001 and facing_planar.dot(offset / distance) < minimum_dot):
			continue
		if distance < best_distance:
			closest = candidate
			best_distance = distance
	return closest
