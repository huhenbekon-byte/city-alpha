extends CharacterBody3D
## Игрок от третьего лица: ходьба, бег, прыжок, камера на пружине.
## По умолчанию собирает стилизованного персонажа из примитивов с процедурной
## анимацией. Если указать Model Scene (свой .glb/.fbx с анимациями) —
## используется он и его анимации Idle / Walk / Run / Jump.

const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const BodyMesh := preload("res://scripts/body_mesh.gd")
## Персонаж Quaternius (CC0) с анимациями. Если файла нет — собираем своего из деталей.
const CHARACTER_PATH := "res://models/character/character.gltf"
const CHAR_DIR := "res://models/character/"
## Какие анимации из библиотеки брать для состояний.
const ANIM_NAMES := {"idle": "Idle_Loop", "walk": "Walk_Loop", "run": "Sprint_Loop", "jog": "Jog_Fwd_Loop",
        "jump": "Jump_Loop"}

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

## Шаг (для звука). run — бежит.
signal stepped(run: bool)
var _step_acc := 0.0
var _was_on_floor := true
var _look_mats := {}   # slot -> материал (куртка, штаны, кроссовки, волосы, кожа)
var _face_mat: ShaderMaterial = null
var _tex_cache := {}

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
var _model: Node3D = null
var _gun_holder: BoneAttachment3D = null
var _gun: Node3D = null
var _gun_muzzle := Vector3.ZERO
var armed := false            # в руке оружие (не кулак)
var _action_until := 0.0      # пока идёт удар/выстрел — другие анимации не включаем
var _punch_flip := false
var _spawn := Vector3.ZERO


func _ready() -> void:
    add_to_group("player")
    _spawn = global_position
    floor_snap_length = 0.3
    floor_max_angle = deg_to_rad(50.0)  # чтобы заходить на бордюр
    floor_constant_speed = true         # на подъёме и спуске скорость та же
    floor_block_on_wall = true

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
    if model_scene == null and ResourceLoader.exists(CHARACTER_PATH):
        model_scene = load(CHARACTER_PATH)
        _skin_path = CHARACTER_PATH
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
    _camera.add_to_group("game_camera")
    _spring.add_child(_camera)


var _carry_kind := ""
var _carry_node: MeshInstance3D


## Показать, что игрок несёт: "" — ничего, "box" — коробку, "log" — бревно.
func set_carry(what: String) -> void:
    if what == _carry_kind:
        return
    _carry_kind = what
    if _carry_node:
        _carry_node.queue_free()
        _carry_node = null
    if what == "":
        return
    var bm := BoxMesh.new()
    var mat := StandardMaterial3D.new()
    _carry_node = MeshInstance3D.new()
    if what == "box":
        bm.size = Vector3(0.6, 0.45, 0.5)
        mat.albedo_color = Color(0.72, 0.55, 0.35)
        _carry_node.position = Vector3(0, 1.15, -0.45)
    else:
        bm.size = Vector3(0.3, 0.3, 1.6)
        mat.albedo_color = Color(0.45, 0.30, 0.18)
        _carry_node.position = Vector3(0.25, 1.62, 0)
    _carry_node.mesh = bm
    _carry_node.material_override = mat
    _visual.add_child(_carry_node)


## Перекрасить одежду/внешность: {"jacket": Color, ...} и ткани {"jacket": "cloth_leather", ...}.
func set_look(colors: Dictionary, textures := {}) -> void:
    for id: String in colors:
        if _look_mats.has(id):
            var m: StandardMaterial3D = _look_mats[id]
            m.albedo_color = colors[id]
    for id: String in textures:
        if _look_mats.has(id):
            _set_cloth(_look_mats[id], String(textures[id]))
    if _body_sh:
        for slot: String in ["jacket", "pants", "shoes"]:
            if colors.has(slot):
                var c: Color = colors[slot]
                _body_sh.set_shader_parameter(slot + "_col", Vector3(c.r, c.g, c.b))
            if textures.has(slot):
                var t := _load_tex(String(textures[slot]))
                if t:
                    _body_sh.set_shader_parameter(slot + "_tex", t)
        if textures.has("jacket_style"):
            var style := String(textures["jacket_style"])
            _body_sh.set_shader_parameter("long_sleeves", 0.0 if style.contains("short") else 1.0)
            # шеврон фракции («badge:police») или герб СССР на майке («print»)
            var badge := ""
            for part in style.split(","):
                if String(part).begins_with("badge:"):
                    badge = String(part).substr(6)
            var print_path := CHAR_DIR + ("body_badge_%s.png" % badge if badge != "" else "print_ussr.png")
            if ResourceLoader.exists(print_path):
                _body_sh.set_shader_parameter("print_tex", load(print_path))
            _body_sh.set_shader_parameter("print_on", 1.0 if (style.contains("print") or badge != "") else 0.0)
            _set_overlay("lampas", style.contains("lampas"))
            _set_overlay("tape", style.contains("tape"))
            _set_overlay("vest", style.contains("vest"))
        if colors.has("skin"):
            var sc: Color = colors["skin"]
            _body_sh.set_shader_parameter("skin_tint", Vector3(sc.r / 0.87, sc.g / 0.68, sc.b / 0.55))
    if _hair_mat and colors.has("hair"):
        var hc: Color = colors["hair"]
        _hair_mat.albedo_color = hc.lightened(0.15)
    if _face_mat and colors.has("skin"):
        var c: Color = colors["skin"]
        _face_mat.set_shader_parameter("skin", Vector3(c.r, c.g, c.b))


