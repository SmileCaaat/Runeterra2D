shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.78, 0.96, 1.0, 1.0);
uniform float outline_width : hint_range(0.001, 0.04) = 0.009;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb;
}
