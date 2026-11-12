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
@export var kind := "car"   # "car", "bus", "truck", "moto"
## Готовая 3D-модель из models/cars ("vaz2106", "sedan", "uaz452"...). Пусто — своя модель из кода.
@export var model_id := ""
@export var car_name := "Классика"
@export var price := 8000
## Фракционная раскраска: надпись и полоса по бортам, мигалки на крыше.
@export var livery_text := ""
@export var livery_color := Color(0.15, 0.30, 0.70)
@export var has_lights := false
@export var light_a := Color(1.0, 0.12, 0.10)
@export var light_b := Color(0.15, 0.35, 1.0)

## Сцепление с дорогой у всех машин (дождь, снег — меньше). Задаёт main.gd.
static var grip := 1.0
const FRONT_GRIP := 2.6
const REAR_GRIP := 2.5

## Куплена ли машина. Чужую (с рынка, не купленную) водить нельзя.
var owned := false
## Состояние 0..100: аварии портят машину, ремонт — на СТО.
var condition := 100.0
## Тюнинг: тонировка, цвет дисков (пусто — обычные), номер.
var tint := false
var rim_color := Color(0, 0, 0, 0)
var plate_text := ""
var rider_color := Color(0.09, 0.42, 0.52)
var _body_mi: MeshInstance3D
var _wheel_mis: Array[MeshInstance3D] = []
var _all_wheels: Array[VehicleWheel3D] = []
var _plates: Array[Label3D] = []
var _smoke: CPUParticles3D = null
var _rider: Node3D = null
var _model_info := {}
var _paint_surfaces: Array[int] = []

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
var siren_on := false            # сирена (у машин с мигалками, кнопка «БИП» включает/выключает)
var _siren: AudioStreamPlayer = null

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
        "moto":
            mass = 260.0
            center_of_mass = Vector3(0, 0.15, 0)
            tank = 15.0
            fuel = minf(fuel, tank)
        "bus":
            mass = 6000.0
            center_of_mass = Vector3(0, 0.55, 0)
        "truck":
            mass = 7000.0
            center_of_mass = Vector3(0, 0.55, 0.5)
        _:
            mass = 1150.0
            center_of_mass = Vector3(0, 0.12, 0.0)  # центр масс почти у земли — машина не кувыркается
    angular_damp = 0.8   # кузов не раскручивается волчком
    linear_damp = 0.03
    _spawn = global_transform
    _last_pos = global_position

    CarModel.add_collision(self, kind)
    _tail_mat = CarModel.make_tail_material()
    _model_info = CarModel.model_info(model_id) if kind == "car" else {}
    if not _model_info.is_empty():
        _setup_model()
    else:
        _body_mi = MeshInstance3D.new()
        _body_mi.mesh = CarModel.body_mesh(paint, _tail_mat, kind)
        add_child(_body_mi)
        for spot: Array in CarModel.wheel_spots(kind):
            _add_wheel(spot[0], spot[1])

    _build_livery()
    if kind == "car":
        var plates: Dictionary = _model_info.get("plates", {})
        for sz: float in [1.0, -1.0]:
            var l := Label3D.new()
            l.font_size = 30
            l.pixel_size = 0.0032
            l.modulate = Color(0.05, 0.05, 0.08)
            l.outline_size = 0
            l.double_sided = false
            l.position = Vector3(0, 0.455, 2.1 * sz + 0.004 * sz)
            var key := "PlateF" if sz > 0.0 else "PlateR"
            if plates.has(key):
                l.position = plates[key] + Vector3(0, 0, 0.03 * sz)
            elif not _model_info.is_empty():
                l.visible = false   # у модели нет места под номер
            l.rotation.y = 0.0 if sz > 0.0 else PI
            add_child(l)
            _plates.append(l)
    if kind == "moto":
        _build_rider()
    apply_tuning()
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


