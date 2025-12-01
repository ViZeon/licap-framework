shader_type spatial;


uniform sampler2D tangent_normal_map : hint_normal, filter_linear;
uniform float normal_map_strength : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D diffuse_texture: hint_default_white, source_color, filter_linear;
uniform sampler2D licap_texture : hint_default_white, source_color, filter_linear, repeat_disable;
uniform float fresnel_intensity;
uniform sampler2D fresnel_matcap : hint_default_white, source_color, filter_linear, repeat_disable;
uniform vec3 light_position_w;
uniform float light_range = 5.0;

uniform float liCap_rotation = 90.0;
uniform float gamma = 2.2;

// Uniforms for gradient control points
uniform int gradient_points_count = 2;
uniform vec4 gradient_point_list[16]: source_color;
uniform int easing_type = 0;

uniform sampler2D baked_gradient: source_color;

uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float max_derivative = 0.1;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 smooth_normal;
varying vec3 base_color;

uniform bool use_custom_light = false;

// RGB to HSL conversion
vec3 rgb2hsl(vec3 c) {
    float maxC = max(max(c.r, c.g), c.b);
    float minC = min(min(c.r, c.g), c.b);
    float delta = maxC - minC;

    float l = (maxC + minC) / 2.0;

    float s = 0.0;
    if (delta > 0.0001) {
        s = l < 0.5 ? delta / (maxC + minC) : delta / (2.0 - maxC - minC);
    }

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

vec3 blend_rnm(vec3 base, vec3 detail, float factor) {
    detail = mix(vec3(0.0, 0.0, 1.0), detail, factor);
    base.z += 1.0;
    detail.xy = -detail.xy;
    return normalize(base * dot(base, detail) - detail * base.z);
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

vec3 evaluate_color_ramp(float input_value, vec4[16] gradient_stops, int points_count) {
    input_value = clamp(input_value, 0.0, 1.0);

    int left_idx = 0;
    for (int i = 0; i < points_count - 1; i++) {
        if (input_value >= gradient_stops[i].a) {
            left_idx = i;
        }
    }

    int right_idx = min(left_idx + 1, points_count - 1);

    float left_pos = gradient_stops[left_idx].a;
    float right_pos = gradient_stops[right_idx].a;
    float blend = (input_value - left_pos) / (right_pos - left_pos + 0.0001);

    if (easing_type == 1) {
        int p0_idx = max(left_idx - 1, 0);
        int p3_idx = min(right_idx + 1, points_count - 1);

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
    smooth_normal = world_normal;
}

void fragment() {
    // Apply normal smoothing
    vec3 final_smooth_normal = smooth_normal;
    
    if (normal_smoothing > 0.0) {
        vec3 dNdx = dFdx(world_normal);
        vec3 dNdy = dFdy(world_normal);
        dNdx = clamp(dNdx, -max_derivative, max_derivative);
        dNdy = clamp(dNdy, vec3(-max_derivative), vec3(max_derivative));
        final_smooth_normal = normalize(world_normal - (dNdx + dNdy) * normal_smoothing);
    }
    
    // Apply normal map
    vec3 normal_map_sample = texture(tangent_normal_map, UV).rgb * 2.0 - 1.0;
    normal_map_sample.z = -normal_map_sample.z;
    final_smooth_normal = blend_rnm(final_smooth_normal, normal_map_sample, normal_map_strength);
    
    // Set the normal for lighting (convert back to view space)
    NORMAL = (INV_VIEW_MATRIX * vec4(final_smooth_normal, 0.0)).xyz;
    
    // Calculate MatCap UV for fresnel (view-based, not light-based)
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    vec3 view_right = normalize(cross(vec3(0.0, 1.0, 0.0), view_dir));
    vec3 view_up = cross(view_dir, view_right);
    
    float u_matcap = dot(final_smooth_normal, view_right);
    float v_matcap = dot(final_smooth_normal, view_up);
    vec2 matcap_coords = vec2(u_matcap, v_matcap) * 0.5 + 0.5;
    
    // Sample base color
    vec4 color = texture(diffuse_texture, UV);
    color = vec4(pow(color.rgb, vec3(1.0 / gamma)), color.a);
    
    // Sample and apply fresnel
    vec3 fresnel_col = texture(fresnel_matcap, matcap_coords).rgb;
    vec3 final_color = mix(color.rgb, fresnel_col, fresnel_intensity);
    
    // Store base color for light() to use
    ALBEDO = final_color;
}

void light() {
	
	
    // Get the smooth normal in world space
    vec3 final_smooth_normal = (VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    
	
    // LIGHT is the direction TO the light (already normalized in view space)
    // Calculate LiCap rotation
    float theta = radians(liCap_rotation);
    float c = cos(theta);
    float s = sin(theta);
    
    // Rotate the light direction
    vec3 rotated_light = vec3(
        LIGHT.x * c - LIGHT.z * s,
        LIGHT.y,
        LIGHT.x * s + LIGHT.z * c
    );
    
    // Create light coordinate system
    vec3 light_forward = normalize(rotated_light);
    vec3 light_right = normalize(cross(vec3(0.0, 1.0, 0.0), light_forward));
    vec3 light_up = cross(light_forward, light_right);
    
    // Calculate LiCap UV coordinates
    float u = dot(final_smooth_normal, light_right);
    float v = dot(final_smooth_normal, light_up);
    vec2 licap_uv = clamp(vec2(-u, v) * 0.5 + 0.5, 0.0, 1.0);
    
    // Sample LiCap texture and evaluate gradient
    float mask_value = texture(licap_texture, licap_uv).r;
    vec3 shadow_ramp = evaluate_color_ramp(mask_value, gradient_point_list, gradient_points_count);
    
    // Apply shadow ramp to base color in HSL space
    vec3 shadow_hsl = rgb2hsl(shadow_ramp);
    vec3 color_hsl = rgb2hsl(ALBEDO);
    
    float color_h = color_hsl.r;
    float color_s = color_hsl.g / shadow_hsl.b;
    float color_l = color_hsl.b * shadow_hsl.b;
    
    vec3 mixed_hsl = vec3(color_h, color_s, color_l);
    vec3 combined_rgb = hsl2rgb(mixed_hsl);
    
    // Apply gamma correction
    vec3 gamma_corrected = pow(combined_rgb, vec3(gamma));
    
    // Output the final lit color
    DIFFUSE_LIGHT = gamma_corrected* ATTENUATION;
}