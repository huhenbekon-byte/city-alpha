extends Node3D
## Работы «на месте» и экзамен в автошколе:
##   bus    — водитель автобуса: маршрут по остановкам, платят за каждую;
##   truck  — дальнобойщик: отвезти груз на точку за городом;
##   loader — грузчик: носить коробки из фуры на склад (пешком);
##   lumber — лесоруб: срубить дерево и отнести бревно на лесопилку (пешком);
##   exam   — практический экзамен: проехать маршрут без превышения скорости.
## Машину для работы создаёт main.gd по сигналу vehicle_needed.

signal paid(amount: int, text: String)
signal message(text: String)
signal vehicle_needed(vehicle_kind: String, at: Transform3D)
signal vehicle_done
signal exam_finished(passed: bool, text: String)

const MarkerScript := preload("res://scripts/marker.gd")

const EXAM_ROUTE := [
    Vector3(25, 0, 43), Vector3(43, 0, 25), Vector3(43, 0, -25), Vector3(25, 0, -43),
    Vector3(-25, 0, -43), Vector3(-43, 0, -25), Vector3(-43, 0, 25), Vector3(-25, 0, 43),
    Vector3(-18, 0, 30),
]
const EXAM_SPEED_LIMIT := 70.0

var city = null
var kind := ""
var carrying := ""     # "" / "box" / "log" — что игрок несёт в руках
var target := Vector3.ZERO
var exam_vehicle := "school"   # на чём сдаём: "school" (B), "school_moto" (A), "school_truck" (C)

var active: bool:
    get:
        return kind != ""

var _marker: MarkerScript
var _route: Array = []
var _idx := 0
var _stop_timer := 0.0
var _reward := 0
var _chops := 0
var _time_left := 0.0
var _penalties := 0
var _penalty_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.randomize()
    _marker = MarkerScript.new()
    add_child(_marker)


func start(job_kind: String) -> void:
    kind = job_kind
    carrying = ""
    _idx = 0
    match kind:
        "bus":
            _route = _make_bus_route()
            vehicle_needed.emit("bus", city.bus_spawn)
            message.emit("Автобус подан. Проедь маршрут: %d остановок" % _route.size())
            _show_route_point()
        "truck":
            vehicle_needed.emit("truck", city.truck_spawn)
            _new_truck_order(city.truck_depot)
        "loader":
            _set_target(city.warehouse_pick, "ВЗЯТЬ КОРОБКУ", Color(1.0, 0.8, 0.1))
            message.emit("Грузчик: носи коробки из фуры на склад")
        "lumber":
            _new_tree()
            message.emit("Лесоруб: руби деревья и носи брёвна на лесопилку")
        "exam":
            _route = EXAM_ROUTE.duplicate()
            _time_left = 240.0
            _penalties = 0
            vehicle_needed.emit(exam_vehicle, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-18, 0.7, 30)))
            message.emit("Экзамен! Проедь по меткам, не быстрее %d км/ч" % int(EXAM_SPEED_LIMIT))
            _show_route_point()


func stop() -> void:
    var had_vehicle := kind == "bus" or kind == "truck" or kind == "exam"
    kind = ""
    carrying = ""
    _marker.visible = false
    if had_vehicle:
        vehicle_done.emit()


func has_target() -> bool:
    return active and _marker.visible


func target_color() -> Color:
    return Color(0.2, 1.0, 0.4) if carrying != "" else Color(1.0, 0.8, 0.1)


## in_vehicle — игрок сидит именно в рабочей машине.
func update(focus: Vector3, in_vehicle: bool, speed_kmh: float, delta: float) -> void:
    if not active:
        return
    _marker.update_distance(focus)
    var d := _dist(focus, target)
    match kind:
        "bus":
            if in_vehicle and d < 8.0 and absf(speed_kmh) < 5.0:
                _stop_timer += delta
                if _stop_timer >= 2.0:
                    _stop_timer = 0.0
                    _idx += 1
                    if _idx >= _route.size():
                        paid.emit(150 + 400, "Маршрут пройден! +550 ₽ (с премией)")
                        _route = _make_bus_route()
                        _idx = 0
                    else:
                        paid.emit(150, "Остановка %d/%d: +150 ₽" % [_idx, _route.size()])
                    _show_route_point()
            else:
                _stop_timer = 0.0
        "truck":
            if in_vehicle and d < 10.0 and absf(speed_kmh) < 5.0:
                paid.emit(_reward, "Груз доставлен! +%d ₽" % _reward)
                _new_truck_order(target)
        "exam":
            _time_left -= delta
            _penalty_cd -= delta
            if in_vehicle and absf(speed_kmh) > EXAM_SPEED_LIMIT and _penalty_cd <= 0.0:
                _penalties += 1
                _penalty_cd = 3.0
                message.emit("Превышение скорости! Штрафной балл %d/3" % _penalties)
            if _penalties >= 3:
                _finish_exam(false, "Экзамен не сдан: 3 нарушения скорости")
            elif _time_left <= 0.0:
                _finish_exam(false, "Экзамен не сдан: не уложился во время")
            elif in_vehicle and d < 8.0:
                _idx += 1
                if _idx >= _route.size():
                    _finish_exam(true, "Экзамен сдан! Права получены")
                else:
                    _show_route_point()


