shader_type canvas_item;
render_mode unshaded;

uniform sampler2D portrait_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 theme_color : source_color = vec4(0.09, 0.17, 0.28, 1.0);
uniform vec4 accent_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float exit_progress : hint_range(0.0, 1.0) = 0.0;
uniform float slant : hint_range(-1.0, 1.0) = -0.17;
uniform float feather : hint_range(0.001, 0.2) = 0.015;
uniform float mirror_mask : hint_range(0.0, 1.0) = 0.0;
uniform float portrait_scale : hint_range(0.25, 3.0) = 1.01;
uniform vec2 portrait_offset = vec2(0.10, -0.01);
uniform float image_aspect = 1.7777778;
uniform float panel_aspect = 1.7777778;
uniform float shine_progress : hint_range(0.0, 1.0) = 0.0;
uniform float global_alpha : hint_range(0.0, 1.0) = 0.38;
uniform float edge_fade : hint_range(0.0, 0.45) = 0.16;
uniform float gradient_alpha_start : hint_range(0.0, 1.0) = 0.84;
uniform float gradient_alpha_end : hint_range(0.0, 1.0) = 0.49;
uniform int gradient_mode = 2; // 0 none, 1 left->right, 2 top->bottom, 3 along slant
uniform int filter_mode = 1; // 0 none, 1 cinematic, 2 cold, 3 warm, 4 ink, 5 chromatic
uniform float filter_strength : hint_range(0.0, 1.0) = 0.74;
uniform float vignette_strength : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.61;
uniform float contrast : hint_range(0.2, 2.0) = 1.14;
uniform float brightness : hint_range(-0.5, 0.5) = 0.09;
uniform float theme_mix : hint_range(0.0, 1.0) = 0.40;
uniform float stripe_amount : hint_range(0.0, 0.25) = 0.13;
uniform float edge_glow_amount : hint_range(0.0, 2.0) = 1.06;

vec3 apply_saturation(vec3 color, float amount) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luma), color, amount);
}

vec3 apply_contrast(vec3 color, float amount) {
	return (color - 0.5) * amount + 0.5;
}

vec3 apply_filter(vec3 color, vec2 uv, float strength) {
	vec3 out_color = color;
	if (filter_mode == 1) {
		vec3 cinema = apply_contrast(apply_saturation(color, 0.85), 1.18);
		cinema.r *= 1.02;
		cinema.b *= 1.06;
		out_color = cinema;
	} else if (filter_mode == 2) {
		out_color = color * vec3(0.86, 0.96, 1.18);
		out_color = apply_saturation(out_color, 1.15);
	} else if (filter_mode == 3) {
		out_color = color * vec3(1.18, 1.02, 0.86);
		out_color = apply_saturation(out_color, 1.12);
	} else if (filter_mode == 4) {
		vec3 ink = apply_saturation(color, 0.35);
		ink = apply_contrast(ink, 1.55);
		float bands = floor(ink.r * 5.0) / 5.0;
		out_color = mix(ink, vec3(bands), 0.35);
	} else if (filter_mode == 5) {
		float shift = 0.0045 * strength;
		float r = texture(portrait_texture, uv + vec2(shift, 0.0)).r;
		float g = texture(portrait_texture, uv).g;
		float b = texture(portrait_texture, uv - vec2(shift, 0.0)).b;
		out_color = vec3(r, g, b);
	}
	return mix(color, out_color, clamp(strength, 0.0, 1.0));
}

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

	float soft_edge = 1.0;
	if (edge_fade > 0.0001) {
		float to_cut = abs(d - visible_edge);
		soft_edge = smoothstep(0.0, edge_fade, to_cut);
		soft_edge = mix(1.0, soft_edge, panel_mask);
		// Fade near panel perimeter in UV space as well.
		float border = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
		soft_edge *= smoothstep(0.0, edge_fade, border);
	}

	float gradient_alpha = 1.0;
	if (gradient_mode == 1) {
		gradient_alpha = mix(gradient_alpha_start, gradient_alpha_end, axis_x);
	} else if (gradient_mode == 2) {
		gradient_alpha = mix(gradient_alpha_start, gradient_alpha_end, uv.y);
	} else if (gradient_mode == 3) {
		gradient_alpha = mix(gradient_alpha_start, gradient_alpha_end, clamp(d, 0.0, 1.0));
	}

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
	float stripes = smoothstep(0.82, 1.0, stripe_wave) * stripe_amount;

	vec3 graded = mix(portrait.rgb, portrait.rgb * theme_color.rgb * 1.25, theme_mix);
	graded += accent_color.rgb * (edge_glow * edge_glow_amount + shine * 0.28 + stripes);
	graded = apply_saturation(graded, saturation);
	graded = apply_contrast(graded, contrast);
	graded += vec3(brightness);
	graded = apply_filter(graded, portrait_uv, filter_strength);
	float vignette = smoothstep(0.85, 0.20, distance(uv, vec2(0.5)));
	graded *= mix(1.0 - vignette_strength, 1.0 + vignette_strength * 0.2, vignette);

	float alpha = portrait.a * panel_mask * global_alpha * soft_edge * gradient_alpha;
	COLOR = vec4(graded, clamp(alpha, 0.0, 1.0));
}
