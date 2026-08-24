shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_noise : hint_range(0.0, 0.2) = 0.08;
uniform float edge_softness : hint_range(0.001, 0.15) = 0.045;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 sampled = texture(texture_albedo, UV) * tint;
	float noise = hash(floor(UV * vec2(28.0, 40.0))) - 0.5;
	float frontier = 1.0 - dissolve_amount + noise * edge_noise;
	float keep = 1.0 - smoothstep(frontier - edge_softness, frontier + edge_softness, UV.y);
	sampled.a *= keep;
	if (sampled.a < 0.01) discard;
	ALBEDO = sampled.rgb;
	ALPHA = sampled.a;
}