func _add_wheel(pos: Vector3, front: bool, model_wheel: Mesh = null, model_r := 0.0, model_basis := Basis()) -> void:
    var w := VehicleWheel3D.new()
    w.position = pos
    w.use_as_steering = front
    # легковые — полный привод (стабильнее на поворотах, не уходит в занос от газа)
    w.use_as_traction = (not front) or kind == "car"
    var r := model_r if model_wheel != null else CarModel.wheel_radius(kind)
    w.wheel_radius = r
    w.wheel_rest_length = 0.12
    w.suspension_travel = 0.16
    w.suspension_stiffness = 34.0 if kind != "moto" else 40.0
    w.suspension_max_force = mass * 14.0
    w.damping_compression = 2.2
    w.damping_relaxation = 3.2
    w.wheel_friction_slip = FRONT_GRIP if front else REAR_GRIP
    w.wheel_roll_influence = 0.0 if kind == "moto" else 0.02   # меньше крена — меньше переворотов
    add_child(w)
    _all_wheels.append(w)
    var mi := MeshInstance3D.new()
    if model_wheel != null:
        mi.mesh = model_wheel
        mi.basis = model_basis   # правые колёса — то же колесо, развёрнутое на 180°
    else:
        mi.mesh = CarModel.wheel_mesh()
        mi.scale = Vector3.ONE * (r / CarModel.WHEEL_RADIUS)
    w.add_child(mi)
    _wheel_mis.append(mi)
    if not front:
        _rear.append(w)


# ---------------------------------------------------------------- водитель

func set_driven(on: bool) -> void:
    driven = on
    if _rider:
        _rider.visible = on
    if on:
        sleeping = false
        _cam_yaw.rotation.y = _heading_yaw() + PI
        _cam_pitch.rotation.x = -0.22
        _look_timer = 0.0
        _cam_yaw.global_position = global_position + Vector3(0, _cam_h(), 0)
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
        elif kmh < max_speed_kmh * (0.55 if condition < 30.0 else 1.0):
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
    if condition <= 0.0:
        eng = 0.0
    if kind == "car":
        eng *= 0.5                       # сила делится на 4 ведущих колеса, а не на 2
        if kmh < 20.0 and absf(steering) > 0.3:
            eng *= 0.7                   # «антипробуксовка» в крутом повороте с места

    engine_force = eng
    brake = brk
    for w in _all_wheels:
        if w.use_as_steering:
            w.wheel_friction_slip = FRONT_GRIP * grip
    for w in _rear:
        w.wheel_friction_slip = (1.0 if hand else REAR_GRIP) * grip
        w.brake = brake_force if hand else 0.0
    if kind == "moto":
        # мотоцикл держится вертикально: «гироскоп» гасит крен
        var up := basis_now.y
        var fwd := basis_now.z
        var roll := up.cross(Vector3.UP).dot(fwd)
        apply_torque(fwd * roll * mass * 40.0 - fwd * angular_velocity.dot(fwd) * mass * 6.0)

    # На скорости руль поворачивается меньше — машина устойчивее.
    var steer_limit := lerpf(max_steer, 0.09 if kind == "car" else 0.12, clampf(kmh / 100.0, 0.0, 1.0))
    var steer_target := steer_in * steer_limit
    # к центру руль возвращается быстрее, чем поворачивается
    var steer_rate := 1.6 if absf(steer_target) > absf(steering) else 3.2
    steering = move_toward(steering, steer_target, steer_rate * delta)

    if kind != "moto":
        _stabilize(basis_now, fwd_speed, hand, delta)

    _tail_mat.emission_energy_multiplier = 2.5 if (driven and brk > 2.0) else 0.3
    _update_fx(hand, kmh, throttle, absf(linear_velocity.dot(basis_now.x)))

    # Перевернулась — через 1.5 с ставим на колёса.
    if driven and basis_now.y.y < 0.45 and linear_velocity.length() < 3.0:
        _flip_timer += delta
        if _flip_timer > 1.0:
            _put_upright()
    else:
        _flip_timer = 0.0
    if global_position.y < -30.0:
        _put_upright()


