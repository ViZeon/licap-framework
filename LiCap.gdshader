
shader_type spatial;
render_mode unshaded;

uniform sampler2D normal_licap : hint_default_white; // Stores normals as RGB
uniform sampler2D licap_texture : hint_default_white;
uniform vec3 light_position_w;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Estimate smooth normal from position derivatives
	vec3 dPdx = dFdx(world_pos);
	vec3 dPdy = dFdy(world_pos);
	vec3 smooth_normal = normalize(cross(dPdx, dPdy));
	
	// Blend between vertex normal and smooth normal
	vec3 blended_normal = normalize(mix(world_normal, smooth_normal, 0.5));
	
	
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
	vec2 uv1 = vec2(u, v) * 0.5 + 0.5;
	vec3 corrected_normal = texture(normal_licap, uv1).rgb * 2.0 - 1.0;
	
	// Second lookup: use corrected normal for actual lighting
	float u2 = dot(corrected_normal, light_right);
	float v2 = dot(corrected_normal, light_up);
	vec2 uv2 = vec2(u2, v2) * 0.5 + 0.5;
	

	
	ALBEDO = texture(licap_texture, uv2).rgb;
}