shader_type spatial;
// Река: синяя вода с бегущей рябью и бликами (без текстур).
render_mode cull_disabled;

uniform vec3 deep : source_color = vec3(0.10, 0.22, 0.30);
uniform vec3 shallow : source_color = vec3(0.22, 0.38, 0.45);
uniform float flow = 0.6;

float wave(vec2 p) {
	return sin(p.x * 1.7 + TIME * 1.1) * 0.5 + sin(p.y * 2.3 - TIME * flow * 2.0 + p.x * 0.4) * 0.5
		+ sin((p.x + p.y) * 3.1 + TIME * 1.7) * 0.25;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz * 0.35;
	float e = 0.05;
	float h = wave(p);
	vec3 n = normalize(vec3(wave(p + vec2(e, 0.0)) - h, 1.0 / 0.12, wave(p + vec2(0.0, e)) - h));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float edge = clamp(abs(fract(wp.x / 70.0 + 0.5) - 0.5) * 2.0, 0.0, 1.0);
	ALBEDO = mix(deep, shallow, 0.3 + 0.2 * h);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	SPECULAR = 0.6;
}
