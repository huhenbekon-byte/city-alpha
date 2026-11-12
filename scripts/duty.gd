extends Node3D
## Служба во фракции: вызовы и задания для каждой организации.
##   police   — задержать нарушителя и доставить в отдел (КПЗ);
##   kgb      — оперативное задание: обыск, материалы — в управление;
##   hospital — вызов к пострадавшему: помочь на месте или отвезти в больницу;
##   fire     — пожар в доме: приехать и потушить, пока не поздно;
##   mayor    — приём граждан в мэрии и проверки бизнеса;
##   ОПГ      — отвезти «груз» из гаража заказчику (можно попасть в розыск).
## Главный файл (main.gd) решает, кто платит, и показывает метку на карте.

signal paid(amount: int, text: String)
signal message(text: String)
signal crime(stars: int)          # ОПГ: засветился — розыск

const MarkerScript := preload("res://scripts/marker.gd")
const FactionData := preload("res://scripts/faction_data.gd")

var city = null
var kind := ""          # вид фракции ("police" и для милиции Пятигорска), пусто — смена не идёт
var fac := ""           # id своей фракции ("police_p"...): куда везти, чья вывеска
var stage := ""         # что делать сейчас
var target := Vector3.ZERO
var calls_done := 0

var active: bool:
    get:
        return kind != ""

var _marker: MarkerScript
var _npc: Node3D = null
var _fire: Node3D = null
var _fire_hp := 0
var _time_left := 0.0
var _wait := 0.0
var _reward := 0
var _variant := ""
var _desk := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.randomize()
    _marker = MarkerScript.new()
    add_child(_marker)


func start(fid: String) -> void:
    stop()
    fac = fid
    kind = FactionData.base(fid)
    calls_done = 0
    message.emit("Смена началась. Жди вызов — он придёт в телефон и на карту")
    _wait = 3.0
    stage = "wait"


func stop() -> void:
    kind = ""
    stage = ""
    _marker.visible = false
    _clear_npc()
    _clear_fire()


func has_target() -> bool:
    return active and _marker.visible


func target_color() -> Color:
    return Color(0.3, 0.6, 1.0) if stage == "deliver" else Color(1.0, 0.3, 0.25)


## base — вход в здание фракции (куда сдавать), focus — где игрок.
func update(focus: Vector3, in_car: bool, delta: float) -> void:
    if not active:
        return
    _marker.update_distance(focus)
    if stage == "wait":
        _wait -= delta
        if _wait <= 0.0:
            _new_call(focus)
        return
    if _time_left > 0.0:
        _time_left -= delta
        if _time_left <= 0.0:
            _fail()
            return
    if _fire != null:
        var k := clampf(float(_fire_hp) / 8.0, 0.15, 1.0)
        _fire.scale = Vector3.ONE * k
        var light: OmniLight3D = _fire.get_node("Light")
        light.light_energy = (1.5 + sin(Time.get_ticks_msec() * 0.02) * 0.4) * k


func action_text(focus: Vector3, in_car: bool) -> String:
    if not active or stage == "wait":
        return ""
    var d := _dist(focus, target)
    match stage:
        "arrest":
            return "ЗАДЕРЖАТЬ" if d < 3.0 and not in_car else ""
        "search":
            return "ОБЫСК" if d < 3.0 and not in_car else ""
        "patient":
            return "ПОМОЧЬ" if d < 3.0 and not in_car else ""
        "fire":
            return "ТУШИТЬ" if d < 14.0 else ""
        "visitor":
            return "ПРИНЯТЬ" if _dist(focus, _desk) < 2.5 and not in_car else ""
        "inspect":
            return "ПРОВЕРИТЬ" if d < 3.0 and not in_car else ""
        "pickup":
            return "ВЗЯТЬ ГРУЗ" if d < 3.0 and not in_car else ""
        "deliver":
            if d < (8.0 if in_car else 3.0):
                return "СДАТЬ"
    return ""


