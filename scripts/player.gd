extends CharacterBody3D
## Игрок от третьего лица: ходьба, бег, прыжок, камера на пружине.
## По умолчанию собирает стилизованного персонажа из примитивов с процедурной
## анимацией. Если указать Model Scene (свой .glb/.fbx с анимациями) —
## используется он и его анимации Idle / Walk / Run / Jump.

const TouchControlsScript := preload("res://scripts/touch_controls.gd")

@export_group("Движение")
@export var walk_speed := 2.4
@export var run_speed := 6.0
@export var jump_velocity := 5.2
@export var acceleration := 18.0
@export var air_control := 5.0

@export_group("Камера")
@export var look_sensitivity := 0.006
@export var camera_distance := 4.2
@export var camera_side_offset := 0.3

@export_group("Своя модель")
## Перетащи сюда .glb / .fbx / .tscn персонажа. Пусто — встроенный персонаж.
@export var model_scene: PackedScene
## Большинство моделей (Mixamo, Quaternius) смотрят в +Z — оставь включённым.
@export var model_faces_plus_z := true
@export var model_scale := 1.0

var touch: TouchControlsScript = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _visual: Node3D
var _cam_yaw: Node3D
var _cam_pitch: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _joints := {}
var _phase := 0.0
var _time := 0.0
var _anim: AnimationPlayer
var _anim_map := {}
var _spawn := Vector3.ZERO


func _ready() -> void:
    _spawn = global_position
    floor_snap_length = 0.3
    floor_max_angle = deg_to_rad(50.0)  # чтобы заходить на бордюр

    var shape := CapsuleShape3D.new()
    shape.radius = 0.32
    shape.height = 1.8
    var col := CollisionShape3D.new()
    col.shape = shape
    col.position.y = 0.9
    add_child(col)

    _visual = Node3D.new()
    _visual.name = "Visual"
    add_child(_visual)
    if model_scene:
        _setup_model()
    else:
        _build_character()

    _setup_camera()


# ---------------------------------------------------------------- камера

func _setup_camera() -> void:
    _cam_yaw = Node3D.new()
    _cam_yaw.position = Vector3(0, 1.55, 0)
    add_child(_cam_yaw)

    _cam_pitch = Node3D.new()
    _cam_pitch.rotation.x = -0.25
    _cam_yaw.add_child(_cam_pitch)

    _spring = SpringArm3D.new()
    _spring.spring_length = camera_distance
    _spring.margin = 0.2
    _spring.position.x = camera_side_offset
    var probe := SphereShape3D.new()
    probe.radius = 0.25
    _spring.shape = probe
    _spring.add_excluded_object(get_rid())
    _cam_pitch.add_child(_spring)

    _camera = Camera3D.new()
    _camera.fov = 70.0
    _camera.near = 0.05
    _camera.current = true
    _spring.add_child(_camera)


## Включить/выключить игрока (выключаем, пока он сидит в машине).
func set_active(on: bool) -> void:
    visible = on
    velocity = Vector3.ZERO
    process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
    if on:
        _camera.make_current()


## Повернуть камеру и персонажа (при появлении и выходе из машины).
func set_camera_yaw(yaw: float) -> void:
    _cam_yaw.rotation.y = yaw
    _visual.rotation.y = yaw


## Вызывается из TouchControls (свайп пальцем или drag мышью).
func look(relative: Vector2) -> void:
    _cam_yaw.rotation.y -= relative.x * look_sensitivity
    _cam_pitch.rotation.x = clampf(_cam_pitch.rotation.x - relative.y * look_sensitivity, -1.2, 0.4)


# ---------------------------------------------------------------- движение

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= _gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var running := Input.is_action_pressed("sprint")
    if touch and touch.joy_vector.length() > 0.05:
        input = touch.joy_vector
        running = input.length() > 0.85  # джойстик до упора = бег
    input = input.limit_length(1.0)

    var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _cam_yaw.rotation.y)
    var speed := run_speed if running else walk_speed
    var target := Vector2(dir.x, dir.z) * speed
    var accel := acceleration if is_on_floor() else air_control
    var hv := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
    velocity.x = hv.x
    velocity.z = hv.y

    move_and_slide()

    if hv.length() > 0.3:
        var yaw := atan2(-hv.x, -hv.y)
        _visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-12.0 * delta))

    if global_position.y < -30.0:
        global_position = _spawn
        velocity = Vector3.ZERO


