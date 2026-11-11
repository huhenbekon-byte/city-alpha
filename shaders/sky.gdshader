shader_type sky;
// Небо со сменой дня и ночи: градиент + облака из картинки (textures/sky_clouds.png)
// + солнце + звёзды ночью. Цвета задаёт main.gd в _update_daylight().

uniform vec3 top_color : source_color = vec3(0.30, 0.50, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.76, 0.82, 0.88);
uniform vec3 ground_color : source_color = vec3(0.25, 0.26, 0.24);
uniform vec3 cloud_light : source_color = vec3(1.0);
uniform vec3 cloud_dark : source_color = vec3(0.62, 0.66, 0.74);
uniform float cloud_alpha = 1.0;
uniform float stars = 0.0;
uniform float drift = 0.0;
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_strength = 1.0;
uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;

void sky() {
    vec3 d = normalize(EYEDIR);
    float e = d.y;
    vec3 col;
    if (e >= 0.0) {
        col = mix(horizon_color, top_color, pow(clamp(e, 0.0, 1.0), 0.55));
        // солнце
        float sd = dot(d, normalize(sun_dir));
        col += sun_color * sun_strength * (smoothstep(0.9990, 0.9996, sd) + pow(max(sd, 0.0), 64.0) * 0.25);
        // звёзды
        float el = asin(clamp(e, 0.0, 1.0));
        float u = atan(d.x, d.z) / TAU + 0.5;
        float v = 1.0 - el / (PI * 0.5);
        if (stars > 0.001) {
            vec2 g = floor(vec2(u * 1400.0, v * 400.0));
            float h = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
            col += vec3(step(0.9975, h)) * stars * smoothstep(0.05, 0.3, e);
        }
        // облака
        vec4 c = texture(clouds, vec2(u + drift, v));
        float a = c.a * cloud_alpha * smoothstep(0.0, 0.06, e);
        col = mix(col, mix(cloud_dark, cloud_light, c.r), a);
    } else {
        col = mix(horizon_color, ground_color, clamp(-e * 4.0, 0.0, 1.0));
    }
    COLOR = col;
}
