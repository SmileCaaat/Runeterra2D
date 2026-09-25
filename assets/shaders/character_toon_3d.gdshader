shader_type spatial;
// Orthographic cameras support normal 3D lighting.  The stage supplies a
// directional key light plus ambient fill; diffuse_toon converts that real
// lighting into clean bands without allowing black backfaces.
render_mode diffuse_toon, specular_toon, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_albedo_texture = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float albedo_boost : hint_range(0.5, 2.0) = 1.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.84;
uniform vec4 team_color : source_color = vec4(0.34, 0.72, 0.86, 1.0);
uniform float team_rim_strength : hint_range(0.0, 0.3) = 0.0;
uniform float team_rim_power : hint_range(1.0, 8.0) = 3.5;

void fragment() {
	vec4 sampled = use_albedo_texture ? texture(albedo_texture, UV) : vec4(1.0);
	// Do not write ALPHA here: doing so moves the whole skinned character into
	// Godot's transparent pass and makes it fight the opaque outline mesh.
	// Imported character textures only need a hard cutout for genuinely empty
	// pixels, while the remaining surface must write depth as an opaque object.
	if (sampled.a * base_color.a < 0.08) {
		discard;
	}
	ALBEDO = sampled.rgb * base_color.rgb * albedo_boost;
	ROUGHNESS = roughness;
	SPECULAR = 0.12;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), team_rim_power);
	EMISSION = team_color.rgb * fresnel * team_rim_strength;
}
