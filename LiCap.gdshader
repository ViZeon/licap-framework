shader_type spatial;
render_mode unshaded;

uniform sampler2D licap_texture : hint_default_white;
uniform vec3 light_position_w;

void fragment() {
	// Get world space normal
	vec3 Nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	// Get world space position (use FRAGCOORD to reconstruct or pass from vertex)
	vec3 fragment_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Light direction in world space
	vec3 Lw = normalize(light_position_w - fragment_world_pos);
	
	// Rotate light direction into surface's local tangent space
	// (simulating how the light "looks" from the surface's perspective)
	vec3 binormal = normalize(cross(Nw, vec3(0.0, 1.0, 0.0)));
	vec3 tangent = cross(binormal, Nw);
	
	float u = dot(Lw, tangent);
	float v = dot(Lw, binormal);
	
	vec2 uv_coords = vec2(u, v) * 0.5 + 0.5;
	
	vec3 LiCapColor = texture(licap_texture, uv_coords).rgb;
	
	ALBEDO = LiCapColor;
}