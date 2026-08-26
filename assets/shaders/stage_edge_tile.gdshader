shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Samples only a deliberately selected edge strip from the full ground atlas,
// then repeats that strip across a BoxMesh side.  The 4:1 playfield therefore
// stays intact on the top face while its 64:1 / 16:1 sides do not stretch it.
uniform sampler2D albedo_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 edge_origin = vec2(0.0, 0.88);
uniform vec2 edge_size = vec2(1.0, 0.12);
uniform vec2 tile_count = vec2(8.0, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.72;
uniform float contrast : hint_range(0.0, 1.5) = 0.84;
uniform float brightness : hint_range(0.0, 1.5) = 0.90;
uniform vec3 environment_tint : source_color = vec3(1.0);

void fragment() {
	vec2 tiled_uv = fract(UV * tile_count);
	vec4 sampled = texture(albedo_texture, edge_origin + tiled_uv * edge_size);
	float luminance = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), sampled.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	ALBEDO = max(graded * environment_tint * brightness, vec3(0.0));
}
