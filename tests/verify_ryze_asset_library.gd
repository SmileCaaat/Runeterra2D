extends SceneTree

const SKILL_LIBRARY := "res://assets/vfx/ryze_skills/ryze_skill_vfx_frames.tres"


func _initialize() -> void:
	var skill_frames := load(SKILL_LIBRARY) as SpriteFrames
	var skill_ok := skill_frames != null and skill_frames.get_animation_names().size() == 9
	for animation_name: StringName in [&"projectile", &"Ryze_Shield", &"Spell1_Q", &"Spell2_W", &"Spell3_E", &"Spell4_R_winddown", &"T_Buff", &"W_loop", &"impact"]:
		skill_ok = skill_ok and skill_frames.has_animation(animation_name)
	skill_ok = skill_ok and skill_frames.get_frame_count(&"projectile") == 12
	skill_ok = skill_ok and skill_frames.get_frame_count(&"Ryze_Shield") == 32
	skill_ok = skill_ok and skill_frames.get_animation_loop(&"W_loop") and skill_frames.get_animation_loop(&"Ryze_Shield")
	var skill_total := _frame_total(skill_frames)
	skill_ok = skill_ok and skill_total == 147
	var shield_material_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/ryze_shield_screen_material.tres")
	var audio_ok := ResourceLoader.exists("res://assets/presentation/awakening/ryze/awakening_voice.wav")
	var portrait_ok := ResourceLoader.exists("res://assets/presentation/awakening/ryze/desperate_power_cutin.jpg")
	var icon_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/icons/Ryze_Overload_Q.webp")
	icon_ok = icon_ok and ResourceLoader.exists("res://assets/vfx/ryze_skills/icons/Ryze_Desperate_Power_P.webp")
	print("RYZE_VFX skill=%s frames=%d shield_material=%s audio=%s portrait=%s icons=%s" % [
		skill_ok, skill_total, shield_material_ok, audio_ok, portrait_ok, icon_ok,
	])
	if not skill_ok and skill_frames != null:
		print("RYZE_VFX animations=%s projectile_frames=%d shield_frames=%d w_loop=%s shield_loop=%s" % [
			skill_frames.get_animation_names(), skill_frames.get_frame_count(&"projectile"),
			skill_frames.get_frame_count(&"Ryze_Shield"), skill_frames.get_animation_loop(&"W_loop"),
			skill_frames.get_animation_loop(&"Ryze_Shield"),
		])
	quit(0 if skill_ok and shield_material_ok and audio_ok and portrait_ok and icon_ok else 1)


func _frame_total(library: SpriteFrames) -> int:
	if library == null:
		return 0
	var total := 0
	for animation_name: StringName in library.get_animation_names():
		total += library.get_frame_count(animation_name)
	return total