func do_action(in_fire_truck: bool) -> void:
    match stage:
        "arrest":
            _clear_npc()
            Sfx.play("click")
            _set_deliver("Задержанный в машине. Вези в отдел милиции (КПЗ)", "В ОТДЕЛ")
        "search":
            _clear_npc()
            Sfx.play("click")
            _set_deliver("Материалы изъяты. Доставь их в управление КГБ", "В УПРАВЛЕНИЕ")
        "patient":
            if _variant == "light":
                _clear_npc()
                Sfx.play("heal")
                _done(_reward, "Помощь оказана на месте: +%d ₽")
            else:
                _clear_npc()
                Sfx.play("heal")
                _set_deliver("Пострадавшему нужна больница — вези в приёмное отделение", "В БОЛЬНИЦУ")
        "fire":
            _fire_hp -= 2 if in_fire_truck else 1
            Sfx.play("hit", -10.0, 0.6)
            if _fire_hp <= 0:
                _clear_fire()
                _done(_reward, "Пожар потушен: +%d ₽")
        "visitor":
            Sfx.play("click")
            _done(_reward, "Гражданин принят: +%d ₽")
        "inspect":
            Sfx.play("click")
            _done(_reward, "Проверка бизнеса проведена: +%d ₽")
        "pickup":
            Sfx.play("click")
            _set_deliver("Груз у тебя. Вези заказчику, не попадись милиции", "ЗАКАЗЧИК", _random_far(target))
        "deliver":
            Sfx.play("coin")
            if FactionData.is_gang(kind) and _rng.randf() < 0.35:
                crime.emit(1)
            _done(_reward, "Задание выполнено: +%d ₽")


func status_text(focus: Vector3) -> String:
    if not active:
        return ""
    var fname := String(FactionData.get_faction(fac).get("name", ""))
    var d := int(_dist(focus, target))
    var t := ""
    if _time_left > 0.0:
        t = " · %d:%02d" % [int(_time_left) / 60, int(_time_left) % 60]
    match stage:
        "wait":
            return "Смена (%s): ждём вызов..." % fname
        "arrest":
            return "Вызов: задержать нарушителя — %d м%s" % [d, t]
        "search":
            return "Задание: провести обыск — %d м%s" % [d, t]
        "patient":
            return "Вызов: пострадавший — %d м%s" % [d, t]
        "fire":
            return "ПОЖАР! Потуши (осталось %d) — %d м%s" % [maxi(_fire_hp, 0), d, t]
        "visitor":
            return "Приём граждан: паспортный стол в мэрии"
        "inspect":
            return "Проверка бизнеса — %d м%s" % [d, t]
        "pickup":
            return "Забери груз в гараже — %d м" % d
        "deliver":
            return "Доставка — %d м%s" % [d, t]
    return ""


# ---------------------------------------------------------------- вызовы

func _new_call(focus: Vector3) -> void:
    _time_left = 0.0
    match kind:
        "police":
            var p := _street_spot(focus)
            _npc = _make_npc(p, Color(0.75, 0.15, 0.15), "Нарушитель", false)
            _reward = 600
            _time_left = 240.0
            stage = "arrest"
            _set_target(p, "НАРУШИТЕЛЬ", Color(1.0, 0.3, 0.25))
            message.emit("Вызов: нарушитель %s. Задержи его" % _place(p))
        "kgb":
            var p := _street_spot(focus)
            _npc = _make_npc(p, Color(0.2, 0.2, 0.22), "Объект", false)
            _reward = 750
            _time_left = 240.0
            stage = "search"
            _set_target(p, "ОБЪЕКТ", Color(1.0, 0.3, 0.25))
            message.emit("Оперативное задание: объект %s. Проведи обыск" % _place(p))
        "hospital":
            var p := _street_spot(focus)
            _npc = _make_npc(p, Color(0.3, 0.45, 0.8), "Пострадавший", true)
            _variant = "light" if _rng.randf() < 0.5 else "heavy"
            _reward = 400 if _variant == "light" else 850
            _time_left = 180.0
            stage = "patient"
            _set_target(p, "ПОСТРАДАВШИЙ", Color(1.0, 0.3, 0.25))
            message.emit("Вызов скорой: пострадавший %s" % _place(p))
        "fire":
            var p := _near_drop(focus)
            _make_fire(p)
            _fire_hp = 8
            _reward = 1000
            _time_left = 200.0
            stage = "fire"
            _set_target(p, "ПОЖАР", Color(1.0, 0.45, 0.1))
            message.emit("ПОЖАР %s! Выезжай и туши" % _place(p))
        "mayor":
            if _rng.randf() < 0.6:
                _reward = 300
                stage = "visitor"
                _desk = city.interiors["mayor"]["desk"]
                _set_target(city.faction_sites["mayor"]["door"], "ПРИЁМ ГРАЖДАН", Color(0.4, 0.6, 1.0))
                message.emit("В мэрию пришёл гражданин. Прими его у паспортного стола")
            else:
                var pk: Array = city.pickups
                var b: Dictionary = pk[_rng.randi() % pk.size()]
                _reward = 500
                _time_left = 240.0
                stage = "inspect"
                _set_target(b["pos"], "ПРОВЕРКА", Color(0.4, 0.6, 1.0))
                message.emit("Проверка бизнеса: %s %s" % [String(b["name"]).capitalize(), _place(b["pos"])])
        _:
            if FactionData.is_gang(kind):
                _reward = 900
                stage = "pickup"
                _set_target(city.faction_sites[fac]["door"], "ГРУЗ", Color(1.0, 0.3, 0.25))
                message.emit("Есть дело: забери груз в гараже и отвези заказчику")


