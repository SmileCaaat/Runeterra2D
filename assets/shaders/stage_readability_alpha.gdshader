shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float contrast : hint_range(0.0, 1.5) = 1.0;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform vec3 environment_tint : source_color = vec3(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

void fragment() {
	vec4 sampled = texture(albedo_texture, UV * uv_scale + uv_offset);
	float luminance = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luminance), sampled.rgb, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);
	graded *= environment_tint * brightness;
	ALBEDO = max(graded, vec3(0.0));
	ALPHA = sampled.a;
}
