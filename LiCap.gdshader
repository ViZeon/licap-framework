
shader_type spatial;
render_mode unshaded;

uniform sampler2D normal_map : hint_normal, filter_linear;
uniform float normal_map_strength : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D diffuse_texture: hint_default_white, source_color, filter_linear;
uniform sampler2D licap_texture : hint_default_white, source_color, filter_linear, repeat_disable;
uniform vec3 light_position_w;

varying vec3 world_pos;
varying vec3 world_normal;

// Uniforms for gradient control points
uniform int num_gradient_points = 2;
uniform sampler2D gradient_stops[16]:  source_color, filter_linear;//source_color;  // RGB = color, A = position

uniform float uv_smoothing : hint_range(0.0, 0.5) = 0.0;

uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float max_derivative = 0.1;

varying vec3 tangent_w;
varying vec3 binormal_w;

uniform vec3 shadow_tint = vec3(0.6, 0.7, 1.0); // Cool shadows
uniform vec3 highlight_tint = vec3(1.0, 0.95, 0.85); // Warm highlights
uniform float shadow_hue_shift = -0.05; // Hue shift in shadows (negative = toward blue)
uniform float highlight_hue_shift = 0.03; // Hue shift in highlights (positive = toward yellow)
uniform float saturation_boost = 1.2; // Midtone saturation multiplier
uniform float dark_saturation_boost = 1.0; // Multiplier for dark areas

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Saturation curve - peaks in midtones
float saturation_curve(float luminance) {
    // Parabolic curve peaking around 0.5
    float mid_boost = 1.0 - 4.0 * pow(luminance - 0.5, 2.0);
    return mix(0.7, saturation_boost, mid_boost);
}
// Normal
vec3 blend_normal(vec3 base, vec3 blend, float factor) {
    return mix(base, blend, factor);
}

// Multiply
vec3 blend_multiply(vec3 base, vec3 blend, float factor) {
    return mix(base, base * blend, factor);
}

// Screen
vec3 blend_screen(vec3 base, vec3 blend, float factor) {
    return mix(base, 1.0 - (1.0 - base) * (1.0 - blend), factor);
}

// Overlay
vec3 blend_overlay(vec3 base, vec3 blend, float factor) {
    vec3 result = mix(
        2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        step(0.5, base)
    );
    return mix(base, result, factor);
}

// Soft Light
vec3 blend_soft_light(vec3 base, vec3 blend, float factor) {
    vec3 result = mix(
        2.0 * base * blend + base * base * (1.0 - 2.0 * blend),
        sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend),
        step(0.5, blend)
    );
    return mix(base, result, factor);
}

// Hard Light
vec3 blend_hard_light(vec3 base, vec3 blend, float factor) {
    vec3 result = mix(
        2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
        step(0.5, blend)
    );
    return mix(base, result, factor);
}

// Darken
vec3 blend_darken(vec3 base, vec3 blend, float factor) {
    return mix(base, min(base, blend), factor);
}

// Lighten
vec3 blend_lighten(vec3 base, vec3 blend, float factor) {
    return mix(base, max(base, blend), factor);
}

// Color Dodge
vec3 blend_color_dodge(vec3 base, vec3 blend, float factor) {
    vec3 result = base / (1.0 - blend + 0.0001);
    return mix(base, clamp(result, 0.0, 1.0), factor);
}

// Color Burn
vec3 blend_color_burn(vec3 base, vec3 blend, float factor) {
    vec3 result = 1.0 - (1.0 - base) / (blend + 0.0001);
    return mix(base, clamp(result, 0.0, 1.0), factor);
}

// Linear Dodge (Add)
vec3 blend_linear_dodge(vec3 base, vec3 blend, float factor) {
    return mix(base, clamp(base + blend, 0.0, 1.0), factor);
}

// Linear Burn
vec3 blend_linear_burn(vec3 base, vec3 blend, float factor) {
    return mix(base, clamp(base + blend - 1.0, 0.0, 1.0), factor);
}

// Difference
vec3 blend_difference(vec3 base, vec3 blend, float factor) {
    return mix(base, abs(base - blend), factor);
}

