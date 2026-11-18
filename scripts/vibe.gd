extends Node3D
## Атмосфера города (только снаружи, дёшево для слабых устройств):
##  * осенью (сентябрь–ноябрь) вокруг игрока кружатся жёлтые и рыжие листья;
##  * из ларьков, с АЗС, со дворов и у ДК тихо играет радио — 3 ближайших источника, звук в пространстве;
##  * иногда вдалеке гудит поезд, ночью — лает собака;
##  * ночью один фонарь из девяти иногда мигает (main.gd спрашивает flicker()).
## main.gd вызывает update(focus, night, indoor, weather) каждый кадр.

const RADIO_RANGE := 45.0
const RADIOS := 3

var city: Node
var lite := false

var _leaves: CPUParticles3D
var _radios: Array[AudioStreamPlayer3D] = []
var _sources: Array = []        # [позиция, станция]
var _radio_t := 0.0
var _far_t := 40.0
var _rng := RandomNumberGenerator.new()
var _flicker := {}              # индекс фонаря -> до какого времени погашен


func setup() -> void:
    _rng.randomize()
    _build_leaves()
    for i in RADIOS:
        var p := AudioStreamPlayer3D.new()
        p.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
        p.unit_size = 4.0
        p.max_distance = RADIO_RANGE
        p.volume_db = -9.0
        p.attenuation_filter_cutoff_hz = 2200.0   # как из окна или маленького динамика
        p.attenuation_filter_db = -18.0
        add_child(p)
        _radios.append(p)
    if city == null:
        return
    var k := 0
    for g: Vector3 in city.gas_shops:
        _sources.append([g + Vector3(0, 1.5, 0), "radio_estrada" if k % 2 == 0 else "radio_mayak"])
        k += 1
    k = 0
    for w: Vector3 in city.workout_spots:
        if k % 3 == 0:     # не в каждом дворе: где-то окно открыто
            _sources.append([w + Vector3(4, 4.0, 0), ["radio_dvor", "radio_retro", "radio_rock"][(k / 3) % 3]])
        k += 1
    if city.dk.has("out"):
        _sources.append([city.dk["out"] + Vector3(0, 2.0, 0), "radio_disco"])
    if city.get("scooter_point") is Vector3:
        _sources.append([city.scooter_point + Vector3(0, 1.5, 0), "radio_synthwave"])
    if city.get("kassa_point") is Vector3:
        _sources.append([city.kassa_point + Vector3(0, 2.0, 0), "radio_march"])


func _build_leaves() -> void:
    _leaves = CPUParticles3D.new()
    _leaves.amount = 26 if lite else 60
    _leaves.lifetime = 7.0
    _leaves.preprocess = 4.0
    _leaves.local_coords = false
    _leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _leaves.emission_box_extents = Vector3(10, 3.5, 10)
    _leaves.direction = Vector3(1, -0.4, 0.3)
    _leaves.spread = 35.0
    _leaves.gravity = Vector3(0.6, -0.55, 0.2)
    _leaves.initial_velocity_min = 0.3
    _leaves.initial_velocity_max = 1.2
    _leaves.angular_velocity_min = -160.0
    _leaves.angular_velocity_max = 160.0
    _leaves.angle_min = 0.0
    _leaves.angle_max = 360.0
    _leaves.scale_amount_min = 0.7
    _leaves.scale_amount_max = 1.3
    var q := QuadMesh.new()
    q.size = Vector2(0.24, 0.24)
    var m := StandardMaterial3D.new()
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    m.alpha_scissor_threshold = 0.4
    m.vertex_color_use_as_albedo = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    if ResourceLoader.exists("res://textures/fx/leaf.png"):
        m.albedo_texture = load("res://textures/fx/leaf.png")
    q.material = m
    _leaves.mesh = q
    var g := Gradient.new()   # жёлтые, рыжие, бурые листья
    g.set_color(0, Color(0.95, 0.72, 0.18))
    g.set_color(1, Color(0.62, 0.28, 0.1))
    g.add_point(0.5, Color(0.88, 0.45, 0.12))
    _leaves.color_initial_ramp = g
    _leaves.emitting = false
    add_child(_leaves)


func update(focus: Vector3, night: float, indoor: bool, weather: String, delta: float) -> void:
    # листья: осенью, снаружи, не в снег и не в дождь
    var month := int(Time.get_date_dict_from_system()["month"])
    var autumn := month >= 9 and month <= 11
    _leaves.emitting = autumn and not indoor and weather != "snow" and weather != "rain"
    _leaves.global_position = focus + Vector3(0, 3.5, 0)
    # радио — три ближайших источника
    _radio_t -= delta
    if _radio_t <= 0.0:
        _radio_t = 1.0
        _update_radios(focus, indoor)
    # далёкие звуки города
    _far_t -= delta
    if _far_t <= 0.0 and not indoor:
        _far_t = _rng.randf_range(70.0, 160.0)
        var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
        if night > 0.5 and _rng.randf() < 0.4:
            Sfx.play_at("dog", focus + dir * 70.0, -12.0, _rng.randf_range(0.85, 1.1))
        else:
            Sfx.play_at("train_horn", focus + dir * 160.0, -10.0, _rng.randf_range(0.9, 1.05))


func _update_radios(focus: Vector3, indoor: bool) -> void:
    var near: Array = []
    if not indoor:
        for s: Array in _sources:
            var d := focus.distance_to(s[0])
            if d < RADIO_RANGE:
                near.append([d, s])
        near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
    for i in _radios.size():
        var p := _radios[i]
        if i >= near.size():
            if p.playing:
                p.stop()
            continue
        var src: Array = near[i][1]
        var path := "res://music/%s.ogg" % src[1]
        if p.get_meta("src", "") != str(src[0]) or not p.playing:
            p.set_meta("src", str(src[0]))
            p.global_position = src[0]
            if ResourceLoader.exists(path):
                var st: AudioStream = load(path)
                if st is AudioStreamOggVorbis:
                    (st as AudioStreamOggVorbis).loop = true
                p.stream = st
                # «в эфире»: у всех слушателей играет одно и то же место
                p.play(fmod(Time.get_unix_time_from_system(), maxf(1.0, st.get_length())))


## Мигает ли сейчас фонарь с этим номером (ночью у каждого девятого бывает).
func flicker(i: int, pos: Vector3) -> float:
    var h := absi(int(pos.x * 7.0 + pos.z * 13.0)) % 9
    if h != 0:
        return 1.0
    var now := Time.get_ticks_msec() / 1000.0
    if _flicker.get(i, 0.0) > now:
        return 0.08
    if _rng.randf() < 0.18:
        _flicker[i] = now + _rng.randf_range(0.08, 0.35)
        return 0.08
    return 1.0
