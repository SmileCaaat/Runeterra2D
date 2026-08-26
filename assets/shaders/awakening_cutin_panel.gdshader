shader_type canvas_item;
render_mode unshaded;

uniform sampler2D portrait_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 theme_color : source_color = vec4(0.09, 0.17, 0.28, 1.0);
uniform vec4 accent_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float exit_progress : hint_range(0.0, 1.0) = 0.0;
uniform float slant : hint_range(-1.0, 1.0) = 0.28;
uniform float feather : hint_range(0.001, 0.2) = 0.015;
uniform float mirror_mask : hint_range(0.0, 1.0) = 0.0;
uniform float portrait_scale : hint_range(0.25, 3.0) = 1.0;
uniform vec2 portrait_offset = vec2(0.0);
uniform float image_aspect = 1.7777778;
uniform float panel_aspect = 1.7777778;
uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform float global_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	float axis_x = mix(uv.x, 1.0 - uv.x, mirror_mask);
	float d = axis_x + slant * (uv.y - 0.5);
	float permanent_edge = 1.0;
	float moving_edge = mix(-0.35, 1.10, reveal);
	float visible_edge = min(permanent_edge, moving_edge);
	float enter_mask = 1.0 - smoothstep(visible_edge - feather, visible_edge + feather, d);
	float exit_edge = mix(-0.40, 1.40, exit_progress);
	float exit_mask = smoothstep(exit_edge - feather, exit_edge + feather, d);
	float panel_mask = enter_mask * exit_mask;

	vec2 portrait_uv = uv - vec2(0.5);
	if (panel_aspect > image_aspect) {
		portrait_uv.y *= image_aspect / max(panel_aspect, 0.001);
	} else {
		portrait_uv.x *= panel_aspect / max(image_aspect, 0.001);
	}
	portrait_uv /= max(portrait_scale, 0.001);
	portrait_uv += vec2(0.5) + portrait_offset;
	vec4 portrait = texture(portrait_texture, portrait_uv);

	float edge_distance = abs(d - visible_edge);
	float edge_glow = 1.0 - smoothstep(0.0, feather * 3.5, edge_distance);
	float shine_center = mix(-0.15, 1.15, shine_progress);
	float shine = 1.0 - smoothstep(0.0, 0.075, abs(d - shine_center));
	float stripe_wave = sin((uv.x - uv.y * slant) * 150.0 + TIME * 2.0);
	float stripes = smoothstep(0.82, 1.0, stripe_wave) * 0.07;

	vec3 graded = mix(portrait.rgb, portrait.rgb * theme_color.rgb * 1.25, 0.18);
	graded += accent_color.rgb * (edge_glow * 0.75 + shine * 0.28 + stripes);
	float vignette = smoothstep(0.85, 0.20, distance(uv, vec2(0.5)));
	graded *= mix(0.76, 1.05, vignette);
	COLOR = vec4(graded, portrait.a * panel_mask * global_alpha);
}
