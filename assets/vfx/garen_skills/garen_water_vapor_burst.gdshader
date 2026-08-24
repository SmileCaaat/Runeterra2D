shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;

uniform float progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec4 vapor_color : source_color = vec4(0.24, 0.78, 1.0, 0.52);

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 fraction = fract(value);
	vec2 weight = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), weight.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), weight.x),
		weight.y
	);
}

void fragment() {
	float vapor_noise = value_noise(UV * vec2(9.0, 5.0) + vec2(progress * 2.4, -progress * 1.7));
	float breakup = smoothstep(progress * 0.82 - 0.08, progress * 0.82 + 0.28, vapor_noise);
	float fade = 1.0 - smoothstep(0.46, 1.0, progress);
	float density = mix(0.18, 0.46, vapor_noise);
	ALBEDO = vapor_color.rgb * mix(0.72, 1.16, vapor_noise);
	ALPHA = density * breakup * vapor_color.a * fade;
}