func _process(delta: float) -> void:
    _time += delta
    if _anim:
        _animate_model()
    else:
        _animate_procedural(delta)


# ---------------------------------------------------------------- своя модель

func _setup_model() -> void:
    var m := model_scene.instantiate() as Node3D
    if m == null:
        _build_character()
        return
    if model_faces_plus_z:
        m.rotation.y = PI
    m.scale = Vector3.ONE * model_scale
    _visual.add_child(m)

    var players := m.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        push_warning("В модели нет AnimationPlayer — анимаций не будет.")
        return
    _anim = players[0] as AnimationPlayer
    for anim_name in _anim.get_animation_list():
        var low := String(anim_name).to_lower()
        for key in ["idle", "walk", "run", "jump"]:
            if low.contains(key) and not _anim_map.has(key):
                _anim_map[key] = anim_name
    for key in ["idle", "walk", "run"]:
        if _anim_map.has(key):
            _anim.get_animation(_anim_map[key]).loop_mode = Animation.LOOP_LINEAR


func _animate_model() -> void:
    var hspeed := Vector2(velocity.x, velocity.z).length()
    var want := "idle"
    if not is_on_floor() and _anim_map.has("jump"):
        want = "jump"
    elif hspeed > (walk_speed + run_speed) * 0.5 and _anim_map.has("run"):
        want = "run"
    elif hspeed > 0.2 and _anim_map.has("walk"):
        want = "walk"
    if not _anim_map.has(want):
        return
    var anim_name: String = _anim_map[want]
    if _anim.current_animation != anim_name:
        _anim.play(anim_name, 0.2)


# ---------------------------------------------------------------- встроенный персонаж

func _build_character() -> void:
    var skin := _mat(Color(0.87, 0.68, 0.55), 0.6)
    var hair := _mat(Color(0.16, 0.11, 0.08), 0.7)
    var jacket := _mat(Color(0.09, 0.42, 0.52), 0.55)
    var shirt := _mat(Color(0.95, 0.95, 0.93), 0.8)
    var jeans := _mat(Color(0.17, 0.24, 0.38), 0.85)
    var shoes := _mat(Color(0.96, 0.96, 0.96), 0.5)
    var sole := _mat(Color(0.2, 0.2, 0.2), 0.9)
    var eye := _mat(Color(0.05, 0.05, 0.05), 0.3)

    var body := _joint(_visual, Vector3.ZERO, "body")
    var pelvis := _joint(body, Vector3(0, 0.95, 0), "pelvis")
    _part(pelvis, _capsule(0.15, 0.42), jeans, Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.8))

    for side in [-1.0, 1.0]:
        var sfx := "_l" if side < 0.0 else "_r"
        var hip := _joint(pelvis, Vector3(0.1 * side, -0.02, 0), "hip" + sfx)
        _part(hip, _capsule(0.085, 0.5), jeans, Vector3(0, -0.22, 0))
        var knee := _joint(hip, Vector3(0, -0.45, 0), "knee" + sfx)
        _part(knee, _capsule(0.075, 0.46), jeans, Vector3(0, -0.2, 0))
        _part(knee, _capsule(0.065, 0.27), shoes, Vector3(0, -0.41, -0.04), Vector3(PI / 2, 0, 0))
        _part(knee, _box(Vector3(0.13, 0.03, 0.27)), sole, Vector3(0, -0.455, -0.04))

    var spine := _joint(pelvis, Vector3(0, 0.05, 0), "spine")
    _part(spine, _capsule(0.2, 0.58), jacket, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.15, 1, 0.72))
    _part(spine, _box(Vector3(0.12, 0.26, 0.02)), shirt, Vector3(0, 0.25, -0.142))
    _part(spine, _cylinder(0.055, 0.1), skin, Vector3(0, 0.55, 0))

    var head := _joint(spine, Vector3(0, 0.58, 0), "head")
    _part(head, _sphere(0.12), skin, Vector3(0, 0.1, 0))
    _part(head, _sphere(0.13), hair, Vector3(0, 0.14, 0.02), Vector3.ZERO, Vector3(1, 0.85, 1.05))
    for side in [-1.0, 1.0]:
        _part(head, _sphere(0.018), eye, Vector3(0.045 * side, 0.11, -0.112))

    for side in [-1.0, 1.0]:
        var sfx := "_l" if side < 0.0 else "_r"
        var sh := _joint(spine, Vector3(0.26 * side, 0.45, 0), "sh" + sfx)
        _part(sh, _sphere(0.08), jacket, Vector3.ZERO)
        _part(sh, _capsule(0.07, 0.32), jacket, Vector3(0, -0.14, 0))
        var el := _joint(sh, Vector3(0, -0.29, 0), "el" + sfx)
        _part(el, _capsule(0.058, 0.28), jacket, Vector3(0, -0.13, 0))
        _part(el, _sphere(0.055), skin, Vector3(0, -0.29, 0))


