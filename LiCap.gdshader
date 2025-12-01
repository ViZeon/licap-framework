
shader_type spatial;
render_mode unshaded;
stencil_mode 1;


uniform sampler2D tangent_normal_map : hint_normal, filter_linear;
uniform float normal_map_strength : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D diffuse_texture: hint_default_white, source_color, filter_linear;
uniform sampler2D licap_texture : hint_default_white, source_color, filter_linear, repeat_disable;
uniform float fresnel_intensity;
uniform sampler2D fresnel_matcap : hint_default_white, source_color, filter_linear, repeat_disable;
uniform vec3 light_position_w;
uniform float light_range = 5.0;

uniform float liCap_rotation = 90;
uniform float gamma = 2.2;


// Uniforms for gradient control points
uniform int gradient_points_count = 2;
uniform vec4 gradient_point_list[16]:  source_color;
// Easing type selector
uniform int easing_type = 0;

uniform sampler2D baked_gradient: source_color;


uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float max_derivative = 0.1;

// The distance (in world units) for the full falloff.
uniform float falloff_radius : hint_range(0.1, 50.0) = 15.0;

// Steepness of the fade (Higher = sharper).
uniform float sharpness : hint_range(1.0, 10.0) = 4.0;

// The color and maximum opacity (alpha) of the mask.
uniform vec4 shadow_mask_color;

varying vec3 world_pos;
varying vec3 world_normal;

varying vec3 tangent_w;
varying vec3 binormal_w;

varying vec3 shadow_map;


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
float saturation_curve(float luminance, float saturation_boost) {
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

// Unpack normal map and convert to world space
	vec3 apply_normal_map(sampler2D normal_texture, vec2 uv, vec3 tangent, vec3 normal, float strength) {
    vec3 normal_map = texture(normal_texture, uv).rgb * 2.0 - 1.0;
    normal_map.xy *= strength;
    normal_map = normalize(normal_map);

    vec3 T = normalize(tangent);
    vec3 N = normalize(normal);
    vec3 B = cross(N, T); // Calculate binormal instead of using BINORMAL

    mat3 tbn = mat3(T, B, N);
    return normalize(tbn * normal_map);
}

vec3 blend_rnm(vec3 base, vec3 detail, float factor) {
    // Lerp detail towards neutral normal (0, 0, 1) based on factor
    detail = mix(vec3(0.0, 0.0, 1.0), detail, factor);

    base.z += 1.0;
    detail.xy = -detail.xy;
    return normalize(base * dot(base, detail) - detail * base.z);
}

void calc_shadows ( ){

}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    tangent_w = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
    binormal_w = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}


