shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 ghost_color : source_color = vec4(0.16, 0.72, 1.0, 0.32);

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	ALBEDO = ghost_color.rgb * (0.45 + rim * 0.55);
	EMISSION = ghost_color.rgb * (0.35 + rim * 0.9);
	ALPHA = ghost_color.a;
}
