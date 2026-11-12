extends VehicleBody3D
## Машина, на которой можно ездить. Физика — VehicleBody3D (подвеска на лучах),
## задний привод, передние колёса рулевые. Своя камера сзади.

const CarModel := preload("res://scripts/car_model.gd")

@export var paint := Color(0.92, 0.92, 0.90)
@export var max_engine_force := 5000.0
@export var max_speed_kmh := 120.0
@export var reverse_speed_kmh := 30.0
@export var brake_force := 30.0
@export var max_steer := 0.55
@export var look_sensitivity := 0.006
@export var kind := "car"   # "car", "bus", "truck"
@export var car_name := "Классика"
@export var price := 8000
## Фракционная раскраска: надпись и полоса по бортам, мигалки на крыше.
@export var livery_text := ""
@export var livery_color := Color(0.15, 0.30, 0.70)
@export var has_lights := false
@export var light_a := Color(1.0, 0.12, 0.10)
@export var light_b := Color(0.15, 0.35, 1.0)

## Куплена ли машина. Чужую (с рынка, не купленную) водить нельзя.
var owned := false

## Бензин. uses_fuel = false у рабочих машин (автобус, фура, учебная).
var tank := 40.0
var fuel := 40.0
var uses_fuel := true
var _range_m := 6000.0     # на сколько метров хватает полного бака
var _last_pos := Vector3.ZERO
var _price_label: Label3D
var _headlight: SpotLight3D
var _night := false

## TouchControls (задаёт main.gd). Пусто — только клавиатура.
var touch = null
var driven := false

var _rear: Array[VehicleWheel3D] = []
var _cam_yaw: Node3D
var _cam_pitch: Node3D
var _camera: Camera3D
var _look_timer := 0.0
var _flip_timer := 0.0
var _tail_mat: StandardMaterial3D
var _spawn := Transform3D()
var _lamp_a: StandardMaterial3D = null
var _lamp_b: StandardMaterial3D = null
var _flash_t := 0.0

# Звук мотора синтезируется прямо в коде (без аудиофайлов).
const MIX_RATE := 22050.0
var _audio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _filt := 0.0
var _rpm := 0.0


func _ready() -> void:
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    match kind:
        "bus":
            mass = 6000.0
            center_of_mass = Vector3(0, 0.9, 0)
        "truck":
            mass = 7000.0
            center_of_mass = Vector3(0, 0.9, 0.5)
        _:
            mass = 1150.0
            center_of_mass = Vector3(0, 0.35, 0.1)  # низкий центр масс — меньше переворотов
    _spawn = global_transform
    _last_pos = global_position

    CarModel.add_collision(self, kind)
    _tail_mat = CarModel.make_tail_material()
    var body_mi := MeshInstance3D.new()
    body_mi.mesh = CarModel.body_mesh(paint, _tail_mat, kind)
    add_child(body_mi)

    for spot: Array in CarModel.wheel_spots(kind):
        _add_wheel(spot[0], spot[1])

    _build_livery()
    _setup_camera()
    _setup_audio()

    _price_label = Label3D.new()
    _price_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _price_label.font_size = 64
    _price_label.pixel_size = 0.006
    _price_label.outline_size = 14
    _price_label.position.y = 2.4
    add_child(_price_label)
    set_owned(owned)

    # Фары — настоящий свет, только у машины, которой управляет игрок, и только ночью.
    _headlight = SpotLight3D.new()
    _headlight.position = Vector3(0, 0.85, 2.1)
    _headlight.rotation = Vector3(-0.12, PI, 0.0)  # SpotLight светит в -Z, а перед машины — +Z
    _headlight.spot_range = 38.0
    _headlight.spot_angle = 34.0
    _headlight.light_energy = 1.6
    _headlight.light_color = Color(1.0, 0.95, 0.82)
    _headlight.shadow_enabled = false
    _headlight.visible = false
    add_child(_headlight)


func set_night(on: bool) -> void:
    _night = on
    _headlight.visible = on and driven


## Некупленная машина спрятана и выключена (её «нет в городе»).
func set_available(on: bool) -> void:
    visible = on
    process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func set_owned(value: bool) -> void:
    owned = value
    _price_label.visible = not owned
    _price_label.text = "%s\n%d %03d ₽\n%d км/ч" % [car_name, price / 1000, price % 1000, int(max_speed_kmh)]