## Ткань на материал: по координатам самой детали, повтор каждые ~30 см.
func _set_cloth(m: StandardMaterial3D, tex_name: String) -> void:
    var t := _load_tex(tex_name)
    if t == null:
        return
    m.albedo_texture = t
    m.uv1_triplanar = true
    m.uv1_scale = Vector3.ONE * 3.5


func _load_tex(tex_name: String) -> Texture2D:
    if tex_name == "":
        return null
    if _tex_cache.has(tex_name):
        return _tex_cache[tex_name]
    var path := "res://textures/%s.png" % tex_name
    var t: Texture2D = null
    if ResourceLoader.exists(path):
        t = load(path)
        var img := t.get_image()
        if img:
            if img.is_compressed():
                img.decompress()
            img.generate_mipmaps()
            t = ImageTexture.create_from_image(img)
    _tex_cache[tex_name] = t
    return t


## Включить/выключить игрока (выключаем, пока он сидит в машине).
func set_active(on: bool) -> void:
    if on and seated != "":
        set_seated("")
    visible = on
    velocity = Vector3.ZERO
    process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
    if on:
        _camera.make_current()


## Повернуть камеру и персонажа (при появлении и выходе из машины).
func set_camera_yaw(yaw: float) -> void:
    _cam_yaw.rotation.y = yaw
    _visual.rotation.y = yaw


func get_camera_yaw() -> float:
    return _cam_yaw.rotation.y


## Куда смотрит персонаж (для стрелки на мини-карте).
func get_facing() -> Vector3:
    return -_visual.global_transform.basis.z


## Вызывается из TouchControls (свайп пальцем или drag мышью).
func look(relative: Vector2) -> void:
    _cam_yaw.rotation.y -= relative.x * look_sensitivity
    _cam_pitch.rotation.x = clampf(_cam_pitch.rotation.x - relative.y * look_sensitivity, -1.2, 0.4)


# ---------------------------------------------------------------- движение

## Прыжок «как в хороших играх»: можно прыгнуть чуть позже края (coyote time) и нажать чуть раньше
## приземления (буфер); вниз падает быстрее, чем взлетает; отпустил кнопку — прыжок ниже.
const COYOTE := 0.12
const JUMP_BUFFER := 0.15
const FALL_GRAVITY := 1.6
var _coyote := 0.0
var _jump_buf := 0.0
var _down_until := 0.0      # сбит машиной — лежит и встаёт


func _physics_process(delta: float) -> void:
    _coyote = COYOTE if is_on_floor() else _coyote - delta
    _jump_buf = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buf - delta
    if not is_on_floor():
        var g := _gravity * (FALL_GRAVITY if velocity.y < 0.0 else 1.0)
        if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
            g *= 1.8                       # кнопку отпустили — прыжок ниже
        velocity.y -= g * delta
    if _jump_buf > 0.0 and _coyote > 0.0 and _time >= _down_until and seated == "":
        velocity.y = jump_velocity
        _jump_buf = 0.0
        _coyote = 0.0
    if _time < _down_until:   # лежит после удара машиной
        velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
        move_and_slide()
        return

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var running := Input.is_action_pressed("sprint")
    var mag := 1.0
    if touch and touch.joy_vector.length() > 0.05:
        input = touch.joy_vector
        running = input.length() > 0.85  # джойстик до упора = бег
        mag = clampf(input.length() / 0.85, 0.35, 1.0)   # чуть наклонил — идёт медленно
    input = input.limit_length(1.0)
    if _consume_until > _time or emote != "":
        if input.length() > 0.3:
            _end_consume()
            emote = ""

    var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, _cam_yaw.rotation.y) if input.length() > 0.01 else Vector3.ZERO
    var speed := run_speed if running else walk_speed * mag
    var target := Vector2(dir.x, dir.z) * speed
    # разгон мягче, остановка и разворот — резче (не «катается на льду»)
    var accel := air_control
    if is_on_floor():
        var cur := Vector2(velocity.x, velocity.z)
        accel = acceleration * (1.5 if target.length() < 0.1 or cur.dot(target) < 0.0 else 1.0)
    var hv := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
    velocity.x = hv.x
    velocity.z = hv.y

    move_and_slide()

    var hs := Vector2(velocity.x, velocity.z).length()
    var grounded := is_on_floor()
    if not grounded:
        _fall_v = minf(_fall_v, velocity.y)
    if grounded and not _was_on_floor:
        stepped.emit(true)  # приземлился
        if _fall_v < -3.0 and _anim and _anim_map.has("land") and seated == "":
            _anim.play(_anim_map["land"], 0.05)
            _anim.speed_scale = 1.0 if _fall_v < -6.0 else 1.5
            _action_until = _time + (0.3 if _fall_v < -6.0 else 0.2)
        _fall_v = 0.0
    _was_on_floor = grounded
    if grounded and hs > 0.5:
        _step_acc += hs * delta
        var fast := hs > walk_speed + 0.5
        if _step_acc > (1.05 if fast else 0.68):
            _step_acc = 0.0
            stepped.emit(fast)

    if hv.length() > 0.3:
        var yaw := atan2(-hv.x, -hv.y)
        _visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-12.0 * delta))

    if global_position.y < -30.0:
        global_position = _spawn
        velocity = Vector3.ZERO


