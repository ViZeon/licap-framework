
shader_type spatial;
render_mode unshaded;

uniform sampler2D terminator_gradient:  source_color, filter_linear, repeat_disable;
uniform sampler2D normal_licap : hint_default_white; // Stores normals as RGB
uniform sampler2D licap_texture : hint_default_white, source_color, filter_linear, repeat_disable;
uniform vec3 light_position_w;

varying vec3 world_pos;
varying vec3 world_normal;

// Uniforms for gradient control points
uniform int num_gradient_points = 2;
uniform vec4 gradient_stops[16]: source_color;  // RGB = color, A = position

vec3 evaluate_color_ramp(float input_value) {
    input_value = clamp(input_value, 0.0, 1.0);

    // Find surrounding stops
    int left_idx = 0;
    for (int i = 0; i < num_gradient_points - 1; i++) {
        if (input_value >= gradient_stops[i].a) {
            left_idx = i;
        }
    }

    int right_idx = min(left_idx + 1, num_gradient_points - 1);

    // Interpolate
    float left_pos = gradient_stops[left_idx].a;
    float right_pos = gradient_stops[right_idx].a;
    float blend = (input_value - left_pos) / (right_pos - left_pos + 0.0001);

    return mix(gradient_stops[left_idx].rgb, gradient_stops[right_idx].rgb, blend);
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

	float mask_value = texture(licap_texture, uv_coords).r;
	vec3 final_color = evaluate_color_ramp(mask_value);
	ALBEDO = final_color;

	//ALBEDO = vec3(remapped);
}
