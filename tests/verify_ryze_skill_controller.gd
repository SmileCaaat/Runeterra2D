extends SceneTree


func _initialize() -> void:
	await process_frame
	var scene := load("res://scenes/units/ryze.tscn") as PackedScene
	if scene == null:
		push_error("Ryze skill controller verification requires Ryze scene")
		quit(1)
		return
	var actor := scene.instantiate() as CharacterBody3D
	root.add_child(actor)
	var skills := actor.get_node_or_null("RyzeSkillController") as RyzeSkillController
	var structure_ok := skills != null and skills.has_method("cast_q_directional") \
		and skills.has_method("launch_directional_projectile") and skills.has_method("cast_realm_warp") \
		and skills.has_method("resolve_e_chain") and skills.has_method("damage")
	var state_ok := false
	if skills != null:
		var cooldowns: Dictionary = actor.get("cooldowns")
		cooldowns[&"q"] = 3.0
		skills.tick_effects(0.5)
		actor.set("arcane_stacks", 2)
		skills.supercharged_casts = 3
		actor.set("action_lock", 1.2)
		skills.tick_action_lock(0.2)
		state_ok = is_equal_approx(float(cooldowns[&"q"]), 2.5) \
			and skills.arcane_stacks == 2 and int(actor.get("supercharged_casts")) == 3 \
			and is_equal_approx(float(actor.get("action_lock")), 1.0)
	print("RYZE_SKILL_CONTROLLER structure=%s state=%s" % [structure_ok, state_ok])
	actor.queue_free()
	quit(0 if structure_ok and state_ok else 1)
