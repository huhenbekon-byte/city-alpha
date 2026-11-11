extends Node3D
## Работы: «courier» (курьер) и «taxi» (таксист).
## Курьер: забрать заказ в ларьке/магазине → отнести/отвезти к подъезду. Можно пешком.
## Таксист: подъехать к пассажиру у подъезда → отвезти по адресу. Только на машине.
## Цель — светящийся столб (жёлтый — забрать, зелёный — доставить) и точка на мини-карте.

signal paid(amount: int, text: String)
signal message(text: String)

enum State { OFF, TO_PICKUP, TO_CLIENT, WAITING }

const PICKUP_COLOR := Color(1.0, 0.8, 0.1, 0.35)
const CLIENT_COLOR := Color(0.2, 1.0, 0.4, 0.35)
const PASSENGER_SHIRTS := [
    Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.7, 0.2),
    Color(0.3, 0.6, 0.3), Color(0.6, 0.3, 0.6), Color(0.9, 0.9, 0.9),
]

var city = null   # city_builder.gd
var kind := ""    # "courier" / "taxi"
var state: State = State.OFF
var target := Vector3.ZERO
var reward := 0
var time_left := 0.0

var active: bool:
    get:
        return state != State.OFF

var _place_name := ""
var _wait := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _marker: Node3D
var _beam_mat: StandardMaterial3D
var _label: Label3D
var _passenger: Node3D
var _arm: Node3D
var _shirt_mat: StandardMaterial3D


func _ready() -> void:
    _rng.randomize()
    _marker = Node3D.new()
    _marker.visible = false
    add_child(_marker)

    _beam_mat = StandardMaterial3D.new()
    _beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _beam_mat.albedo_color = PICKUP_COLOR

    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.9
    beam_mesh.bottom_radius = 0.9
    beam_mesh.height = 30.0
    beam_mesh.radial_segments = 16
    beam_mesh.rings = 1
    beam_mesh.cap_top = false
    beam_mesh.cap_bottom = false
    var beam := MeshInstance3D.new()
    beam.mesh = beam_mesh
    beam.material_override = _beam_mat
    beam.position.y = 15.0
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _marker.add_child(beam)

    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 2.2
    ring_mesh.bottom_radius = 2.2
    ring_mesh.height = 0.04
    ring_mesh.radial_segments = 24
    var ring := MeshInstance3D.new()
    ring.mesh = ring_mesh
    ring.material_override = _beam_mat
    ring.position.y = 0.13
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _marker.add_child(ring)

    _label = Label3D.new()
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true   # видно сквозь дома
    _label.fixed_size = true      # одинаковый размер на любом расстоянии
    _label.pixel_size = 0.0018
    _label.font_size = 40
    _label.outline_size = 10
    _label.position.y = 3.5
    _marker.add_child(_label)

    _build_passenger()


func start(job_kind: String, from: Vector3) -> void:
    kind = job_kind
    _new_order(from)


func stop() -> void:
    state = State.OFF
    _marker.visible = false
    _passenger.visible = false


func has_target() -> bool:
    return state == State.TO_PICKUP or state == State.TO_CLIENT


func target_color() -> Color:
    var c := PICKUP_COLOR if state == State.TO_PICKUP else CLIENT_COLOR
    return Color(c.r, c.g, c.b, 1.0)


## Вызывается из main.gd каждый кадр.
func update(focus: Vector3, in_car: bool, speed_kmh: float, delta: float) -> void:
    _time += delta
    if _passenger.visible:  # пассажир машет рукой
        _arm.rotation.z = 2.6 + sin(_time * 6.0) * 0.35
    match state:
        State.OFF:
            return
        State.WAITING:
            _wait -= delta
            if _wait <= 0.0:
                _new_order(focus)
            return
        State.TO_CLIENT:
            time_left -= delta
    var d := _flat_dist(focus, target)
    _label.text = "%s\n%d м" % [_place_name, int(d)]
    if kind == "taxi" and not in_car:
        return  # такси работает только на машине
    var reach := 8.0 if in_car else 3.0
    var max_speed := 15.0 if kind == "taxi" else 25.0
    if d < reach and absf(speed_kmh) < max_speed:
        if state == State.TO_PICKUP:
            _picked_up()
        else:
            _delivered()


func status_text(focus: Vector3, in_car: bool) -> String:
    var d := int(_flat_dist(focus, target))
    var who := "Таксист" if kind == "taxi" else "Курьер"
    if kind == "taxi" and not in_car and has_target():
        return "Таксист: сядь в свою машину"
    match state:
        State.TO_PICKUP:
            if kind == "taxi":
                return "Таксист: забери пассажира — %d м (остановись рядом)" % d
            return "Курьер: забери заказ — %d м" % d
        State.TO_CLIENT:
            var t := "опаздываешь"
            if time_left > 0.0:
                var sec := int(time_left)
                t = "%d:%02d" % [sec / 60, sec % 60]
            return "%s: %s · %d руб. · %d м · %s" % [who,
                    "вези пассажира" if kind == "taxi" else "доставка", reward, d, t]
        State.WAITING:
            return "%s: ждём новый заказ…" % who
    return ""


