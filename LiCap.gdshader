shader_type spatial;
render_mode unshaded;

uniform sampler2D licap_texture : hint_default_white;
varying vec3 world_normal;
uniform	float light_intensity = 5.0;
uniform vec3 light_position_w;

void fragment() {
	vec3 fragment_world_pos = (MODEL_MATRIX*vec4(VERTEX, 1.0)).xyz;
	vec3 light_vector = light_position_w-fragment_world_pos;
	vec3 Lw = normalize((light_vector));
	
	//Matrix transform
	vec3 Lv = (VIEW_MATRIX*vec4(Lw, 0.0)).xyz;
	vec3 Lv_normalized =normalize(Lv);
	//vec3 Lv = (MODEL_NORMAL_MATRIX*Lw);
	
	vec2 uv_coords = Lv_normalized.xy * 0.5 + 0.5;
	
	vec3 LiCapColor = texture(licap_texture, uv_coords).rgb;
	
	ALBEDO = LiCapColor;
}
