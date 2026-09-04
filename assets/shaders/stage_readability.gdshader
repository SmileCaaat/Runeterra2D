shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float contrast : hint_range(0.0, 1.5) = 1.0;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform vec3 environment_tint : source_color = vec3(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

// Enabled only by the training-ground top material. It reconstructs the
// source UV from the deformed trapezoid, avoiding the normal QuadMesh's
// affine UV stretch across its two triangles.
uniform bool use_trapezoid_projection = false;
uniform float trapezoid_near_scale : hint_range(0.5, 1.5) = 1.0;
uniform float trapezoid_far_scale : hint_range(0.5, 1.5) = 1.0;
uniform float trapezoid_center_offset : hint_range(-0.5, 0.5) = 0.0;
uniform float trapezoid_half_width : hint_range(0.01, 100.0) = 1.0;

varying vec2 trapezoid_projected;

void vertex() {
	float depth_t = clamp(UV.y, 0.0, 1.0);
	float edge_scale = mix(trapezoid_far_scale, trapezoid_near_scale, depth_t);
	float edge_offset = trapezoid_center_offset * (1.0 - edge_scale);
	if (use_trapezoid_projection) {
		VERTEX.x = VERTEX.x * edge_scale + edge_offset;
		trapezoid_projected = vec2(VERTEX.x, depth_t);
	}
}

void fragment() {
	vec2 source_uv = UV;
	if (use_trapezoid_projection) {
		float depth_t = clamp(trapezoid_projected.y, 0.0, 1.0);
		float edge_scale = mix(trapezoid_far_scale, trapezoid_near_scale, depth_t);
		float edge_offset = trapezoid_center_offset * (1.0 - edge_scale);
		source_uv.x = clamp(0.5 + (trapezoid_projected.x - edge_offset) / (2.0 * trapezoid_half_width * max(edge_scale, 0.001)), 0.0, 1.0);
		source_uv.y = depth_t;
	}
	vec4 sampled = texture(albedo_texture, source_uv * uv_scale + uv_offset);
	float luminance = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), sampled.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= environment_tint * brightness;
	ALBEDO = max(graded, vec3(0.0));
}