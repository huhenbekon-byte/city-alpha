shader_type spatial;
// Голова персонажа: спереди — лицо с картинки (textures/face.png), остальное — кожа.
// Цвет кожи меняется в магазине, лицо подкрашивается под него.

uniform sampler2D face_tex : source_color, filter_linear_mipmap;
uniform vec3 skin : source_color = vec3(0.87, 0.68, 0.55);
uniform vec3 base_skin : source_color = vec3(0.87, 0.68, 0.55);
varying vec3 lpos;

void vertex() {
    lpos = VERTEX;
}

void fragment() {
    vec3 n = normalize(lpos);
    float front = smoothstep(0.45, 0.8, -n.z);          // перед лица смотрит в -Z
    vec2 uv = vec2(0.5 - lpos.x * 5.8, 0.37 - lpos.y * 4.5);
    float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
    vec3 f = texture(face_tex, uv).rgb * (skin / base_skin);
    ALBEDO = mix(skin, f, front * inside);
    ROUGHNESS = 0.7;
}