func _add_wheel(pos: Vector3, front: bool) -> void:
    var w := VehicleWheel3D.new()
    w.position = pos
    w.use_as_steering = front
    w.use_as_traction = not front
    var r := CarModel.wheel_radius(kind)
    w.wheel_radius = r
    w.wheel_rest_length = 0.12
    w.suspension_travel = 0.18
    w.suspension_stiffness = 40.0
    w.suspension_max_force = mass * 12.0
    w.damping_compression = 1.8
    w.damping_relaxation = 2.6
    w.wheel_friction_slip = 3.0 if front else 2.7
    w.wheel_roll_influence = 0.05
    add_child(w)
    var mi := MeshInstance3D.new()
    mi.mesh = CarModel.wheel_mesh()
    mi.scale = Vector3.ONE * (r / CarModel.WHEEL_RADIUS)
    w.add_child(mi)
    if not front:
        _rear.append(w)


# ---------------------------------------------------------------- водитель

func set_driven(on: bool) -> void:
    driven = on
    if on:
        sleeping = false
        _cam_yaw.rotation.y = _heading_yaw() + PI
        _cam_pitch.rotation.x = -0.22
        _look_timer = 0.0
        _cam_yaw.global_position = global_position + Vector3(0, 1.5 if kind == "car" else 3.0, 0)
        _camera.make_current()
        _audio.play()
        _playback = _audio.get_stream_playback()
        _headlight.visible = _night
    else:
        engine_force = 0.0
        steering = 0.0
        _audio.stop()
        _playback = null
        _headlight.visible = false


## Поставить машину в точку (сброс прогресса, загрузка).
func reset_to(t: Transform3D) -> void:
    if driven:
        set_driven(false)
    global_transform = t
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _spawn = t


## Куда поставить игрока при выходе: слева (водительская дверь), если занято — справа.
func get_exit_position() -> Vector3:
    var space := get_world_3d().direct_space_state
    var basis_now := global_transform.basis
    var from := global_position + Vector3.UP * 0.9
    for side: float in [1.0, -1.0]:
        var half := 1.25 if kind != "car" else 0.8
        var target := global_position + basis_now.x * ((half + 0.9) * side)
        var q := PhysicsRayQueryParameters3D.create(from, target + Vector3.UP * 0.9)
        q.exclude = [get_rid()]
        if space.intersect_ray(q).is_empty():
            return target + Vector3.UP * 0.2
    return global_position + Vector3.UP * 2.2


func get_camera_yaw() -> float:
    return _cam_yaw.rotation.y


func speed_kmh() -> float:
    return linear_velocity.dot(global_transform.basis.z) * 3.6


func look(relative: Vector2) -> void:
    _cam_yaw.rotation.y -= relative.x * look_sensitivity
    _cam_pitch.rotation.x = clampf(_cam_pitch.rotation.x - relative.y * look_sensitivity, -1.0, 0.3)
    _look_timer = 1.5


# ---------------------------------------------------------------- физика

