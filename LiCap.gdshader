
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
uniform vec4 gradient_stops[16]:  source_color;
uniform sampler2D saturation_gradient: source_color;

uniform float uv_smoothing : hint_range(0.0, 0.5) = 0.0;

uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float max_derivative = 0.1;

varying vec3 tangent_w;
varying vec3 binormal_w;

uniform float sss_strength;

uniform vec3 shadow_tint = vec3(0.6, 0.7, 1.0);
uniform vec3 highlight_tint = vec3(1.0, 0.95, 0.85);
uniform float shadow_hue_shift = -0.05;
uniform float highlight_hue_shift = 0.03;
uniform float saturation_boost = 1.2;
uniform float dark_saturation_boost = 1.0;

// Easing type selector
uniform int easing_type = 0;

// RGB to HSL conversion (using Luminance instead of Value)
vec3 rgb2hsl(vec3 c) {
    float maxC = max(max(c.r, c.g), c.b);
    float minC = min(min(c.r, c.g), c.b);
    float delta = maxC - minC;
    
    // Luminance
    float l = (maxC + minC) / 2.0;
    
    // Saturation
    float s = 0.0;
    if (delta > 0.0001) {
        s = l < 0.5 ? delta / (maxC + minC) : delta / (2.0 - maxC - minC);
    }
    
    // Hue
    float h = 0.0;
    if (delta > 0.0001) {
        if (maxC == c.r) {
            h = (c.g - c.b) / delta + (c.g < c.b ? 6.0 : 0.0);
        } else if (maxC == c.g) {
            h = (c.b - c.r) / delta + 2.0;
        } else {
            h = (c.r - c.g) / delta + 4.0;
        }
        h /= 6.0;
    }
    
    return vec3(h, s, l);
}

// HSL to RGB conversion
vec3 hsl2rgb(vec3 c) {
    float h = c.x;
    float s = c.y;
    float l = c.z;
    
    float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    float p = 2.0 * l - q;
    
    vec3 rgb;
    rgb.r = h + 1.0/3.0;
    rgb.g = h;
    rgb.b = h - 1.0/3.0;
    
    for(int i = 0; i < 3; i++) {
        if(rgb[i] < 0.0) rgb[i] += 1.0;
        if(rgb[i] > 1.0) rgb[i] -= 1.0;
        
        if(rgb[i] < 1.0/6.0)
            rgb[i] = p + (q - p) * 6.0 * rgb[i];
        else if(rgb[i] < 0.5)
            rgb[i] = q;
        else if(rgb[i] < 2.0/3.0)
            rgb[i] = p + (q - p) * (2.0/3.0 - rgb[i]) * 6.0;
        else
            rgb[i] = p;
    }
    
    return rgb;
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

// Color Dodge (float version)
float blend_color_dodge_f(float base, float blend, float factor) {
    float result = base / (1.0 - blend + 0.0001);
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

// Cardinal spline interpolation
vec3 cardinal_spline(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
    float tension = 0.5;
    
    vec3 m1 = (1.0 - tension) * (p2 - p0);
    vec3 m2 = (1.0 - tension) * (p3 - p1);
    
    float t2 = t * t;
    float t3 = t2 * t;
    
    float h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    float h10 = t3 - 2.0 * t2 + t;
    float h01 = -2.0 * t3 + 3.0 * t2;
    float h11 = t3 - t2;
    
    return h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2;
}

vec3 evaluate_color_ramp(float input_value) {
    input_value = clamp(input_value, 0.0, 1.0);

    int left_idx = 0;
    for (int i = 0; i < num_gradient_points - 1; i++) {
        if (input_value >= gradient_stops[i].a) {
            left_idx = i;
        }
    }

    int right_idx = min(left_idx + 1, num_gradient_points - 1);

    float left_pos = gradient_stops[left_idx].a;
    float right_pos = gradient_stops[right_idx].a;
    float blend = (input_value - left_pos) / (right_pos - left_pos + 0.0001);

    if (easing_type == 1) {
        int p0_idx = max(left_idx - 1, 0);
        int p3_idx = min(right_idx + 1, num_gradient_points - 1);
        
        vec3 p0 = gradient_stops[p0_idx].rgb;
        vec3 p1 = gradient_stops[left_idx].rgb;
        vec3 p2 = gradient_stops[right_idx].rgb;
        vec3 p3 = gradient_stops[p3_idx].rgb;
        
        return cardinal_spline(p0, p1, p2, p3, blend);
    } else {
        return mix(gradient_stops[left_idx].rgb, gradient_stops[right_idx].rgb, blend);
    }
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

		dNdx = clamp(dNdx, -max_derivative, max_derivative);
		dNdy = clamp(dNdy, vec3(-max_derivative), vec3(max_derivative));

		smooth_normal = normalize(world_normal - (dNdx + dNdy) * normal_smoothing);
	}

	vec3 normal_map_sample = texture(normal_map, UV).rgb * 2.0 - 1.0;
	normal_map_sample.x = -normal_map_sample.x;

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
	vec4 satu_gradient = texture(saturation_gradient,uv_coords);

	float mask_value = texture(licap_texture, uv_coords).r;
	vec3 mask_col = texture(licap_texture, uv_coords).rgb;

	vec3 color_filter_02 = blend_soft_light( evaluate_color_ramp(mask_value),color.rgb, 1);
	
	vec3 shadow_albedo = blend_multiply(color.rgb, color.rgb, 1);
	vec3 final_color = blend_multiply(shadow_albedo,color.rgb, mask_value);
	
	vec3 shadow_ramp = evaluate_color_ramp(mask_value);
	vec3 shadow_hsl = rgb2hsl(shadow_ramp);
	vec3 color_hsl = rgb2hsl(color.rgb);
	
	float color_h = color_hsl.r;
	float color_s = saturation_curve(color_hsl.g)*satu_gradient.r*3.0;
	float satu_luminance = color_s;
	
	


	float color_l = shadow_hsl.b * color_hsl.b / satu_luminance * 1.5;
	
		float shadow_amount = (1.0 - mask_value);
	float sss_factor = clamp((shadow_amount) * sss_strength + (1.0-color_l) ,0.0, 1.0);

	// Apply to luminance channel
	float sss_luminance = blend_color_dodge_f(color_hsl.b, 0.8, sss_factor);
	 //color_l = sss_luminance;
	
	vec3 mixed_hsl = vec3(color_h, color_s, color_l);
	
	mixed_hsl.r *= satu_luminance * 1.5 + (1.0 - satu_luminance)*sss_luminance;
	
	vec3 combined_rgb = hsl2rgb(mixed_hsl);

	float albedo_float = sss_luminance;
	ALBEDO = combined_rgb;
	//ALBEDO = vec3(albedo_float,albedo_float,albedo_float);
}
