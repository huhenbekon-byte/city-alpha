extends Node3D
## Машины-боты. Ездят по правой полосе, на перекрёстках случайно едут прямо
## или поворачивают (плавно, по кривой), тормозят перед игроком, его машинами
## и друг другом. Физика простая (AnimatableBody3D): машину игрока они толкают.

signal honk(pos: Vector3)

const CityBuilder := preload("res://scripts/city_builder.gd")
const CarModel := preload("res://scripts/car_model.gd")

const COUNT := 14
const LANE := 3.5          # смещение полосы от оси дороги
const CRUISE := 11.0       # м/с (~40 км/ч)
const TURN_SPEED := 6.0
const LOOK_AHEAD := 9.0
const COLORS := [
    Color(0.85, 0.85, 0.82), Color(0.55, 0.10, 0.10), Color(0.15, 0.25, 0.45),
    Color(0.20, 0.35, 0.25), Color(0.12, 0.12, 0.13), Color(0.75, 0.65, 0.35),
    Color(0.60, 0.62, 0.65), Color(0.95, 0.85, 0.20),
]

var city = null
var obstacles: Array = []   # Node3D: игрок и его машины (задаёт main.gd)
var focus := Vector3.ZERO   # где камера — далёкие машины не рисуем

var _agents: Array = []
var _rng := RandomNumberGenerator.new()
var _ext := 0.0


func setup() -> void:
    _rng.randomize()
    _ext = (CityBuilder.GRID + 0.5) * CityBuilder.PITCH + 1.0
    var meshes := {}
    for i in COUNT:
        var ci := _rng.randi() % COLORS.size()
        if not meshes.has(ci):
            meshes[ci] = CarModel.parked_mesh(COLORS[ci], ["vaz2106", "sedan", "hatch", "volga", "vaz2106", "suv"][ci % 6])
        var body := AnimatableBody3D.new()
        body.sync_to_physics = true
        CarModel.add_collision(body)
        var mi := MeshInstance3D.new()
        mi.mesh = meshes[ci]
        body.add_child(mi)
        add_child(body)

        # Старт: случайный перекрёсток и направление, где-то посреди квартала.
        var lines: Array = city.road_lines
        var inter := Vector3(lines[_rng.randi() % lines.size()], 0.0, lines[_rng.randi() % lines.size()])
        var dir := _random_dir(inter, Vector3.ZERO)
        var a := {"body": body, "dir": dir, "inter": inter, "speed": CRUISE,
                "t": _rng.randf(), "seg": {}, "blocked": 0.0, "ghost": 0.0,
                "pos": Vector3.ZERO, "fwd": dir}
        _start_straight(a, inter, dir)
        var seg: Dictionary = a["seg"]
        var p0: Vector3 = seg["p0"]
        var p2: Vector3 = seg["p2"]
        a["pos"] = p0.lerp(p2, float(a["t"]))
        _agents.append(a)


func _physics_process(delta: float) -> void:
    for a: Dictionary in _agents:
        var seg: Dictionary = a["seg"]
        var pos: Vector3 = a["pos"]
        var fwd: Vector3 = a["fwd"]

        # Есть ли кто-то впереди на полосе?
        var blocked := false
        a["honked"] = float(a.get("honked", 0.0)) - delta
        if float(a["ghost"]) <= 0.0:
            var who := _blocker(a, pos, fwd)
            blocked = who != 0
            # Игрок мешает проехать — сигналим (не чаще раза в 4 с).
            if who == 1 and float(a["blocked"]) > 1.2 and float(a.get("honked", 0.0)) <= 0.0:
                a["honked"] = 4.0
                honk.emit(pos)
        else:
            a["ghost"] = float(a["ghost"]) - delta
        if blocked:
            a["blocked"] = float(a["blocked"]) + delta
            if float(a["blocked"]) > 5.0:  # стоим слишком долго — проезжаем «сквозь»
                a["ghost"] = 2.0
                a["blocked"] = 0.0
        else:
            a["blocked"] = 0.0

        var want := 0.0 if blocked else (TURN_SPEED if seg["turn"] else CRUISE)
        var speed: float = a["speed"]
        speed = move_toward(speed, want, (10.0 if want < speed else 3.5) * delta)
        a["speed"] = speed

        var t: float = a["t"] + speed * delta / float(seg["len"])
        if t >= 1.0:
            _next_segment(a)
            t = 0.0
            seg = a["seg"]
        a["t"] = t

        var p0: Vector3 = seg["p0"]
        var p1: Vector3 = seg["p1"]
        var p2: Vector3 = seg["p2"]
        var u := 1.0 - t
        pos = p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)
        var d := (p1 - p0) * (2.0 * u) + (p2 - p1) * (2.0 * t)
        if d.length() > 0.001:
            fwd = d.normalized()
        a["pos"] = pos
        a["fwd"] = fwd

        var body: AnimatableBody3D = a["body"]
        body.global_transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), pos)
        body.visible = pos.distance_to(focus) < 220.0


