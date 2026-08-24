shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform vec4 ocean_tint : source_color = vec4(0.16, 0.72, 1.0, 0.36);
uniform float tint_mix : hint_range(0.0, 1.0, 0.01) = 0.96;

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
	float brightness = max(source.r, max(source.g, source.b));
	vec3 ocean_detail = ocean_tint.rgb * (0.55 + brightness * 0.65);
	ALBEDO = mix(source.rgb, ocean_detail, tint_mix);
	ALPHA = source.a * ocean_tint.a;
}