# ---------------------------------------------------------------- заказы

func _new_order(from: Vector3) -> void:
    if kind == "taxi":
        var spot := _pick_point(city.dropoffs, from, 40.0, 300.0)
        _set_target(spot, "ПАССАЖИР", PICKUP_COLOR)
        _passenger.position = Vector3(spot.x, spot.y, spot.z)
        _shirt_mat.albedo_color = PASSENGER_SHIRTS[_rng.randi() % PASSENGER_SHIRTS.size()]
        _passenger.visible = true
        state = State.TO_PICKUP
        message.emit("Вызов такси! Пассажир ждёт у подъезда")
        return

    var all: Array = city.pickups
    var cands := []
    for p: Dictionary in all:
        var dd := _flat_dist(from, p["pos"])
        if dd > 30.0 and dd < 350.0:
            cands.append(p)
    if cands.is_empty():
        cands = all.duplicate()
    var pick: Dictionary = cands[_rng.randi() % cands.size()]
    var place: String = pick["name"]
    _set_target(pick["pos"], "ЗАБРАТЬ: " + place, PICKUP_COLOR)
    state = State.TO_PICKUP
    message.emit("Новый заказ! Забери его: «%s»" % place)


func _picked_up() -> void:
    var from := target
    var to: Vector3
    var dist: float
    if kind == "taxi":
        _passenger.visible = false
        to = _pick_point(city.dropoffs, from, 150.0, 450.0)
        dist = _flat_dist(from, to)
        reward = int(round((200.0 + dist * 2.2) / 10.0)) * 10
        time_left = dist / 8.0 + 30.0
        _set_target(to, "ВЫСАДКА", CLIENT_COLOR)
        message.emit("Пассажир сел. Вези по адресу — %d м" % int(dist))
    else:
        to = _pick_point(city.dropoffs, from, 80.0, 330.0)
        dist = _flat_dist(from, to)
        reward = int(round((150.0 + dist * 1.6) / 10.0)) * 10
        time_left = dist / 5.0 + 40.0
        _set_target(to, "ДОСТАВКА", CLIENT_COLOR)
        message.emit("Заказ у тебя! Отвези к подъезду — %d м" % int(dist))
    state = State.TO_CLIENT


func _delivered() -> void:
    var pay := reward
    var what := "Поездка оплачена" if kind == "taxi" else "Доставлено"
    var text := "%s! +%d руб." % [what, pay]
    if time_left > 0.0:
        var bonus := int(reward * 0.3 / 10.0) * 10
        pay += bonus
        text = "%s! +%d руб. (бонус за скорость %d)" % [what, pay, bonus]
    paid.emit(pay, text)
    _marker.visible = false
    state = State.WAITING
    _wait = 3.0


## Случайная точка из списка на расстоянии от min_d до max_d (или любая, если таких нет).
func _pick_point(points: Array, from: Vector3, min_d: float, max_d: float) -> Vector3:
    var cands := []
    for p: Vector3 in points:
        var dd := _flat_dist(from, p)
        if dd > min_d and dd < max_d:
            cands.append(p)
    if cands.is_empty():
        cands = points.duplicate()
    return cands[_rng.randi() % cands.size()]


func _set_target(pos: Vector3, place: String, col: Color) -> void:
    target = pos
    _place_name = place
    _marker.position = Vector3(pos.x, 0.0, pos.z)
    _beam_mat.albedo_color = col
    _label.modulate = Color(col.r, col.g, col.b, 1.0)
    _marker.visible = true


func _flat_dist(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


## Простой человечек-пассажир, машет поднятой рукой.
func _build_passenger() -> void:
    _passenger = Node3D.new()
    _passenger.visible = false
    add_child(_passenger)
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.87, 0.68, 0.55)
    _shirt_mat = StandardMaterial3D.new()
    _shirt_mat.albedo_color = PASSENGER_SHIRTS[0]
    var pants := StandardMaterial3D.new()
    pants.albedo_color = Color(0.2, 0.22, 0.28)

    _arm = Node3D.new()
    _arm.position = Vector3(0.26, 1.42, 0)
    _passenger.add_child(_arm)
    _part(_arm, _capsule(0.06, 0.6), _shirt_mat, Vector3(0, -0.28, 0))

    _part(_passenger, _capsule(0.2, 0.62), _shirt_mat, Vector3(0, 1.2, 0))
    _part(_passenger, _capsule(0.08, 0.6), _shirt_mat, Vector3(-0.27, 1.12, 0))
    _part(_passenger, _sphere(0.12), skin, Vector3(0, 1.66, 0))
    for side: float in [-0.1, 0.1]:
        _part(_passenger, _capsule(0.08, 0.92), pants, Vector3(side, 0.46, 0))


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)


func _capsule(r: float, h: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 10
    m.rings = 4
    return m


func _sphere(r: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = r * 2.0
    m.radial_segments = 12
    m.rings = 6
    return m