void fragment() {

	float theta = radians(liCap_rotation);
	float c = cos(theta);
	float s = sin(theta);

	theta = theta * PI/2.0;
	vec3 offset = light_position_w - world_pos;
	vec3 rotating = vec3 (
		offset.x*c - offset.z*s,
		offset.y,
		offset.x*s + offset.z*c);
	vec3 rotated_light_coords = world_pos + rotating;


	vec3 Lw = normalize(offset);
	vec3 light_forward = rotating;
	//not sure what this is doing, I think it's mapping the coordinates for the texture, or the right axis?
	vec3 light_right = normalize(cross(vec3(world_pos), light_forward));
	// what does cross do?
	vec3 light_up = cross(light_forward, light_right);






	//this is passed from the vertex shader, I need to dig up what it does
	vec3 smooth_normal = world_normal;

	//ah.. one conditional to remove/replace
	if (normal_smoothing > 0.0) {
		// need to check what the dFdy/y function does
		vec3 dNdx = dFdx(world_normal);
		vec3 dNdy = dFdy(world_normal);

		//and what their clamping actually does
		dNdx = clamp(dNdx, -max_derivative, max_derivative);
		dNdy = clamp(dNdy, vec3(-max_derivative), vec3(max_derivative));

		//The fuck does this do exactly? lotsa math to understand
		smooth_normal = normalize(world_normal - (dNdx + dNdy) * normal_smoothing);
	}
	// I get it's taking the normal map, I don't get the numerical settings, it aso inverts it and I don't remember why
	vec3 normal_map_sample = texture(tangent_normal_map, UV).rgb * 2.0 - 1.0;
	normal_map_sample.z = -normal_map_sample.z;

	    //vec3 surface_normal =  apply_normal_map(tangent_normal_map, UV, smooth_normal, NORMAL, normal_map_strength);
		//smooth_normal = blend_rnm(smooth_normal, normal_map_sample, normal_map_strength);

	// so convert normal space then use a simple mix fuction? that kinda feels off for an XYZ map
	smooth_normal = blend_rnm(smooth_normal, normal_map_sample, normal_map_strength);
	//smooth_normal - normalize(mix(smooth_normal, normal_map_sample, normal_map_strength));

	// Add after your smooth_normal calculation
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 view_right = normalize(cross(world_pos, view_dir));
	vec3 view_up = cross(view_dir, view_right);

	// MatCap UV coordinates
	float u_matcap = dot(smooth_normal, view_right);
	float v_matcap = dot(smooth_normal, view_up);
	vec2 matcap_uv = vec2(u_matcap, v_matcap) * 0.5 + 0.5;

		// Values to utilize in shading, still need to understand what dot means but as far as I know, it checks how perpendicular a vector is to another
	// This is passsing the normals as first vector, and light as the 2nd? are UV coordicates percentage based? so like.. convert normals to a bunch of vectors and access them per frame?
	float u = dot(smooth_normal, light_right);
	float v = dot(smooth_normal, light_up);
	// Why clamp? did I overshoot? is it possible to overshoot a UV percentage? or is the map smaller than it should be?
	vec2 uv_coords = clamp(vec2(-u, v) * 0.5 + 0.5, 0.0, 1.0);

	    // Transform world_pos to light space
    vec3 relative_pos = world_pos - rotated_light_coords;
    vec2 light_space_xy = vec2(
        dot(smooth_normal, light_right),
        dot(smooth_normal, light_up)
		);

		// ok so uv_coords is our LiCap mapping? when applied to any texture, it is used like a MatCap/LiCap?
	vec4 color = texture(diffuse_texture,UV);
	color = vec4(pow(color.rgb, vec3(1.0/gamma)), color.a);
	vec4 baked_gradient_tex = texture(baked_gradient,uv_coords);

	float mask_value = texture(licap_texture, uv_coords).r;
	vec3 mask_col = texture(licap_texture, uv_coords).rgb;

	vec3 fresnel_col = texture(fresnel_matcap, matcap_uv).rgb;
	//vec3 matcap_mask = texture(matcap_mask_texture, matcap_uv).rgb;




	// Yeah all these need a different kind of understanding, gonna have to test in an art software
	// This is lightening up the mask value based on the gradient? or vice versa?
	//vec3 color_filter_02 = blend_soft_light( evaluate_color_ramp(mask_value, gradient_point_list, gradient_points_count),color.rgb, 1);

	// This applies the ram to the LiCap mask, hmm..
	vec3 shadow_ramp = evaluate_color_ramp(mask_value, gradient_point_list, gradient_points_count);

	//color.rgb = color.rgb*shadow_ramp;

	// Splits shadow LiCap and color maps into HSL
	vec3 shadow_hsl = rgb2hsl(shadow_ramp);
	vec3 color_hsl = rgb2hsl(color.rgb);
	vec3 fresnel_hsl = rgb2hsl(fresnel_col);


	// Mapping what goes to what
	float color_h = color_hsl.r;//mix(,color_hsl.r,0.1);
	float color_s = color_hsl.g;
	float color_l = color_hsl.b;

	// apply shadow
	//color_h = color_h * shadow_hsl.b;
	color_s = color_s / shadow_hsl.b;
	color_l = color_l * shadow_hsl.b;



	//color_s = clamp(color_s,0.0,1.0);
	vec3 mixed_hsl = vec3(color_h, color_s, color_l);

	// mixing them back
	vec3 combined_rgb = hsl2rgb(mixed_hsl);
	vec3 gamma_correction = pow(combined_rgb, vec3(gamma));
	







	    // Light direction
    vec3 to_light = rotated_light_coords - world_pos;
    float dist = length(to_light);
    vec3 light_dir = to_light / dist;
	    // Check if facing light
    float facing = dot(smooth_normal, rotated_light_coords);
	float range_place = light_range - distance(world_pos, rotated_light_coords) ;
	 // 2. Normalize the distance and clamp it. (0.0 near light, 1.0 far away).
    float normalized_dist = clamp(dist / falloff_radius, 0.0, 1.0);

    // 3. Apply sharpness to create the mask strength curve.
    float mask_strength = pow(normalized_dist, sharpness);

	vec3 color_start = vec3(1.0,1.0,1.0);
	vec3 color_end = vec3(0.0,0.0,0.0);
    // 4. Set ALBEDO and modulate ALPHA with the calculated mask strength.
    vec3 shadow_mask_ramp = mix(color_start, color_end, normalized_dist);
    //ALPHA = shadow_mask_color.a * mask_strength;
	
if ((shadow_mask_ramp.r < shadow_map.r))
{

	//shadow_map.r = shadow_mask_ramp.r; // Store distance
	//shadow_map.g = 0.0;

}
else
{
	//ALBEDO.b = 0.0;
}

//ALBEDO = shadow_map;
    //ALBEDO = vec3(0.8) * shadow;
float albedo_float = shadow_map.r;

	ALBEDO = vec3(albedo_float,albedo_float,albedo_float);
	ALBEDO = shadow_map;
	//evaluate_color_ramp(mask_value);

	ALBEDO = gamma_correction;
	/*
		if(!(facing > 0.0)) {
	        ALBEDO = vec3(dist / 100.0); // Store distance
	    } else {
	        if (!(ALBEDO== vec3(1.0)))
			ALBEDO = vec3(0.0); // Max distance = shadowed
	    }
	*/
	

}