func _set_deliver(text: String, title: String, to = null) -> void:
    stage = "deliver"
    var p: Vector3
    if to != null:
        p = to
        _time_left = 200.0
    else:
        var site: Dictionary = city.faction_sites.get(_deliver_site(), {})
        p = site.get("out", Vector3.ZERO)
    _set_target(p, title, Color(0.3, 0.6, 1.0))
    message.emit(text)


func _deliver_site() -> String:
    match kind:
        "hospital", "kgb", "police":
            return fac
    return "police"


func _done(amount: int, text: String) -> void:
    calls_done += 1
    paid.emit(amount, text % amount)
    _marker.visible = false
    _time_left = 0.0
    stage = "wait"
    _wait = _rng.randf_range(6.0, 12.0)


func _fail() -> void:
    _clear_npc()
    _clear_fire()
    _marker.visible = false
    match stage:
        "fire":
            message.emit("Не успели: дом выгорел. Ждём следующий вызов")
        "patient":
            message.emit("Пострадавшего увезла другая бригада. Ждём следующий вызов")
        _:
            message.emit("Время вышло — задание провалено. Ждём следующий вызов")
    stage = "wait"
    _wait = 8.0


# ---------------------------------------------------------------- мир

## Точка на тротуаре случайного квартала, не слишком близко и не слишком далеко.
func _street_spot(focus: Vector3) -> Vector3:
    var best := Vector3.ZERO
    for k in 12:
        var i := _rng.randi_range(-2, 2)
        var j := _rng.randi_range(-2, 2)
        var c := Vector3(i * 86.0, 0.08, j * 86.0)
        var side := _rng.randi() % 4
        var t := _rng.randf_range(-30.0, 30.0)
        var offs: Array = [Vector3(t, 0, -34), Vector3(t, 0, 34), Vector3(-34, 0, t), Vector3(34, 0, t)]
        var p: Vector3 = c + offs[side]
        best = p
        var d := _dist(p, focus)
        if d > 80.0 and d < 320.0:
            break
    return best


func _random_far(from: Vector3) -> Vector3:
    var drops: Array = city.dropoffs
    var p: Vector3 = drops[_rng.randi() % drops.size()]
    for k in 8:
        if _dist(p, from) > 150.0:
            break
        p = drops[_rng.randi() % drops.size()]
    return p


## Название места: улица ближайшего дома.
func _place(p: Vector3) -> String:
    var best := ""
    var bd := INF
    for h: Dictionary in city.homes:
        var hp: Vector3 = h["pos"]
        var d := _dist(hp, p)
        if d < bd:
            bd = d
            best = String(h["addr"]).get_slice(",", 0)
    return "в районе: " + best if best != "" else ""


