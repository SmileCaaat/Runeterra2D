shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float black_cutoff : hint_range(0.0, 0.5, 0.001) = 0.025;
uniform float black_feather : hint_range(0.001, 0.5, 0.001) = 0.10;
uniform float edge_erosion : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float alpha_feather : hint_range(0.001, 0.5, 0.001) = 0.06;
uniform vec4 frame_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float canvas_edge_fade : hint_range(0.0, 0.5, 0.005) = 0.15;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ground_height = 0.0;
uniform float ground_fade_width : hint_range(0.001, 1.0, 0.001) = 0.18;
uniform float ground_occluded_alpha : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float depth_bias : hint_range(0.0, 0.2, 0.001) = 0.02;
uniform float ground_depth_fade : hint_range(0.001, 2.0, 0.001) = 0.9;
uniform bool show_over_models = false;

varying vec3 vfx_world_position;

float keyed_coverage(vec2 uv) {
	vec4 sample_color = texture(frame_texture, uv);
	float brightness = max(sample_color.r, max(sample_color.g, sample_color.b));
	return sample_color.a * smoothstep(black_cutoff, black_cutoff + black_feather, brightness);
}

float canvas_edge_mask(vec2 uv) {
	vec2 frame_size = max(frame_uv_rect.zw, vec2(0.000001));
	vec2 frame_uv = (uv - frame_uv_rect.xy) / frame_size;
	vec2 distance_to_edge = min(frame_uv, vec2(1.0) - frame_uv);
	float nearest_edge = min(distance_to_edge.x, distance_to_edge.y);
	if (canvas_edge_fade <= 0.0001) {
		return step(0.0, nearest_edge);
	}
	return smoothstep(0.0, canvas_edge_fade, nearest_edge);
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
	float depth_delta = fragment_depth - scene_linear_depth(screen_uv, inv_projection);
	if (depth_delta <= depth_bias) {
		return coverage;
	}
	float ground_mask = 1.0 - smoothstep(
		ground_height,
		ground_height + max(ground_fade_width, 0.001),
		world_height
	);
	if (ground_mask > 0.001) {
		float depth_fade = smoothstep(
			depth_bias,
			depth_bias + max(ground_depth_fade, 0.001),
			depth_delta
		);
		float occlusion_amount = depth_fade * ground_mask;
		return coverage * mix(1.0, ground_occluded_alpha, occlusion_amount);
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
	coverage *= canvas_edge_mask(UV);
	coverage = apply_ground_occlusion(
		coverage, SCREEN_UV, INV_PROJECTION_MATRIX, -VERTEX.z, vfx_world_position.y
	);
	ALBEDO = source.rgb * tint.rgb;
	ALPHA = coverage * tint.a;
}
