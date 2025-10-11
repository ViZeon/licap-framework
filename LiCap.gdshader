shader_type spatial;
render_mode diffuse_toon;
uniform sampler2D licap_texture : hint_default_white;
varying vec3 world_normal;
uniform	float light_intensity = 5.0;

void vertex(){
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}

void fragment ()
{
	//vec3 view_normal = -normalize((VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 view_normal = -normalize(NORMAL);
	vec2 matcap_uv = view_normal.xy*0.5+0.5;
	vec3 matcap = texture(licap_texture,matcap_uv).rgb;


	//ALBEDO = texture(licap_texture,UV).rgb;
	//ALBEDO = NORMAL *0.5 + 0.5;
	//ALBEDO = matcap;
}

void light() {
	vec3 light_dir = normalize((inverse(VIEW_MATRIX) * vec4(LIGHT, 0.0)).xyz);
	vec3 normal = normalize(world_normal);//NORMAL;

	vec3 right = normalize(cross(light_dir, vec3(0.0,0.0,0.1)));

	//vec3 base_color: source_color = vec3(0.5,0.5,0.5);

	//U coordinates [light]
	float u = dot(normal, right);
	float v = dot(normal, light_dir);



	vec2 licap_UV = vec2(u,v)*0.5+0.5;
	vec3 licap = texture(licap_texture,licap_UV).rgb;
	licap = pow(licap,vec3(2.2));
	float alignment = dot(normal,light_dir);

	licap = pow(licap, vec3(1.0/light_intensity));

	DIFFUSE_LIGHT = licap; //*ATTENUATION*LIGHT_COLOR   //* ALBEDO;vec3(alignment) * ATTENUATION;
}
/*
void light() {
    vec3 light_dir = normalize(LIGHT);
    vec3 normal = NORMAL;

    vec3 right = normalize(cross(light_dir, vec3(0.0, 0.0, 1.0)));

    float u = dot(normal, right);
    float v = dot(normal, light_dir);

    vec2 licap_uv = vec2(u, v) * 0.5 + 0.5;
    vec3 licap = texture(licap_texture, licap_uv).rgb;
    // licap * ATTENUATION *
    DIFFUSE_LIGHT = ALBEDO;
}
*/