func _make_npc(p: Vector3, shirt: Color, title: String, lying: bool) -> Node3D:
    _clear_npc()
    var root := Node3D.new()
    add_child(root)
    root.position = p
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.25
    cap.height = 1.7
    body.mesh = cap
    var m := StandardMaterial3D.new()
    m.albedo_color = shirt
    body.material_override = m
    var head := MeshInstance3D.new()
    var sph := SphereMesh.new()
    sph.radius = 0.14
    sph.height = 0.28
    head.mesh = sph
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.87, 0.68, 0.55)
    head.material_override = skin
    if lying:
        body.rotation.x = PI * 0.5
        body.position = Vector3(0, 0.27, 0)
        head.position = Vector3(0, 0.27, -1.0)
    else:
        body.position = Vector3(0, 0.85, 0)
        head.position = Vector3(0, 1.82, 0)
    root.add_child(body)
    root.add_child(head)
    var l := Label3D.new()
    l.text = title
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.font_size = 48
    l.pixel_size = 0.006
    l.outline_size = 10
    l.modulate = Color(1.0, 0.45, 0.4)
    l.position = Vector3(0, 2.4, 0)
    root.add_child(l)
    _npc = root
    return root


func _clear_npc() -> void:
    if _npc != null:
        _npc.queue_free()
        _npc = null


## Огонь и дым из окна дома.
func _make_fire(p: Vector3) -> void:
    _clear_fire()
    var root := Node3D.new()
    add_child(root)
    root.position = p + Vector3(0, 1.5, 0)
    var flame := CPUParticles3D.new()
    flame.amount = 40
    flame.lifetime = 0.9
    flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    flame.emission_sphere_radius = 1.4
    flame.direction = Vector3.UP
    flame.spread = 20.0
    flame.gravity = Vector3(0, 4.0, 0)
    flame.initial_velocity_min = 1.0
    flame.initial_velocity_max = 2.5
    flame.scale_amount_min = 0.8
    flame.scale_amount_max = 1.6
    var q := _fx_quad("flame", 1.2)
    flame.mesh = q
    var grad := Gradient.new()
    grad.set_color(0, Color(1.0, 0.95, 0.85, 1.0))
    grad.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
    flame.color_ramp = grad
    root.add_child(flame)
    var smoke := CPUParticles3D.new()
    smoke.amount = 24
    smoke.lifetime = 3.0
    smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    smoke.emission_sphere_radius = 1.0
    smoke.direction = Vector3.UP
    smoke.spread = 15.0
    smoke.gravity = Vector3(0, 1.5, 0)
    smoke.initial_velocity_min = 1.5
    smoke.initial_velocity_max = 2.5
    smoke.scale_amount_min = 2.0
    smoke.scale_amount_max = 4.0
    smoke.mesh = _fx_quad("smoke_dark", 1.0)
    var sg := Gradient.new()
    sg.set_color(0, Color(1, 1, 1, 0.85))
    sg.set_color(1, Color(1, 1, 1, 0.0))
    smoke.color_ramp = sg
    smoke.position = Vector3(0, 2.0, 0)
    root.add_child(smoke)
    var sparks := CPUParticles3D.new()
    sparks.amount = 14
    sparks.lifetime = 1.2
    sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    sparks.emission_sphere_radius = 1.0
    sparks.direction = Vector3.UP
    sparks.spread = 35.0
    sparks.initial_velocity_min = 2.0
    sparks.initial_velocity_max = 4.5
    sparks.gravity = Vector3(0, 1.0, 0)
    sparks.mesh = _fx_quad("spark", 0.25)
    root.add_child(sparks)
    var light := OmniLight3D.new()
    light.name = "Light"
    light.light_color = Color(1.0, 0.55, 0.2)
    light.omni_range = 10.0
    light.light_energy = 1.5
    root.add_child(light)
    _fire = root


func _clear_fire() -> void:
    if _fire != null:
        _fire.queue_free()
        _fire = null


func _set_target(pos: Vector3, title: String, col: Color) -> void:
    target = pos
    _marker.show_at(pos, title, col)


func _dist(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()



## Квадрат-частица с мягкой картинкой из textures/fx (нет файла — просто цветной квадрат).
static func _fx_quad(fx_name: String, size: float) -> QuadMesh:
    var q := QuadMesh.new()
    q.size = Vector2(size, size)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    var path := "res://textures/fx/%s.png" % fx_name
    if ResourceLoader.exists(path):
        m.albedo_texture = load(path)
    q.material = m
    return q



## Подъезд не слишком далеко от игрока (пожары — в своём городе).
func _near_drop(focus: Vector3) -> Vector3:
    var drops: Array = city.dropoffs
    var p: Vector3 = drops[_rng.randi() % drops.size()]
    for k in 30:
        if _dist(p, focus) < 300.0:
            break
        p = drops[_rng.randi() % drops.size()]
    return p
