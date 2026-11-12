shader_type spatial;
// Персонаж Quaternius: кожа из текстуры, а куртка, штаны и обувь — по маске
// (R — куртка, G — штаны, B — обувь) в цвет и ткань, купленные на рынке.

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform sampler2D mask_tex : filter_linear;
// где у куртки предплечья: у майки и футболки рукава короткие (long_sleeves = 0)
uniform sampler2D sleeve_tex : filter_linear;
uniform float long_sleeves = 1.0;
// принт на груди (уже разложен по развёртке тела)
uniform sampler2D print_tex : source_color, filter_linear;
uniform float print_on = 0.0;
// форма фракций: лампасы, светоотражающая лента, жилет ДПС (всё разложено по развёртке тела)
uniform sampler2D lampas_tex : source_color, filter_linear;
uniform float lampas_on = 0.0;
uniform sampler2D tape_tex : source_color, filter_linear;
uniform float tape_on = 0.0;
uniform sampler2D vest_mask : filter_linear;
uniform sampler2D vest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float vest_on = 0.0;
uniform sampler2D jacket_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pants_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D shoes_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 jacket_col : source_color = vec3(0.09, 0.42, 0.52);
uniform vec3 pants_col : source_color = vec3(0.17, 0.24, 0.38);
uniform vec3 shoes_col : source_color = vec3(0.96, 0.96, 0.96);
uniform vec3 skin_tint = vec3(1.0);
uniform float cloth_scale = 8.0;

void fragment() {
	vec3 base = texture(body_tex, UV).rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	m.r *= 1.0 - texture(sleeve_tex, UV).r * (1.0 - long_sleeves);
	// складки и объём одежды берём из яркости кожи под ней
	float shade = clamp(dot(base, vec3(0.333)) / 0.55, 0.65, 1.2);
	shade = mix(1.0, shade, 0.6);
	vec2 cuv = UV * cloth_scale;
	vec3 jacket = texture(jacket_tex, cuv).rgb * jacket_col * shade;
	vec3 pants = texture(pants_tex, cuv).rgb * pants_col * shade;
	vec3 shoes = texture(shoes_tex, cuv).rgb * shoes_col * shade;
	vec3 col = base * skin_tint;
	col = mix(col, pants, m.g);
	float vm = texture(vest_mask, UV).r * vest_on;
	jacket = mix(jacket, texture(vest_tex, cuv).rgb * shade, vm);
	vec4 pr = texture(print_tex, UV);
	jacket = mix(jacket, pr.rgb * shade, pr.a * print_on);
	col = mix(col, jacket, m.r);
	col = mix(col, shoes, m.b);
	float cloth = max(m.r, m.g);
	vec4 lp = texture(lampas_tex, UV);
	col = mix(col, lp.rgb * shade, lp.a * lampas_on * cloth);
	vec4 tp = texture(tape_tex, UV);
	col = mix(col, tp.rgb, tp.a * tape_on * cloth);
	// швы: край рукавов и ворота, пояс между курткой и штанами
	float seam = max(max(4.0 * m.r * (1.0 - m.r), 4.0 * m.g * (1.0 - m.g)), m.r * m.g);
	col *= 1.0 - 0.35 * clamp(seam, 0.0, 1.0);
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, max(max(m.r, m.g), m.b));
	// лента «светится» в свете фар и фонарей
	EMISSION = tp.rgb * tp.a * tape_on * cloth * 0.12;
}
