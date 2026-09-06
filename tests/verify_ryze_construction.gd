extends SceneTree

func _init() -> void:
	var database := CombatData.database()
	var ryze := database.get_unit(&"ryze") if database != null else null
	var q := database.get_skill_by_slot(&"ryze", 1) if database != null else null
	var r := database.get_skill_by_slot(&"ryze", 4) if database != null else null
	var q_event := database.get_animation_event(&"ryze", &"spell1", "hit") if database != null else null
	var w_event := database.get_animation_event(&"ryze", &"spell2", "hit") if database != null else null
	var e_event := database.get_animation_event(&"ryze", &"spell3", "hit") if database != null else null
	var scene := load("res://scenes/units/ryze.tscn") as PackedScene
	var roster_script := load("res://scripts/ui/training_roster_panel.gd")
	var valid := ryze != null and ryze.class_id == &"mage" and ryze.subclass_id == &"battlemage" \
		and q != null and is_equal_approx(q.cast_range, 5.5) and is_equal_approx(q.radius, 1.1) \
		and r != null and is_equal_approx(r.cast_range, 25.0) and q_event != null and w_event != null and e_event != null \
		and q_event.timing_value == 3.0 and w_event.timing_value == 5.0 and e_event.timing_value == 6.0 and scene != null and roster_script != null
	print("RYZE_CONSTRUCTION data=%s q=%s r=%s scene=%s roster=%s" % [
		str(ryze != null), str(q != null), str(r != null), str(scene != null), str(roster_script != null),
	])
	if scene != null:
		var instance := scene.instantiate()
		root.add_child(instance)
		var sprite := instance.get_node_or_null("CharacterFrames") as AnimatedSprite3D
		var basic_preview := instance.get_node_or_null("CastVFXPreview/BasicProjectile") as AnimatedSprite3D
		var q_preview := instance.get_node_or_null("CastVFXPreview/QProjectile") as AnimatedSprite3D
		var w_preview := instance.get_node_or_null("CastVFXPreview/WEffect") as AnimatedSprite3D
		var e_preview := instance.get_node_or_null("CastVFXPreview/EProjectile") as AnimatedSprite3D
		var r_winddown_preview := instance.get_node_or_null("CastVFXPreview/RWinddown") as AnimatedSprite3D
		var w_loop_preview := instance.get_node_or_null("CastVFXPreview/WLoop") as AnimatedSprite3D
		var impact_preview := instance.get_node_or_null("CastVFXPreview/Impact") as AnimatedSprite3D
		var t_buff := instance.get_node_or_null("TBuff") as AnimatedSprite3D
		var super_armor := instance.get_node_or_null("SuperArmorOutline") as Node3D
		valid = valid and sprite != null and basic_preview != null and q_preview != null and w_preview != null and e_preview != null and r_winddown_preview != null and w_loop_preview != null and impact_preview != null and is_equal_approx(sprite.offset.x, 95.0) and is_equal_approx(sprite.offset.y, 468.5) and is_equal_approx(sprite.pixel_size, 0.004)
		valid = valid and is_equal_approx(r_winddown_preview.position.x, -1.1266189) and is_equal_approx(r_winddown_preview.position.y, 3.3852067) and is_equal_approx(r_winddown_preview.position.z, 0.0)
		valid = valid and is_equal_approx(r_winddown_preview.scale.x, 1.2186399) and is_equal_approx(r_winddown_preview.scale.y, 1.1500558)
		valid = valid and t_buff != null and t_buff.autoplay == "T_Buff" and t_buff.animation == &"T_Buff"
		valid = valid and is_equal_approx(t_buff.position.x, -0.5198593) and is_equal_approx(t_buff.position.y, 5.23897) and is_equal_approx(t_buff.position.z, 1.8116592)
		if super_armor == null and instance.has_method("_build_super_armor_outline"):
			instance.call("_build_super_armor_outline")
			super_armor = instance.get_node_or_null("SuperArmorOutline") as Node3D
		valid = valid and instance.has_method("has_super_armor") and super_armor != null
		var voxel_shell := load("res://scripts/vfx/elastic_voxel_shell.gd")
		var landing_zap := load("res://assets/BinbunVFX_Vol2/ElectricFX/effects/zap/vfx_zap_lightning_01.tscn")
		valid = valid and voxel_shell != null and instance.has_method("_attach_e_voxel_shell")
		valid = valid and landing_zap != null and instance.has_method("_play_r_landing_zap")
		if database != null:
			valid = valid and int(database.get_rule(&"ryze.e.voxel_count", 0)) == 16
			valid = valid and is_equal_approx(float(database.get_rule(&"ryze.supercharge.duration", 0.0)), 2.5)
			valid = valid and is_equal_approx(float(database.get_rule(&"ryze.t.spill_damage_ratio", 0.0)), 0.5)
			valid = valid and is_equal_approx(float(database.get_rule(&"ryze.e.launch_y_bias", 0.0)), 0.8)
			valid = valid and is_equal_approx(float(database.get_rule(&"ryze.hit.fallback_height", 0.0)), 1.15)
			valid = valid and is_equal_approx(float(database.get_rule(&"ryze.e.bounce_ease", 0.0)), -2.2)
			valid = valid and int(database.get_rule(&"ryze.t.lightning_viewport_size", 0)) == 256
			var flux := database.get_buff_modifier(&"ryze_flux", &"magic_resistance")
			valid = valid and flux != null and is_equal_approx(flux.value, 0.92)
		instance.queue_free()
	quit(0 if valid else 1)