/*shader_type spatial;

// CRITICAL RENDER MODES for a transparent overlay mask:
// 1. `unshaded`: Ignores scene lighting (mask color is constant).
// 2. `alpha_blend`: Enables transparency blending.
// 3. `depth_draw_never`: Prevents the mask from blocking other objects' rendering.
render_mode unshaded, alpha_blend, depth_draw_never;

// The 3D world coordinates (x, y, z) of the light source.
uniform vec3 light_world_pos = vec3(0.0, 5.0, 0.0);

// The distance (in world units) for the full falloff.
uniform float falloff_radius : hint_range(0.1, 50.0) = 15.0;

// Steepness of the fade (Higher = sharper).
uniform float sharpness : hint_range(1.0, 10.0) = 4.0;

// The color and maximum opacity (alpha) of the mask.
uniform vec4 mask_color : hint_color = vec4(0.0, 0.0, 0.0, 0.9);

varying vec3 world_fragment_pos;

void vertex() {
    // Pass the fragment's world position to the fragment shader.
    world_fragment_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // 1. Calculate Euclidean distance in 3D space.
    float dist = distance(world_fragment_pos, light_world_pos);

    // 2. Normalize the distance and clamp it. (0.0 near light, 1.0 far away).
    float normalized_dist = clamp(dist / falloff_radius, 0.0, 1.0);

    // 3. Apply sharpness to create the mask strength curve.
    float mask_strength = pow(normalized_dist, sharpness);

    // 4. Set ALBEDO and modulate ALPHA with the calculated mask strength.
    ALBEDO = mask_color.rgb;
    ALPHA = mask_color.a * mask_strength;
}*/


/*
    // Get world position and normal
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_normal = texture(normal_map, UV).xyz * 2.0 - 1.0;

    // Light direction
    vec3 to_light = light_pos - world_pos;
    float dist = length(to_light);
    vec3 light_dir = to_light / dist;

    // Create light-perpendicular basis
    vec3 light_forward = normalize(light_dir);
    vec3 light_right = normalize(cross(light_forward, vec3(0, 1, 0)));
    vec3 light_up = cross(light_right, light_forward);

    // Transform world_pos to light space
    vec3 relative_pos = world_pos - light_pos;
    vec2 light_space_xy = vec2(
        dot(relative_pos, light_right),
        dot(relative_pos, light_up)
    );

    // Check if facing light
    float facing = dot(world_normal, light_dir);

    if(facing > 0.0) {
        ALBEDO = vec3(dist / 100.0); // Store distance
    } else {
        ALBEDO = vec3(1.0); // Max distance = shadowed
    }
	*/
