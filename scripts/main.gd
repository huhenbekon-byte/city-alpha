extends Node3D
## Точка входа: небо и свет, район, игрок, машины, интерфейс,
## посадка в машину и выход из неё.

const PlayerScene := preload("res://scenes/player.tscn")
const CarScene := preload("res://scenes/car.tscn")
const CityBuilder := preload("res://scripts/city_builder.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")

const CAR_COLORS := [
    Color(0.92, 0.92, 0.90), Color(0.45, 0.06, 0.10),
    Color(0.12, 0.32, 0.22), Color(0.15, 0.22, 0.45),
]
const ENTER_DISTANCE := 3.2

var _touch: TouchControlsScript
var _label: Label
var _speed_label: Label
var _player
var _cars: Array = []
var _driving = null


func _ready() -> void:
    _setup_input()
    _build_environment()
    var city := CityBuilder.new()
    city.name = "City"
    add_child(city)
    _build_ui()
    _spawn_player()
    _spawn_cars()


func _process(_delta: float) -> void:
    var near = null if _driving else _nearest_car()
    _touch.mode = TouchControlsScript.Mode.CAR if _driving else TouchControlsScript.Mode.FOOT
    if _driving:
        _touch.interact_text = "ВЫЙТИ"
    elif near:
        _touch.interact_text = "СЕСТЬ"
    else:
        _touch.interact_text = ""

    var text := "CITY ALPHA  v0.3    FPS %d" % Engine.get_frames_per_second()
    if not _touch.pads_enabled:
        if _driving:
            text += "\nW/S — газ/тормоз   A/D — руль   Пробел — ручник   F — выйти   Мышь — камера"
        else:
            text += "\nWASD — ходьба   Shift — бег   Пробел — прыжок   Мышь — камера"
            if near:
                text += "   F — сесть в машину"
    _label.text = text

    _speed_label.visible = _driving != null
    if _driving:
        var vp := get_viewport().get_visible_rect().size
        _speed_label.position = Vector2(vp.x * 0.5 - 100.0, vp.y - 90.0)
        _speed_label.text = "%d км/ч" % int(absf(_driving.speed_kmh()))


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _toggle_vehicle()


# ---------------------------------------------------------------- машины

func _toggle_vehicle() -> void:
    if _driving:
        var pos: Vector3 = _driving.get_exit_position()
        var yaw: float = _driving.get_camera_yaw()
        _driving.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
        _player.set_camera_yaw(yaw)
    else:
        var car = _nearest_car()
        if car == null:
            return
        _player.set_active(false)
        car.set_driven(true)
        _driving = car


func _nearest_car():
    var best = null
    var best_d := ENTER_DISTANCE
    for car in _cars:
        var d: float = car.global_position.distance_to(_player.global_position)
        if d < best_d:
            best_d = d
            best = car
    return best


func _on_look(relative: Vector2) -> void:
    if _driving:
        _driving.look(relative)
    else:
        _player.look(relative)


func _spawn_cars() -> void:
    for i in CAR_COLORS.size():
        var car = CarScene.instantiate()
        car.paint = CAR_COLORS[i]
        car.position = Vector3(-9.0 + i * 6.0, 0.6, 24.0)
        add_child(car)
        car.touch = _touch
        _cars.append(car)


func _spawn_player() -> void:
    _player = PlayerScene.instantiate()
    _player.position = Vector3(0, 0.4, 14)
    add_child(_player)
    _player.touch = _touch
    _player.set_camera_yaw(PI)  # смотрим на машины


# ---------------------------------------------------------------- ввод

func _setup_input() -> void:
    _add_keys("move_forward", [KEY_W, KEY_UP])
    _add_keys("move_back", [KEY_S, KEY_DOWN])
    _add_keys("move_left", [KEY_A, KEY_LEFT])
    _add_keys("move_right", [KEY_D, KEY_RIGHT])
    _add_keys("sprint", [KEY_SHIFT])
    _add_keys("jump", [KEY_SPACE])
    _add_keys("interact", [KEY_F, KEY_E])


func _add_keys(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = k
        InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- окружение и UI

func _build_environment() -> void:
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.30, 0.50, 0.80)
    sky_mat.sky_horizon_color = Color(0.76, 0.82, 0.88)
    sky_mat.ground_horizon_color = Color(0.76, 0.82, 0.88)
    sky_mat.ground_bottom_color = Color(0.25, 0.26, 0.24)
    var sky := Sky.new()
    sky.sky_material = sky_mat

    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.85
    env.fog_enabled = true
    env.fog_light_color = Color(0.76, 0.82, 0.88)
    env.fog_density = 0.0025
    env.fog_sky_affect = 0.3
    env.glow_enabled = false  # на телефоне дорого и «засвечивает» картинку

    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_color = Color(1.0, 0.95, 0.86)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # самый дешёвый режим
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    _touch = TouchControlsScript.new()
    _touch.pads_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
    _touch.look_drag.connect(_on_look)
    _touch.interact_pressed.connect(_toggle_vehicle)
    layer.add_child(_touch)

    _label = Label.new()
    _label.position = Vector2(16, 12)
    var ls := LabelSettings.new()
    ls.font_size = 16
    ls.outline_size = 5
    ls.outline_color = Color(0, 0, 0, 0.7)
    _label.label_settings = ls
    layer.add_child(_label)

    _speed_label = Label.new()
    _speed_label.size = Vector2(200, 60)
    _speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var ss := LabelSettings.new()
    ss.font_size = 40
    ss.outline_size = 8
    ss.outline_color = Color(0, 0, 0, 0.75)
    _speed_label.label_settings = ss
    _speed_label.visible = false
    layer.add_child(_speed_label)
