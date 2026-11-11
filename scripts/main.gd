extends Node3D
## Точка входа: небо, смена дня и ночи, район, игрок, машины, интерфейс,
## деньги (наличные и карта), документы, работы, заправки, сохранение.

const PlayerScene := preload("res://scenes/player.tscn")
const CarScene := preload("res://scenes/car.tscn")
const CityBuilder := preload("res://scripts/city_builder.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const HudScript := preload("res://scripts/hud.gd")
const JobScript := preload("res://scripts/job.gd")
const MenuScript := preload("res://scripts/menu.gd")
const TrafficScript := preload("res://scripts/traffic.gd")
const PedestriansScript := preload("res://scripts/pedestrians.gd")
const CarModel := preload("res://scripts/car_model.gd")
const Clothes := preload("res://scripts/clothes.gd")
const WardrobeScript := preload("res://scripts/wardrobe.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const WorkScript := preload("res://scripts/work.gd")

const VERSION := "v0.10"
const SAVE_PATH := "user://save.cfg"
const START_MONEY := 5000
const GAME_MINUTES_PER_SECOND := 1.0   # 1 реальная секунда = 1 игровая минута
## Машины автосалона на площади: название, цена, цвет, макс. скорость, мощность.
const CAR_MODELS := [
    {"name": "Классика", "price": 8000, "color": Color(0.92, 0.92, 0.90), "speed": 105.0, "force": 4200.0},
    {"name": "Комфорт", "price": 15000, "color": Color(0.15, 0.22, 0.45), "speed": 125.0, "force": 5000.0},
    {"name": "Спорт", "price": 28000, "color": Color(0.45, 0.06, 0.10), "speed": 155.0, "force": 6500.0},
    {"name": "Люкс", "price": 45000, "color": Color(0.10, 0.10, 0.11), "speed": 175.0, "force": 7400.0},
]
const ENTER_DISTANCE := 3.2
const LAMP_LIGHTS := 6   # сколько фонарей рядом с игроком дают настоящий свет ночью
const PLAYER_SPAWN := Vector3(0, 0.4, 14)
const FUEL_PRICE := 50          # ₽ за литр
const EXAM_PRICE := 2000
const DPS_FINE := 1500
## Вопросы теории в автошколе: [вопрос, [варианты], номер правильного].
const QUIZ := [
    ["На какой свет можно ехать?", ["Красный", "Жёлтый", "Зелёный"], 2],
    ["Максимальная скорость в городе?", ["60 км/ч", "90 км/ч", "110 км/ч"], 0],
    ["Кому уступать на нерегулируемом перекрёстке равнозначных дорог?", ["Тому, кто слева", "Тому, кто справа", "Никому"], 1],
    ["Что делать на «зебре», если идёт пешеход?", ["Посигналить", "Уступить дорогу", "Проехать быстрее"], 1],
    ["Можно ли говорить по телефону за рулём без гарнитуры?", ["Да", "Только на светофоре", "Нет"], 2],
    ["Что обязательно делать водителю и пассажирам?", ["Пристёгиваться", "Слушать музыку", "Открывать окна"], 0],
    ["С какой стороны обгонять?", ["Справа", "Слева", "С любой"], 1],
    ["Что означает мигающий жёлтый?", ["Стоп", "Нерегулируемый перекрёсток", "Проезд запрещён"], 1],
]

const DAY_TOP := Color(0.30, 0.50, 0.80)
const DAY_HORIZON := Color(0.76, 0.82, 0.88)
const DUSK_HORIZON := Color(0.95, 0.60, 0.40)
const NIGHT_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_HORIZON := Color(0.08, 0.10, 0.18)
const DAY_AMBIENT := Color(0.55, 0.60, 0.70)
const NIGHT_AMBIENT := Color(0.10, 0.12, 0.22)

var cash := START_MONEY      # наличные
var bank := 0                # на карте
var passport_name := ""      # «Имя_Фамилия», пусто — паспорта нет
var has_license := false
var level := 1
var xp := 0                  # опыт на текущем уровне
var total_xp := 0            # весь опыт — это и есть рейтинг
var phone_number := ""
var card_number := ""
var history: Array = []      # операции по карте: [сумма, описание]
var day := 1
var minutes := 9.0 * 60.0   # время суток в игровых минутах
var look := Clothes.default_look()   # что надето: slot -> номер вещи
var owned_clothes := {}              # slot -> Array купленных номеров

var _touch: TouchControlsScript
var _hud: HudScript
var _job: JobScript
var _city
var _label: Label
var _speed_label: Label
var _player
var _cars: Array = []
var _driving = null
var _menu: MenuScript
var _started := false
var _shadows_on := true
var _wardrobe: WardrobeScript
var _traffic: TrafficScript
var _peds: PedestriansScript
var _lamp_lights: Array[OmniLight3D] = []
var _lamp_timer := 0.0
var _night_k := 0.0
var _loaded := {}   # что прочитали из сохранения до появления игрока и машин
var _dialog: DialogScript
var _work: WorkScript
var _work_vehicle = null     # автобус / фура / учебная машина
var _points: Array = []      # точки взаимодействия: {pos, r, text, cb, car}
var _point = null            # точка, рядом с которой стоим
var _dps_timer := 40.0
var _view_far := 300.0
var _fuel_warned := false
var _quiz: Array = []
var _quiz_i := 0
var _quiz_ok := 0

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _light_timer := 0.0
var _save_timer := 0.0


func _ready() -> void:
    _load_game()
    _setup_input()
    _build_environment()
    _city = CityBuilder.new()
    _city.name = "City"
    add_child(_city)
    _job = JobScript.new()
    _job.city = _city
    _job.paid.connect(_on_job_paid)
    _job.message.connect(_on_job_message)
    add_child(_job)
    _work = WorkScript.new()
    _work.city = _city
    _work.paid.connect(_on_job_paid)
    _work.message.connect(_on_job_message)
    _work.vehicle_needed.connect(_on_work_vehicle_needed)
    _work.vehicle_done.connect(_on_work_vehicle_done)
    _work.exam_finished.connect(_on_exam_finished)
    add_child(_work)
    _build_ui()
    _spawn_player()
    _spawn_cars()
    _spawn_life()
    _restore_state()
    _setup_points()
    _ensure_numbers()
    _apply_settings()
    _open_menu()


func _process(delta: float) -> void:
    # Часы
    minutes += delta * GAME_MINUTES_PER_SECOND
    if minutes >= 1440.0:
        minutes -= 1440.0
        day += 1
    _light_timer -= delta
    if _light_timer <= 0.0:
        _light_timer = 0.25
        _update_daylight()

    var focus := _focus()
    var speed := 0.0
    if _driving:
        speed = _driving.speed_kmh()
    _job.update(focus, _driving != null, speed, delta)
    var in_work_vehicle: bool = _driving != null and _driving == _work_vehicle
    _work.update(focus, in_work_vehicle, speed, delta)
    _player.set_carry(_work.carrying)
    _check_dps(delta, speed)
    _traffic.focus = focus
    _peds.focus = focus
    _lamp_timer -= delta
    if _lamp_timer <= 0.0:
        _lamp_timer = 0.5
        _update_lamp_lights(focus)

    Sfx.night = _night_k

    # Кнопка действия: работа → точка (банкомат, АЗС…) → машина
    _touch.mode = TouchControlsScript.Mode.CAR if _driving else TouchControlsScript.Mode.FOOT
    _point = _find_point(focus, absf(speed))
    var work_action := _work.action_text(focus, _driving != null)
    var near = null if _driving else _nearest_car()
    if work_action != "":
        _touch.interact_text = work_action
    elif _point != null:
        _touch.interact_text = _point["text"]
    elif _driving:
        _touch.interact_text = "ВЫЙТИ"
    elif near:
        _touch.interact_text = "СЕСТЬ" if near.owned else "КУПИТЬ"
    else:
        _touch.interact_text = ""

    # Интерфейс
    _hud.set_money(cash, bank)
    _hud.set_nick(passport_name)
    if _hud.profile.is_open():
        _hud.profile.set_data(_profile_data())
    var hh := int(minutes) / 60
    var mm := int(minutes) % 60
    _hud.set_clock("%02d:%02d   День %d" % [hh, mm, day])
    var job_text: String = _work.status_text(focus, in_work_vehicle) if _work.active \
            else _job.status_text(focus, _driving != null)
    _hud.set_job(job_text)
    if _hud.phone_open:
        _hud.update_phone(_job.active or _work.active, _phone_text(job_text))

    var mini := _hud.minimap
    mini.focus = focus
    mini.heading = _driving.global_transform.basis.z if _driving else _player.get_facing()
    if _work.active:
        mini.has_target = _work.has_target()
        mini.target = _work.target
        mini.target_color = _work.target_color()
    else:
        mini.has_target = _job.has_target()
        mini.target = _job.target
        mini.target_color = _job.target_color()
    mini.queue_redraw()

    var text := "CITY ALPHA %s   FPS %d" % [VERSION, Engine.get_frames_per_second()]
    if not _touch.pads_enabled:
        if _driving:
            text += "\nW/S — газ/тормоз   A/D — руль   Пробел — ручник   H — гудок   F — выйти"
        else:
            text += "\nWASD — ходьба   Shift — бег   Пробел — прыжок   F — сесть / купить машину"
        text += "\nМышь — камера   Tab — телефон   Esc — меню"
    _label.text = text

    _speed_label.visible = _driving != null
    if _driving:
        var vp := get_viewport().get_visible_rect().size
        _speed_label.position = Vector2(vp.x * 0.5 - 100.0, vp.y - 110.0)
        _speed_label.text = "%d км/ч" % int(absf(speed))
        if _driving.uses_fuel:
            var fuel: float = _driving.fuel
            var tank: float = _driving.tank
            _speed_label.text += "\nБензин %d/%d л" % [int(ceil(fuel)), int(tank)]
            if fuel < tank * 0.15 and not _fuel_warned:
                _fuel_warned = true
                _hud.show_toast("Мало бензина! Заправься на АЗС (точки на карте)")
            elif fuel > tank * 0.3:
                _fuel_warned = false

    _save_timer += delta
    if _save_timer > 15.0:
        _save_timer = 0.0
        _save_game()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _on_interact()
    elif event.is_action_pressed("phone"):
        _toggle_phone()
    elif event.is_action_pressed("ui_cancel"):
        _open_menu()
    elif event.is_action_pressed("horn"):
        _on_horn()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:  # кнопка «Назад» на Android
        if _menu and _menu.visible:
            if _started:
                _on_play()
        else:
            _open_menu()


# ---------------------------------------------------------------- меню и настройки

func _open_menu() -> void:
    if _player:
        _save_game()
    if _hud.phone_open:
        _hud.close_phone()
    _hud.profile.close_all()
    get_tree().paused = true
    _touch.visible = false
    _menu.show_menu(_started, VERSION)


func _on_play() -> void:
    Sfx.start_ambient()
    if not _started and passport_name == "":
        _hud.show_toast("Получи паспорт в МЭРИИ на площади — синяя точка на карте")
    _started = true
    _menu.visible = false
    _touch.visible = true
    get_tree().paused = false


func _on_quit() -> void:
    _save_game()
    get_tree().quit()


func _on_reset() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    cash = START_MONEY
    bank = 0
    passport_name = ""
    has_license = false
    level = 1
    xp = 0
    total_xp = 0
    history = []
    phone_number = ""
    card_number = ""
    _ensure_numbers()
    day = 1
    minutes = 9.0 * 60.0
    _job.stop()
    _work.stop()
    if _driving:
        _driving.set_driven(false)
        _driving = null
        _player.set_active(true)
    for i in _cars.size():
        _cars[i].reset_to(_car_spawn(i))
        _cars[i].set_owned(false)
        _cars[i].fuel = _cars[i].tank
    look = Clothes.default_look()
    owned_clothes = {}
    _player.set_look(Clothes.colors(look))
    _player.global_position = PLAYER_SPAWN
    _player.set_camera_yaw(PI)
    _update_daylight()
    _save_game()
    _hud.show_toast("Прогресс сброшен")


func _apply_settings() -> void:
    var st: Dictionary = _menu.settings
    var q := int(st["quality"])
    var v := int(st["view"])
    get_viewport().scaling_3d_scale = [0.6, 0.75, 1.0][q]
    _sun.directional_shadow_max_distance = [30.0, 45.0, 70.0][q]
    _shadows_on = bool(st["shadows"])
    _env.fog_density = [0.007, 0.0035, 0.0015][v]
    var far: float = [170.0, 300.0, 550.0][v]
    _view_far = far
    for cam in get_tree().get_nodes_in_group("game_camera"):
        cam.far = far
    _label.visible = bool(st["fps"])
    var vol := _menu.volume()
    AudioServer.set_bus_mute(0, vol <= 0.0)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))
    _update_daylight()