func _process(delta: float) -> void:
    _time += delta
    if seated != "":
        _process_seated()
        return
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
    _model = m
    if model_faces_plus_z:
        m.rotation.y = PI
    m.scale = Vector3.ONE * model_scale
    _visual.add_child(m)

    var players := m.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        push_warning("В модели нет AnimationPlayer — анимаций не будет.")
        return
    _anim = players[0] as AnimationPlayer
    if not _custom_skin:
        _setup_character_look(m)
    for key: String in ANIM_NAMES:
        var want_name := String(ANIM_NAMES[key])
        if _anim.has_animation(want_name):
            _anim_map[key] = want_name
        elif _anim.has_animation(want_name.trim_suffix("_Loop")):   # Godot убирает «_Loop» при импорте
            _anim_map[key] = want_name.trim_suffix("_Loop")
    for anim_name in _anim.get_animation_list():
        var low := String(anim_name).to_lower()
        for key in ["idle", "walk", "run", "jump"]:
            if low.contains(key) and not _anim_map.has(key):
                _anim_map[key] = anim_name
    for extra: Array in [["pistol_idle", "pistol_idle"], ["shoot", "pistol_shoot"], ["punch1", "punch_jab"], ["punch2", "punch_cross"],
            ["drive", "driving"], ["sit", "sitting_idle"]]:
        for an in _anim.get_animation_list():
            if String(an).to_lower().begins_with(String(extra[1])) and not _anim_map.has(extra[0]):
                _anim_map[extra[0]] = String(an)
    if _anim_map.has("pistol_idle"):
        _anim.get_animation(_anim_map["pistol_idle"]).loop_mode = Animation.LOOP_LINEAR
    for key in ["idle", "walk", "run", "jog", "jump", "drive", "sit"]:
        if _anim_map.has(key):
            _anim.get_animation(_anim_map[key]).loop_mode = Animation.LOOP_LINEAR
    # анимации из кода (poses.gd): жесты, стойка, удар ногой, приземление, еда и питьё;
    # ходьба и бег — с выпрямленной спиной (в исходных анимациях сильный наклон вперёд)
    var sks := m.find_children("*", "Skeleton3D", true, false)
    if not sks.is_empty():
        var sk := sks[0] as Skeleton3D
        if sk.find_bone("spine_01") >= 0:
            Poses.install(_anim, sk)
            for key in ["walk", "run", "jog"]:
                if _anim_map.has(key):
                    Poses.fix_lean(_anim, sk, _anim_map[key], 0.35)
        for pk: Array in [["squat", "Pose_Squat"], ["salute", "Pose_Salute"], ["rest", "Pose_Rest"], ["guard", "Pose_Guard"],
                ["land", "Anim_Land"], ["kick", "Anim_Kick"], ["eat", "Anim_Eat"], ["drink", "Anim_Drink"]]:
            if _anim.has_animation(pk[1]):
                _anim_map[pk[0]] = pk[1]
    for an in _anim.get_animation_list():
        var low := String(an).to_lower()
        if low.begins_with("hit_chest") and not _anim_map.has("hit"):
            _anim_map["hit"] = String(an)
        if low.begins_with("pistol_aim") and not _anim_map.has("aim"):
            _anim_map["aim"] = String(an)
    if _anim_map.has("aim"):
        _anim.get_animation(_anim_map["aim"]).loop_mode = Animation.LOOP_LINEAR


## Сменить персонажа (скин фракции): path — .gltf со скелетом и анимациями как у основного,
## "" — обычный персонаж. Возвращает true, если модель поменялась (оружие надо выдать заново).
var _skin_path := ""
var _custom_skin := false


