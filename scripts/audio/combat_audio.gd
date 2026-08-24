class_name CombatAudio
extends RefCounted

const MATERIAL_SURFACES := [&"flesh", &"metal", &"stone", &"wood"]


static func configure_player(
	player: AudioStreamPlayer3D,
	database: CombatDatabase,
	profile_id: StringName
) -> AssetProfileDefinition:
	if player == null or database == null or profile_id.is_empty():
		return null
	var profile := database.get_asset_profile(profile_id)
	if profile == null or profile.asset_type != "audio":
		return null
	var stream := load(profile.audio_path) as AudioStream
	if stream == null:
		return null
	player.stream = stream
	player.volume_db = profile.volume_db
	player.max_distance = profile.max_distance
	return profile


static func play_hit(
	player: AudioStreamPlayer3D,
	database: CombatDatabase,
	hit_profile: HitProfileDefinition,
	surface: StringName,
	critical: bool,
	random: RandomNumberGenerator
) -> bool:
	if hit_profile == null:
		return false
	var audio_id := resolve_surface_audio(hit_profile.hit_audio_profile_id, surface, critical)
	var profile := configure_player(player, database, audio_id)
	if profile == null:
		return false
	player.pitch_scale = random.randf_range(profile.pitch_min, profile.pitch_max)
	player.play()
	return true


static func resolve_surface_audio(
	configured_id: StringName,
	surface: StringName,
	critical: bool
) -> StringName:
	var configured := String(configured_id)
	if not configured.begins_with("garen_basic_hit_") and not configured.begins_with("garen_crit_hit_"):
		return configured_id
	var resolved_surface := surface if MATERIAL_SURFACES.has(surface) else &"flesh"
	var force_critical := configured.begins_with("garen_crit_hit_")
	var prefix := "garen_crit_hit_" if critical or force_critical else "garen_basic_hit_"
	return StringName(prefix + String(resolved_surface))