func _focus() -> Vector3:
    return _driving.global_position if _driving else _player.global_position


# ---------------------------------------------------------------- телефон и работа

func _toggle_phone() -> void:
    if _wardrobe.visible or _dialog.visible or _hud.profile.is_open():
        return
    if _hud.phone_open:
        _hud.close_phone()
    else:
        _touch.blocked = true
        var t: String = _work.status_text(_focus(), _driving == _work_vehicle) if _work.active \
                else _job.status_text(_focus(), _driving != null)
        _hud.open_phone(_job.active or _work.active, _phone_text(t))


func _on_phone_closed() -> void:
    _touch.blocked = false
    _touch.visible = not _menu.visible


func _on_job_selected(kind: String) -> void:
    if not _check_docs(kind == "taxi"):
        return
    if kind == "taxi" and not _has_owned_car():
        _hud.show_toast("Для такси нужна своя машина — купи в автосалоне на площади")
        return
    _work.stop()
    _job.start(kind, _focus())
    _hud.close_phone()


func _on_job_stopped() -> void:
    _job.stop()
    _work.stop()
    _hud.show_toast("Смена закончена")
    _hud.close_phone()


func _phone_text(job_text: String) -> String:
    var docs := "Паспорт: %s\nПрава: %s" % [passport_name if passport_name != "" else "нет (мэрия на площади)",
            "есть" if has_license else "нет (автошкола на площади)"]
    if job_text != "":
        return job_text + "\n\n" + docs
    return docs + "\n\nКурьер и таксист — здесь. Автобус, грузчик, дальнобойщик, лесоруб — на месте (жёлтые точки на карте)."


