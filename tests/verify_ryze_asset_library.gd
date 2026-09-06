extends SceneTree

const CHARACTER_LIBRARY := "res://assets/characters/rune_mage_ryze/ryze_sprite_frames.tres"
const SKILL_LIBRARY := "res://assets/vfx/ryze_skills/ryze_skill_vfx_frames.tres"


func _initialize() -> void:
	var character_frames := load(CHARACTER_LIBRARY) as SpriteFrames
	var skill_frames := load(SKILL_LIBRARY) as SpriteFrames
	var character_ok := character_frames != null and character_frames.get_animation_names().size() == 21
	character_ok = character_ok and character_frames.has_animation(&"taunt")
	character_ok = character_ok and character_frames.get_frame_count(&"taunt") == 24
	character_ok = character_ok and character_frames.has_animation(&"idle") and character_frames.get_animation_loop(&"idle")
	character_ok = character_ok and character_frames.has_animation(&"run") and character_frames.get_animation_loop(&"run")
	character_ok = character_ok and character_frames.has_animation(&"run_spell") and character_frames.get_animation_loop(&"run_spell")
	var character_total := _frame_total(character_frames)
	character_ok = character_ok and character_total == 501
	var skill_ok := skill_frames != null and skill_frames.get_animation_names().size() == 9
	for animation_name: StringName in [&"basic_attack", &"Ryze_Shield", &"Spell1_Q", &"Spell2_W", &"Spell3_E", &"Spell4_R_winddown", &"T_Buff", &"W_loop", &"impact"]:
		skill_ok = skill_ok and skill_frames.has_animation(animation_name)
	skill_ok = skill_ok and skill_frames.get_frame_count(&"basic_attack") == 12
	skill_ok = skill_ok and skill_frames.get_frame_count(&"Ryze_Shield") == 32
	skill_ok = skill_ok and skill_frames.get_animation_loop(&"W_loop") and skill_frames.get_animation_loop(&"Ryze_Shield")
	var skill_total := _frame_total(skill_frames)
	skill_ok = skill_ok and skill_total == 147
	var shield_material_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/ryze_shield_screen_material.tres")
	var audio_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/Ryze_awake.wav")
	var portrait_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/符文法师 - 原画.jpg")
	var icon_ok := ResourceLoader.exists("res://assets/vfx/ryze_skills/icons/Ryze_Overload_Q.webp")
	icon_ok = icon_ok and ResourceLoader.exists("res://assets/vfx/ryze_skills/icons/Ryze_Desperate_Power_P.webp")
	print("RYZE_ASSETS character=%s frames=%d skill=%s frames=%d shield_material=%s taunt_t=true audio=%s portrait=%s icons=%s" % [
		character_ok, character_total, skill_ok, skill_total, shield_material_ok, audio_ok, portrait_ok, icon_ok,
	])
	quit(0 if character_ok and skill_ok and shield_material_ok and audio_ok and portrait_ok and icon_ok else 1)


func _frame_total(library: SpriteFrames) -> int:
	if library == null:
		return 0
	var total := 0
	for animation_name: StringName in library.get_animation_names():
		total += library.get_frame_count(animation_name)
	return total
