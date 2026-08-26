class_name StatusDebuffBurst
extends Node3D

const FRAMES := preload("res://assets/vfx/status/armor_shred/armor_shred_burst_frames.tres")
const METAL_HATCH := preload("res://addons/Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Metal Hatch.wav")
const OVERWHELM_ICON := preload("res://assets/icons/status/overwhelm.png")

var burst_frames: AnimatedSprite3D
var icon: Sprite3D
var audio: AudioStreamPlayer3D
var active_tween: Tween


static func get_or_create(owner: Node3D) -> StatusDebuffBurst:
	var existing := owner.get_node_or_null("ArmorShredBurst") as StatusDebuffBurst
	if existing != null:
		return existing
	var burst := (load("res://scripts/presentation/status_debuff_burst.gd") as Script).new() as StatusDebuffBurst
	burst.name = "ArmorShredBurst"
	owner.add_child(burst)
	return burst


func _ready() -> void:
	burst_frames = AnimatedSprite3D.new()
	burst_frames.sprite_frames = FRAMES
	burst_frames.animation = &"burst"
	burst_frames.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	burst_frames.pixel_size = 0.015
	burst_frames.no_depth_test = true
	burst_frames.render_priority = 46
	burst_frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst_frames.visible = false
	add_child(burst_frames)
	icon = Sprite3D.new()
	icon.texture = OVERWHELM_ICON
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.00042
	icon.no_depth_test = true
	icon.render_priority = 47
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	icon.visible = false
	add_child(icon)
	audio = AudioStreamPlayer3D.new()
	audio.stream = METAL_HATCH
	audio.max_distance = 22.0
	add_child(audio)


func play_burst() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	burst_frames.visible = true
	burst_frames.frame = 0
	burst_frames.speed_scale = 1.0
	burst_frames.play(&"burst")
	burst_frames.position = Vector3(0.0, 1.10, 0.06)
	burst_frames.scale = Vector3.ONE
	burst_frames.modulate = Color.WHITE
	icon.visible = true
	icon.position = Vector3(0.0, 1.10, 0.04)
	icon.scale = Vector3.ONE * 0.396
	icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	audio.pitch_scale = 3.0
	audio.play()
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(icon, "modulate:a", 1.0, 0.07)
	active_tween.tween_property(icon, "scale", Vector3.ONE * 2.088, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(icon, "position:x", 0.085, 0.07).set_trans(Tween.TRANS_SINE)
	active_tween.chain().tween_property(icon, "position:x", -0.070, 0.10).set_trans(Tween.TRANS_SINE)
	active_tween.chain().tween_property(icon, "position:x", 0.0, 0.08).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(icon, "scale", Vector3.ONE * 1.656, 0.15).set_delay(0.11).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(icon, "modulate:a", 0.0, 0.28).set_delay(0.18)
	active_tween.chain().tween_callback(func() -> void:
		burst_frames.visible = false
		icon.visible = false
	)
