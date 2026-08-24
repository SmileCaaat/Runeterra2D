shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D shrine_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 sampled = texture(shrine_texture, UV);
	ALBEDO = sampled.rgb;
	EMISSION = sampled.rgb * 0.35;
	ALPHA = sampled.a * opacity;
	if (ALPHA < 0.01) discard;
}