func set_skin(path: String) -> bool:
    var want := path if path != "" and ResourceLoader.exists(path) else CHARACTER_PATH
    if want == _skin_path or not ResourceLoader.exists(want):
        return false
    var ps = load(want)
    if not (ps is PackedScene):
        return false
    _skin_path = want
    if _gun:
        _gun.queue_free()
        _gun = null
    _gun_holder = null
    _bat = null
    armed = false
    if _model:
        _model.queue_free()
    _model = null
    _anim = null
    _anim_map.clear()
    _body_sh = null
    _hair_mat = null
    model_scene = ps
    _custom_skin = want != CHARACTER_PATH
    _cap = null
    _cap_kind = ""
    _setup_model()
    set_cap(_cap_name, _cap_col)
    return true


## Жест: "squat" — на корточки, "salute" — отдать честь, "rest" — руки за спину. Сбрасывается, если пойти.
var emote := ""


func play_emote(key: String) -> bool:
    if not _anim_map.has(key) or seated != "":
        return false
    emote = key
    return true


func _animate_model() -> void:
    if _time < _action_until:
        return
    var hspeed := Vector2(velocity.x, velocity.z).length()
    if _time < _consume_until:
        return
    if _prop != null:
        _end_consume()
    if emote != "":
        if hspeed > 0.2 or not is_on_floor() or armed:
            emote = ""
        else:
            var en: String = _anim_map[emote]
            if _anim.current_animation != en:
                _anim.play(en, 0.35)
            _anim.speed_scale = 1.0
            return
    var want := "pistol_idle" if armed and _anim_map.has("pistol_idle") else "idle"
    if armed and _time < _aim_until and _anim_map.has("aim"):
        want = "aim"                       # после выстрела ещё держит пистолет на прицеле
    elif not armed and _time < _guard_until and _anim_map.has("guard"):
        want = "guard"                     # после драки — в боевой стойке
    var rate := 1.0
    var blend := 0.2
    if not is_on_floor() and _anim_map.has("jump"):
        want = "jump"
        rate = 0.8
    elif hspeed > walk_speed + 0.8 and (_anim_map.has("jog") or _anim_map.has("run")):
        # бег: «Jog» (ровная спина, естественный шаг), скорость ног — по скорости движения
        want = "jog" if _anim_map.has("jog") else "run"
        rate = clampf(hspeed / 4.4, 0.85, 1.45)
        if hspeed > run_speed + 1.5 and _anim_map.has("run"):
            want = "run"
            rate = clampf(hspeed / 7.0, 0.8, 1.3)
    elif hspeed > 0.2 and _anim_map.has("walk"):
        want = "walk"
        rate = clampf(hspeed / 1.45, 0.55, 1.7)   # анимация шагает ~1.45 м/с — ноги не «скользят»
        blend = 0.25
    if not _anim_map.has(want):
        return
    var anim_name: String = _anim_map[want]
    if _anim.current_animation != anim_name:
        _anim.play(anim_name, blend)
    _anim.speed_scale = rate


# ---------------------------------------------------------------- драка, стрельба, еда

var _fall_v := 0.0
var _combo := 0
var _combo_t := -10.0
var _guard_until := 0.0
var _aim_until := 0.0
var _consume_until := 0.0
var _prop: Node3D = null


## Сбила машина: отлетает, падает и через пару секунд встаёт.
func knockdown(push: Vector3) -> void:
    if _time < _down_until or seated != "":
        return
    _end_consume()
    emote = ""
    velocity = push + Vector3(0, 3.5, 0)
    _down_until = _time + 2.0
    _action_until = _down_until
    if _anim:
        for an in _anim.get_animation_list():
            if String(an).to_lower().begins_with("death"):
                _anim.play(an, 0.05)
                _anim.speed_scale = 1.8
                break
    get_tree().create_timer(1.6).timeout.connect(func() -> void:
        if _anim and _anim_map.has("land"):
            _anim.play(_anim_map["land"], 0.3)
            _anim.speed_scale = 0.7)


func is_down() -> bool:
    return _time < _down_until


## Получил удар — дёрнуться (если не занят другим действием).
func play_hit() -> void:
    if _anim == null or not _anim_map.has("hit") or seated != "" or _time < _action_until:
        return
    _anim.play(_anim_map["hit"], 0.05)
    _anim.speed_scale = 1.4
    _action_until = _time + 0.35
    _guard_until = _time + 3.0


## Съесть или выпить: рука ко рту, в руке — пирожок или стакан. Пошёл — перестал есть.
func play_consume(drink: bool) -> void:
    var key := "drink" if drink else "eat"
    if _anim == null or not _anim_map.has(key) or seated != "" or armed:
        return
    emote = ""
    _anim.play(_anim_map[key], 0.2)
    _anim.speed_scale = 1.0
    _consume_until = _time + _anim.get_animation(_anim_map[key]).length
    _attach_prop(drink)


