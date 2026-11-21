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
// готовая форма, запечённая в развёртку (scripts/outfits.gd): верх — куртка, низ — штаны и обувь
uniform sampler2D outfit_top : source_color, filter_linear_mipmap;
uniform sampler2D outfit_bottom : source_color, filter_linear_mipmap;
uniform float outfit_top_on = 0.0;
uniform float outfit_bottom_on = 0.0;
uniform float outfit_tint_mode = 0.0;   // 1 — перекрасить только светлое (полосы и надписи костюма «ОПГ»)
uniform float outfit_shoes_on = 0.0;
uniform vec4 outfit_tint = vec4(1.0, 1.0, 1.0, 0.0);   // перекраска (спортивные костюмы), a — сила
uniform float cloth_scale = 8.0;
uniform vec2 cloth_aspect = vec2(1.0);      // развёртка 2:1 (новая модель) — ткань без растяжения
uniform vec3 hair_col : source_color = vec3(0.18, 0.13, 0.09);
uniform float hair_on = 0.0;                // перекраска волос (канал A маски, новая модель)
// Покрой одежды (scripts/outfits.gd, по форме организации). В цвете вершин новой модели запечено:
// R — насколько выступают ягодицы, G — пах спереди, B — высота точки в позе покоя (доля роста).
uniform float shape_on = 0.0;               // 1 — у модели есть эти данные (human.gltf / human_f.gltf)
uniform float inflate_top = 0.008;          // толщина куртки, м (одежда не «нарисована» на коже)
uniform float inflate_bottom = 0.010;       // свободные брюки
uniform float butt_flat = 0.45;             // 0..1 — сгладить ягодицы под одеждой
uniform float crotch_fill = 0.6;            // 0..1 — ткань брюк закрывает пах
uniform float hem = 0.0;                    // низ куртки/кителя/халата (доля роста), 0 — по поясу
varying float rest_h;
varying float shape_w;   // ягодицы и пах: там складки кожи на ткани не рисуем

void vertex() {
	rest_h = COLOR.b;
	shape_w = shape_on > 0.5 ? clamp(max(COLOR.r * 1.6 + COLOR.g, COLOR.a), 0.0, 1.0) : 0.0;
	if (shape_on > 0.5) {
		vec3 mk = textureLod(mask_tex, UV, 0.0).rgb;
		float top = mk.r;
		float bottom = mk.g;
		// под длинным кителем или халатом бёдра и ягодицы — в ткани куртки, она толще
		float coat = (hem > 0.0 && rest_h > hem && rest_h < 0.6) ? bottom : 0.0;
		float push = top * inflate_top + bottom * inflate_bottom + coat * (inflate_top + 0.003);
		float cloth = clamp(top + bottom, 0.0, 1.0);
		push -= COLOR.r * 0.075 * butt_flat * cloth;             // ягодицы — внутрь, к линии поясницы
		push += COLOR.g * 0.014 * crotch_fill * bottom;          // пах — ровная ткань
		push += COLOR.a * (1.0 - COLOR.r) * 0.012 * butt_flat * cloth;   // ложбинку ткань перекрывает
		VERTEX += NORMAL * push;
	}
}

void fragment() {
	vec3 base = texture(body_tex, UV, shape_w * 3.0).rgb;
	vec4 mk = texture(mask_tex, UV);
	vec3 m = mk.rgb;
	base = mix(base, vec3(dot(base, vec3(0.333))) * hair_col * 2.4, mk.a * hair_on);
	m.r *= 1.0 - texture(sleeve_tex, UV).r * (1.0 - long_sleeves);
	// складки и объём одежды берём из яркости кожи под ней
	float shade = clamp(dot(base, vec3(0.333)) / 0.55, 0.65, 1.2);
	shade = mix(1.0, shade, 0.6);
	shade = mix(shade, 1.0, shape_w * 0.8 * max(mk.r, mk.g));   // ткань гладкая, а не «нарисована» по рельефу тела
	vec2 cuv = UV * cloth_scale * cloth_aspect;
	vec3 jacket = texture(jacket_tex, cuv).rgb * jacket_col * shade;
	vec3 pants = texture(pants_tex, cuv).rgb * pants_col * shade;
	vec3 shoes = texture(shoes_tex, cuv).rgb * shoes_col * shade;
	// готовый образ (весь персонаж: лицо, кожа, одежда): складки уже нарисованы, освещение — слабее
	float oshade = mix(1.0, shade, 0.35);
	// под длинным кителем/халатом (ниже пояса, выше hem) — ткань куртки: берём её со спины чуть ниже пояса
	float coat_f = (shape_on > 0.5 && hem > 0.0) ? smoothstep(hem - 0.004, hem + 0.004, rest_h) * (1.0 - step(0.6, rest_h)) * m.g : 0.0;
	vec4 ot = texture(outfit_top, mix(UV, vec2(UV.x, 0.66), step(0.5, coat_f)));
	vec4 ob = texture(outfit_bottom, UV, shape_w * 3.5);   // нарисованная ложбинка и складки на ягодицах — размыть
	base = mix(base, ot.rgb, outfit_top_on);
	vec3 otc = mix(ot.rgb, vec3(dot(ot.rgb, vec3(0.333))) * outfit_tint.rgb * 2.6, outfit_tint.a);
	vec3 obc = mix(ob.rgb, vec3(dot(ob.rgb, vec3(0.333))) * outfit_tint.rgb * 2.6, outfit_tint.a);
	if (outfit_tint_mode > 0.5) {
		float lt = dot(ot.rgb, vec3(0.333));
		float lb = dot(ob.rgb, vec3(0.333));
		otc = mix(ot.rgb, outfit_tint.rgb * (0.45 + 0.7 * lt), smoothstep(0.32, 0.55, lt) * outfit_tint.a);
		obc = mix(ob.rgb, outfit_tint.rgb * (0.45 + 0.7 * lb), smoothstep(0.32, 0.55, lb) * outfit_tint.a);
	}
	jacket = mix(jacket, otc * oshade, ot.a * outfit_top_on);
	pants = mix(pants, obc * oshade, ob.a * outfit_bottom_on);
	shoes = mix(shoes, ob.rgb * oshade, ob.a * outfit_shoes_on);
	vec3 col = base * skin_tint;
	col = mix(col, pants, m.g);
	// длинный китель / пиджак / халат закрывает ягодицы и бёдра до линии hem
	m.r = max(m.r, coat_f);
	m.g *= 1.0 - coat_f;
	float vm = texture(vest_mask, UV).r * vest_on;
	jacket = mix(jacket, texture(vest_tex, cuv).rgb * shade, vm);
	vec4 pr = texture(print_tex, UV);
	jacket = mix(jacket, pr.rgb * shade, pr.a * print_on * (1.0 - outfit_top_on));   // на готовой форме шевроны уже нарисованы
	col = mix(col, jacket, m.r);
	col = mix(col, shoes, m.b);
	float cloth = max(m.r, m.g);
	vec4 lp = texture(lampas_tex, UV);
	col = mix(col, lp.rgb * shade, lp.a * lampas_on * cloth * (1.0 - outfit_bottom_on));   // на готовой форме лампасы уже нарисованы
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
