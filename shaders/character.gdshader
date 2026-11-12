shader_type spatial;
// Персонаж Quaternius: кожа из текстуры, а куртка, штаны и обувь — по маске
// (R — куртка, G — штаны, B — обувь) в цвет и ткань, купленные на рынке.

uniform sampler2D body_tex : source_color, filter_linear_mipmap;
uniform sampler2D mask_tex : filter_linear;
uniform sampler2D jacket_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pants_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D shoes_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 jacket_col = vec3(0.09, 0.42, 0.52);
uniform vec3 pants_col = vec3(0.17, 0.24, 0.38);
uniform vec3 shoes_col = vec3(0.96, 0.96, 0.96);
uniform vec3 skin_tint = vec3(1.0);
uniform float cloth_scale = 8.0;

void fragment() {
	vec3 base = texture(body_tex, UV).rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	// складки и объём одежды берём из яркости кожи под ней
	float shade = clamp(dot(base, vec3(0.333)) / 0.55, 0.65, 1.2);
	shade = mix(1.0, shade, 0.6);
	vec2 cuv = UV * cloth_scale;
	vec3 jacket = texture(jacket_tex, cuv).rgb * jacket_col * shade;
	vec3 pants = texture(pants_tex, cuv).rgb * pants_col * shade;
	vec3 shoes = texture(shoes_tex, cuv).rgb * shoes_col * shade;
	vec3 col = base * skin_tint;
	col = mix(col, pants, m.g);
	col = mix(col, jacket, m.r);
	col = mix(col, shoes, m.b);
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, max(max(m.r, m.g), m.b));
}