## 0 — путь свободен, 1 — мешает игрок или его машина, 2 — другой бот.
func _blocker(a: Dictionary, pos: Vector3, fwd: Vector3) -> int:
    var right := _right(fwd)
    for o in obstacles:
        if is_instance_valid(o) and o.visible and _in_front(pos, fwd, right, o.global_position):
            return 1
    for b: Dictionary in _agents:
        if b["body"] != a["body"] and _in_front(pos, fwd, right, b["pos"]):
            return 2
    return 0


func _in_front(pos: Vector3, fwd: Vector3, right: Vector3, o: Vector3) -> bool:
    var rel := o - pos
    var ahead := rel.x * fwd.x + rel.z * fwd.z
    var side := absf(rel.x * right.x + rel.z * right.z)
    return ahead > 0.5 and ahead < LOOK_AHEAD and side < 2.0


# ---------------------------------------------------------------- маршрут

## Отрезок прямо по полосе от выезда с перекрёстка до въезда на следующий.
func _start_straight(a: Dictionary, from_inter: Vector3, dir: Vector3) -> void:
    var nxt := from_inter + dir * CityBuilder.PITCH
    var p0 := _exit_point(from_inter, dir)
    var p2 := _entry_point(nxt, dir)
    a["seg"] = {"p0": p0, "p1": (p0 + p2) * 0.5, "p2": p2, "len": p0.distance_to(p2), "turn": false}
    a["inter"] = nxt
    a["dir"] = dir


func _next_segment(a: Dictionary) -> void:
    var seg: Dictionary = a["seg"]
    var inter: Vector3 = a["inter"]
    var dir: Vector3 = a["dir"]
    if seg["turn"]:
        _start_straight(a, inter, dir)
        return
    # Подъехали к перекрёстку — выбираем, куда дальше.
    var d2 := _random_dir(inter, dir)
    var p0 := _entry_point(inter, dir)
    var p2 := _exit_point(inter, d2)
    var p1 := (p0 + p2) * 0.5
    if d2 != dir:
        p1 = inter + _right(dir) * LANE + _right(d2) * LANE  # точка пересечения полос
    a["seg"] = {"p0": p0, "p1": p1, "p2": p2,
            "len": maxf((p0.distance_to(p1) + p1.distance_to(p2)) * 0.9, 1.0), "turn": true}
    a["dir"] = d2


## Случайное направление с перекрёстка: прямо (чаще), налево, направо —
## только туда, где город продолжается. Разворотов нет.
func _random_dir(inter: Vector3, dir: Vector3) -> Vector3:
    var options := []
    var all: Array = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for d: Vector3 in all:
        if dir != Vector3.ZERO and d == -dir:
            continue
        var n := inter + d * CityBuilder.PITCH
        if absf(n.x) > _ext or absf(n.z) > _ext:
            continue
        options.append(d)
        if d == dir:
            options.append(d)  # прямо — вдвое вероятнее
    if options.is_empty():
        return -dir
    return options[_rng.randi() % options.size()]


func _half() -> float:
    return CityBuilder.ROAD * 0.5 + 2.0


func _right(d: Vector3) -> Vector3:
    return Vector3(-d.z, 0.0, d.x)


func _entry_point(inter: Vector3, d: Vector3) -> Vector3:
    return inter - d * _half() + _right(d) * LANE


func _exit_point(inter: Vector3, d: Vector3) -> Vector3:
    return inter + d * _half() + _right(d) * LANE
