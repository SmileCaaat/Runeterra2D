shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// 3D Sprite adaptation of VFX Library's Outline Glow shader. The silhouette
// is deliberately outline-only; the source character remains responsible for
// the interior pixels.
uniform sampler2D frame_texture : source_color, filter_linear;
// Sprite3D receives atlas-space UVs for AtlasTexture frames. Constraining all
// samples to this rectangle prevents adjacent frames from leaking into the
// outline when a sample reaches a cell boundary.
uniform vec4 frame_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 outline_red : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform vec4 outline_gold : source_color = vec4(1.0, 0.80, 0.20, 1.0);
uniform float outline_width_pixels : hint_range(0.5, 12.0) = 2.5;
uniform float alpha_threshold : hint_range(0.05, 0.95) = 0.35;
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.4;
uniform float opacity : hint_range(0.0, 1.0) = 0.78;

float frame_alpha(vec2 atlas_uv) {
	vec2 frame_min = frame_uv_rect.xy;
	vec2 frame_max = frame_uv_rect.xy + frame_uv_rect.zw;
	if (atlas_uv.x < frame_min.x || atlas_uv.y < frame_min.y
		|| atlas_uv.x > frame_max.x || atlas_uv.y > frame_max.y) {
		return 0.0;
	}
	return texture(frame_texture, atlas_uv).a;
}

void fragment() {
	float source_alpha = frame_alpha(UV);
	vec2 texel = 1.0 / vec2(textureSize(frame_texture, 0));
	vec2 step_uv = texel * outline_width_pixels;
	float neighboring_alpha = 0.0;
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV + vec2(step_uv.x, 0.0)));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV - vec2(step_uv.x, 0.0)));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV + vec2(0.0, step_uv.y)));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV - vec2(0.0, step_uv.y)));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV + step_uv));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV - step_uv));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV + vec2(step_uv.x, -step_uv.y)));
	neighboring_alpha = max(neighboring_alpha, frame_alpha(UV + vec2(-step_uv.x, step_uv.y)));

	float outline = step(alpha_threshold, neighboring_alpha) * (1.0 - step(alpha_threshold, source_alpha));
	// The contour reads as gold -> red -> gold from one end of the
	// character silhouette to the other; it is intentionally not a
	// one-way “top gold / bottom red” gradient.
	float gold_at_ends = abs(UV.y * 2.0 - 1.0);
	vec4 color = mix(outline_red, outline_gold, gold_at_ends);
	ALBEDO = color.rgb;
	EMISSION = color.rgb * glow_intensity * outline;
	ALPHA = outline * color.a * opacity;
}