func _animate_procedural(delta: float) -> void:
    if _joints.is_empty():
        return
    var hspeed := Vector2(velocity.x, velocity.z).length()
    var move := clampf(hspeed / walk_speed, 0.0, 1.0)
    var run := clampf((hspeed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
    # Фаза шага привязана к пройденному расстоянию — ноги меньше «скользят».
    _phase = fmod(_phase + hspeed * delta * lerpf(4.6, 3.0, run), TAU)
    var s := sin(_phase)
    var c := cos(_phase)
    var breath := sin(_time * 2.2)

    var leg := lerpf(0.5, 0.85, run) * move
    var knee := lerpf(0.7, 1.4, run) * move
    var arm := lerpf(0.35, 0.95, run) * move
    var elbow := 0.15 + lerpf(0.25, 1.3, run) * move

    var t := {}
    t["hip_l"] = Vector3(s * leg, 0, 0)
    t["hip_r"] = Vector3(-s * leg, 0, 0)
    t["knee_l"] = Vector3(-maxf(0.0, c) * knee - 0.05 * move, 0, 0)
    t["knee_r"] = Vector3(-maxf(0.0, -c) * knee - 0.05 * move, 0, 0)
    t["sh_l"] = Vector3(-s * arm, 0, -0.08 - 0.02 * breath)
    t["sh_r"] = Vector3(s * arm, 0, 0.08 + 0.02 * breath)
    t["el_l"] = Vector3(elbow, 0, 0)
    t["el_r"] = Vector3(elbow, 0, 0)
    t["spine"] = Vector3(-lerpf(0.04, 0.22, run) * move + 0.02 * breath * (1.0 - move), s * 0.12 * move, 0)
    t["head"] = Vector3(lerpf(0.02, 0.15, run) * move, -s * 0.08 * move, 0)
    var body_y := -absf(s) * lerpf(0.03, 0.08, run) * move + 0.006 * breath

    if not is_on_floor():
        t["hip_l"] = Vector3(0.7, 0, 0)
        t["hip_r"] = Vector3(-0.15, 0, 0)
        t["knee_l"] = Vector3(-1.0, 0, 0)
        t["knee_r"] = Vector3(-0.5, 0, 0)
        t["sh_l"] = Vector3(-0.4, 0, -0.5)
        t["sh_r"] = Vector3(0.3, 0, 0.5)
        t["el_l"] = Vector3(0.6, 0, 0)
        t["el_r"] = Vector3(0.6, 0, 0)
        body_y = 0.0

    var w := 1.0 - exp(-14.0 * delta)
    for k in t:
        var j: Node3D = _joints[k]
        j.rotation = j.rotation.lerp(t[k], w)
    var b: Node3D = _joints["body"]
    b.position.y = lerpf(b.position.y, body_y, w)


# ---------------------------------------------------------------- помощники

func _joint(parent: Node3D, pos: Vector3, joint_name: String) -> Node3D:
    var j := Node3D.new()
    j.name = joint_name
    j.position = pos
    parent.add_child(j)
    _joints[joint_name] = j
    return j


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
        rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation = rot
    mi.scale = scl
    parent.add_child(mi)
    return mi


func _mat(col: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = rough
    return m


func _capsule(r: float, h: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 16
    m.rings = 6
    return m


func _sphere(r: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = r * 2.0
    m.radial_segments = 20
    m.rings = 10
    return m


func _cylinder(r: float, h: float) -> CylinderMesh:
    var m := CylinderMesh.new()
    m.top_radius = r
    m.bottom_radius = r
    m.height = h
    m.radial_segments = 12
    return m


func _box(size: Vector3) -> BoxMesh:
    var m := BoxMesh.new()
    m.size = size
    return m
