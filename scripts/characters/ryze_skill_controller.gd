class_name RyzeSkillController
extends Node

## Owns Ryze's mutable skill state. The actor exposes forwarding properties for
## existing HUD/debug contracts while player and AI keep a shared action gate.

var cooldowns: Dictionary = {&"q": 0.0, &"w": 0.0, &"e": 0.0, &"r": 0.0, &"t": 0.0}
var arcane_stacks := 0
var arcane_timer := 0.0
var supercharged_casts := 0
var supercharged_timer := 0.0
var desperate_timer := 0.0
var attack_index := 0
var attack_timer := 0.0
var action_lock := 0.0
var super_armor_timer := 0.0
var r_landing_resolving := false
var r_landing_zapped: Dictionary = {}


func _actor() -> Variant:
	return get_parent()


func tick_effects(delta: float) -> void:
	for key: StringName in cooldowns:
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	arcane_timer = maxf(0.0, arcane_timer - delta)
	if arcane_timer <= 0.0 and arcane_stacks > 0:
		arcane_stacks = 0
	supercharged_timer = maxf(0.0, supercharged_timer - delta)
	if supercharged_timer <= 0.0:
		supercharged_casts = 0
	desperate_timer = maxf(0.0, desperate_timer - delta)
	super_armor_timer = maxf(0.0, super_armor_timer - delta)


func tick_action_lock(delta: float) -> void:
	action_lock = maxf(0.0, action_lock - delta)


func reset_on_death() -> void:
	action_lock = 0.0
	super_armor_timer = 0.0


func reset_for_training() -> void:
	for key: StringName in cooldowns:
		cooldowns[key] = 0.0
	arcane_stacks = 0
	arcane_timer = 0.0
	supercharged_casts = 0
	supercharged_timer = 0.0
	desperate_timer = 0.0
	attack_index = 0
	attack_timer = 0.0
	action_lock = 0.0
	super_armor_timer = 0.0


## Cast events remain measured in authored seconds even when Supercharge speeds
## up the GLB animation. The lock releases only after the event and recovery.
func play_action_to_end(animation: StringName, cast_event_seconds: float, event: Callable) -> void:
	var actor: Variant = _actor()
	var model: Node3D = actor.character_model
	action_lock = INF
	var supercharged: bool = is_supercharged() and is_supercharge_cast_animation(animation)
	var speed: float = supercharge_cast_speed() if supercharged else cast_speed()
	model.call(&"set_animation_speed", speed)
	model.call(&"play_semantic", animation)
	var event_sent := false
	var event_elapsed := -1.0
	var event_time := cast_event_seconds / speed
	var recovery: float = actor._rulef(&"ryze.cast.recovery_seconds", 0.35)
	var min_lock: float = actor._rulef(&"ryze.supercharge.min_lock_seconds", 0.70) if supercharged else actor._rulef(&"ryze.cast.min_lock_seconds", 0.90)
	while StringName(model.get(&"current_animation")) == animation and bool(model.call(&"is_playing")):
		var elapsed: float = actor._animation_elapsed_seconds()
		if not event_sent and elapsed >= event_time:
			event_sent = true
			event_elapsed = elapsed
			if supercharged and actor.supercharge_mesh_afterimage != null:
				actor.supercharge_mesh_afterimage.capture(model)
			event.call()
		var unlock_at := min_lock
		if event_sent:
			unlock_at = maxf(event_elapsed + recovery, min_lock)
		if elapsed >= unlock_at:
			break
		await get_tree().process_frame
	if not event_sent:
		if supercharged and actor.supercharge_mesh_afterimage != null:
			actor.supercharge_mesh_afterimage.capture(model)
		event.call()
	action_lock = 0.0


## Begins one basic attack. Guided and directional projectiles share the same
## cast event; only projectile travel and hit acquisition differ.
func basic_attack(victim: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	var animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"crit"]
	var animation := animations[attack_index]
	attack_index = (attack_index + 1) % animations.size()
	await play_action_to_end(animation, actor._cast_event_seconds(animation, 0.5), func() -> void:
		launch_projectile(victim, &"basic_attack", actor._basic_missile_speed(), &"basic")
	)