## Помощь водителю, как в аркадных гонках: держим машину на колёсах и не даём ей
## вертеться волчком. Настоящая физика остаётся, но без «кувырков» на ровном месте.
func _stabilize(b: Basis, fwd_speed: float, hand: bool, _delta: float) -> void:
    var grounded := false
    for w in _all_wheels:
        if w.is_in_contact():
            grounded = true
            break
    var up := b.y
    var fwd := b.z
    var side := b.x
    # 1. Крен и тангаж: мягко возвращаем кузов горизонтально (в воздухе — сильнее)
    var k := 6.0 if grounded else 10.0
    var roll := up.cross(Vector3.UP).dot(fwd)
    var pitch := up.cross(Vector3.UP).dot(side)
    var roll_rate := angular_velocity.dot(fwd)
    var pitch_rate := angular_velocity.dot(side)
    apply_torque((fwd * (roll * k - roll_rate * 1.5) + side * (pitch * k * 0.5 - pitch_rate * 1.0)) * mass)
    if not grounded:
        return
    var v := absf(fwd_speed)
    # 2. Прижимная сила на скорости
    apply_central_force(-up * mass * minf(v * v * 0.004, 6.0))
    # 3. Боковое сцепление: гасим занос (кроме ручника)
    if not hand:
        var lat := linear_velocity.dot(side)
        apply_central_force(-side * lat * mass * 2.2)
    # 4. Поворот не быстрее, чем позволяет скорость (не крутится на месте)
    var max_yaw := 0.25 + v * (0.32 if not hand else 0.6)
    var yaw := angular_velocity.dot(up)
    if absf(yaw) > max_yaw:
        angular_velocity -= up * (yaw - signf(yaw) * max_yaw)


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
    spring.spring_length = 6.5 if kind == "car" else (5.0 if kind == "moto" else 11.0)
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
    _cam_yaw.global_position = global_position + Vector3(0, _cam_h(), 0)
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
    if _model_info.has("side"):   # у готовой модели — по её борту
        var sd: Vector3 = _model_info["side"]
        w = sd.x + 0.01
        ty = sd.y + 0.04
        sy = sd.y - 0.18
        ln = 3.0 if sd.y < 0.9 else 3.6
        fs = 64 if sd.y < 0.9 else 84
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
        if _model_info.has("roof"):
            var rf: Vector3 = _model_info["roof"]
            ly = rf.y + 0.04
            bz = rf.z
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
func toggle_siren() -> void:
    siren_on = not siren_on
    if _siren == null:
        _siren = AudioStreamPlayer.new()
        _siren.stream = Sfx.get_sound("siren")
        _siren.volume_db = -12.0
        add_child(_siren)
    if not siren_on:
        _siren.stop()


func _update_flashers(delta: float) -> void:
    if _siren != null:
        if siren_on and driven and _siren.stream != null:
            if not _siren.playing:
                _siren.play()
        elif _siren.playing:
            _siren.stop()
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



func _cam_h() -> float:
    return 1.5 if kind == "car" or kind == "moto" else 3.0


# ---------------------------------------------------------------- тюнинг и поломки

## Перекрасить (меш кузова собирается заново).
func repaint(col: Color) -> void:
    paint = col
    if not _model_info.is_empty():
        for i in _paint_surfaces:
            _body_mi.set_surface_override_material(i, CarModel.paint_material(_body_mi.mesh.surface_get_material(i), paint))
        return
    _body_mi.mesh = CarModel.body_mesh(paint, _tail_mat, kind)
    apply_tuning()


## Тонировка, цвет дисков, номер — после покупки, загрузки или тюнинга на СТО.
func apply_tuning() -> void:
    var glass := CarModel.glass_material()
    var tinted := StandardMaterial3D.new()
    tinted.albedo_color = Color(0.02, 0.02, 0.03)
    tinted.roughness = 0.05
    tinted.metallic = 0.7
    tinted.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mesh := _body_mi.mesh
    for i in mesh.get_surface_count():
        var sm := mesh.surface_get_material(i)
        if sm == glass or (sm and String(sm.resource_name) == "Glass"):
            _body_mi.set_surface_override_material(i, tinted if tint else null)
    var rim := CarModel.rim_material()
    var custom: StandardMaterial3D = null
    if rim_color.a > 0.0:
        custom = StandardMaterial3D.new()
        custom.albedo_color = rim_color
        custom.metallic = 0.85
        custom.roughness = 0.25
        custom.cull_mode = BaseMaterial3D.CULL_DISABLED
    for mi in _wheel_mis:
        for i in mi.mesh.get_surface_count():
            var wm := mi.mesh.surface_get_material(i)
            if wm == rim or (wm and String(wm.resource_name) in ["Rim", "M_Grey"]):
                mi.set_surface_override_material(i, custom)
    for l in _plates:
        l.text = plate_text


