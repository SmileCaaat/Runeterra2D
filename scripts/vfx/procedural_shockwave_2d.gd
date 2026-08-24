class_name ProceduralShockwave2D
extends Node2D

var active := false
var elapsed := 0.0
var duration := 0.22
var max_radius := 78.0
var ring_width := 5.0
var ring_color := Color.WHITE


func play(profile: Variant) -> void:
	duration = maxf(profile.shockwave_duration, 0.01)
	max_radius = profile.shockwave_radius
	ring_width = profile.shockwave_width
	ring_color = profile.core_color
	elapsed = 0.0
	active = true
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if elapsed >= duration:
		active = false
		visible = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var radius := lerpf(8.0, max_radius, eased)
	var alpha := pow(1.0 - t, 1.6)
	var color := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, maxf(0.5, ring_width * (1.0 - t * 0.65)), true)
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 48, Color(color.r, color.g, color.b, color.a * 0.35), 1.0, true)