## Текст кнопки действия рядом с точкой (грузчик и лесоруб, пешком).
func action_text(focus: Vector3, in_car: bool) -> String:
    if in_car or _dist(focus, target) > 2.8:
        return ""
    match kind:
        "loader":
            return "ПОЛОЖИТЬ" if carrying == "box" else "ВЗЯТЬ"
        "lumber":
            return "СДАТЬ" if carrying == "log" else "РУБИТЬ"
    return ""


func do_action() -> void:
    match kind:
        "loader":
            if carrying == "box":
                carrying = ""
                paid.emit(60, "Коробка на складе: +60 ₽")
                _set_target(city.warehouse_pick, "ВЗЯТЬ КОРОБКУ", Color(1.0, 0.8, 0.1))
            else:
                carrying = "box"
                Sfx.play("click")
                _set_target(city.warehouse_drop, "ОТНЕСТИ НА СКЛАД", Color(0.2, 1.0, 0.4))
        "lumber":
            if carrying == "log":
                carrying = ""
                paid.emit(180, "Бревно сдано: +180 ₽")
                _new_tree()
            else:
                _chops += 1
                Sfx.play("hit", -2.0, _rng.randf_range(0.9, 1.1))
                if _chops >= 4:
                    _chops = 0
                    carrying = "log"
                    message.emit("Дерево срублено! Неси бревно на лесопилку")
                    _set_target(city.log_pile, "ЛЕСОПИЛКА", Color(0.2, 1.0, 0.4))


func status_text(focus: Vector3, in_vehicle: bool) -> String:
    var d := int(_dist(focus, target))
    match kind:
        "bus":
            if not in_vehicle:
                return "Автобус: вернись в автобус"
            return "Автобус: остановка %d/%d — %d м (встань и подожди 2 с)" % [_idx + 1, _route.size(), d]
        "truck":
            if not in_vehicle:
                return "Дальнобойщик: вернись в фуру"
            return "Дальнобойщик: груз · %d ₽ · %d м" % [_reward, d]
        "loader":
            return "Грузчик: %s — %d м" % ["неси на склад" if carrying == "box" else "возьми коробку", d]
        "lumber":
            if carrying == "log":
                return "Лесоруб: неси бревно на лесопилку — %d м" % d
            return "Лесоруб: руби дерево (%d/4) — %d м" % [_chops, d]
        "exam":
            var sec := maxi(0, int(_time_left))
            return "Экзамен: метка %d/%d · %d м · %d:%02d · нарушений %d/3" % [
                    _idx + 1, _route.size(), d, sec / 60, sec % 60, _penalties]
    return ""


# ---------------------------------------------------------------- внутреннее

func _finish_exam(passed: bool, text: String) -> void:
    stop()
    exam_finished.emit(passed, text)


func _show_route_point() -> void:
    var p: Vector3 = _route[_idx]
    var title := "ОСТАНОВКА" if kind == "bus" else "МЕТКА"
    _set_target(p, "%s %d/%d" % [title, _idx + 1, _route.size()], Color(1.0, 0.8, 0.1))


## 5 остановок подряд, каждая — ближайшая из ещё не посещённых.
func _make_bus_route() -> Array:
    var left: Array = city.bus_stops.duplicate()
    var route := []
    var cur: Vector3 = city.bus_spawn.origin
    for k in mini(5, left.size()):
        var best := 0
        for i in left.size():
            if _dist(cur, left[i]) < _dist(cur, left[best]) and _dist(cur, left[i]) > 30.0:
                best = i
        cur = left[best]
        route.append(cur)
        left.remove_at(best)
    return route


func _new_truck_order(from: Vector3) -> void:
    var drops: Array = city.truck_drops
    var to: Vector3 = drops[_rng.randi() % drops.size()]
    if _dist(from, to) < 100.0:
        to = drops[(drops.find(to) + 1) % drops.size()]
    var dist := _dist(from, to)
    _reward = int(round((900.0 + dist * 2.5) / 10.0)) * 10
    _set_target(to, "РАЗГРУЗКА", Color(0.2, 1.0, 0.4))
    message.emit("Новый груз: %d м, оплата %d ₽" % [int(dist), _reward])


func _new_tree() -> void:
    var trees: Array = city.forest_trees
    var t: Vector3 = trees[_rng.randi() % trees.size()]
    _chops = 0
    _set_target(t, "СРУБИТЬ", Color(1.0, 0.8, 0.1))


func _set_target(pos: Vector3, title: String, col: Color) -> void:
    target = pos
    _marker.show_at(pos, title, col)


func _dist(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()