## Ставит ближайшую свою машину рядом с игроком.
func _on_summon_car() -> void:
    if _driving:
        _hud.show_toast("Ты уже в машине")
        return
    var best = null
    var best_d := INF
    for car in _cars:
        if not car.owned:
            continue
        var d: float = car.global_position.distance_to(_player.global_position)
        if d < best_d:
            best_d = d
            best = car
    if best == null:
        _hud.show_toast("У тебя нет машины — купи в автосалоне на площади")
        return
    var spot = _free_spot_near(_player.global_position, _player.get_camera_yaw())
    if spot == null:
        _hud.show_toast("Тут негде поставить машину — выйди на открытое место")
        return
    best.reset_to(spot)
    best.set_owned(true)
    _hud.close_phone()
    _hud.show_toast("Машина подана")


## Ищет свободное место 2x5 м рядом с точкой (справа, слева, сзади, спереди).
func _free_spot_near(pos: Vector3, yaw: float):
    var space := get_world_3d().direct_space_state
    var box := BoxShape3D.new()
    box.size = Vector3(2.2, 1.4, 4.8)
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = box
    var rot := Basis(Vector3.UP, yaw)
    for off: Vector3 in [Vector3(3.5, 0, 0), Vector3(-3.5, 0, 0), Vector3(0, 0, 5.5), Vector3(0, 0, -5.5)]:
        var p := pos + rot * off
        q.transform = Transform3D(rot, p + Vector3(0, 1.0, 0))
        if space.intersect_shape(q, 1).is_empty():
            return Transform3D(rot, p + Vector3(0, 0.5, 0))
    return null


func _has_owned_car() -> bool:
    for car in _cars:
        if car.owned:
            return true
    return false


## Оплата: сначала наличными, остальное с карты. false — не хватает денег.
func _pay(amount: int, reason := "Покупка") -> bool:
    if cash + bank < amount:
        Sfx.play("error")
        _hud.show_toast("Не хватает %d ₽" % (amount - cash - bank))
        return false
    var from_cash := mini(cash, amount)
    cash -= from_cash
    bank -= amount - from_cash
    if amount - from_cash > 0:
        _bank_log(-(amount - from_cash), reason)
    return true


func _bank_log(amount: int, text: String) -> void:
    history.append([amount, text])
    if history.size() > 30:
        history.pop_front()


func _need_xp() -> int:
    return 100 + (level - 1) * 60


func _add_xp(amount: int) -> void:
    xp += amount
    total_xp += amount
    while xp >= _need_xp():
        xp -= _need_xp()
        level += 1
        Sfx.play("notify")
        _hud.show_toast("Новый уровень: %d!" % level)


func _job_name() -> String:
    var k: String = _work.kind if _work.active else (_job.kind if _job.active else "")
    match k:
        "courier":
            return "Курьер"
        "taxi":
            return "Таксист"
        "bus":
            return "Водитель автобуса"
        "loader":
            return "Грузчик"
        "truck":
            return "Дальнобойщик"
        "lumber":
            return "Лесоруб"
        "exam":
            return "Экзамен в автошколе"
    return "Безработный"


