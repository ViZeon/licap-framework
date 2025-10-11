shader_type spatial;
render_mode unshaded;

uniform sampler2D licap_texture : hint_default_white;
uniform vec3 light_position_w;

void fragment() {
	// Get world space position and normal
	vec3 fragment_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 Nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Light direction in world space
	vec3 Lw = normalize(light_position_w - fragment_world_pos);
	
	// Project normal onto plane perpendicular to light direction
	// This gives you the XY coordinates as seen from the light's perspective
	vec3 light_up = vec3(0.0, 1.0, 0.0);
	vec3 light_right = normalize(cross(light_up, Lw));
	light_up = cross(Lw, light_right);
	
	float u = dot(Nw, light_right);
	float v = dot(Nw, light_up);
	
	vec2 uv_coords = vec2(u, v) * 0.5 + 0.5;
	
	vec3 LiCapColor = texture(licap_texture, uv_coords).rgb;
	
	ALBEDO = LiCapColor;
}