shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform float black_cutoff : hint_range(0.0, 0.5, 0.001) = 0.025;
uniform float black_feather : hint_range(0.001, 0.5, 0.001) = 0.10;
uniform float edge_erosion : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float alpha_feather : hint_range(0.001, 0.5, 0.001) = 0.06;
uniform vec4 tint : source_color = vec4(1.0);

float keyed_coverage(vec2 uv) {
	vec4 sample_color = texture(frame_texture, uv);
	float brightness = max(sample_color.r, max(sample_color.g, sample_color.b));
	return sample_color.a * smoothstep(black_cutoff, black_cutoff + black_feather, brightness);
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
	vec4 source = texture(frame_texture, UV);
	vec2 pixel = 1.0 / vec2(textureSize(frame_texture, 0));
	float coverage = keyed_coverage(UV);
	float neighbour_coverage = min(
		min(keyed_coverage(UV + vec2(pixel.x, 0.0)), keyed_coverage(UV - vec2(pixel.x, 0.0))),
		min(keyed_coverage(UV + vec2(0.0, pixel.y)), keyed_coverage(UV - vec2(0.0, pixel.y)))
	);
	coverage = mix(coverage, neighbour_coverage, edge_erosion);
	coverage *= smoothstep(0.0, alpha_feather, coverage);
	ALBEDO = source.rgb * tint.rgb;
	ALPHA = coverage * tint.a;
}
