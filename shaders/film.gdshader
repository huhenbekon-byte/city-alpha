shader_type canvas_item;
// «Плёнка 80-х»: лёгкое зерно и затемнение по краям кадра. Рисуется поверх 3D, под интерфейсом.
uniform float grain = 0.045;
uniform float vignette = 0.42;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.38, 0.95, d) * vignette;
	float n = fract(sin(dot(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 24.0) * 17.0, vec2(12.9898, 78.233))) * 43758.5453);
	float a = v + grain;
	COLOR = vec4(mix(vec3(n), vec3(0.04, 0.03, 0.02), v / max(a, 0.001)), a);
}