func _profile_data() -> Dictionary:
    return {"name": passport_name if passport_name != "" else "Без паспорта",
            "level": level, "xp": xp, "need": _need_xp(), "rating": total_xp,
            "cash": cash, "bank": bank, "job": _job_name(),
            "phone": phone_number, "home": "Нет", "org": "Нет",
            "card": card_number, "history": history}


## Номер телефона и карты выдаются один раз и сохраняются.
func _ensure_numbers() -> void:
    if phone_number == "":
        phone_number = "+7 9%02d %03d %02d %02d" % [randi() % 100, randi() % 1000, randi() % 100, randi() % 100]
    if card_number == "":
        card_number = "2202  %04d  %04d  %04d" % [randi() % 10000, randi() % 10000, randi() % 10000]


func _on_profile_opened() -> void:
    _touch.blocked = true
    _hud.profile.set_data(_profile_data())


func _on_profile_closed() -> void:
    _touch.blocked = false


func _try_buy(car) -> void:
    var price: int = car.price
    if not _pay(price, "Автосалон: " + String(car.car_name)):
        return
    Sfx.play("coin")
    car.set_owned(true)
    _hud.show_toast("Куплено: %s! Нажми СЕСТЬ" % car.car_name)
    _save_game()


func _on_job_paid(amount: int, text: String) -> void:
    bank += amount   # зарплата приходит на карту
    _bank_log(amount, "Зарплата: " + _job_name())
    Sfx.play("coin")
    _hud.show_toast(text + " (на карту)")
    _add_xp(maxi(5, amount / 20))
    _save_game()


func _on_job_message(text: String) -> void:
    Sfx.play("notify", -4.0)
    _hud.show_toast(text)


# ---------------------------------------------------------------- звуки, гудок, одежда

func _on_horn() -> void:
    if _driving:
        Sfx.play("horn", -3.0)


func _on_step(run: bool) -> void:
    Sfx.play("step", -8.0 if run else -12.0, randf_range(0.85, 1.15))


func _near_shop() -> bool:
    if _driving or _city == null:
        return false
    var p: Vector3 = _player.global_position
    var s: Vector3 = _city.clothes_shop
    return Vector2(p.x - s.x, p.z - s.z).length() < 3.5


func _open_wardrobe() -> void:
    _touch.blocked = true
    _wardrobe.open(look, owned_clothes)


func _on_wardrobe_preview(new_look: Dictionary) -> void:
    _player.set_look(Clothes.colors(new_look))


func _on_wardrobe_buy(new_look: Dictionary, cost: int) -> void:
    if not _pay(cost, "Магазин одежды"):
        return
    for id: String in new_look:
        var list: Array = owned_clothes.get(id, [0])
        if not (int(new_look[id]) in list):
            list.append(int(new_look[id]))
        owned_clothes[id] = list
    look = new_look
    _player.set_look(Clothes.colors(look))
    Sfx.play("coin" if cost > 0 else "click")
    _hud.show_toast("Обновка! −%d ₽" % cost if cost > 0 else "Переоделся")
    _save_game()
    _wardrobe.visible = false
    _on_wardrobe_closed()


func _on_wardrobe_closed() -> void:
    _player.set_look(Clothes.colors(look))  # снять примерку
    _touch.blocked = false


# ---------------------------------------------------------------- машины

## Кнопка действия: сначала работа, потом точка рядом, потом машина.
func _on_interact() -> void:
    if _hud.phone_open or _wardrobe.visible or _dialog.visible or _hud.profile.is_open():
        return
    if _work.action_text(_focus(), _driving != null) != "":
        _work.do_action()
        return
    if _point != null:
        var cb: Callable = _point["cb"]
        cb.call()
        return
    _toggle_vehicle()


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
        if not car.owned:
            _try_buy(car)
            return
        _player.set_active(false)
        car.set_driven(true)
        _driving = car


func _nearest_car():
    var best = null
    var best_d := ENTER_DISTANCE
    var all: Array = _cars.duplicate()
    if _work_vehicle != null:
        all.append(_work_vehicle)
    for car in all:
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


## Город оживает: машины-боты на дорогах и прохожие на тротуарах.
func _spawn_life() -> void:
    _traffic = TrafficScript.new()
    _traffic.city = _city
    add_child(_traffic)
    _traffic.obstacles = [_player] + _cars
    _traffic.honk.connect(func(pos: Vector3) -> void: Sfx.play_at("horn", pos, -2.0, 0.9))
    _traffic.setup()

    _peds = PedestriansScript.new()
    add_child(_peds)
    _peds.player = _player
    _peds.cars = _cars.duplicate()  # копия: туда добавляются и рабочие машины
    _peds.setup()

    for i in LAMP_LIGHTS:
        var l := OmniLight3D.new()
        l.omni_range = 16.0
        l.light_energy = 1.6
        l.light_color = Color(1.0, 0.85, 0.6)
        l.shadow_enabled = false
        l.visible = false
        add_child(l)
        _lamp_lights.append(l)


## Ночью ставит несколько настоящих источников света в ближайшие к игроку фонари
## (свет от всех 300 фонарей сразу телефон не потянет).
func _update_lamp_lights(focus: Vector3) -> void:
    var on := _night_k > 0.35
    if not on:
        for l in _lamp_lights:
            l.visible = false
        return
    var lamps: Array = _city.lamp_positions.duplicate()
    _sort_focus = focus
    lamps.sort_custom(_closer_to_focus)
    for i in _lamp_lights.size():
        var l := _lamp_lights[i]
        l.visible = i < lamps.size()
        if l.visible:
            l.global_position = lamps[i]
            l.light_energy = 1.6 * _night_k


var _sort_focus := Vector3.ZERO


func _closer_to_focus(a: Vector3, b: Vector3) -> bool:
    return a.distance_squared_to(_sort_focus) < b.distance_squared_to(_sort_focus)


func _car_spawn(i: int) -> Transform3D:
    return Transform3D(Basis(), Vector3(-9.0 + i * 6.0, 0.6, 24.0))


