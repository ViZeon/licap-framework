
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

uniform float uv_smoothing : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	vec3 Lw = normalize(light_position_w - world_pos);
	Lw = vec3(-Lw.z, Lw.y, Lw.x);
	
	vec3 light_forward = Lw;
	vec3 light_right = normalize(cross(vec3(0.0, 1.0, 0.0), light_forward));
	vec3 light_up = cross(light_forward, light_right);
	
	float u = dot(world_normal, light_right);
	float v = dot(world_normal, light_up);
	vec2 uv_coords = vec2(u, v) * 0.5 + 0.5;
	
	// Sample with blur for smoothing
	vec3 result = vec3(0.0);
	if (uv_smoothing > 0.0) {
		for(float x = -1.0; x <= 1.0; x++) {
			for(float y = -1.0; y <= 1.0; y++) {
				result += texture(licap_texture, uv_coords + vec2(x,y) * uv_smoothing).rgb;
			}
		}
		result /= 9.0;
	} else {
		result = texture(licap_texture, uv_coords).rgb;
	}
	
	ALBEDO = result;
}