func _end_consume() -> void:
    _consume_until = 0.0
    if _prop and is_instance_valid(_prop):
        _prop.queue_free()
    _prop = null


func _attach_prop(drink: bool) -> void:
    _end_consume_prop_only()
    if _model == null:
        return
    var sks := _model.find_children("*", "Skeleton3D", true, false)
    if sks.is_empty():
        return
    var sk := sks[0] as Skeleton3D
    var hb := sk.find_bone("hand_r")
    if hb < 0:
        return
    var att := BoneAttachment3D.new()
    att.bone_name = "hand_r"
    sk.add_child(att)
    _prop = att
    # к ладони: вдоль кисти к среднему пальцу и чуть внутрь
    var fingers := Vector3(0, 0.1, 0)
    var mid := sk.find_bone("middle_01_r")
    if mid >= 0:
        fingers = sk.get_bone_rest(mid).origin
    var palm := fingers * 0.75
    var mi := MeshInstance3D.new()
    var m := StandardMaterial3D.new()
    if drink:
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.042
        cyl.bottom_radius = 0.037
        cyl.height = 0.13
        cyl.radial_segments = 12
        mi.mesh = cyl
        m.albedo_color = Color(0.75, 0.85, 0.9, 0.6)
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.roughness = 0.05
        var tea := MeshInstance3D.new()
        var tc := CylinderMesh.new()
        tc.top_radius = 0.03
        tc.bottom_radius = 0.027
        tc.height = 0.07
        tea.mesh = tc
        var tm := StandardMaterial3D.new()
        tm.albedo_color = Color(0.55, 0.3, 0.1)
        tea.material_override = tm
        tea.position.y = -0.015
        mi.add_child(tea)
    else:
        var sph := SphereMesh.new()
        sph.radius = 0.06
        sph.height = 0.12
        mi.mesh = sph
        mi.scale = Vector3(1.0, 0.7, 1.7)
        m.albedo_color = Color(0.78, 0.52, 0.22)
        m.roughness = 0.8
    mi.material_override = m
    var holder := Node3D.new()
    holder.position = palm
    att.add_child(holder)
    holder.add_child(mi)
    # стакан стоит вертикально в мире, пирожок — поперёк ладони
    holder.global_basis = Basis()
    mi.position = Vector3.ZERO


func _end_consume_prop_only() -> void:
    if _prop and is_instance_valid(_prop):
        _prop.queue_free()
    _prop = null


## Материалы для персонажа Quaternius: тело с одеждой по маске, волосы, брови.
var _body_sh: ShaderMaterial = null
var _hair_mat: StandardMaterial3D = null