func _spawn_cars() -> void:
    var saved: Array = _loaded.get("cars", [])
    var owned: Array = _loaded.get("owned", [])
    for i in CAR_MODELS.size():
        var m: Dictionary = CAR_MODELS[i]
        var car = CarScene.instantiate()
        car.paint = m["color"]
        car.car_name = m["name"]
        car.price = m["price"]
        car.max_speed_kmh = m["speed"]
        car.max_engine_force = m["force"]
        car.owned = i < owned.size() and bool(owned[i])
        var fuels: Array = _loaded.get("fuel", [])
        if i < fuels.size():
            car.fuel = float(fuels[i])
        car.transform = _car_spawn(i)
        if i < saved.size():
            var e: Array = saved[i]
            var pos: Vector3 = e[0]
            if pos.y > -5.0:
                car.position = pos + Vector3.UP * 0.3
                car.rotation.y = float(e[1])
        add_child(car)
        car.touch = _touch
        _cars.append(car)
    _hud.minimap.cars = _cars

    # Вывеска автосалона над рядом машин
    var sign := Label3D.new()
    sign.text = "АВТОСАЛОН"
    sign.font_size = 160
    sign.pixel_size = 0.01
    sign.outline_size = 24
    sign.modulate = Color(1.0, 0.85, 0.3)
    sign.position = Vector3(0, 6.0, 28.5)
    sign.rotation.y = PI  # лицом к площади
    add_child(sign)


func _spawn_player() -> void:
    _player = PlayerScene.instantiate()
    _player.position = PLAYER_SPAWN
    var lp = _loaded.get("player_pos")
    if lp is Vector3 and lp.y > -5.0:
        _player.position = lp + Vector3.UP * 0.3
    add_child(_player)
    _player.touch = _touch
    _player.set_look(Clothes.colors(look))
    _player.stepped.connect(_on_step)
    _player.set_camera_yaw(float(_loaded.get("player_yaw", PI)))


## Вернуть то, что было при выходе: сидел ли в машине, шла ли смена курьера.
func _restore_state() -> void:
    var di := int(_loaded.get("driving", -1))
    if di >= 0 and di < _cars.size():
        _player.set_active(false)
        _cars[di].set_driven(true)
        _driving = _cars[di]
    var kind := String(_loaded.get("job_kind", ""))
    if bool(_loaded.get("job", false)) and kind != "":
        _job.start(kind, _focus())


# ---------------------------------------------------------------- сохранение

func _save_game() -> void:
    if _player == null:
        return
    var cfg := ConfigFile.new()
    cfg.set_value("player", "money", cash)
    cfg.set_value("player", "bank", bank)
    cfg.set_value("player", "passport", passport_name)
    cfg.set_value("player", "license", has_license)
    cfg.set_value("player", "level", level)
    cfg.set_value("player", "xp", xp)
    cfg.set_value("player", "total_xp", total_xp)
    cfg.set_value("player", "phone", phone_number)
    cfg.set_value("player", "card", card_number)
    cfg.set_value("player", "history", history)
    var fuel := []
    for car in _cars:
        fuel.append(car.fuel)
    cfg.set_value("world", "fuel", fuel)
    cfg.set_value("player", "pos", _player.global_position)
    cfg.set_value("player", "yaw", _player.get_camera_yaw())
    cfg.set_value("player", "driving", _cars.find(_driving) if _driving else -1)
    if _driving and _driving == _work_vehicle:
        cfg.set_value("player", "pos", _driving.global_position + Vector3(3, 0.5, 0))
    var cars := []
    for car in _cars:
        var f: Vector3 = car.global_transform.basis.z
        cars.append([car.global_position, atan2(f.x, f.z)])
    cfg.set_value("world", "cars", cars)
    cfg.set_value("job", "active", _job.active and not _work.active)
    cfg.set_value("job", "kind", _job.kind)
    cfg.set_value("player", "look", look)
    cfg.set_value("player", "owned_clothes", owned_clothes)
    var owned := []
    for car in _cars:
        owned.append(car.owned)
    cfg.set_value("world", "owned", owned)
    cfg.set_value("world", "day", day)
    cfg.set_value("world", "minutes", minutes)
    cfg.save(SAVE_PATH)


func _load_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    cash = int(cfg.get_value("player", "money", START_MONEY))
    bank = int(cfg.get_value("player", "bank", 0))
    passport_name = String(cfg.get_value("player", "passport", ""))
    has_license = bool(cfg.get_value("player", "license", false))
    level = int(cfg.get_value("player", "level", 1))
    xp = int(cfg.get_value("player", "xp", 0))
    total_xp = int(cfg.get_value("player", "total_xp", 0))
    phone_number = String(cfg.get_value("player", "phone", ""))
    card_number = String(cfg.get_value("player", "card", ""))
    history = cfg.get_value("player", "history", [])
    _loaded["fuel"] = cfg.get_value("world", "fuel", [])
    day = int(cfg.get_value("world", "day", 1))
    minutes = float(cfg.get_value("world", "minutes", 9.0 * 60.0))
    _loaded["player_pos"] = cfg.get_value("player", "pos", null)
    _loaded["player_yaw"] = cfg.get_value("player", "yaw", PI)
    _loaded["driving"] = cfg.get_value("player", "driving", -1)
    _loaded["cars"] = cfg.get_value("world", "cars", [])
    _loaded["job"] = cfg.get_value("job", "active", false)
    _loaded["job_kind"] = cfg.get_value("job", "kind", "")
    _loaded["owned"] = cfg.get_value("world", "owned", [])
    var saved_look = cfg.get_value("player", "look", null)
    if saved_look is Dictionary:
        look.merge(saved_look, true)
    var saved_owned = cfg.get_value("player", "owned_clothes", null)
    if saved_owned is Dictionary:
        owned_clothes = saved_owned


# ---------------------------------------------------------------- ввод

