shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;

// Explicit Screen blend for the animated Ryze shield.  AnimatedSprite3D
// supplies the current atlas frame through the material parameter.
uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 source = texture(frame_texture, UV) * tint;
	float coverage = source.a * max(source.r, max(source.g, source.b));
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;
	vec3 screened = vec3(1.0) - (vec3(1.0) - background) * (vec3(1.0) - source.rgb);
	ALBEDO = screened;
	ALPHA = coverage;
}