func _setup_character_look(root: Node) -> void:
    if not ResourceLoader.exists("res://shaders/character.gdshader") or not ResourceLoader.exists(CHAR_DIR + "body_mask.png"):
        return
    _body_sh = ShaderMaterial.new()
    _body_sh.shader = load("res://shaders/character.gdshader")
    _body_sh.set_shader_parameter("body_tex", load(CHAR_DIR + "body_light.png"))
    _body_sh.set_shader_parameter("mask_tex", load(CHAR_DIR + "body_mask.png"))
    if ResourceLoader.exists(CHAR_DIR + "sleeve_mask.png"):
        _body_sh.set_shader_parameter("sleeve_tex", load(CHAR_DIR + "sleeve_mask.png"))
    if ResourceLoader.exists(CHAR_DIR + "print_ussr.png"):
        _body_sh.set_shader_parameter("print_tex", load(CHAR_DIR + "print_ussr.png"))
    for slot: String in ["jacket", "pants", "shoes"]:
        var t := _load_tex({"jacket": "cloth_red_cotton", "pants": "cloth_denim_blue", "shoes": "cloth_leather_brown"}[slot])
        if t:
            _body_sh.set_shader_parameter(slot + "_tex", t)
    _hair_mat = StandardMaterial3D.new()
    _hair_mat.albedo_color = Color(0.25, 0.17, 0.12)
    if ResourceLoader.exists(CHAR_DIR + "hair_gray.png"):
        _hair_mat.albedo_texture = load(CHAR_DIR + "hair_gray.png")
    _hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    _hair_mat.alpha_scissor_threshold = 0.4
    _hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _hair_mat.roughness = 0.7
    for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh_i := mi as MeshInstance3D
        var nm := String(mesh_i.name).to_lower()
        if nm.contains("hairalt"):
            mesh_i.visible = false     # другие причёски — для прохожих
        elif nm.contains("superhero") or nm.contains("body"):
            mesh_i.material_override = _body_sh
        elif nm.contains("hair") or nm.contains("eyebrow"):
            mesh_i.material_override = _hair_mat


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
    _look_mats = {"skin": skin, "hair": hair, "jacket": jacket, "pants": jeans, "shoes": shoes}
    _set_cloth(shirt, "cloth_knit")
    # Лицо: шейдер с картинкой спереди головы (если есть textures/face.png)
    var face_tex := _load_tex("face")
    var head_mat: Material = skin
    if face_tex and ResourceLoader.exists("res://shaders/face.gdshader"):
        _face_mat = ShaderMaterial.new()
        _face_mat.shader = load("res://shaders/face.gdshader")
        _face_mat.set_shader_parameter("face_tex", face_tex)
        head_mat = _face_mat

    var body := _joint(_visual, Vector3.ZERO, "body")
    var pelvis := _joint(body, Vector3(0, 0.95, 0), "pelvis")
    _part(pelvis, BodyMesh.part("pelvis"), jeans, Vector3(0, 0.02, 0))

    for side in [-1.0, 1.0]:
        var sfx := "_l" if side < 0.0 else "_r"
        var hip := _joint(pelvis, Vector3(0.1 * side, -0.02, 0), "hip" + sfx)
        _part(hip, BodyMesh.part("thigh"), jeans, Vector3.ZERO)
        var knee := _joint(hip, Vector3(0, -0.45, 0), "knee" + sfx)
        _part(knee, _sphere(0.068), jeans, Vector3.ZERO)
        _part(knee, BodyMesh.part("calf"), jeans, Vector3.ZERO)
        _part(knee, BodyMesh.part("shoe"), shoes, Vector3(0, -0.41, 0.07), Vector3(-PI / 2, 0, 0))
        _part(knee, _box(Vector3(0.11, 0.025, 0.29)), sole, Vector3(0, -0.452, -0.075))

    var spine := _joint(pelvis, Vector3(0, 0.05, 0), "spine")
    _part(spine, BodyMesh.part("torso"), jacket, Vector3.ZERO)
    _part(spine, _box(Vector3(0.12, 0.26, 0.02)), shirt, Vector3(0, 0.25, -0.142))
    _part(spine, _cylinder(0.055, 0.1), skin, Vector3(0, 0.55, 0))

    var head := _joint(spine, Vector3(0, 0.58, 0), "head")
    _part(head, _sphere(0.12), head_mat, Vector3(0, 0.1, 0))
    _part(head, BodyMesh.part("hair"), hair, Vector3(0, 0.125, 0.02))
    if _face_mat == null:   # без картинки лица — простые глаза
        for side in [-1.0, 1.0]:
            _part(head, _sphere(0.018), eye, Vector3(0.045 * side, 0.11, -0.112))

    for side in [-1.0, 1.0]:
        var sfx := "_l" if side < 0.0 else "_r"
        var sh := _joint(spine, Vector3(0.26 * side, 0.45, 0), "sh" + sfx)
        _part(sh, _sphere(0.085), jacket, Vector3.ZERO)
        _part(sh, BodyMesh.part("upper_arm"), jacket, Vector3.ZERO)
        var el := _joint(sh, Vector3(0, -0.29, 0), "el" + sfx)
        _part(el, _sphere(0.058), jacket, Vector3.ZERO)
        _part(el, BodyMesh.part("forearm"), jacket, Vector3.ZERO)
        _part(el, BodyMesh.part("hand"), skin, Vector3.ZERO)


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



# ---------------------------------------------------------------- оружие

## Положить оружие в правую руку (path — .gltf из models/guns) или убрать ("").
func set_weapon(path: String, muzzle := Vector3.ZERO) -> void:
    if _gun:
        _gun.queue_free()
        _gun = null
    armed = path != ""
    if not armed or _model == null or not ResourceLoader.exists(path):
        return
    if _gun_holder == null:
        var skels := _model.find_children("*", "Skeleton3D", true, false)
        if skels.is_empty():
            return
        var sk := skels[0] as Skeleton3D
        if sk.find_bone("hand_r") < 0:
            return
        _gun_holder = BoneAttachment3D.new()
        _gun_holder.bone_name = "hand_r"
        sk.add_child(_gun_holder)
    var ps = load(path)
    if not (ps is PackedScene):
        return
    _gun = (ps as PackedScene).instantiate() as Node3D
    # ствол вперёд, когда персонаж держит пистолет двумя руками (рассчитано по позе Pistol_Idle)
    _gun.transform = Transform3D(Basis(Vector3(0.03, 0.9824, -0.1844), Vector3(-0.0419, 0.1856, 0.9817),
            Vector3(0.9987, -0.0217, 0.0467)), Vector3(0.0, 0.0556, 0.0251))
    _gun_holder.add_child(_gun)
    _gun_muzzle = muzzle


## Бита в правой руке (ОПГ): простая деревянная модель с обмоткой на рукояти.
var _bat: Node3D = null