## Удар: машина портится. Возвращает true, если сломалась совсем.
func damage(amount: float) -> bool:
    condition = maxf(0.0, condition - amount)
    _update_smoke()
    return condition <= 0.0


func repair() -> void:
    condition = 100.0
    _update_smoke()


func _update_smoke() -> void:
    if condition >= 30.0:
        if _smoke:
            _smoke.emitting = false
        return
    if _smoke == null:
        _smoke = CPUParticles3D.new()
        _smoke.amount = 16
        _smoke.lifetime = 1.6
        _smoke.direction = Vector3.UP
        _smoke.spread = 25.0
        _smoke.gravity = Vector3(0, 1.0, 0)
        _smoke.initial_velocity_min = 0.8
        _smoke.initial_velocity_max = 1.6
        _smoke.scale_amount_min = 0.6
        _smoke.scale_amount_max = 1.4
        var q := QuadMesh.new()
        q.size = Vector2(0.9, 0.9)
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.vertex_color_use_as_albedo = true
        if ResourceLoader.exists("res://textures/fx/smoke_light.png"):
            m.albedo_texture = load("res://textures/fx/smoke_light.png")
        q.material = m
        _smoke.mesh = q
        var g := Gradient.new()
        g.set_color(0, Color(0.7, 0.7, 0.7, 0.7))
        g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
        _smoke.color_ramp = g
        _smoke.position = Vector3(0, 1.0, 1.5) if kind == "car" else Vector3(0, 1.0, 0.5)
        add_child(_smoke)
    _smoke.emitting = true
    _smoke.color_ramp.set_color(0, Color(0.15, 0.15, 0.15, 0.8) if condition <= 0.0 else Color(0.7, 0.7, 0.7, 0.7))


## Мотоциклист: виден, только пока игрок за рулём.
func _build_rider() -> void:
    _rider = Node3D.new()
    add_child(_rider)
    var m := StandardMaterial3D.new()
    m.albedo_color = rider_color
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.2
    cap.height = 0.8
    body.mesh = cap
    body.material_override = m
    body.position = Vector3(0, 1.2, -0.15)
    body.rotation.x = 0.35
    _rider.add_child(body)
    var head := MeshInstance3D.new()
    var sph := SphereMesh.new()
    sph.radius = 0.15
    sph.height = 0.3
    head.mesh = sph
    var hm := StandardMaterial3D.new()
    hm.albedo_color = Color(0.1, 0.1, 0.12)   # шлем
    head.material_override = hm
    head.position = Vector3(0, 1.68, 0.02)
    _rider.add_child(head)
    _rider.visible = false


func set_rider_color(col: Color) -> void:
    rider_color = col
    if _rider:
        var body: MeshInstance3D = _rider.get_child(0)
        (body.material_override as StandardMaterial3D).albedo_color = col



## Готовая модель: кузов (с покраской и стоп-сигналами) и 4 колеса на своих местах.
func _setup_model() -> void:
    var root := CarModel.model_instance(model_id)
    var wheels: Dictionary = _model_info["wheels"]
    var r: float = _model_info["radius"]
    for n: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        var nm := String(mi.name)
        if nm == "Body":
            _body_mi = MeshInstance3D.new()
            _body_mi.mesh = mi.mesh
            _body_mi.transform = CarModel._rel(mi, root)
            add_child(_body_mi)
            for i in mi.mesh.get_surface_count():
                var mat := mi.mesh.surface_get_material(i)
                var role := String(mat.resource_name) if mat else ""
                if role == "Paint":
                    _paint_surfaces.append(i)
                    _body_mi.set_surface_override_material(i, CarModel.paint_material(mat, paint))
                elif role == "Tail":
                    _body_mi.set_surface_override_material(i, _tail_mat)
        elif nm.begins_with("Wheel_"):
            var front := nm.begins_with("Wheel_F")
            # точка подвески чуть выше центра колеса (ход подвески 0,12 м)
            _add_wheel(wheels[nm] + Vector3(0, 0.11, 0), front, mi.mesh, r, mi.transform.basis)
    root.free()


# ---------------------------------------------------------------- место водителя

var _seat_cache: Array = []