func _physics_process(delta: float) -> void:
    var basis_now := global_transform.basis
    var fwd_speed := linear_velocity.dot(basis_now.z)
    var kmh := absf(fwd_speed) * 3.6

    var throttle := 0.0
    var steer_in := 0.0
    var hand := false
    if driven:
        throttle = Input.get_axis("move_back", "move_forward")
        steer_in = Input.get_axis("move_right", "move_left")  # +1 = влево
        hand = Input.is_action_pressed("jump")
        if touch:
            if touch.gas:
                throttle = 1.0
            elif touch.brake:
                throttle = -1.0
            var jx: float = touch.joy_vector.x
            if absf(jx) > 0.05:
                steer_in = -jx

    var eng := 0.0
    var brk := 0.0
    if not driven:
        brk = 4.0                      # стоит на ручнике
    elif throttle > 0.05:
        if fwd_speed < -1.0:
            brk = brake_force * throttle
        elif kmh < max_speed_kmh:
            eng = max_engine_force * throttle
    elif throttle < -0.05:
        if fwd_speed > 1.0:
            brk = brake_force * -throttle
        elif kmh < reverse_speed_kmh:
            eng = max_engine_force * 0.6 * throttle  # задний ход
    else:
        brk = 1.0                      # торможение двигателем

    # Бензин тратится с пройденным расстоянием; пустой бак — мотор не тянет.
    var moved := global_position.distance_to(_last_pos)
    _last_pos = global_position
    if driven and uses_fuel and moved < 5.0:
        fuel = maxf(0.0, fuel - moved * tank / _range_m)
    if uses_fuel and fuel <= 0.0:
        eng = 0.0

    engine_force = eng
    brake = brk
    for w in _rear:
        w.wheel_friction_slip = 1.3 if hand else 2.7
        if hand:
            w.brake = brake_force

    # На скорости руль поворачивается меньше — машина устойчивее.
    var steer_limit := lerpf(max_steer, 0.16, clampf(kmh / 110.0, 0.0, 1.0))
    steering = move_toward(steering, steer_in * steer_limit, 2.2 * delta)

    _tail_mat.emission_energy_multiplier = 2.5 if (driven and brk > 2.0) else 0.3

    # Перевернулась — через 1.5 с ставим на колёса.
    if driven and basis_now.y.y < 0.35 and linear_velocity.length() < 2.0:
        _flip_timer += delta
        if _flip_timer > 1.5:
            _put_upright()
    else:
        _flip_timer = 0.0
    if global_position.y < -30.0:
        _put_upright()


func _put_upright() -> void:
    _flip_timer = 0.0
    var pos := global_position + Vector3.UP
    if pos.y < -20.0:
        pos = _spawn.origin + Vector3.UP
    global_transform = Transform3D(Basis(Vector3.UP, _heading_yaw()), pos)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


func _heading_yaw() -> float:
    var f := global_transform.basis.z
    return atan2(f.x, f.z)


# ---------------------------------------------------------------- камера

func _setup_camera() -> void:
    _cam_yaw = Node3D.new()
    _cam_yaw.top_level = true  # не крутится вместе с кузовом
    add_child(_cam_yaw)

    _cam_pitch = Node3D.new()
    _cam_pitch.rotation.x = -0.22
    _cam_yaw.add_child(_cam_pitch)

    var spring := SpringArm3D.new()
    spring.spring_length = 6.5 if kind == "car" else 11.0
    spring.margin = 0.3
    var probe := SphereShape3D.new()
    probe.radius = 0.3
    spring.shape = probe
    spring.add_excluded_object(get_rid())
    _cam_pitch.add_child(spring)

    _camera = Camera3D.new()
    _camera.fov = 72.0
    _camera.near = 0.05
    _camera.add_to_group("game_camera")
    spring.add_child(_camera)


func _process(delta: float) -> void:
    if _lamp_a != null:
        _update_flashers(delta)
    if not driven:
        return
    if _playback:
        _fill_engine_sound()
    _cam_yaw.global_position = global_position + Vector3(0, 1.5 if kind == "car" else 3.0, 0)
    _look_timer -= delta
    # Если игрок не крутит камеру — она плавно встаёт за машину.
    if _look_timer <= 0.0 and linear_velocity.length() > 1.0:
        var target := _heading_yaw() + PI
        _cam_yaw.rotation.y = lerp_angle(_cam_yaw.rotation.y, target, 1.0 - exp(-3.0 * delta))


# ---------------------------------------------------------------- звук мотора

func _setup_audio() -> void:
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = MIX_RATE
    gen.buffer_length = 0.12
    _audio = AudioStreamPlayer.new()
    _audio.stream = gen
    _audio.volume_db = -10.0
    add_child(_audio)