func set_bat(on: bool) -> void:
    if _bat:
        _bat.queue_free()
        _bat = null
    if not on or _model == null:
        return
    if _gun_holder == null:
        var skels := _model.find_children("*", "Skeleton3D", true, false)
        if skels.is_empty():
            return
        var sk := skels[0] as Skeleton3D
        if sk.find_bone("hand_r") < 0:
            return
        _gun_holder = BoneAttachment3D.new()
        _gun_holder.bone_name = "hand_r"
        sk.add_child(_gun_holder)
    _bat = Node3D.new()
    _bat.name = "Bat"
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.78, 0.6, 0.38)
    wood.roughness = 0.55
    var tape := StandardMaterial3D.new()
    tape.albedo_color = Color(0.12, 0.08, 0.06)
    var body := CylinderMesh.new()
    body.top_radius = 0.036
    body.bottom_radius = 0.015
    body.height = 0.78
    body.radial_segments = 12
    var b := MeshInstance3D.new()
    b.mesh = body
    b.material_override = wood
    b.position = Vector3(0, 0.32, 0)
    _bat.add_child(b)
    var grip := CylinderMesh.new()
    grip.top_radius = 0.018
    grip.bottom_radius = 0.017
    grip.height = 0.16
    grip.radial_segments = 10
    var g := MeshInstance3D.new()
    g.mesh = grip
    g.material_override = tape
    g.position = Vector3(0, 0.0, 0)
    _bat.add_child(g)
    var knob := CylinderMesh.new()
    knob.top_radius = 0.026
    knob.bottom_radius = 0.026
    knob.height = 0.02
    var kn := MeshInstance3D.new()
    kn.mesh = knob
    kn.material_override = wood
    kn.position = Vector3(0, -0.085, 0)
    _bat.add_child(kn)
    # рукоять в кулаке, бита смотрит вверх-назад, как на плече
    _bat.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(155.0), 0.0, 0.0)), Vector3(0.0, 0.07, 0.02))
    _gun_holder.add_child(_bat)


## Где дуло (для вспышки и трассера). Без оружия — перед грудью.
func muzzle_position() -> Vector3:
    if _gun and _gun.is_inside_tree():
        return _gun.global_transform * _gun_muzzle
    return global_position + Vector3(0, 1.4, 0) + aim_direction() * 0.5


## Куда смотрит камера (по горизонтали) — туда бьём и стреляем.
func aim_direction() -> Vector3:
    var f := -_cam_yaw.global_transform.basis.z
    f.y = 0.0
    return f.normalized()


## Удар или выстрел: повернуться по камере и проиграть анимацию.
func attack(melee: bool) -> void:
    _visual.rotation.y = _cam_yaw.rotation.y
    if _anim == null:
        return
    _end_consume()
    emote = ""
    var key := "shoot"
    var dur := 0.3
    if melee:
        # серия: джеб — кросс — удар ногой; пауза больше секунды — серия сначала
        _combo = _combo + 1 if _time - _combo_t < 1.0 else 0
        _combo_t = _time
        key = ["punch1", "punch2", "kick"][_combo % 3]
        if not _anim_map.has(key):
            key = "punch2" if _combo % 2 == 1 else "punch1"
        dur = 0.6 if key == "kick" else 0.42
        _guard_until = _time + 3.0
        if is_on_floor():   # шаг вперёд вместе с ударом
            var f := aim_direction()
            velocity.x += f.x * 2.2
            velocity.z += f.z * 2.2
    else:
        _aim_until = _time + 1.5
    if not _anim_map.has(key):
        return
    _anim.play(_anim_map[key], 0.06)
    _anim.speed_scale = 1.0 if key == "kick" else (1.6 if melee else 1.4)
    _action_until = _time + dur



## Слои формы на теле: лампасы, светоотражающая лента, жилет ДПС.
func _set_overlay(kind: String, on: bool) -> void:
    if _body_sh == null:
        return
    _body_sh.set_shader_parameter(kind + "_on", 1.0 if on else 0.0)
    if not on or _body_sh.get_meta("ov_" + kind, false):
        return
    _body_sh.set_meta("ov_" + kind, true)
    match kind:
        "lampas":
            _body_sh.set_shader_parameter("lampas_tex", load(CHAR_DIR + "body_lampas.png"))
        "tape":
            _body_sh.set_shader_parameter("tape_tex", load(CHAR_DIR + "body_tape.png"))
        "vest":
            _body_sh.set_shader_parameter("vest_mask", load(CHAR_DIR + "body_vest.png"))
            var vt := _load_tex("uni_vest")
            if vt:
                _body_sh.set_shader_parameter("vest_tex", vt)


# ---------------------------------------------------------------- сидя (за рулём, на лавке)

## Таз в позе сидя относительно ног персонажа (из анимаций Driving / Sitting_Idle).
const PELVIS_DRIVE := Vector3(-0.003, 0.559, 0.321)
const PELVIS_SIT := Vector3(-0.003, 0.561, 0.343)

