shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float black_cutoff : hint_range(0.0, 0.5, 0.001) = 0.045;
uniform float black_feather : hint_range(0.001, 0.5, 0.001) = 0.16;
uniform float edge_erosion : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float alpha_feather : hint_range(0.001, 0.5, 0.001) = 0.08;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ground_height = 0.0;
uniform float ground_fade_width : hint_range(0.001, 1.0, 0.001) = 0.18;
uniform float ground_occluded_alpha : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float depth_bias : hint_range(0.0, 0.2, 0.001) = 0.02;
uniform bool show_over_models = false;

varying vec3 vfx_world_position;

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
	vfx_world_position = (billboard_model * vec4(VERTEX, 1.0)).xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
}

float scene_linear_depth(vec2 screen_uv, mat4 inv_projection) {
	float scene_depth = texture(depth_texture, screen_uv).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(screen_uv, scene_depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(screen_uv * 2.0 - 1.0, scene_depth);
	#endif
	vec4 scene_view = inv_projection * vec4(ndc, 1.0);
	return -(scene_view.z / scene_view.w);
}

float apply_ground_occlusion(
	float coverage,
	vec2 screen_uv,
	mat4 inv_projection,
	float fragment_depth,
	float world_height
) {
	bool is_occluded = fragment_depth > scene_linear_depth(screen_uv, inv_projection) + depth_bias;
	if (!is_occluded) {
		return coverage;
	}
	float ground_mask = 1.0 - smoothstep(
		ground_height,
		ground_height + max(ground_fade_width, 0.001),
		world_height
	);
	if (ground_mask > 0.001) {
		return coverage * mix(1.0, ground_occluded_alpha, ground_mask);
	}
	if (!show_over_models) {
		discard;
	}
	return coverage;
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
	coverage = apply_ground_occlusion(
		coverage, SCREEN_UV, INV_PROJECTION_MATRIX, -VERTEX.z, vfx_world_position.y
	);
	vec3 effect_color = source.rgb * tint.rgb;
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = vec3(1.0) - (vec3(1.0) - background) * (vec3(1.0) - effect_color);
	ALPHA = coverage * tint.a;
}
