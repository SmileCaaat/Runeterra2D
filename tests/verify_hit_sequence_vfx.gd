extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var effect := CPUParticles3D.new()
	effect.set_script(load("res://scripts/vfx/hit_spark_particles.gd"))
	root.add_child(effect)
	await process_frame

	var sprite := effect.get_node("HitSequence") as Sprite3D
	var passed := sprite != null and sprite.hframes == 4 and sprite.vframes == 4
	passed = passed and not effect.emitting and effect.mesh == null

	effect.call("burst", Vector3(1.0, 2.0, 3.0), Vector3.RIGHT, false)
	passed = passed and sprite.visible and sprite.texture.resource_path.ends_with("hit_yellow1.png")
	passed = passed and not bool(effect.get("last_critical")) and int(effect.get("burst_count")) == 1
	var pool := get_first_node_in_group(&"hit_impact_vfx_pool")
	passed = passed and pool != null and (pool.get("slots") as Array).size() == 8
	passed = passed and (pool.get("profiles_by_id") as Dictionary).size() == 6
	passed = passed and int(pool.get("play_count")) == 1 and StringName(pool.get("last_profile_id")) == &"normal"
	if pool != null:
		var first_slot: Dictionary = (pool.get("slots") as Array)[0]
		var procedural_effect := first_slot.effect as Node2D
		passed = passed and (first_slot.viewport as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS
		var gpu_layers := 0
		for child: Node in procedural_effect.get_children():
			if child is GPUParticles2D:
				gpu_layers += 1
		passed = passed and gpu_layers == 4
	await create_timer(0.18).timeout
	passed = passed and sprite.frame > 0 and sprite.frame < 16
	await create_timer(0.20).timeout
	passed = passed and not sprite.visible

	effect.call("burst", Vector3.ZERO, Vector3.LEFT, true)
	passed = passed and sprite.visible and sprite.texture.resource_path.ends_with("hit_yellow2.png")
	passed = passed and bool(effect.get("last_critical")) and sprite.flip_h
	passed = passed and int(effect.get("burst_count")) == 2
	passed = passed and int(pool.get("play_count")) == 2 and StringName(pool.get("last_profile_id")) == &"critical"
	passed = passed and StringName(effect.call("_resolve_procedural_profile", &"breaker_hit", false)) == &"heavy"
	passed = passed and StringName(effect.call("_resolve_procedural_profile", &"ocean_hit", false)) == &"elemental"
	passed = passed and StringName(effect.call("_resolve_procedural_profile", &"judgment_hit", false)) == &"anchor"
	passed = passed and StringName(effect.call("_resolve_procedural_profile", &"ghostship_hit", false)) == &"magic"

	print("HIT_VFX sequence=normal/critical gpu_layers=4 flash=true shockwave=true pool=8 profiles=6")
	effect.queue_free()
	if not passed:
		push_error("Hit sequence VFX verification failed")
	quit(0 if passed else 2)