## Где сидит водитель (таз, в координатах машины) и во сколько уменьшить фигуру,
## чтобы голова не торчала из крыши. Только легковые (у мотоцикла свой седок).
func driver_seat() -> Array:
    if kind != "car" or _body_mi == null or _body_mi.mesh == null:
        return []
    if not _seat_cache.is_empty():
        return _seat_cache
    var box := _body_mi.transform * _body_mi.mesh.get_aabb()
    var front_z := 1.2
    var wheel_y := 0.3
    for w: VehicleWheel3D in _all_wheels:
        if w.use_as_steering:
            front_z = w.position.z
            wheel_y = w.position.y - 0.11
    var roof := box.position.y + box.size.y
    var floor_y := box.position.y + 0.06
    var hip_z := front_z - 1.3
    if model_id == "uaz452":   # «буханка»: кабина над передней осью
        floor_y = wheel_y + 0.25
        hip_z = front_z - 0.35
    var sc := clampf((roof - 0.14 - floor_y) / 1.42, 0.62, 1.0)
    var hip := Vector3(box.size.x * 0.21, floor_y + 0.47 * sc, hip_z)
    _seat_cache = [hip, sc]
    return _seat_cache


# ---------------------------------------------------------------- выхлоп и дым из-под колёс

var _exhaust: CPUParticles3D = null
var _tire_smoke: Array[CPUParticles3D] = []


func _puffs(amount: int, life: float, size: float, col: Color, tex: String) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.local_coords = false      # дым остаётся в воздухе, машина уезжает
    p.emitting = false
    p.spread = 20.0
    p.gravity = Vector3(0, 0.6, 0)
    p.scale_amount_min = 0.5
    p.scale_amount_max = 1.6
    var q := QuadMesh.new()
    q.size = Vector2(size, size)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    if ResourceLoader.exists("res://textures/fx/%s.png" % tex):
        m.albedo_texture = load("res://textures/fx/%s.png" % tex)
    q.material = m
    p.mesh = q
    var g := Gradient.new()
    g.set_color(0, col)
    g.set_color(1, Color(col.r, col.g, col.b, 0.0))
    p.color_ramp = g
    var sc := Curve.new()
    sc.add_point(Vector2(0, 0.4))
    sc.add_point(Vector2(1, 1.0))
    p.scale_amount_curve = sc
    add_child(p)
    return p


func _update_fx(hand: bool, kmh: float, throttle: float, slide: float) -> void:
    if not driven:
        if _exhaust:
            _exhaust.emitting = false
        for t in _tire_smoke:
            t.emitting = false
        return
    if _exhaust == null and kind != "moto":
        var rear_z := -2.1
        var low_y := 0.3
        if _body_mi and _body_mi.mesh:
            var box := _body_mi.transform * _body_mi.mesh.get_aabb()
            rear_z = box.position.z + 0.05
            low_y = box.position.y + 0.12
        _exhaust = _puffs(14, 1.1, 0.35, Color(0.55, 0.55, 0.55, 0.35), "smoke_light")
        _exhaust.position = Vector3(-0.45, low_y, rear_z)
        _exhaust.direction = Vector3(0, 0.25, -1)
        _exhaust.initial_velocity_min = 0.6
        _exhaust.initial_velocity_max = 1.2
        for w in _rear:
            var t := _puffs(24, 1.4, 1.1, Color(0.85, 0.85, 0.85, 0.5), "smoke_light")
            t.position = Vector3(w.position.x, 0.15, w.position.z)
            t.direction = Vector3(0, 0.6, -1)
            t.initial_velocity_min = 0.4
            t.initial_velocity_max = 1.4
            t.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
            t.emission_sphere_radius = 0.25
            _tire_smoke.append(t)
    if _exhaust:
        _exhaust.emitting = (not uses_fuel) or fuel > 0.0
        _exhaust.speed_scale = 1.0 + absf(throttle) * 1.5   # газуешь — дымит гуще
    var skid := (hand and kmh > 15.0) or (slide > 4.5 and kmh > 20.0) or (throttle > 0.9 and kmh < 8.0 and _rear_spinning())
    for t in _tire_smoke:
        t.emitting = skid


func _rear_spinning() -> bool:
    for w in _rear:
        if w.get_skidinfo() < 0.5:
            return true
    return false
