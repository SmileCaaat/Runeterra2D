shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, cull_disabled, billboard_enabled;

uniform vec4 tint_color : source_color = vec4(1.0, 0.12, 0.12, 1.0);

void fragment() {
	float alpha = texture(ALBEDO_TEXTURE, UV).a;
	if (alpha < 0.02) {
		discard;
	}
	ALBEDO = tint_color.rgb;
	ALPHA = alpha * tint_color.a;
}