var seated := ""            # "" — стоит, "drive" — за рулём, "sit" — на лавке
var _saved_layer := 1
var _saved_mask := 1
var _stand_pos := Vector3.ZERO


func can_sit(kind: String) -> bool:
    return _anim != null and _anim_map.has(kind)


## Сесть ("drive"/"sit") или встать (""). Пока сидит — без физики и без столкновений.
func set_seated(kind: String) -> void:
    if kind == seated:
        return
    var was := seated
    seated = kind
    velocity = Vector3.ZERO
    if kind != "":
        visible = true
        process_mode = Node.PROCESS_MODE_INHERIT
        set_physics_process(false)
        if collision_layer != 0:
            _saved_layer = collision_layer
            _saved_mask = collision_mask
        collision_layer = 0
        collision_mask = 0
        _visual.rotation.y = 0.0
        if _gun:
            _gun.visible = false
        if _carry_node:
            _carry_node.visible = false
    else:
        _visual.scale = Vector3.ONE
        transform.basis = Basis()   # из машины мог выйти с наклоном кузова
        set_physics_process(true)
        collision_layer = _saved_layer
        collision_mask = _saved_mask
        if _gun:
            _gun.visible = true
        if _carry_node:
            _carry_node.visible = true
        if was == "sit":
            global_position = _stand_pos


## Посадить за руль: seat — точка таза в машине (локально), sc — масштаб (в маленьких машинах — меньше).
## Возвращает локальную позицию игрока в машине (повёрнут лицом по ходу машины).
func driver_transform(seat: Vector3, sc: float) -> Transform3D:
    var b := Basis(Vector3.UP, PI)
    return Transform3D(b, seat - b * (PELVIS_DRIVE * sc * model_scale))


func set_seat_scale(sc: float) -> void:
    _visual.scale = Vector3.ONE * sc


## Сесть на лавку: center — середина сиденья (на земле), facing — куда смотрит лавка.
func sit_at(center: Vector3, facing: Vector3) -> bool:
    if not can_sit("sit") or seated != "":
        return false
    _stand_pos = global_position
    set_seated("sit")
    var yaw := atan2(-facing.x, -facing.z)
    _visual.rotation.y = yaw
    global_position = center + Basis(Vector3.UP, yaw) * (-PELVIS_SIT * model_scale) * Vector3(1, 0, 1) - facing * 0.05
    return true


func _process_seated() -> void:
    if _anim:
        var key := "drive" if seated == "drive" else "sit"
        if _anim_map.has(key):
            var an: String = _anim_map[key]
            if _anim.current_animation != an:
                _anim.play(an, 0.3)
            _anim.speed_scale = 1.0
    if seated == "sit":
        var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        if touch and touch.joy_vector.length() > 0.3:
            input = touch.joy_vector
        if input.length() > 0.3 or Input.is_action_just_pressed("jump"):
            set_seated("")


# ---------------------------------------------------------------- головной убор

var _cap: Node3D = null
var _cap_kind := ""
var _cap_name := ""
var _cap_col := Color(0, 0, 0, 0)
const Hats := preload("res://scripts/hats.gd")
const Poses := preload("res://scripts/poses.gd")


## Головной убор (см. hats.gd): "militia", "kgb", "petushok", "fire_helmet"... или "" — без него.
## col — цвет для шапок, у которых он свой (петушок, кепка).
func set_cap(kind: String, col := Color(0, 0, 0, 0)) -> void:
    var key := kind + col.to_html()
    if key == _cap_kind and (kind == "" or (_cap != null and is_instance_valid(_cap))):
        return
    _cap_kind = key
    _cap_name = kind
    _cap_col = col
    if _cap and is_instance_valid(_cap):
        _cap.queue_free()
    _cap = null
    _set_hair_visible(true)
    if kind == "" or _model == null or _custom_skin:
        return
    var skels := _model.find_children("*", "Skeleton3D", true, false)
    if skels.is_empty():
        return
    var sk := skels[0] as Skeleton3D
    if sk.find_bone("Head") < 0:
        return
    var att := BoneAttachment3D.new()
    att.bone_name = "Head"
    sk.add_child(att)
    _cap = att
    var hat := Hats.build(kind, col)
    hat.position = Vector3(0, 0.16, 0.008)   # от кости головы до низа околыша (по модели персонажа)
    att.add_child(hat)
    if Hats.covers_hair(kind):
        _set_hair_visible(false)


func _set_hair_visible(on: bool) -> void:
    if _model == null:
        return
    for mi: Node in _model.find_children("*", "MeshInstance3D", true, false):
        var nm := String(mi.name).to_lower()
        if nm.contains("hair") and not nm.contains("hairalt"):
            (mi as MeshInstance3D).visible = on
