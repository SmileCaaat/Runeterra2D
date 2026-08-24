shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float distortion_strength : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.55;

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

void vertex() {
	vec3 model_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	mat4 billboard_model = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * model_scale.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * model_scale.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * model_scale.z, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	vec2 direction = centered / max(radius, 0.001);
	float angle = atan(centered.y, centered.x);
	float broad_noise = value_noise(vec2(angle * 1.45 + 7.0, progress * 2.2));
	float detail_noise = value_noise(vec2(angle * 4.7 + 31.0, progress * 3.1));
	float broken_edge = broad_noise * 0.72 + detail_noise * 0.28;
	float wave_radius = mix(0.08, 0.94, progress) + (broken_edge - 0.5) * 0.16;
	float pressure_width = mix(0.22, 0.10, progress);
	float pressure_front = 1.0 - smoothstep(
		pressure_width, pressure_width * 1.75, abs(radius - wave_radius)
	);
	float inner_pressure = (1.0 - smoothstep(0.0, max(wave_radius, 0.01), radius)) * (1.0 - progress);
	float envelope = (1.0 - smoothstep(0.72, 1.0, radius)) * (1.0 - smoothstep(0.78, 1.0, progress));
	float turbulence = mix(0.65, 1.15, broken_edge);
	float distortion = (pressure_front * 0.78 + inner_pressure * 0.20) * distortion_strength * turbulence * (1.0 - progress);
	vec2 warped_uv = clamp(SCREEN_UV + direction * distortion, vec2(0.001), vec2(0.999));
	vec3 refracted;
	refracted.r = texture(screen_texture, clamp(SCREEN_UV + direction * distortion * 1.08, vec2(0.001), vec2(0.999))).r;
	refracted.g = texture(screen_texture, warped_uv).g;
	refracted.b = texture(screen_texture, clamp(SCREEN_UV + direction * distortion * 0.92, vec2(0.001), vec2(0.999))).b;
	ALBEDO = refracted + vec3(0.025 * pressure_front * (1.0 - progress));
	ALPHA = clamp((pressure_front * 0.62 + inner_pressure * 0.10) * opacity * envelope, 0.0, 0.58);
}
