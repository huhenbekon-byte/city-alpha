extends Node3D
## Электричка: тепловоз и вагоны вдоль оси X. Ходит по расписанию:
## прибывает к перрону, стоит, уезжает за горизонт, через время приходит снова.
## one_shot — поезд уже стоит у перрона, постоит немного, уедет и исчезнет (после поездки игрока).

signal arriving
signal arrived
signal departing

const STAND_TIME := 45.0
const AWAY_TIME := 40.0
const MOVE_TIME := 14.0
const RUN := 420.0              # откуда приходит / куда уходит, м от перрона

var platform_x := 0.0           # середина поезда у перрона
var wagons := 4
var one_shot := false
var title := "КАЗАНЬ — ПЯТИГОРСК"

var state := "away"             # away / arriving / standing / leaving
var _t := 0.0
var _length := 0.0


func _ready() -> void:
    _build()
    if one_shot:
        state = "standing"
        _t = 6.0
        position.x = platform_x
    else:
        state = "away"
        _t = 5.0
        position.x = platform_x + RUN
        visible = false


func _physics_process(delta: float) -> void:
    _t -= delta
    match state:
        "arriving":
            var k := clampf(1.0 - _t / MOVE_TIME, 0.0, 1.0)
            position.x = platform_x - RUN * pow(1.0 - k, 2.0)     # тормозит к перрону
            if _t <= 0.0:
                state = "standing"
                _t = 6.0 if one_shot else STAND_TIME
                position.x = platform_x
                arrived.emit()
        "standing":
            if _t <= 0.0:
                state = "leaving"
                _t = MOVE_TIME
                departing.emit()
        "leaving":
            var k := clampf(1.0 - _t / MOVE_TIME, 0.0, 1.0)
            position.x = platform_x + RUN * k * k                  # разгоняется
            if _t <= 0.0:
                if one_shot:
                    queue_free()
                    return
                state = "away"
                _t = AWAY_TIME
                visible = false
        "away":
            if _t <= 0.0:
                state = "arriving"
                _t = MOVE_TIME
                position.x = platform_x - RUN
                visible = true
                arriving.emit()


## Стоит у перрона — можно садиться.
func is_standing() -> bool:
    return state == "standing"


## Через сколько секунд поезд будет у перрона (0 — уже стоит).
func time_to_arrival() -> float:
    match state:
        "standing":
            return 0.0
        "arriving":
            return _t
        "leaving":
            return _t + AWAY_TIME + MOVE_TIME
    return _t + MOVE_TIME


func _mat(c: Color, rough := 0.55) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    add_child(mi)


func _build() -> void:
    var green := _mat(Color(0.16, 0.36, 0.24))
    var blue := _mat(Color(0.20, 0.33, 0.62))
    var roofm := _mat(Color(0.35, 0.36, 0.37), 0.6)
    var stripe := _mat(Color(0.92, 0.80, 0.3), 0.5)
    var dark := _mat(Color(0.08, 0.08, 0.09), 0.8)
    var glass := _mat(Color(0.12, 0.16, 0.2), 0.15)
    glass.metallic = 0.4
    var light := _mat(Color(1.0, 0.95, 0.7))
    light.emission_enabled = true
    light.emission = Color(1.0, 0.9, 0.6)
    light.emission_energy_multiplier = 2.0
    var parts := []   # [x0, длина] — для коллизии
    var x := 0.0
    for w in wagons + 1:
        var loco := w == wagons   # тепловоз впереди (по ходу +X)
        var length := 17.0 if loco else 22.0
        var cx := x + length * 0.5
        _box(Vector3(length, 3.0, 3.1), Vector3(cx, 2.6, 0), blue if loco else green)
        _box(Vector3(length - 0.4, 0.5, 2.9), Vector3(cx, 4.35, 0), roofm)
        _box(Vector3(length + 0.02, 0.18, 3.14), Vector3(cx, 1.75, 0), stripe)
        _box(Vector3(length - 1.0, 0.9, 1.4), Vector3(cx, 0.75, 0), dark)
        if loco:
            _box(Vector3(0.1, 1.0, 2.2), Vector3(x + length - 0.02, 3.3, 0), glass)   # лобовое (вперёд по +X)
            for sz: float in [-0.9, 0.9]:
                _box(Vector3(0.12, 0.3, 0.3), Vector3(x + length + 0.02, 1.6, sz), light)
            _label("ЧС2", Vector3(cx, 2.6, 1.57), 0.0, 90)
            _label("ЧС2", Vector3(cx, 2.6, -1.57), PI, 90)
        else:
            var wx := x + 2.0
            while wx < x + length - 2.0:
                _box(Vector3(1.1, 0.8, 3.14), Vector3(wx, 3.15, 0), glass)
                wx += 1.9
            _label(title, Vector3(cx, 2.15, 1.57), 0.0, 50)
            _label(title, Vector3(cx, 2.15, -1.57), PI, 50)
        parts.append([x, length])
        x += length + 0.8
    _length = x
    # поезд целиком сдвинут так, чтобы его середина была в начале координат
    for c in get_children():
        if c is Node3D:
            (c as Node3D).position.x -= _length * 0.5
    var body := AnimatableBody3D.new()
    body.sync_to_physics = false
    for p: Array in parts:
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(float(p[1]), 3.6, 3.1)
        cs.shape = bs
        cs.position = Vector3(float(p[0]) + float(p[1]) * 0.5 - _length * 0.5, 2.4, 0)
        body.add_child(cs)
    add_child(body)


func _label(text: String, pos: Vector3, yaw: float, size: int) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = size
    l.pixel_size = 0.005
    l.modulate = Color(0.95, 0.88, 0.6)
    l.outline_size = 0
    l.double_sided = false
    l.position = pos
    l.rotation.y = yaw
    add_child(l)
