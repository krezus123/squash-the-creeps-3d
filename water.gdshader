shader_type spatial;
render_mode cull_back;

uniform vec4 deep_color : source_color = vec4(0.04, 0.28, 0.58, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.06, 0.58, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 5.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
			}
		}
	}
	return sqrt(md);
}

void fragment() {
	vec2 uv = UV * 18.0;
	float t = TIME * 0.7;

	float c1 = voronoi(uv + vec2(t * 0.4, t * 0.3));
	float c2 = voronoi(uv * 1.25 - vec2(t * 0.3, t * 0.5));
	float caustics = min(c1, c2);

	float wave_lines = smoothstep(0.20, 0.08, caustics);

	vec3 water = mix(deep_color.rgb, shallow_color.rgb, c1 * 0.65);
	vec3 final_color = mix(water, foam_color.rgb, wave_lines * 0.85);

	ALBEDO = final_color;
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
}