func _setup_input() -> void:
    _add_keys("move_forward", [KEY_W, KEY_UP])
    _add_keys("move_back", [KEY_S, KEY_DOWN])
    _add_keys("move_left", [KEY_A, KEY_LEFT])
    _add_keys("move_right", [KEY_D, KEY_RIGHT])
    _add_keys("sprint", [KEY_SHIFT])
    _add_keys("jump", [KEY_SPACE])
    _add_keys("interact", [KEY_F, KEY_E])
    _add_keys("phone", [KEY_TAB, KEY_P])
    _add_keys("horn", [KEY_H])


func _add_keys(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = k
        InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- небо, свет, день и ночь

func _build_environment() -> void:
    _sky_mat = ProceduralSkyMaterial.new()
    _sky_mat.sky_top_color = DAY_TOP
    _sky_mat.sky_horizon_color = DAY_HORIZON
    _sky_mat.ground_horizon_color = DAY_HORIZON
    _sky_mat.ground_bottom_color = Color(0.25, 0.26, 0.24)
    var sky := Sky.new()
    sky.sky_material = _sky_mat
    sky.radiance_size = Sky.RADIANCE_SIZE_32

    _env = Environment.new()
    _env.background_mode = Environment.BG_SKY
    _env.sky = sky
    # Фоновый свет задаём цветом, а не от неба: так смена дня и ночи
    # не пересчитывает освещение от неба каждый раз (дорого на телефоне).
    _env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _env.ambient_light_color = DAY_AMBIENT
    _env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    _env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    _env.tonemap_exposure = 0.9
    _env.fog_enabled = true
    _env.fog_light_color = DAY_HORIZON
    _env.fog_density = 0.0025
    _env.fog_sky_affect = 0.3
    _env.glow_enabled = false

    var we := WorldEnvironment.new()
    we.environment = _env
    add_child(we)

    _sun = DirectionalLight3D.new()
    _sun.rotation_degrees = Vector3(-48, -35, 0)
    _sun.light_color = Color(1.0, 0.95, 0.86)
    _sun.light_energy = 1.05
    _sun.shadow_enabled = true
    _sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    _sun.directional_shadow_max_distance = 45.0
    add_child(_sun)


func _update_daylight() -> void:
    var h := minutes / 60.0
    var elev := sin((h - 6.0) / 12.0 * PI)          # > 0 днём, < 0 ночью
    var day_k := clampf(elev * 3.0 + 0.2, 0.0, 1.0)  # 0 — ночь, 1 — день
    var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)

    if elev > 0.0:
        _sun.rotation_degrees = Vector3(-(6.0 + 56.0 * elev), -35.0 + (h - 12.0) * 10.0, 0.0)
        _sun.light_color = Color(1.0, 0.70, 0.50).lerp(Color(1.0, 0.95, 0.86), clampf(elev * 2.5, 0.0, 1.0))
        _sun.light_energy = lerpf(0.2, 1.05, clampf(elev * 2.0, 0.0, 1.0))
        _sun.shadow_enabled = _shadows_on
    else:
        # Ночью «солнце» становится слабой луной без теней.
        _sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
        _sun.light_color = Color(0.55, 0.65, 0.95)
        _sun.light_energy = 0.15
        _sun.shadow_enabled = false

    var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day_k).lerp(DUSK_HORIZON, dusk * 0.6)
    _sky_mat.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, day_k)
    _sky_mat.sky_horizon_color = horizon
    _sky_mat.ground_horizon_color = horizon
    _env.fog_light_color = horizon
    _env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, day_k)
    _night_k = 1.0 - day_k
    if _city:
        if _city.lamp_mat:
            _city.lamp_mat.emission_energy_multiplier = lerpf(4.0, 0.4, day_k)
        _city.set_night(_night_k)
    CarModel.set_night(_night_k)
    for car in _cars:
        car.set_night(_night_k > 0.4)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    _touch = TouchControlsScript.new()
    _touch.pads_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
    _touch.look_drag.connect(_on_look)
    _touch.interact_pressed.connect(_on_interact)
    _touch.phone_pressed.connect(_toggle_phone)
    _touch.horn_pressed.connect(_on_horn)
    _touch.hudmenu_pressed.connect(func() -> void: _hud.profile.toggle_popup())
    layer.add_child(_touch)

    _hud = HudScript.new()
    layer.add_child(_hud)
    _hud.minimap.city = _city
    _hud.job_selected.connect(_on_job_selected)
    _hud.job_stopped.connect(_on_job_stopped)
    _hud.summon_car.connect(_on_summon_car)
    _hud.phone_closed.connect(_on_phone_closed)
    _hud.menu_requested.connect(_open_menu)
    _hud.profile.opened.connect(_on_profile_opened)
    _hud.profile.closed.connect(_on_profile_closed)

    _wardrobe = WardrobeScript.new()
    layer.add_child(_wardrobe)
    _wardrobe.preview_changed.connect(_on_wardrobe_preview)
    _wardrobe.buy_pressed.connect(_on_wardrobe_buy)
    _wardrobe.closed.connect(_on_wardrobe_closed)

    _dialog = DialogScript.new()
    layer.add_child(_dialog)
    _dialog.closed.connect(_on_dialog_closed)

    var menu_layer := CanvasLayer.new()
    menu_layer.layer = 10
    add_child(menu_layer)
    _menu = MenuScript.new()
    menu_layer.add_child(_menu)
    _menu.play_pressed.connect(_on_play)
    _menu.quit_pressed.connect(_on_quit)
    _menu.reset_pressed.connect(_on_reset)
    _menu.settings_changed.connect(_apply_settings)

    _label = Label.new()
    _label.position = Vector2(560, 6)
    var ls := LabelSettings.new()
    ls.font_size = 14
    ls.font_color = Color(1, 1, 1, 0.8)
    ls.outline_size = 4
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


# ================================================================ точки, документы, банк, АЗС, работы

func _add_point(pos: Vector3, r: float, text: String, cb: Callable, in_car := false, color := Color(1, 0.8, 0.1)) -> void:
    _points.append({"pos": pos, "r": r, "text": text, "cb": cb, "car": in_car})
    _hud.minimap.points.append([pos, color])