// Exclusion
vec3 blend_exclusion(vec3 base, vec3 blend, float factor) {
    return mix(base, base + blend - 2.0 * base * blend, factor);
}

// Subtract
vec3 blend_subtract(vec3 base, vec3 blend, float factor) {
    return mix(base, clamp(base - blend, 0.0, 1.0), factor);
}

// Divide
vec3 blend_divide(vec3 base, vec3 blend, float factor) {
    vec3 result = base / (blend + 0.0001);
    return mix(base, clamp(result, 0.0, 1.0), factor);
}


vec3 evaluate_color_ramp(float input_value, vec2 uv) {
    input_value = clamp(input_value, 0.0, 1.0);

    // Find surrounding stops
    int left_idx = 0;
    for (int i = 0; i < num_gradient_points - 1; i++) {
        if (input_value >= texture(gradient_stops[i], uv).a) {
            left_idx = i;
        }
    }

    int right_idx = min(left_idx + 1, num_gradient_points - 1);

    // Interpolate
    float left_pos = texture(gradient_stops[left_idx], uv).a;
    float right_pos = texture(gradient_stops[right_idx], uv).a;
    float blend = (input_value - left_pos) / (right_pos - left_pos + 0.0001);

    return mix(texture(gradient_stops[left_idx], uv).rgb, texture(gradient_stops[right_idx], uv).rgb, blend);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    tangent_w = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
    binormal_w = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}


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


	// Blend normal map using mesh UVs
	//vec3 normal_map_sample = texture(normal_map, UV).rgb * 2.0 - 1.0;
	//smooth_normal = normalize(smooth_normal + normal_map_sample * normal_map_strength);


	// Sample and transform normal map to world space

vec3 normal_map_sample = texture(normal_map, UV).rgb * 2.0 - 1.0;
normal_map_sample.x = -normal_map_sample.x; // Flip Y

vec3 normal_from_map = normalize(
    normal_map_sample.x * tangent_w +
    normal_map_sample.y * binormal_w +
    normal_map_sample.z * smooth_normal
);

smooth_normal = normalize(mix(smooth_normal, normal_from_map, normal_map_strength));

	float u = dot(smooth_normal, light_right);
	float v = dot(smooth_normal, light_up);
	vec2 uv_coords = clamp(vec2(-u, v) * 0.5 + 0.5, 0.0, 1.0);

	vec4 color = texture(diffuse_texture,UV);

	float mask_value = texture(licap_texture, uv_coords).r;

	//ALBEDO = final_color;
		vec3 color_filter_01 = blend_multiply(color.rgb,evaluate_color_ramp(mask_value, UV), mask_value*3.0);
	// Get base albedo
	    vec3 base_color = texture(diffuse_texture, UV).rgb;

	    // Your LUT lighting result goes here
	    // For demo purposes, using DIFFUSE_LIGHT as stand-in
	    float lighting = color_filter_01.g; //evaluate_color_ramp(mask_value).r;//dot(mask_value, vec3(0.299, 0.587, 0.114)); // Luminance

	    // Convert to HSV
	    vec3 hsv = rgb2hsv(base_color);

	    // Hue shift based on lighting
	    float hue_shift = mix(shadow_hue_shift, highlight_hue_shift, lighting);
	    hsv.x = fract(hsv.x + hue_shift);

	    // Saturation adjustment based on lighting
	    float sat_mult = saturation_curve(lighting);
	    //hsv.y *= sat_mult;
		float dark_boost = mix(dark_saturation_boost, 1.0, lighting);
		hsv.y *= sat_mult * dark_boost;

	    // Convert back to RGB
	    vec3 shifted_color = hsv2rgb(hsv);

	    // Temperature tinting
	    vec3 temp_tint = blend_color_dodge(shadow_tint, highlight_tint, lighting);
	    shifted_color *= temp_tint;



	//vec3 color_filter_02 = blend_soft_light( evaluate_color_ramp(mask_value),color.rgb, 1);
	vec3 final_color = color_filter_01;

	    ALBEDO = color_filter_01;
	}
		//ALBEDO = vec3(remapped);
