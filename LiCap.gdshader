
shader_type spatial;
render_mode unshaded;

uniform sampler2D diffuse_texture;
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

vec3 overlay(vec3 base, vec3 blend)
{
	return mix(2.0 * base * blend, 1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5,base));
}

// --- Add these two complex helper functions above fragment() ---

// Converts RGB to HSL. Outputs: H in [0,1], S in [0,1], L in [0,1]
vec3 rgb_to_hsl(vec3 color) {
    float max_c = max(color.r, max(color.g, color.b));
    float min_c = min(color.r, min(color.g, color.b));
    float h = 0.0, s = 0.0, l = (max_c + min_c) / 2.0;
    if (max_c == min_c) {
        h = s = 0.0; // achromatic
    } else {
        float d = max_c - min_c;
        s = l > 0.5 ? d / (2.0 - max_c - min_c) : d / (max_c + min_c);
        if (max_c == color.r) h = (color.g - color.b) / d + (color.g < color.b ? 6.0 : 0.0);
        else if (max_c == color.g) h = (color.b - color.r) / d + 2.0;
        else if (max_c == color.b) h = (color.r - color.g) / d + 4.0;
        h /= 6.0;
    }
    return vec3(h, s, l);
}

// Converts HSL to RGB
// Helper function for hsl_to_rgb. Must be defined before it's called.
float hue_to_rgb_channel(float p, float q, float t) {
    if (t < 0.0) t += 1.0;
    if (t > 1.0) t -= 1.0;
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0/2.0) return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

// Converts HSL to RGB.
vec3 hsl_to_rgb(vec3 hsl) {
    vec3 rgb;
    if (hsl.y == 0.0) {
        rgb = vec3(hsl.z); // Achromatic (grayscale)
    } else {
        float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
        float p = 2.0 * hsl.z - q;
        rgb.r = hue_to_rgb_channel(p, q, hsl.x + 1.0/3.0);
        rgb.g = hue_to_rgb_channel(p, q, hsl.x);
        rgb.b = hue_to_rgb_channel(p, q, hsl.x - 1.0/3.0);
    }
    return rgb;
}


vec3 color_blend ( vec3 base_color, vec3 blend_color) {
// --- In fragment() ---
vec3 base_hsl = rgb_to_hsl(base_color.rgb);
vec3 blend_hsl = rgb_to_hsl(blend_color.rgb);

// Take Hue and Saturation from blend, and Luminance from base
vec3 final_hsl = vec3(blend_hsl.x, blend_hsl.y, base_hsl.z);

return( hsl_to_rgb(final_hsl));
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

	vec4 color = texture(diffuse_texture,UV);

	float mask_value = texture(licap_texture, uv_coords).r;
	vec3 final_color = color_blend( color.rgb, evaluate_color_ramp(mask_value));
	ALBEDO = final_color;

	//ALBEDO = vec3(remapped);
}
