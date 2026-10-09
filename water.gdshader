shader_type spatial;
render_mode cull_back;

uniform vec4 deep_color : source_color = vec4(0.08, 0.42, 0.75, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.20, 0.68, 0.90, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.96, 1.0, 1.0);

void fragment() {
	vec2 uv = UV * 10.0;
	float t = TIME * 0.8;
	
	float w1 = sin(uv.x * 1.2 + t) * cos(uv.y * 1.2 + t * 0.7);
	float w2 = sin(uv.x * 2.0 - t * 0.9 + uv.y * 1.5);
	float wave = (w1 + w2) * 0.5;
	
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, wave * 0.5 + 0.5);
	float foam = smoothstep(0.42, 0.65, wave);
	
	ALBEDO = mix(water, foam_color.rgb, foam * 0.6);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