func _setup_points() -> void:
    _add_point(_city.clothes_shop, 3.5, "ОДЕЖДА", _open_wardrobe, false, Color(0.8, 0.4, 0.8))
    _add_point(_city.city_hall, 3.5, "МЭРИЯ", _open_city_hall, false, Color(0.4, 0.5, 1.0))
    _add_point(_city.driving_school, 3.5, "АВТОШКОЛА", _open_driving_school, false, Color(1.0, 0.6, 0.1))
    for p: Vector3 in _city.atms:
        _add_point(p, 2.2, "БАНКОМАТ", _open_atm, false, Color(0.2, 0.6, 1.0))
    for p: Vector3 in _city.fuel_pumps:
        _add_point(p, 5.5, "ЗАПРАВИТЬ", _open_fuel, true, Color(0.9, 0.2, 0.2))
    _add_point(_city.bus_depot, 3.0, "АВТОБУС", _start_work.bind("bus"))
    _add_point(_city.warehouse_drop + Vector3(4, 0, 0), 2.5, "ГРУЗЧИК", _start_work.bind("loader"))
    _add_point(_city.truck_depot, 3.0, "ДАЛЬНОБОЙ", _start_work.bind("truck"))
    _add_point(_city.log_pile + Vector3(4, 0, 0), 3.0, "ЛЕСОРУБ", _start_work.bind("lumber"))


## Ближайшая доступная точка: пешком — «пешие», в своей машине на месте — «машинные».
func _find_point(focus: Vector3, speed: float):
    if _dialog.visible or _wardrobe.visible:
        return null
    var best = null
    var best_d := INF
    for pt: Dictionary in _points:
        var need_car: bool = pt["car"]
        if need_car:
            if _driving == null or not _driving.uses_fuel or speed > 3.0:
                continue
        elif _driving != null:
            continue
        var pp: Vector3 = pt["pos"]
        var d := Vector2(focus.x - pp.x, focus.z - pp.z).length()
        if d < float(pt["r"]) and d < best_d:
            best_d = d
            best = pt
    return best


func _open_dialog(title: String, text: String, buttons: Array, input_hint := "") -> void:
    _touch.blocked = true
    _dialog.open(title, text, buttons, input_hint)


func _on_dialog_closed() -> void:
    _touch.blocked = false


## Есть ли документы для работы. need_license — нужны права.
func _check_docs(need_license: bool) -> bool:
    if passport_name == "":
        Sfx.play("error")
        _hud.show_toast("Без паспорта на работу не берут — получи его в МЭРИИ на площади")
        return false
    if need_license and not has_license:
        Sfx.play("error")
        _hud.show_toast("Нужны права — сдай экзамен в АВТОШКОЛЕ на площади")
        return false
    return true


# ---------------------------------------------------------------- мэрия

func _open_city_hall() -> void:
    if passport_name != "":
        _open_dialog("Мэрия", "Паспорт уже выдан.\n\nГражданин: %s" % passport_name,
                [["Закрыть", _dialog.close]])
        return
    _open_dialog("Мэрия — паспорт",
            "Впиши имя и фамилию через подчёркивание, с больших букв.\nНапример: Иван_Петров",
            [["Получить паспорт", _issue_passport], ["Закрыть", _dialog.close]], "Имя_Фамилия")


func _issue_passport() -> void:
    var name_text := _dialog.input_text()
    var re := RegEx.new()
    re.compile("^[А-ЯЁA-Z][а-яёa-z]{1,15}_[А-ЯЁA-Z][а-яёa-z]{1,20}$")
    if re.search(name_text) == null:
        Sfx.play("error")
        _hud.show_toast("Неверный формат. Пример: Иван_Петров")
        return
    passport_name = name_text
    _ensure_numbers()
    _add_xp(20)
    Sfx.play("coin")
    _dialog.close()
    _hud.show_toast("Паспорт получен! Добро пожаловать, %s" % passport_name)
    _save_game()


# ---------------------------------------------------------------- автошкола

func _open_driving_school() -> void:
    if has_license:
        _open_dialog("Автошкола", "Права уже есть. Удачи на дорогах!", [["Закрыть", _dialog.close]])
        return
    if passport_name == "":
        _open_dialog("Автошкола", "Для записи нужен паспорт. Получи его в мэрии на площади.",
                [["Закрыть", _dialog.close]])
        return
    _open_dialog("Автошкола", ("Экзамен на права категории B:\n1) теория — 5 вопросов, нужно 4 верных;\n"
            + "2) вождение — проехать по меткам вокруг площади не быстрее 70 км/ч.\n\nСтоимость: %d ₽") % EXAM_PRICE,
            [["Оплатить и начать", _start_quiz], ["Закрыть", _dialog.close]])


func _start_quiz() -> void:
    if not _pay(EXAM_PRICE, "Автошкола"):
        return
    _quiz = QUIZ.duplicate()
    _quiz.shuffle()
    _quiz = _quiz.slice(0, 5)
    _quiz_i = 0
    _quiz_ok = 0
    _show_question()


func _show_question() -> void:
    var q: Array = _quiz[_quiz_i]
    var answers: Array = q[1]
    var buttons := []
    for i in answers.size():
        buttons.append([answers[i], _answer.bind(i == int(q[2]))])
    _open_dialog("Теория: вопрос %d/5" % (_quiz_i + 1), q[0], buttons)


func _answer(correct: bool) -> void:
    if correct:
        _quiz_ok += 1
    _quiz_i += 1
    if _quiz_i < _quiz.size():
        _show_question()
        return
    if _quiz_ok >= 4:
        _open_dialog("Теория сдана", "Верных ответов: %d из 5.\nТеперь вождение: учебная машина уже ждёт." % _quiz_ok,
                [["Начать вождение", _start_exam_drive]])
    else:
        Sfx.play("error")
        _open_dialog("Теория не сдана", "Верных ответов: %d из 5, нужно 4.\nПопробуй ещё раз (экзамен оплачивается заново)." % _quiz_ok,
                [["Закрыть", _dialog.close]])