func _fill_engine_sound() -> void:
    var kmh := absf(speed_kmh())
    # Имитация передач: обороты растут внутри передачи и падают при «переключении».
    var in_gear := fmod(kmh, 32.0) / 32.0 if kmh > 3.0 else 0.0
    var target := 0.12 + in_gear * 0.75 + (0.12 if absf(engine_force) > 0.0 else 0.0)
    _rpm = lerpf(_rpm, target, 0.08)
    var inc := (30.0 + _rpm * 100.0) / MIX_RATE
    var amp := 0.16 + _rpm * 0.14 + (0.06 if absf(engine_force) > 0.0 else 0.0)
    var n := _playback.get_frames_available()
    if n <= 0:
        return
    var buf := PackedVector2Array()
    buf.resize(n)
    for i in n:
        _phase = fmod(_phase + inc, 1.0)
        var saw := _phase * 2.0 - 1.0
        var pulse := 1.0 if _phase < 0.3 else -0.45
        _filt += ((saw * 0.5 + pulse * 0.5) * amp - _filt) * 0.22  # мягкий фильтр
        buf[i] = Vector2(_filt, _filt)
    _playback.push_buffer(buf)


# ---------------------------------------------------------------- раскраска и мигалки

func _build_livery() -> void:
    if livery_text == "" and not has_lights:
        return
    # [полуширина борта, высота надписи, высота полосы, толщина полосы, длина, центр по Z, кегль]
    var w := 0.82
    var ty := 0.74
    var sy := 0.50
    var sh := 0.12
    var ln := 3.4
    var lz := 0.0
    var fs := 64
    match kind:
        "bus":
            w = 1.27
            ty = 1.30
            sy = 0.85
            sh = 0.25
            ln = 9.4
            fs = 110
        "truck":
            w = 1.27
            ty = 2.35
            sy = 1.45
            sh = 0.30
            ln = 6.0
            lz = -1.1
            fs = 130
    if livery_text != "":
        var sm := StandardMaterial3D.new()
        sm.albedo_color = livery_color
        sm.roughness = 0.5
        var bm := BoxMesh.new()
        bm.size = Vector3(0.02, sh, ln)
        for side: float in [1.0, -1.0]:
            var stripe := MeshInstance3D.new()
            stripe.mesh = bm
            stripe.material_override = sm
            stripe.position = Vector3(w * side, sy, lz)
            add_child(stripe)
            var l := Label3D.new()
            l.text = livery_text
            l.font_size = fs
            l.pixel_size = 0.004
            l.modulate = livery_color
            l.outline_size = 0
            l.double_sided = false
            l.position = Vector3((w + 0.025) * side, ty, lz)
            l.rotation.y = PI * 0.5 * side
            add_child(l)
    if has_lights:
        var ly := 1.47
        var bz := -0.15
        var span := 0.32
        match kind:
            "bus":
                ly = 3.26
                bz = 4.3
                span = 0.6
            "truck":
                ly = 3.0
                bz = 3.5
                span = 0.55
        var base := MeshInstance3D.new()
        var bb := BoxMesh.new()
        bb.size = Vector3(span * 2.0 + 0.3, 0.06, 0.28)
        base.mesh = bb
        var bmat := StandardMaterial3D.new()
        bmat.albedo_color = Color(0.1, 0.1, 0.11)
        base.material_override = bmat
        base.position = Vector3(0, ly - 0.04, bz)
        add_child(base)
        _lamp_a = _lamp_mat(light_a)
        _lamp_b = _lamp_mat(light_b)
        var lm := BoxMesh.new()
        lm.size = Vector3(span, 0.14, 0.24)
        for k in 2:
            var mi := MeshInstance3D.new()
            mi.mesh = lm
            mi.material_override = _lamp_a if k == 0 else _lamp_b
            mi.position = Vector3(span * 0.5 * (1.0 if k == 0 else -1.0), ly + 0.06, bz)
            add_child(mi)


func _lamp_mat(col: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col.darkened(0.3)
    m.emission_enabled = true
    m.emission = col
    m.emission_energy_multiplier = 0.2
    return m


## Мигалки работают, пока в машине водитель.
func _update_flashers(delta: float) -> void:
    if not driven:
        if _flash_t != 0.0:
            _flash_t = 0.0
            _lamp_a.emission_energy_multiplier = 0.2
            _lamp_b.emission_energy_multiplier = 0.2
        return
    _flash_t += delta
    var strobe := fmod(_flash_t * 10.0, 1.0) < 0.5     # частое «моргание»
    var first := fmod(_flash_t, 0.8) < 0.4              # половина времени — один цвет
    _lamp_a.emission_energy_multiplier = 5.0 if first and strobe else 0.2
    _lamp_b.emission_energy_multiplier = 5.0 if not first and strobe else 0.2
