
shader_type spatial;
render_mode unshaded;

uniform sampler2D licap_texture : hint_default_white;
uniform vec3 light_position_w;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Light direction in world space
	vec3 Lw = normalize(light_position_w - world_pos);
	
	// Rotate Lw 90 degrees clockwise around Y axis
	Lw = vec3(-Lw.z, Lw.y, Lw.x);
	
	// Create light's coordinate frame (fixed in world space)
	vec3 light_forward = Lw;
	vec3 light_right = normalize(cross(vec3(0.0, 1.0, 0.0), light_forward));
	vec3 light_up = cross(light_forward, light_right);
	
	// Project normal onto light's view plane
	float u = dot(world_normal, light_right);
	float v = dot(world_normal, light_up);
	
	vec2 uv_coords = vec2(u, v) * 0.5 + 0.5;
	
	ALBEDO = texture(licap_texture, uv_coords).rgb;
}