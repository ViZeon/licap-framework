shader_type spatial;
render_mode unshaded;

uniform sampler2D licap_texture : hint_default_white;
uniform float light_intensity = 5.0;
uniform vec3 light_position_w;

void fragment() {
	vec3 fragment_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 light_vector = light_position_w - fragment_world_pos;
	vec3 Lw = normalize(light_vector);
	
	// Transform light direction to view space
	vec3 Lv = normalize((VIEW_MATRIX * vec4(Lw, 0.0)).xyz);
	
	// Map light direction to UV coordinates
	vec2 uv_coords = Lv.xy * 0.5 + 0.5;
	
	vec3 LiCapColor = texture(licap_texture, uv_coords).rgb;
	
	ALBEDO = LiCapColor * light_intensity;
}
