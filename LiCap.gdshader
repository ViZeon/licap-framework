
shader_type spatial;
render_mode unshaded;

uniform int point_count;
uniform float offsets[16];
uniform vec4 colors[16];

uniform float light_intesity;

uniform sampler2D terminator_gradient:  source_color, filter_linear, repeat_disable;
uniform sampler2D normal_licap : hint_default_white; // Stores normals as RGB
uniform sampler2D licap_texture : hint_default_white, source_color, filter_linear, repeat_disable;
uniform vec3 light_position_w;

varying vec3 world_pos;
varying vec3 world_normal;

vec4 sample_gradient(float t) {
    vec4 col = colors[point_count-1];
    for (int i = 0; i < point_count - 1; i++) {
        float w = clamp((t - offsets[i]) / (offsets[i+1] - offsets[i]), 0.0, 1.0);
        col = mix(col, mix(colors[i], colors[i+1], w), step(offsets[i], t) * (1.0 - step(offsets[i+1], t)));
    }
    return col;
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

uniform float uv_smoothing : hint_range(0.0, 0.5) = 0.0;

uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float max_derivative = 0.1;
void fragment() {



	vec3 Lw = normalize(light_position_w - world_pos);
	Lw = vec3(-Lw.z, Lw.y, Lw.x);

	vec3 light_forward = Lw;
	vec3 light_right = normalize(cross(vec3(0.0, 1.0, 0.0), light_forward));
	vec3 light_up = cross(light_forward, light_right);

	vec3 smooth_normal = world_normal;
	if (normal_smoothing > 0.0) {
		vec3 dNdx = dFdx(world_normal);
		vec3 dNdy = dFdy(world_normal);

		// Clamp derivative magnitude to prevent edge artifacts

		dNdx = clamp(dNdx, -max_derivative, max_derivative);
		dNdy = clamp(dNdy, vec3(-max_derivative), vec3(max_derivative));

		smooth_normal = normalize(world_normal - (dNdx + dNdy) * normal_smoothing);
	}

	float u = dot(smooth_normal, light_right);
	float v = dot(smooth_normal, light_up);
	vec2 uv_coords = clamp(vec2(u, v) * 0.5 + 0.5, 0.0, 1.0);

	float mask_value = texture(licap_texture,uv_coords).r;
	float remapped = texture(terminator_gradient, vec2(mask_value,0.5)).r;


	ALBEDO = vec3(remapped);
}