func basic_attack_directional(direction: Vector3) -> void:
	var actor: Variant = _actor()
	var animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"crit"]
	var animation := animations[attack_index]
	attack_index = (attack_index + 1) % animations.size()
	await play_action_to_end(animation, actor._cast_event_seconds(animation, 0.5), func() -> void:
		launch_directional_projectile(animation, actor._basic_missile_speed(), &"basic", direction, basic_attack_range())
	)


func cast_q(victim: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	cooldowns[&"q"] = actor._skill_cooldown(&"ryze_overload", 4.0)
	add_arcane_stack(true)
	await play_action_to_end(&"spell1", actor._cast_event_seconds(&"spell1", 0.3), func() -> void:
		launch_projectile(victim, &"Spell1_Q", rulef(&"ryze.q.missile_speed", 17.0), &"q")
	)


func cast_q_directional(direction: Vector3) -> void:
	var actor: Variant = _actor()
	cooldowns[&"q"] = actor._skill_cooldown(&"ryze_overload", 4.0)
	add_arcane_stack(true)
	await play_action_to_end(&"spell1", actor._cast_event_seconds(&"spell1", 0.3), func() -> void:
		launch_directional_projectile(&"Spell1_Q", rulef(&"ryze.q.missile_speed", 17.0), &"q", direction, skill_range(&"ryze_overload"))
	)


func cast_w(victim: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	cooldowns[&"w"] = actor._skill_cooldown(&"ryze_rune_prison", 14.0)
	add_arcane_stack(true)
	await play_action_to_end(&"spell2", actor._cast_event_seconds(&"spell2", 0.5), func() -> void:
		if actor._valid_target(victim):
			actor._play_target_vfx(victim, &"Spell2_W")
			actor._damage(victim, actor._ranked_damage(&"ryze_w_damage", 80.0), &"magic", &"ryze_w_hit")
			var root_duration: float = actor._ranked_control(&"ryze_w_root", 1.0)
			var applied_root_duration := float(victim.call("apply_root", root_duration))
			actor._play_w_loop(victim, applied_root_duration)
	)


func cast_e(victim: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	cooldowns[&"e"] = actor._skill_cooldown(&"ryze_spell_flux", 7.0)
	add_arcane_stack(true)
	await play_action_to_end(&"spell3", actor._cast_event_seconds(&"spell3", 0.6), func() -> void:
		launch_projectile(victim, &"Spell3_E", rulef(&"ryze.e.missile_speed", 15.0), &"e")
	)


func cast_desperate_power() -> void:
	var actor: Variant = _actor()
	if cooldowns[&"t"] > 0.0:
		return
	cooldowns[&"t"] = actor._skill_cooldown(&"ryze_desperate_power", 50.0)
	actor.character_model.call(&"play_semantic", &"taunt")
	var channel: float = actor._rulef(&"ryze.t.channel_duration", 0.8)
	action_lock = channel
	super_armor_timer = channel
	_request_awakening_cutin(&"ryze_desperate_power")
	await get_tree().create_timer(channel).timeout
	desperate_timer = desperate_duration()
	actor._sync_t_buff_presentation()
	if actor._rulei(&"ryze.t.grant_supercharge", 1) != 0:
		grant_supercharge()
	else:
		add_arcane_stack(false)


func _request_awakening_cutin(skill_id: StringName) -> void:
	var manager := get_node_or_null("/root/AwakeningCutIn")
	if manager == null:
		manager = get_tree().get_first_node_in_group(&"awakening_cutin_manager")
	if manager == null or not manager.has_method("request_skill"):
		return
	manager.call("request_skill", skill_id, {"source": _actor()})


## Realm Warp keeps the authored channel, ally collection, landing effects and
## winddown behavior; only the owner of its mutable cast state changes.
func cast_realm_warp(destination: Vector3) -> void:
	var actor: Variant = _actor()
	if cooldowns[&"r"] > 0.0:
		return
	cooldowns[&"r"] = actor._skill_cooldown(&"ryze_realm_warp", 180.0)
	var channel: float = actor._rulef(&"ryze.r.channel_duration", 0.9)
	var previous_animation_speed := _play_realm_warp_windup(channel)
	action_lock = channel
	await get_tree().create_timer(channel).timeout
	actor.character_model.call(&"set_animation_speed", previous_animation_speed)
	var origin: Vector3 = actor.global_position
	var planar: Vector3 = actor._clamp_to_arena(destination) - origin
	planar.y = 0.0
	var delta := planar.limit_length(actor._warp_range())
	var ally_radius: float = actor._skill_radius(&"ryze_realm_warp", 5.5)
	var allies := _collect_warp_allies(ally_radius)
	_teleport_actor(actor, origin + delta)
	for ally: CharacterBody3D in allies:
		_teleport_actor(ally, ally.global_position + delta)
	actor.character_model.call(&"play_semantic", &"spell4_winddown")
	action_lock = float(actor.character_model.call(&"get_semantic_animation_length", &"spell4_winddown"))
	actor._play_r_winddown()
	r_landing_resolving = true
	r_landing_zapped.clear()
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate == null or candidate == actor or not actor._is_enemy_candidate(candidate):
			continue
		if candidate.global_position.distance_to(actor.global_position) <= ally_radius:
			actor._play_r_landing_zap_once(candidate)
			for _i in actor._rulei(&"ryze.r.landing_e_hits", 3):
				actor._apply_e(candidate)
	r_landing_resolving = false
	r_landing_zapped.clear()
	add_arcane_stack(true)


func _play_realm_warp_windup(channel_duration: float) -> float:
	var model: Node3D = _actor().character_model
	var previous_speed := float(model.get("animation_speed_scale"))
	var animation_duration := float(model.call("get_semantic_animation_length", &"spell4"))
	if channel_duration > 0.0 and animation_duration > 0.0:
		model.call("set_animation_speed", previous_speed * animation_duration / channel_duration)
	model.call(&"play_semantic", &"spell4")
	return previous_speed


func _collect_warp_allies(radius: float) -> Array[CharacterBody3D]:
	var actor: Variant = _actor()
	var allies: Array[CharacterBody3D] = []
	var seen: Dictionary = {}
	for group_name: StringName in [&"combat_target", &"friendly_actor", &"enemy_actor", &"player_actor", &"hero_actor"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var candidate := node as CharacterBody3D
			if candidate == null or seen.has(candidate.get_instance_id()):
				continue
			if not _is_warp_ally(candidate):
				continue
			var offset: Vector3 = candidate.global_position - actor.global_position
			offset.y = 0.0
			if offset.length() > radius:
				continue
			seen[candidate.get_instance_id()] = true
			allies.append(candidate)
	return allies


func _is_warp_ally(candidate: CharacterBody3D) -> bool:
	var actor: Variant = _actor()
	if candidate == null or candidate == actor or not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
		return false
	if candidate.has_method("get_team"):
		return String(candidate.call("get_team")) == String(actor.get_team())
	if actor.team == "friendly":
		return candidate.is_in_group(&"friendly_actor")
	if actor.team == "enemy":
		return candidate.is_in_group(&"enemy_actor")
	return false


func _teleport_actor(unit: CharacterBody3D, destination: Vector3) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	unit.global_position = _actor()._clamp_to_arena(destination)
	unit.velocity = Vector3.ZERO


func grant_supercharge() -> void:
	var actor: Variant = _actor()
	supercharged_casts = actor._rulei(&"ryze.supercharge.max_casts", 5)
	supercharged_timer = actor._rulef(&"ryze.supercharge.duration", 2.5)
	arcane_stacks = 0


func add_arcane_stack(consumes_supercharge: bool) -> void:
	var actor: Variant = _actor()
	var max_stacks: int = actor._buff_max_stacks(&"ryze_arcane_mastery", 5)
	arcane_stacks = mini(max_stacks, arcane_stacks + 1)
	arcane_timer = actor._buff_duration(&"ryze_arcane_mastery", 6.0)
	if arcane_stacks == max_stacks:
		grant_supercharge()
	if consumes_supercharge and supercharged_casts > 0:
		supercharged_casts -= 1
		var refund: float = actor._rulef(&"ryze.supercharge.cooldown_refund", 4.0)
		for key: StringName in cooldowns:
			cooldowns[key] = maxf(0.0, float(cooldowns[key]) - refund)


func resolve_e_chain(victim: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	apply_e(victim)
	var chain: Array[CharacterBody3D] = []
	for candidate_node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := candidate_node as CharacterBody3D
		if candidate != null and candidate != victim and actor._valid_target(candidate) and candidate.global_position.distance_to(victim.global_position) <= actor._skill_radius(&"ryze_spell_flux", 3.5):
			chain.append(candidate)
	for candidate: CharacterBody3D in chain.slice(0, actor._rulei(&"ryze.e.max_bounce_targets", 6)):
		launch_e_bounce(victim, candidate, 1.0, victim)
	if chain.is_empty():
		launch_e_bounce(victim, victim, actor._rulef(&"ryze.e.bounce_damage_ratio", 0.5), null)


func launch_e_bounce(source: CharacterBody3D, victim: CharacterBody3D, damage_multiplier: float, return_target: CharacterBody3D) -> void:
	var actor: Variant = _actor()
	if not is_instance_valid(source) or not actor._valid_target(source) or not is_instance_valid(victim) or not actor._valid_target(victim):
		return
	var projectile: AnimatedSprite3D = actor.e_projectile_template.duplicate() as AnimatedSprite3D
	projectile.visible = true
	projectile.set_meta(&"authored_offset", projectile.offset)
	get_tree().current_scene.add_child(projectile)
	var start: Vector3 = actor._skill_travel_point(source, &"e")
	var destination: Vector3 = actor._skill_travel_point(victim, &"e")
	projectile.global_position = start
	projectile.frame = 0
	projectile.play()
	var authored_scale := projectile.scale
	var e_shell: Node3D = actor._attach_e_voxel_shell(projectile, true)
	var distance := start.distance_to(destination)
	var duration := maxf(distance / maxf(rulef(&"ryze.e.missile_speed", 15.0), 0.01), rulef(&"ryze.e.min_travel_seconds", 0.08))
	var elapsed := 0.0
	var landing_pulse := false
	while is_instance_valid(projectile) and is_instance_valid(victim) and actor._valid_target(victim) and elapsed < duration:
		var step := minf(1.0 / 60.0, duration - elapsed)
		elapsed += step
		var progress := elapsed / duration
		var eased := ease(progress, rulef(&"ryze.e.bounce_ease", -2.2))
		var hop := sin(progress * PI) + sin(progress * PI * 2.0) * rulef(&"ryze.e.bounce_hop", 0.14)
		var arc := hop * minf(rulef(&"ryze.e.bounce_arc_cap", 0.85), distance * rulef(&"ryze.e.bounce_arc_ratio", 0.26))
		var next_position := start.lerp(destination, eased) + Vector3.UP * maxf(arc, 0.0)
		var travel := next_position - projectile.global_position
		actor._update_projectile_facing(projectile, travel)
		actor._sync_e_voxel_shell(projectile, e_shell)
		projectile.global_position = next_position
		var apex := sin(progress * PI)
		projectile.scale = Vector3(
			authored_scale.x * (rulef(&"ryze.e.bounce_scale_x", 1.16) - apex * rulef(&"ryze.e.bounce_squash_x", 0.30)),
			authored_scale.y * (rulef(&"ryze.e.bounce_scale_y", 0.76) + apex * rulef(&"ryze.e.bounce_squash_y", 0.40)),
			authored_scale.z
		)
		if e_shell != null:
			if e_shell.has_method("set_travel"):
				e_shell.call("set_travel", travel)
			if e_shell.has_method("set_apex_stretch"):
				e_shell.call("set_apex_stretch", apex)
			if not landing_pulse and progress >= rulef(&"ryze.e.landing_pulse_progress", 0.78) and e_shell.has_method("pulse_elastic"):
				e_shell.call("pulse_elastic", rulef(&"ryze.e.landing_pulse", 1.15))
				landing_pulse = true
		if not projectile.is_playing():
			projectile.play()
		await get_tree().physics_frame
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not is_instance_valid(victim) or not actor._valid_target(victim):
		return
	apply_e(victim, damage_multiplier)
	if is_instance_valid(return_target) and actor._valid_target(return_target):
		launch_e_bounce(victim, return_target, rulef(&"ryze.e.bounce_damage_ratio", 0.5), null)


func apply_e(victim: CharacterBody3D, damage_multiplier: float = 1.0) -> void:
	var actor: Variant = _actor()
	if not actor._can_harm(victim):
		return
	damage(victim, actor._ranked_damage(&"ryze_e_damage", 36.0) * damage_multiplier, &"magic", &"ryze_e_hit")
	if victim.has_method("apply_magic_resistance_shred"):
		victim.call("apply_magic_resistance_shred", actor._flux_remain_multiplier(), actor._flux_duration())


func damage(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	var actor: Variant = _actor()
	if not actor._can_harm(victim):
		return
	deal_hit(victim, amount, type, hit_profile)
	if desperate_timer <= 0.0:
		return
	actor._play_t_overflow_lightning(victim)
	spill_desperate(victim, amount, type, hit_profile)


func deal_hit(victim: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	var actor: Variant = _actor()
	if not actor._can_harm(victim):
		return
	if victim.has_method("receive_skill_damage"):
		victim.call("receive_skill_damage", amount, "瑞兹", false, actor.global_position, type, hit_profile, actor)
	actor._play_impact(victim)


func spill_desperate(primary: CharacterBody3D, amount: float, type: StringName, hit_profile: StringName) -> void:
	var actor: Variant = _actor()
	for node: Node in get_tree().get_nodes_in_group(&"combat_target"):
		var candidate := node as CharacterBody3D
		if candidate == null or candidate == primary or not actor._can_harm(candidate):
			continue
		var offset := candidate.global_position - primary.global_position
		offset.y = 0.0
		if offset.length() <= actor._skill_radius(&"ryze_desperate_power", 3.5):
			deal_hit(candidate, amount * actor._rulef(&"ryze.t.spill_damage_ratio", 0.5), type, hit_profile)
			if r_landing_resolving:
				actor._play_r_landing_zap_once(candidate)


func ranked_damage(effect: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var row := database.get_skill_effect_rank(effect, 1) if database != null else null
	if row == null:
		push_error("Ryze requires damage effect rank %s" % effect)
		return 0.0
	return row.base_value


func ranked_control(effect: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var row := database.get_skill_effect_rank(effect, 1) if database != null else null
	if row == null:
		push_error("Ryze requires control effect rank %s" % effect)
		return 0.0
	return row.control_duration


func rulef(rule_id: StringName, fallback: float) -> float:
	var database: CombatDatabase = _actor().database
	if String(rule_id).begins_with("presentation."):
		return float(database.get_rule(rule_id, fallback)) if database != null else fallback
	var value: Variant = database.get_rule(rule_id) if database != null else null
	if value == null:
		push_error("Ryze requires combat rule %s" % rule_id)
		return 0.0
	return float(value)


func rulei(rule_id: StringName, fallback: int) -> int:
	var database: CombatDatabase = _actor().database
	if String(rule_id).begins_with("presentation."):
		return int(database.get_rule(rule_id, fallback)) if database != null else fallback
	var value: Variant = database.get_rule(rule_id) if database != null else null
	if value == null:
		push_error("Ryze requires combat rule %s" % rule_id)
		return 0
	return int(value)


func skill_cooldown(skill_id: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var rank := database.get_skill_rank(skill_id, 1) if database != null else null
	if rank == null:
		push_error("Ryze requires skill rank %s" % skill_id)
		return 0.0
	return rank.cooldown


func skill_range(skill_id: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var rank := database.get_skill_rank(skill_id, 1) if database != null else null
	if rank == null:
		push_error("Ryze requires skill rank %s" % skill_id)
		return 0.0
	return rank.cast_range


func basic_attack_range() -> float:
	var actor: Variant = _actor()
	var database: CombatDatabase = actor.database
	var value := database.get_unit_stat_value(&"ryze", &"attack_range", actor.level) if database != null else 0.0
	if value <= 0.0:
		push_error("Ryze requires positive attack_range unit stat")
	return value


func desperate_duration() -> float:
	var database: CombatDatabase = _actor().database
	var rank := database.get_skill_rank(&"ryze_desperate_power", 1) if database != null else null
	if rank == null:
		push_error("Ryze requires Desperate Power rank data")
		return 0.0
	return rank.duration


func is_supercharged() -> bool:
	return supercharged_casts > 0 and supercharged_timer > 0.0


func ready_basic_spell_count() -> int:
	var count := 0
	for key: StringName in [&"q", &"w", &"e"]:
		if float(cooldowns[key]) <= 0.0:
			count += 1
	return count


func is_supercharge_cast_animation(animation: StringName) -> bool:
	return animation == &"spell1" or animation == &"spell2" or animation == &"spell3" \
		or animation == &"attack1" or animation == &"attack2" or animation == &"attack3" or animation == &"crit"


func cast_speed() -> float:
	return rulef(&"ryze.cast.speed_scale", 1.35)


func supercharge_cast_speed() -> float:
	return rulef(&"ryze.supercharge.cast_speed_scale", 1.8)


func skill_radius(skill_id: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var rank := database.get_skill_rank(skill_id, 1) if database != null else null
	if rank == null:
		push_error("Ryze requires skill rank %s" % skill_id)
		return 0.0
	return rank.radius


func skill_cast_time(skill_id: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var rank := database.get_skill_rank(skill_id, 1) if database != null else null
	if rank == null:
		push_error("Ryze requires skill rank %s" % skill_id)
		return 0.0
	return rank.cast_time


func buff_duration(buff_id: StringName) -> float:
	var database: CombatDatabase = _actor().database
	var buff := database.get_buff(buff_id) if database != null else null
	if buff == null:
		push_error("Ryze requires buff %s" % buff_id)
		return 0.0
	return buff.duration


func buff_max_stacks(buff_id: StringName) -> int:
	var database: CombatDatabase = _actor().database
	var buff := database.get_buff(buff_id) if database != null else null
	if buff == null:
		push_error("Ryze requires buff %s" % buff_id)
		return 0
	return buff.max_stacks


func flux_remain_multiplier() -> float:
	var database: CombatDatabase = _actor().database
	var modifier := database.get_buff_modifier(&"ryze_flux", &"magic_resistance") if database != null else null
	if modifier == null:
		push_error("Ryze requires flux magic_resistance modifier")
		return 0.0
	return modifier.value


func get_skill_cooldown_state(slot: StringName) -> Dictionary:
	var cooldown_data: Dictionary = {
		&"q": &"ryze_overload", &"w": &"ryze_rune_prison", &"e": &"ryze_spell_flux",
		&"r": &"ryze_realm_warp", &"t": &"ryze_desperate_power",
	}
	if not cooldown_data.has(slot):
		return {"remaining": 0.0, "total": 0.0}
	return {"remaining": float(cooldowns.get(slot, 0.0)), "total": skill_cooldown(cooldown_data[slot])}


## AI projectiles track their selected unit; manual projectiles instead keep a
## fixed aim vector and acquire the first hostile they physically cross.
func launch_projectile(victim: CharacterBody3D, animation: StringName, speed: float, payload: StringName) -> void:
	var actor: Variant = _actor()
	if not is_instance_valid(victim) or not actor._valid_target(victim):
		return
	var projectile: AnimatedSprite3D = actor._create_projectile(payload, animation)
	if projectile == null:
		return
	actor._update_projectile_facing(projectile, actor._skill_travel_point(victim, payload) - projectile.global_position)
	projectile.frame = 0
	projectile.play()
	var e_shell: Node3D = actor._attach_e_voxel_shell(projectile, false) if payload == &"e" else null
	var q_base_scale := projectile.scale
	var q_elapsed := 0.0
	if payload == &"q":
		actor._update_q_travel_deform(projectile, q_base_scale, actor._skill_travel_point(victim, payload) - projectile.global_position, 0.0)
	while is_instance_valid(projectile) and is_instance_valid(victim) and actor._valid_target(victim):
		var hit_point: Vector3 = actor._skill_travel_point(victim, payload)
		var direction := hit_point - projectile.global_position
		var stop_distance: float = rulef(&"ryze.basic.stop_distance", 0.45) if payload == &"basic" else rulef(&"ryze.skill.stop_distance", 0.08)
		if direction.length() <= stop_distance:
			if payload != &"basic":
				projectile.global_position = hit_point
			break
		actor._update_projectile_facing(projectile, direction)
		if e_shell != null:
			actor._sync_e_voxel_shell(projectile, e_shell)
			if e_shell.has_method("set_travel"):
				e_shell.call("set_travel", direction)
		if payload == &"q":
			actor._update_q_travel_deform(projectile, q_base_scale, direction, q_elapsed)
			q_elapsed += 1.0 / 60.0
		var step := speed / 60.0
		if payload != &"basic" and direction.length() <= step:
			projectile.global_position = hit_point
			break
		projectile.global_position += direction.normalized() * step
		if not projectile.is_playing():
			projectile.play()
		await get_tree().physics_frame
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not is_instance_valid(victim) or not actor._valid_target(victim):
		return
	match payload:
		&"basic": damage(victim, actor.definition.attack_damage, &"physical", &"ryze_basic_hit")
		&"q": damage(victim, ranked_damage(&"ryze_q_damage"), &"magic", &"ryze_q_hit")
		&"e": resolve_e_chain(victim)


func launch_directional_projectile(animation: StringName, speed: float, payload: StringName, direction: Vector3, max_range: float) -> void:
	var actor: Variant = _actor()
	var planar_direction := Vector3(direction.x, 0.0, direction.z)
	if planar_direction.length_squared() <= 0.0001 or speed <= 0.0 or max_range <= 0.0:
		return
	planar_direction = planar_direction.normalized()
	var projectile: AnimatedSprite3D = actor._create_projectile(payload, animation)
	if projectile == null:
		return
	projectile.add_to_group(&"ryze_directional_projectile")
	actor._update_projectile_facing(projectile, planar_direction)
	projectile.frame = 0
	projectile.play()
	var base_scale := projectile.scale
	var elapsed := 0.0
	var traveled := 0.0
	var hit_target: CharacterBody3D
	while is_instance_valid(projectile) and traveled < max_range:
		var delta := get_physics_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		var step_length := minf(speed * delta, max_range - traveled)
		var previous_position := projectile.global_position
		var next_position := previous_position + planar_direction * step_length
		hit_target = first_enemy_on_projectile_segment(previous_position, next_position)
		var travel_direction := next_position - previous_position
		if hit_target != null:
			var hit_point: Vector3 = actor._target_visual_position(hit_target)
			projectile.global_position = Vector3(hit_point.x, previous_position.y, hit_point.z)
			travel_direction = projectile.global_position - previous_position
		else:
			projectile.global_position = next_position
		actor._update_projectile_facing(projectile, travel_direction)
		if payload == &"q":
			actor._update_q_travel_deform(projectile, base_scale, planar_direction * speed, elapsed)
			elapsed += delta
		traveled += step_length
		if not projectile.is_playing():
			projectile.play()
		if hit_target != null:
			break
		await get_tree().physics_frame
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not is_instance_valid(hit_target) or not actor._can_harm(hit_target):
		return
	match payload:
		&"basic": damage(hit_target, actor.definition.attack_damage, &"physical", &"ryze_basic_hit")
		&"q": damage(hit_target, ranked_damage(&"ryze_q_damage"), &"magic", &"ryze_q_hit")


func first_enemy_on_projectile_segment(from: Vector3, to: Vector3) -> CharacterBody3D:
	var actor := _actor() as CharacterBody3D
	return CombatTargetQuery.first_hostile_on_segment(get_tree(), actor, from, to, rulef(&"ryze.projectile.hit_radius", 0.62), Callable(actor, &"_target_visual_position"))