func _start_exam_drive() -> void:
    _dialog.close()
    _job.stop()
    _work.stop()
    _work.start("exam")


func _on_exam_finished(passed: bool, text: String) -> void:
    if passed:
        has_license = true
        _add_xp(50)
        Sfx.play("coin")
        _save_game()
    else:
        Sfx.play("error")
    _hud.show_toast(text)


# ---------------------------------------------------------------- банкомат

func _open_atm() -> void:
    _open_dialog("Банкомат", "Наличные: %s\nНа карте: %s\n\nЗарплата приходит на карту. Покупки — наличными, а если не хватает, то с карты."
            % [HudScript.format_money(cash), HudScript.format_money(bank)],
            [["Снять 1 000", _atm_withdraw.bind(1000)], ["Снять 5 000", _atm_withdraw.bind(5000)],
            ["Снять всё", _atm_withdraw.bind(-1)], ["Положить все наличные", _atm_deposit],
            ["Закрыть", _dialog.close]])


func _atm_withdraw(amount: int) -> void:
    var a := bank if amount < 0 else mini(amount, bank)
    if a <= 0:
        Sfx.play("error")
        _hud.show_toast("На карте нет денег")
        return
    bank -= a
    cash += a
    _bank_log(-a, "Снятие наличных")
    Sfx.play("coin")
    _open_atm()


func _atm_deposit() -> void:
    if cash <= 0:
        Sfx.play("error")
        return
    _bank_log(cash, "Пополнение наличными")
    bank += cash
    cash = 0
    Sfx.play("coin")
    _open_atm()


# ---------------------------------------------------------------- АЗС

func _open_fuel() -> void:
    var car = _driving
    if car == null:
        return
    var need := int(ceil(car.tank - car.fuel))
    _open_dialog("АЗС", "Бензин: %d из %d л\nЦена: %d ₽ за литр" % [int(car.fuel), int(car.tank), FUEL_PRICE],
            [["+10 л (%d ₽)" % (FUEL_PRICE * 10), _refuel.bind(10)],
            ["Полный бак (%d ₽)" % (FUEL_PRICE * need), _refuel.bind(need)],
            ["Закрыть", _dialog.close]])


func _refuel(liters: int) -> void:
    var car = _driving
    if car == null:
        _dialog.close()
        return
    var l := mini(liters, int(ceil(car.tank - car.fuel)))
    if l <= 0:
        _hud.show_toast("Бак уже полный")
        return
    if not _pay(l * FUEL_PRICE, "АЗС: %d л" % l):
        return
    car.fuel = minf(car.tank, car.fuel + l)
    Sfx.play("coin")
    _open_fuel()


# ---------------------------------------------------------------- ДПС

## Ездишь без прав в своей машине — патруль может остановить и оштрафовать.
func _check_dps(delta: float, speed: float) -> void:
    if _driving == null or has_license or _driving == _work_vehicle or absf(speed) < 30.0:
        return
    _dps_timer -= delta
    if _dps_timer > 0.0:
        return
    _dps_timer = 40.0
    if randf() < 0.4:
        var fine := mini(DPS_FINE, cash + bank)
        var from_cash := mini(cash, fine)
        cash -= from_cash
        bank -= fine - from_cash
        if fine - from_cash > 0:
            _bank_log(-(fine - from_cash), "Штраф ДПС")
        Sfx.play("error")
        _hud.show_toast("Тебя остановил ДПС: езда без прав. Штраф %d ₽" % fine)


# ---------------------------------------------------------------- работы на месте

func _start_work(kind: String) -> void:
    if _work.active and _work.kind == kind:
        _open_dialog("Работа", "Ты уже работаешь здесь. Закончить смену?",
                [["Закончить смену", _stop_work_from_dialog], ["Продолжить", _dialog.close]])
        return
    if not _check_docs(kind == "bus" or kind == "truck"):
        return
    _job.stop()
    _work.stop()
    _work.start(kind)


func _stop_work_from_dialog() -> void:
    _dialog.close()
    _work.stop()
    _hud.show_toast("Смена закончена")


func _on_work_vehicle_needed(vehicle_kind: String, at: Transform3D) -> void:
    if _driving:  # выходим из своей машины
        var pos: Vector3 = _driving.get_exit_position()
        _driving.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
    var v = CarScene.instantiate()
    v.owned = true
    v.price = 0
    v.uses_fuel = false
    match vehicle_kind:
        "bus":
            v.kind = "bus"
            v.car_name = "Автобус"
            v.paint = Color(0.95, 0.75, 0.15)
            v.max_engine_force = 18000.0
            v.max_speed_kmh = 80.0
            v.brake_force = 150.0
            v.max_steer = 0.5
        "truck":
            v.kind = "truck"
            v.car_name = "Фура"
            v.paint = Color(0.15, 0.30, 0.65)
            v.max_engine_force = 22000.0
            v.max_speed_kmh = 90.0
            v.brake_force = 180.0
            v.max_steer = 0.5
        _:
            v.car_name = "Учебная"
            v.paint = Color(0.95, 0.95, 0.95)
            v.max_engine_force = 4200.0
            v.max_speed_kmh = 110.0
    v.transform = at
    add_child(v)
    v.touch = _touch
    v.set_night(_night_k > 0.4)
    _work_vehicle = v
    _traffic.obstacles.append(v)
    _peds.cars.append(v)
    _player.set_active(false)
    v.set_driven(true)
    _driving = v
    for cam in get_tree().get_nodes_in_group("game_camera"):
        cam.far = _view_far


func _on_work_vehicle_done() -> void:
    var v = _work_vehicle
    if v == null:
        return
    if _driving == v:
        var pos: Vector3 = v.get_exit_position()
        v.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
    _traffic.obstacles.erase(v)
    _peds.cars.erase(v)
    _work_vehicle = null
    v.queue_free()
