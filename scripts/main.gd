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
const ListWindowScript := preload("res://scripts/list_window.gd")
const MarkerScript := preload("res://scripts/marker.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const WorkScript := preload("res://scripts/work.gd")
const FactionData := preload("res://scripts/faction_data.gd")
const FactionMenuScript := preload("res://scripts/faction_menu.gd")

const VERSION := "v0.15"
const SAVE_PATH := "user://save.cfg"
const START_MONEY := 5000
const GAME_MINUTES_PER_SECOND := 1.0   # 1 реальная секунда = 1 игровая минута
## Машины на Общем рынке: название, цена, цвет, макс. скорость, мощность.
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
const PAYDAY_MINUTES := 180.0   # получка во фракции — раз в 3 игровых часа
const HUNGER_PER_MINUTE := 0.12  # сытость тратится: 100 -> 0 примерно за 14 игровых часов (14 мин)
const TREAT_PRICE := 300         # лечение в больнице
## Еда и лекарства в ларьках: [название, цена, +сытость, +здоровье].
const FOOD := {
    "ШАУРМА": [["Шаурма", 250, 45, 0], ["Шаурма двойная", 380, 70, 0], ["Чай", 50, 5, 2]],
    "ПРОДУКТЫ": [["Хлеб", 60, 15, 0], ["Бутерброд", 120, 25, 0], ["Кефир", 90, 15, 2], ["Пельмени", 300, 55, 0]],
    "КОФЕ": [["Кофе", 120, 10, 3], ["Пирожок", 80, 20, 0], ["Круассан", 150, 25, 0]],
    "КВАС": [["Квас", 70, 8, 2], ["Пирожок", 80, 20, 0]],
    "УНИВЕРСАМ": [["Батон", 50, 15, 0], ["Колбаса", 250, 40, 0], ["Комплексный обед", 450, 80, 5]],
    "АПТЕКА": [["Аптечка", 400, 0, 40], ["Бинт", 150, 0, 15], ["Витамины", 200, 5, 10]],
}
const CANISTER_PRICE := 600
const PHONE_PRICE := 1000
const MARKET_CATS := [
    {"id": "cars", "name": "Транспорт", "icon": "car"},
    {"id": "clothes", "name": "Одежда", "icon": "shirt"},
    {"id": "other", "name": "Прочее", "icon": "dots"},
]
const NAV_CATS := [
    {"id": "home", "name": "Дом", "icon": "house"},
    {"id": "work", "name": "Работа", "icon": "briefcase"},
    {"id": "market", "name": "Рынок", "icon": "car"},
    {"id": "shops", "name": "Магазины", "icon": "cart"},
    {"id": "hospital", "name": "Больницы", "icon": "cross"},
    {"id": "police", "name": "Полиция", "icon": "shield"},
    {"id": "bank", "name": "Банки", "icon": "bank"},
    {"id": "fuel", "name": "АЗС", "icon": "fuel"},
    {"id": "service", "name": "Сервисы", "icon": "wrench"},
    {"id": "fun", "name": "Развлечения", "icon": "star"},
    {"id": "other", "name": "Другое", "icon": "dots"},
]
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
const DAY_AMBIENT := Color(0.36, 0.40, 0.48)
const NIGHT_AMBIENT := Color(0.05, 0.06, 0.12)

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
var faction := ""            # id фракции ("mayor", "police"...), пусто — не во фракции
var faction_rank := 0        # 1..6
var faction_exp := 0         # стаж: сколько получек получено на текущем ранге
var _payday_acc := 0.0       # игровых минут с последней получки
var _faction_car = null      # машина из автопарка (одна на игрока)
var _interior := ""          # в каком здании игрок ("" — на улице)
var health := 100.0          # здоровье 0..100
var hunger := 100.0          # сытость 0..100 (0 — голодный, теряешь здоровье)
var home := -1               # номер купленного жилья в _city.homes, -1 — нет
var _home_inside := -1       # в каком жилье сейчас игрок
var _fridge_at := -9999.0    # когда последний раз ели из холодильника (игровые минуты)
var _starve_acc := 0.0
var _regen_acc := 0.0
var _last_kmh := 0.0
var _last_vy := 0.0
var _beat_t := 0.0
var _home_map_point = null
var faction_news: Array = []  # объявления организации: [текст, автор]
var _fmenu: FactionMenuScript

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
var _win: ListWindowScript     # большое окно: Навигатор или Общий рынок
var _win_mode := ""            # "gps" / "market"
var _win_payload: Array = []   # что стоит за каждой строкой списка
var _preview_look := {}
var _gps_target = null         # Vector3 — куда ведёт навигатор
var _gps_name := ""
var _gps_marker: MarkerScript
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
var _sky_sh: ShaderMaterial = null   # небо с облаками и звёздами (если есть текстура облаков)
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
    _hud.profile.set_faction_visible(faction != "")
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
    _update_vitals(delta, speed)
    if _driving and not Music.is_radio():
        Music.play_radio()
    elif not _driving and Music.is_radio():
        Music.stop()
    if faction != "":
        _payday_acc += delta * GAME_MINUTES_PER_SECOND
        if _payday_acc >= PAYDAY_MINUTES:
            _payday_acc = 0.0
            _faction_payday()
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
        _touch.interact_text = "СЕСТЬ"
    else:
        _touch.interact_text = ""

    # Интерфейс
    _hud.set_money(cash, bank)
    _hud.set_vitals(health, hunger)
    _hud.set_nick(passport_name)
    if _hud.profile.is_open():
        _hud.profile.set_data(_profile_data())
    if _fmenu.visible:
        _fmenu.set_data(_fmenu_data())
    var hh := int(minutes) / 60
    var mm := int(minutes) % 60
    var clock := "%02d:%02d   День %d" % [hh, mm, day]
    if _gps_target != null:
        var gd := Vector2(focus.x - _gps_target.x, focus.z - _gps_target.z).length()
        clock += "   ·   GPS: %s — %s" % [_gps_name, _dist_text(gd)]
        _gps_marker.update_distance(focus)
        if gd < 12.0:
            Sfx.play("notify")
            _hud.show_toast("Вы прибыли: %s" % _gps_name)
            _clear_gps()
    _hud.set_clock(clock)
    var job_text: String = _work.status_text(focus, in_work_vehicle) if _work.active \
            else _job.status_text(focus, _driving != null)
    _hud.set_job(job_text)
    if _hud.phone_open:
        _hud.update_phone(_job.active or _work.active, _phone_text(job_text))

    var mini := _hud.minimap
    mini.focus = focus
    if _interior != "":   # в здании карта показывает, где стоит само здание
        mini.focus = _city.faction_sites[_interior]["door"]
    elif _home_inside >= 0:
        mini.focus = _city.homes[_home_inside]["pos"]
    mini.heading = _driving.global_transform.basis.z if _driving else _player.get_facing()
    if _work.active:
        mini.has_target = _work.has_target()
        mini.target = _work.target
        mini.target_color = _work.target_color()
    else:
        mini.has_target = _job.has_target()
        mini.target = _job.target
        mini.target_color = _job.target_color()
    mini.has_gps = _gps_target != null
    if _gps_target != null:
        mini.gps_target = _gps_target
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
    elif event.is_action_pressed("radio"):
        _on_radio()


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
    _win.close_window()
    _fmenu.close_menu()
    get_tree().paused = true
    _touch.visible = false
    _menu.show_menu(_started, VERSION)
    Music.play_menu()


func _on_play() -> void:
    Sfx.start_ambient()
    if not _started and passport_name == "":
        _hud.show_toast("Получи паспорт в МЭРИИ (паспортный стол) — синяя точка на карте")
    _started = true
    _menu.visible = false
    _touch.visible = true
    get_tree().paused = false
    Music.stop()


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
        _cars[i].set_available(false)
        _cars[i].fuel = _cars[i].tank
    look = Clothes.default_look()
    owned_clothes = {}
    _despawn_faction_car()
    _set_faction("", 0)
    _interior = ""
    health = 100.0
    hunger = 100.0
    _set_home(-1)
    _home_inside = -1
    _clear_gps()
    _player.set_look(Clothes.colors(look), Clothes.textures(look))
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
    Music.volume = _menu.music_volume()
    _update_daylight()


func _focus() -> Vector3:
    return _driving.global_position if _driving else _player.global_position


# ---------------------------------------------------------------- телефон и работа

func _toggle_phone() -> void:
    if _win.visible or _dialog.visible or _hud.profile.is_open() or _fmenu.visible:
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
        _hud.show_toast("Для такси нужна своя машина — купи на Общем рынке на площади")
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
    var docs := "Паспорт: %s\nПрава: %s" % [passport_name if passport_name != "" else "нет (паспортный стол в мэрии)",
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
        _hud.show_toast("У тебя нет машины — купи на Общем рынке на площади")
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
        Sfx.play("levelup")
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
            "phone": phone_number, "home": _home_text(), "org": _org_text(),
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
        if _driving.has_lights:   # у служебных машин кнопка включает сирену
            _driving.toggle_siren()
            _hud.show_toast("Сирена включена" if _driving.siren_on else "Сирена выключена")
            return
        Sfx.play("horn", -3.0)


func _on_radio() -> void:
    if _driving:
        Sfx.play("click")
        _hud.show_toast(Music.next_station())


func _on_step(run: bool) -> void:
    Sfx.play("step", -8.0 if run else -12.0, randf_range(0.85, 1.15))


# ---------------------------------------------------------------- машины

## Кнопка действия: сначала работа, потом точка рядом, потом машина.
func _on_interact() -> void:
    if _hud.phone_open or _win.visible or _dialog.visible or _hud.profile.is_open() or _fmenu.visible:
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
        _player.set_active(false)
        car.set_driven(true)
        _driving = car


func _nearest_car():
    var best = null
    var best_d := ENTER_DISTANCE
    var all: Array = _cars.duplicate()
    if _work_vehicle != null:
        all.append(_work_vehicle)
    if _faction_car != null:
        all.append(_faction_car)
    for car in all:
        if not car.owned or not car.visible:
            continue
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
        l.omni_range = 9.0
        l.omni_attenuation = 2.2   # свет быстро гаснет — стены рядом не «выбеливаются»
        l.light_energy = 0.4
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
            l.light_energy = 0.4 * _night_k


var _sort_focus := Vector3.ZERO


func _closer_to_focus(a: Vector3, b: Vector3) -> bool:
    return a.distance_squared_to(_sort_focus) < b.distance_squared_to(_sort_focus)


## Стоянка у рынка: сюда доставляют купленные машины.
func _car_spawn(i: int) -> Transform3D:
    var xs := [-16.0, -10.0, 10.0, 16.0]
    return Transform3D(Basis(), Vector3(xs[i % xs.size()], 0.6, 20.0))


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
            if pos.y > -5.0 and not _inside_building(pos):
                car.position = pos + Vector3.UP * 0.3
                car.rotation.y = float(e[1])
        add_child(car)
        car.touch = _touch
        car.set_available(car.owned)   # некупленные машины «лежат на складе» рынка
        _cars.append(car)
    _hud.minimap.cars = _cars

    _gps_marker = MarkerScript.new()
    add_child(_gps_marker)


func _spawn_player() -> void:
    _player = PlayerScene.instantiate()
    _player.position = PLAYER_SPAWN
    var lp = _loaded.get("player_pos")
    if lp is Vector3 and lp.y > -5.0 and not _inside_building(lp):
        _player.position = lp + Vector3.UP * 0.3
    add_child(_player)
    _player.touch = _touch
    _player.set_look(Clothes.colors(look), Clothes.textures(look))
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
    if _driving and (_driving == _work_vehicle or _driving == _faction_car):
        cfg.set_value("player", "pos", _driving.global_position + Vector3(3, 0.5, 0))
    if _interior != "":   # сохраняемся «у входа», а не в комнате
        cfg.set_value("player", "pos", _city.faction_sites[_interior]["out"])
    if _home_inside >= 0:
        cfg.set_value("player", "pos", _city.homes[_home_inside]["pos"] + Vector3(0, 0.3, 0))
    cfg.set_value("player", "health", health)
    cfg.set_value("player", "hunger", hunger)
    cfg.set_value("player", "home", home)
    cfg.set_value("player", "fridge", _fridge_at)
    cfg.set_value("faction", "id", faction)
    cfg.set_value("faction", "rank", faction_rank)
    cfg.set_value("faction", "exp", faction_exp)
    cfg.set_value("faction", "payday", _payday_acc)
    cfg.set_value("faction", "news", faction_news)
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
    health = clampf(float(cfg.get_value("player", "health", 100.0)), 1.0, 100.0)
    hunger = clampf(float(cfg.get_value("player", "hunger", 100.0)), 0.0, 100.0)
    _loaded["home"] = int(cfg.get_value("player", "home", -1))
    _fridge_at = float(cfg.get_value("player", "fridge", -9999.0))
    faction = String(cfg.get_value("faction", "id", ""))
    faction_rank = int(cfg.get_value("faction", "rank", 0))
    faction_exp = int(cfg.get_value("faction", "exp", 0))
    _payday_acc = float(cfg.get_value("faction", "payday", 0.0))
    faction_news = cfg.get_value("faction", "news", [])
    if FactionData.get_faction(faction).is_empty():
        faction = ""
        faction_rank = 0
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
    _add_keys("radio", [KEY_R])


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
    if ResourceLoader.exists("res://shaders/sky.gdshader") and ResourceLoader.exists("res://textures/sky_clouds.png"):
        _sky_sh = ShaderMaterial.new()
        _sky_sh.shader = load("res://shaders/sky.gdshader")
        var ct: Texture2D = load("res://textures/sky_clouds.png")
        var img := ct.get_image()
        if img:
            if img.is_compressed():
                img.decompress()
            img.generate_mipmaps()
            ct = ImageTexture.create_from_image(img)
        _sky_sh.set_shader_parameter("clouds", ct)
        sky.sky_material = _sky_sh
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
    _env.tonemap_exposure = 0.8
    # Чуть больше контраста и цвета — фото-текстуры не выглядят «выгоревшими».
    _env.adjustment_enabled = true
    _env.adjustment_contrast = 1.12
    _env.adjustment_saturation = 1.15
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
    _sun.light_energy = 0.95
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
        _sun.light_energy = lerpf(0.2, 0.95, clampf(elev * 2.0, 0.0, 1.0))
        _sun.shadow_enabled = _shadows_on
    else:
        # Ночью «солнце» становится слабой луной без теней.
        _sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
        _sun.light_color = Color(0.55, 0.65, 0.95)
        _sun.light_energy = 0.07
        _sun.shadow_enabled = false

    var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, day_k).lerp(DUSK_HORIZON, dusk * 0.6)
    _sky_mat.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, day_k)
    _sky_mat.sky_horizon_color = horizon
    _sky_mat.ground_horizon_color = horizon
    _env.fog_light_color = horizon
    if _sky_sh:
        var cl := Color(1, 1, 1).lerp(Color(1.0, 0.70, 0.55), dusk).lerp(Color(0.22, 0.24, 0.32), 1.0 - day_k)
        _sky_sh.set_shader_parameter("top_color", NIGHT_TOP.lerp(DAY_TOP, day_k))
        _sky_sh.set_shader_parameter("horizon_color", horizon)
        _sky_sh.set_shader_parameter("cloud_light", cl)
        _sky_sh.set_shader_parameter("cloud_dark", cl.darkened(0.35))
        _sky_sh.set_shader_parameter("cloud_alpha", lerpf(0.55, 1.0, day_k))
        _sky_sh.set_shader_parameter("stars", clampf((1.0 - day_k) * 1.3 - 0.3, 0.0, 1.0))
        _sky_sh.set_shader_parameter("sun_dir", _sun.global_transform.basis.z)
        _sky_sh.set_shader_parameter("sun_color", _sun.light_color)
        _sky_sh.set_shader_parameter("sun_strength", clampf(elev * 3.0, 0.0, 1.0))
        _sky_sh.set_shader_parameter("drift", minutes / 1440.0 * 0.5)  # облака медленно плывут
    _env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, day_k)
    _env.tonemap_exposure = lerpf(0.62, 0.8, day_k)   # ночью картинка темнее
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
    _touch.radio_pressed.connect(_on_radio)
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
    _hud.profile.navigator_requested.connect(_open_gps)
    _hud.profile.faction_requested.connect(_open_faction_menu)

    _win = ListWindowScript.new()
    layer.add_child(_win)
    _win.category_selected.connect(_on_win_category)
    _win.row_selected.connect(_on_win_row)
    _win.search_changed.connect(_on_win_search)
    _win.left_pressed.connect(_on_win_left)
    _win.right_pressed.connect(_on_win_right)
    _win.closed.connect(_on_win_closed)

    _fmenu = FactionMenuScript.new()
    layer.add_child(_fmenu)
    _fmenu.closed.connect(_on_fmenu_closed)
    _fmenu.gps_requested.connect(_on_fmenu_gps)
    _fmenu.leave_requested.connect(_confirm_leave)
    _fmenu.spawn_requested.connect(_on_fmenu_spawn)
    _fmenu.announce_posted.connect(_on_fmenu_news)

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

func _add_point(pos: Vector3, r: float, text: String, cb: Callable, in_car := false, color := Color(1, 0.8, 0.1), on_map := true) -> void:
    _points.append({"pos": pos, "r": r, "text": text, "cb": cb, "car": in_car})
    if on_map:
        _hud.minimap.points.append([pos, color])


func _setup_points() -> void:
    _add_point(_city.market, 4.0, "РЫНОК", _open_market, false, Color(1.0, 0.7, 0.1))
    for fid: String in _city.faction_sites:
        var site: Dictionary = _city.faction_sites[fid]
        var inn: Dictionary = _city.interiors[fid]
        var fc: Color = FactionData.get_faction(fid)["color"]
        if fid == "mayor":
            fc = Color(0.4, 0.5, 1.0)
        _add_point(site["door"], 2.6, "ВОЙТИ", _enter_building.bind(fid), false, fc)
        _add_point(site["marker"], 2.0, "АВТОПАРК", _open_garage.bind(fid), false, Color(1.0, 0.15, 0.1))
        _add_point(inn["exit"], 2.0, "ВЫЙТИ", _exit_building.bind(fid), false, fc, false)
        _add_point(inn["hr"], 2.0, "СМОТРЯЩИЙ" if FactionData.is_gang(fid) else "ОТДЕЛ КАДРОВ",
                _open_hr.bind(fid), false, fc, false)
        if fid == "mayor":
            _add_point(inn["desk"], 2.0, "ПАСПОРТ", _open_city_hall, false, fc, false)
    _add_point(_city.driving_school, 3.5, "АВТОШКОЛА", _open_driving_school, false, Color(1.0, 0.6, 0.1))
    for p: Vector3 in _city.atms:
        _add_point(p, 2.2, "БАНКОМАТ", _open_atm, false, Color(0.2, 0.6, 1.0))
    for pk: Dictionary in _city.pickups:
        var kname := String(pk["name"])
        if FOOD.has(kname):
            _add_point(pk["pos"], 2.4, "АПТЕКА" if kname == "АПТЕКА" else "ЕДА", _open_food.bind(kname), false,
                    Color(1.0, 0.5, 0.2), false)
    if _city.interiors.has("hospital"):
        _add_point(_city.interiors["hospital"]["desk"], 2.0, "ЛЕЧЕНИЕ", _open_treatment, false, Color.WHITE, false)
    for i in _city.homes.size():
        var hm: Dictionary = _city.homes[i]
        _add_point(hm["pos"], 1.6, "ДОМ", _open_home.bind(i), false, Color.WHITE, false)
    for kind: String in _city.home_interiors:
        var hi: Dictionary = _city.home_interiors[kind]
        _add_point(hi["exit"], 1.4, "ВЫЙТИ", _exit_home, false, Color.WHITE, false)
        _add_point(hi["fridge"], 1.5, "ХОЛОДИЛЬНИК", _use_fridge, false, Color.WHITE, false)
        _add_point(hi["bed"], 1.6, "ОТДОХНУТЬ", _use_bed, false, Color.WHITE, false)
    _set_home(int(_loaded.get("home", -1)))
    for p: Vector3 in _city.fuel_pumps:
        _add_point(p, 5.5, "ЗАПРАВИТЬ", _open_fuel, true, Color(0.9, 0.2, 0.2))
    _add_point(_city.bus_depot, 3.0, "АВТОБУС", _start_work.bind("bus"))
    _add_point(_city.warehouse_drop + Vector3(4, 0, 0), 2.5, "ГРУЗЧИК", _start_work.bind("loader"))
    _add_point(_city.truck_depot, 3.0, "ДАЛЬНОБОЙ", _start_work.bind("truck"))
    _add_point(_city.log_pile + Vector3(4, 0, 0), 3.0, "ЛЕСОРУБ", _start_work.bind("lumber"))


## Ближайшая доступная точка: пешком — «пешие», в своей машине на месте — «машинные».
func _find_point(focus: Vector3, speed: float):
    if _dialog.visible or _win.visible or _fmenu.visible:
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
    _touch.blocked = _fmenu.visible


## Есть ли документы для работы. need_license — нужны права.
func _check_docs(need_license: bool) -> bool:
    if passport_name == "":
        Sfx.play("error")
        _hud.show_toast("Без паспорта на работу не берут — получи его в МЭРИИ (синяя точка на карте)")
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
        _open_dialog("Автошкола", "Для записи нужен паспорт. Получи его в мэрии (синяя точка на карте).",
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


# ================================================================ большое окно: Навигатор и Общий рынок

func _open_gps() -> void:
    _touch.blocked = true
    _win_mode = "gps"
    _win.open_window("GPS", "pin", NAV_CATS, true, "Поиск по GPS...")


func _open_market() -> void:
    _touch.blocked = true
    _win_mode = "market"
    _preview_look = look.duplicate()
    _win.open_window("РЫНОК", "cart", MARKET_CATS, false)


func _on_win_closed() -> void:
    if _win_mode == "market":
        _player.set_look(Clothes.colors(look), Clothes.textures(look))   # снять примерку
    _win_mode = ""
    _touch.blocked = false


func _on_win_category(_id: String) -> void:
    _refresh_win(false)


func _on_win_search(_text: String) -> void:
    _refresh_win(false)


func _on_win_row(i: int) -> void:
    if _win_mode == "market" and i < _win_payload.size():
        var p = _win_payload[i]
        if p is Dictionary and p["type"] == "cloth":
            _preview_look = look.duplicate()
            _preview_look[p["slot"]] = p["i"]
            _player.set_look(Clothes.colors(_preview_look), Clothes.textures(_preview_look))
    _update_win_buttons()


func _refresh_win(keep_selection: bool) -> void:
    var rows := []
    _win_payload = []
    if _win_mode == "gps":
        _fill_gps_rows(rows)
    elif _win_mode == "garage":
        _fill_garage_rows(rows)
    else:
        _fill_market_rows(rows)
    _win.set_rows(rows, keep_selection)
    _update_win_buttons()


func _selected_payload():
    var i := _win.selected
    if i < 0 or i >= _win_payload.size():
        return null
    return _win_payload[i]


func _update_win_buttons() -> void:
    var p = _selected_payload()
    if _win_mode == "gps":
        if p == null and _gps_target != null:
            _win.set_buttons("Убрать метку", "Установить метку", true, false)
        else:
            _win.set_buttons("Отметить на карте", "Установить метку", p != null, p != null)
        return
    if _win_mode == "garage":
        if p == null:
            _win.set_buttons("Закрыть", "Выбери машину", true, false)
        elif faction_rank < int(p["rank"]):
            _win.set_buttons("Закрыть", "Нужен ранг %d" % int(p["rank"]), true, false)
        else:
            _win.set_buttons("Закрыть", "Взять машину", true, true)
        return
    # рынок
    if p == null:
        _win.set_buttons("Закрыть", "Выбери товар", true, false)
        return
    match String(p["type"]):
        "car":
            var car = _cars[int(p["i"])]
            if car.owned:
                _win.set_buttons("Закрыть", "Подогнать к рынку", true, true)
            else:
                _win.set_buttons("Закрыть", "Купить за %s" % HudScript.format_money(int(car.price)), true, true)
        "cloth":
            var slot: String = p["slot"]
            var idx: int = p["i"]
            if int(look.get(slot, 0)) == idx:
                _win.set_buttons("Закрыть", "Надето", true, false)
            elif _cloth_owned(slot, idx):
                _win.set_buttons("Закрыть", "Надеть", true, true)
            else:
                _win.set_buttons("Закрыть", "Купить за %s" % HudScript.format_money(int(p["price"])), true, true)
        _:
            _win.set_buttons("Закрыть", "Купить за %s" % HudScript.format_money(int(p["price"])), true, true)


func _on_win_left() -> void:
    if _win_mode == "market" or _win_mode == "garage":
        _win.close_window()
        return
    var p = _selected_payload()
    if p == null:
        _clear_gps()
        _hud.show_toast("Метка убрана")
        _update_win_buttons()
        return
    _set_gps(p["pos"], p["name"], false)
    _hud.show_toast("Отмечено на карте: %s" % p["name"])
    _win.close_window()


func _on_win_right() -> void:
    var p = _selected_payload()
    if p == null:
        return
    if _win_mode == "gps":
        _set_gps(p["pos"], p["name"], true)
        _hud.show_toast("Метка установлена: %s" % p["name"])
        _win.close_window()
        return
    if _win_mode == "garage":
        _win.close_window()
        _spawn_faction_car(p)
        return
    match String(p["type"]):
        "car":
            _market_car(int(p["i"]))
        "cloth":
            _market_cloth(String(p["slot"]), int(p["i"]), int(p["price"]))
        "canister":
            _market_canister()
        "phone":
            if _pay(PHONE_PRICE, "Рынок: новый номер"):
                phone_number = ""
                _ensure_numbers()
                Sfx.play("coin")
                _hud.show_toast("Новый номер: %s" % phone_number)
    _refresh_win(true)


# ---------------------------------------------------------------- навигатор

func _fill_gps_rows(rows: Array) -> void:
    var focus := _focus()
    var q := _win.search_text().to_lower()
    var places := _nav_places()
    var list := []
    for pl: Dictionary in places:
        if q != "":
            if String(pl["name"]).to_lower().find(q) < 0:
                continue
        elif pl["cat"] != _win.category:
            continue
        list.append(pl)
    _sort_focus = focus
    list.sort_custom(_place_closer)
    for pl: Dictionary in list:
        var pos: Vector3 = pl["pos"]
        var d := Vector2(focus.x - pos.x, focus.z - pos.z).length()
        rows.append({"icon": pl["icon"], "icon_col": pl.get("col", Color.WHITE), "name": pl["name"],
                "value": _dist_text(d), "pin": true})
        _win_payload.append(pl)
    if rows.is_empty():
        var msg := "Ничего не найдено"
        var cat := _win.category if q == "" else ""
        match cat:
            "home":
                msg = "Жильё не куплено"
        rows.append({"icon": "dots", "name": msg, "value": "", "enabled": false})
        _win_payload.append(null)


func _place_closer(a: Dictionary, b: Dictionary) -> bool:
    var pa: Vector3 = a["pos"]
    var pb: Vector3 = b["pos"]
    return pa.distance_squared_to(_sort_focus) < pb.distance_squared_to(_sort_focus)


func _nav_places() -> Array:
    var c = _city
    var out := []
    var gold := Color(1.0, 0.72, 0.1)
    if _work.active and _work.has_target():
        out.append({"cat": "work", "icon": "pin", "col": gold, "name": "Текущее задание", "pos": _work.target})
    elif _job.active and _job.has_target():
        out.append({"cat": "work", "icon": "pin", "col": gold, "name": "Текущее задание", "pos": _job.target})
    if home >= 0:
        out.append({"cat": "home", "icon": "house", "col": Color(0.45, 0.9, 0.5), "name": "Мой дом: %s" % c.homes[home]["addr"],
                "pos": c.homes[home]["pos"]})
    for i in c.homes.size():
        if i != home:
            var hm: Dictionary = c.homes[i]
            out.append({"cat": "home", "icon": "house", "name": "Продаётся: %s — %s" % [hm["addr"], HudScript.format_money(int(hm["price"]))],
                    "pos": hm["pos"]})
    for pk: Dictionary in c.pickups:
        if String(pk["name"]) == "АПТЕКА":
            out.append({"cat": "hospital", "icon": "cross", "col": Color(1.0, 0.5, 0.5), "name": "Аптека", "pos": pk["pos"]})
    out.append({"cat": "work", "icon": "bus", "name": "Автобусный парк — водитель", "pos": c.bus_depot})
    out.append({"cat": "work", "icon": "box", "name": "Склад — грузчик", "pos": c.warehouse_drop})
    out.append({"cat": "work", "icon": "truck", "name": "Стоянка фур — дальнобойщик", "pos": c.truck_depot})
    out.append({"cat": "work", "icon": "axe", "name": "Лесопилка — лесоруб", "pos": c.log_pile})
    out.append({"cat": "market", "icon": "car", "col": gold, "name": "Общий рынок", "pos": c.market})
    out.append({"cat": "shops", "icon": "cart", "col": gold, "name": "Общий рынок", "pos": c.market})
    for pk: Dictionary in c.pickups:
        out.append({"cat": "shops", "icon": "cart", "name": String(pk["name"]).capitalize(), "pos": pk["pos"]})
    for p: Vector3 in c.atms:
        out.append({"cat": "bank", "icon": "atm", "name": "Банкомат", "pos": p})
    var pumps: Array = c.fuel_pumps
    var names := ["АЗС — промзона", "АЗС — западная трасса", "АЗС — северная трасса"]
    for k in names.size():
        if k * 2 < pumps.size():
            out.append({"cat": "fuel", "icon": "fuel", "col": Color(1.0, 0.35, 0.3), "name": names[k], "pos": pumps[k * 2]})
    out.append({"cat": "service", "icon": "gavel", "name": "Мэрия — паспорт", "pos": c.city_hall})
    var cats := {"mayor": ["service", "gavel"], "police": ["police", "shield"], "hospital": ["hospital", "cross"],
            "fire": ["service", "shield"], "kgb": ["police", "shield"]}
    for fid: String in c.faction_sites:
        var site: Dictionary = c.faction_sites[fid]
        var ci: Array = cats.get(fid, ["other", "dots"])
        var fcol: Color = FactionData.get_faction(fid)["color"]
        var gang := FactionData.is_gang(fid)
        if gang:
            ci = ["other", "people"]
        out.append({"cat": ci[0], "icon": ci[1], "col": fcol.lightened(0.3),
                "name": ("База: %s" if gang else "%s") % site["name"], "pos": site["door"]})
        if fid == faction:
            out.append({"cat": "work", "icon": "people", "col": gold, "name": "Моя фракция: %s" % site["name"], "pos": site["door"]})
            out.append({"cat": "work", "icon": "car", "col": gold, "name": "Автопарк: %s" % site["name"], "pos": site["marker"]})
    out.append({"cat": "service", "icon": "wheel", "name": "Автошкола — права", "pos": c.driving_school})
    out.append({"cat": "fun", "icon": "star", "name": "Центральная площадь", "pos": Vector3(0, 0, 0)})
    out.append({"cat": "fun", "icon": "star", "name": "Лес за городом", "pos": Vector3(-270, 0, -270)})
    for p: Vector3 in c.bus_stops:
        out.append({"cat": "other", "icon": "dots", "name": "Остановка", "pos": p})
    for car in _cars:
        if car.owned:
            out.append({"cat": "other", "icon": "car", "col": gold, "name": "Моя машина: %s" % car.car_name,
                    "pos": car.global_position})
    return out


func _set_gps(pos: Vector3, place: String, beam: bool) -> void:
    _gps_target = pos
    _gps_name = place
    if beam:
        _gps_marker.show_at(pos, "GPS: " + place, Color(0.75, 0.45, 1.0))
    else:
        _gps_marker.visible = false
    Sfx.play("notify", -4.0)


func _clear_gps() -> void:
    _gps_target = null
    _gps_name = ""
    if _gps_marker:
        _gps_marker.visible = false


func _dist_text(d: float) -> String:
    if d < 1000.0:
        return "%d м" % int(d)
    return "%.1f км" % (d / 1000.0)


# ---------------------------------------------------------------- рынок

func _fill_market_rows(rows: Array) -> void:
    var gold := Color(1.0, 0.75, 0.2)
    var green := Color(0.45, 0.9, 0.5)
    match _win.category:
        "cars":
            for i in _cars.size():
                var car = _cars[i]
                var m: Dictionary = CAR_MODELS[i]
                rows.append({"icon": "car", "icon_col": m["color"].lightened(0.2),
                        "name": "%s · до %d км/ч" % [m["name"], int(m["speed"])],
                        "value": "Куплено" if car.owned else HudScript.format_money(int(m["price"])),
                        "value_col": green if car.owned else gold})
                _win_payload.append({"type": "car", "i": i})
        "clothes":
            for slot: Dictionary in Clothes.SLOTS:
                var id: String = slot["id"]
                var items: Array = slot["items"]
                for k in items.size():
                    var item: Array = items[k]
                    var price: int = item[2]
                    var worn := int(look.get(id, 0)) == k
                    var have := _cloth_owned(id, k)
                    var value := "Надето" if worn else ("Есть" if have else ("Бесплатно" if price == 0 else HudScript.format_money(price)))
                    rows.append({"icon": "shirt", "icon_col": item[1], "name": "%s: %s" % [slot["name"], item[0]],
                            "value": value, "value_col": green if (worn or have) else gold})
                    _win_payload.append({"type": "cloth", "slot": id, "i": k, "price": price})
        _:
            rows.append({"icon": "fuel", "icon_col": Color(1.0, 0.35, 0.3), "name": "Канистра бензина 10 л",
                    "value": HudScript.format_money(CANISTER_PRICE), "value_col": gold})
            _win_payload.append({"type": "canister", "price": CANISTER_PRICE})
            rows.append({"icon": "call", "name": "Новый номер телефона",
                    "value": HudScript.format_money(PHONE_PRICE), "value_col": gold})
            _win_payload.append({"type": "phone", "price": PHONE_PRICE})


func _cloth_owned(slot: String, i: int) -> bool:
    var list: Array = owned_clothes.get(slot, [0])
    return i in list


func _market_car(i: int) -> void:
    var car = _cars[i]
    if car.owned:
        if car == _driving:
            _hud.show_toast("Ты сейчас в этой машине")
            return
        car.reset_to(_car_spawn(i))
        _hud.show_toast("%s ждёт на стоянке у рынка" % car.car_name)
        return
    if not _pay(int(car.price), "Рынок: " + String(car.car_name)):
        return
    car.set_owned(true)
    car.set_available(true)
    car.reset_to(_car_spawn(i))
    car.fuel = car.tank
    Sfx.play("coin")
    _hud.show_toast("Куплено: %s! Машина ждёт на стоянке у рынка" % car.car_name)
    _save_game()


func _market_cloth(slot: String, i: int, price: int) -> void:
    if not _cloth_owned(slot, i):
        if not _pay(price, "Рынок: одежда"):
            return
        var list: Array = owned_clothes.get(slot, [0])
        list.append(i)
        owned_clothes[slot] = list
        Sfx.play("coin")
    else:
        Sfx.play("click")
    look[slot] = i
    _preview_look = look.duplicate()
    _player.set_look(Clothes.colors(look), Clothes.textures(look))
    _hud.show_toast("Обновка надета!")
    _save_game()


func _market_canister() -> void:
    var best = null
    for car in _cars:
        if car.owned and car.visible and car.global_position.distance_to(_focus()) < 25.0:
            best = car
    if best == null:
        Sfx.play("error")
        _hud.show_toast("Подгони свою машину к рынку — канистру зальём прямо в бак")
        return
    if best.fuel >= best.tank - 0.5:
        _hud.show_toast("Бак и так полный")
        return
    if not _pay(CANISTER_PRICE, "Рынок: канистра"):
        return
    best.fuel = minf(best.tank, best.fuel + 10.0)
    Sfx.play("coin")
    _hud.show_toast("+10 л в бак: %s" % best.car_name)


# ================================================================ фракции

## Сохранённая позиция попала внутрь нового здания (город поменялся) — такую не берём.
func _inside_building(p: Vector3) -> bool:
    if absf(p.x) > 1500.0 or absf(p.z) > 1500.0:   # интерьеры
        return true
    for r: Rect2 in _city.building_rects:
        if r.grow(0.5).has_point(Vector2(p.x, p.z)):
            return true
    return false


func _set_faction(fid: String, rank: int) -> void:
    faction = fid
    faction_rank = rank
    faction_exp = 0
    _payday_acc = 0.0
    faction_news = []
    _hud.profile.set_faction_visible(fid != "")


func _faction_name() -> String:
    var f := FactionData.get_faction(faction)
    return String(f.get("name", ""))


func _org_text() -> String:
    if faction == "":
        return "Нет"
    return "%s · %s" % [_faction_name(), FactionData.rank_name(faction_rank, faction)]


func _salary() -> int:
    return FactionData.salary(faction, faction_rank)


## Сколько получек нужно до следующего ранга (0 — повышает только лидер).
func _need_exp() -> int:
    if faction_rank < 1 or faction_rank > FactionData.PROMOTE_AFTER.size():
        return 0
    return int(FactionData.PROMOTE_AFTER[faction_rank - 1])


func _faction_payday() -> void:
    var pay := _salary()
    bank += pay
    _bank_log(pay, ("Доля из общака: " if FactionData.is_gang(faction) else "Зарплата: ") + _faction_name())
    faction_exp += 1
    _add_xp(10)
    Sfx.play("coin")
    var text := ("Доля из общака (%s): %s на карту" if FactionData.is_gang(faction) else "Получка во фракции «%s»: %s на карту") \
            % [_faction_name(), HudScript.format_money(pay)]
    var need := _need_exp()
    if need > 0 and faction_exp >= need:
        text += ". Можно повыситься — %s!" % ("у смотрящего" if FactionData.is_gang(faction) else "в отделе кадров")
    _hud.show_toast(text)
    _save_game()


# ---------------------------------------------------------------- вход в здания

func _enter_building(fid: String) -> void:
    var inn: Dictionary = _city.interiors[fid]
    _interior = fid
    _player.global_position = inn["spawn"]
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(0.0)
    Sfx.play("click")
    _hud.show_toast(String(_city.faction_sites[fid]["name"]))


func _exit_building(fid: String) -> void:
    var site: Dictionary = _city.faction_sites[fid]
    _interior = ""
    _player.global_position = site["out"] + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(float(site["out_yaw"]))
    Sfx.play("click")


# ---------------------------------------------------------------- отдел кадров

func _open_hr(fid: String) -> void:
    var f := FactionData.get_faction(fid)
    var fname := String(f["name"])
    var gang := FactionData.is_gang(fid)
    var head := ("Смотрящий — " if gang else "Отдел кадров — ") + fname
    if faction != "" and faction != fid:
        _open_dialog(head, ("Ты уже в «%s».\nСначала уйди оттуда, потом приходи." if gang
                else "Ты уже состоишь в «%s».\nЧтобы перейти сюда, сначала уволься там.") % _faction_name(),
                [["Закрыть", _dialog.close]])
        return
    if faction == "":
        var lines := ""
        var names := FactionData.ranks(fid)
        var lim := FactionData.limits(fid)
        for i in names.size():
            lines += "%d. %s — %s (мест: %d)\n" % [i + 1, FactionData.rank_name(i + 1, fid),
                    HudScript.format_money(FactionData.salary(fid, i + 1)), int(lim[i])]
        var intro := ("Хочешь к нам на район?\n\n%s\nДоля из общака приходит на карту раз в 3 игровых часа. "
                + "Машины братвы — красная метка у гаража.") if gang else ("Хочешь работать у нас?\n\n%s\n"
                + "Зарплата приходит на карту раз в 3 игровых часа, свой автопарк — красная метка у здания.")
        _open_dialog(head, intro % lines, [["Вступить", _join_faction.bind(fid)], ["Закрыть", _dialog.close]])
        return
    var need := _need_exp()
    var text := "%s\nРанг: %s\n%s: %s\n" % [fname, FactionData.rank_name(faction_rank, fid),
            "Доля из общака" if gang else "Зарплата", HudScript.format_money(_salary())]
    var buttons := []
    if need > 0:
        text += "Стаж на ранге: %d из %d получек" % [mini(faction_exp, need), need]
        if faction_exp >= need:
            buttons.append(["Получить повышение", _promote])
    elif faction_rank < 5:
        text += "Дальше ранги «%s» и «%s» — их назначает руководство." % [FactionData.rank_name(5, fid),
                FactionData.rank_name(6, fid)]
    else:
        text += "Ты в руководстве."
    buttons.append(["Уйти из ОПГ" if gang else "Уволиться", _confirm_leave])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog(head, text, buttons)


func _join_faction(fid: String) -> void:
    if not FactionData.is_gang(fid) and not _check_docs(false):
        return
    _set_faction(fid, 1)
    _add_xp(20)
    Sfx.play("coin")
    _dialog.close()
    _hud.show_toast("Ты в «%s»: %s. Меню — кнопка «Фракция»" % [_faction_name(), FactionData.rank_name(1, fid)])
    _save_game()


func _promote() -> void:
    if _need_exp() <= 0 or faction_exp < _need_exp():
        return
    faction_rank += 1
    faction_exp = 0
    _add_xp(30)
    Sfx.play("coin")
    _dialog.close()
    _hud.show_toast("Повышение! Новый ранг: %s" % FactionData.rank_name(faction_rank, faction))
    _save_game()


func _confirm_leave() -> void:
    _open_dialog("Уход", "Точно уйти из «%s»? Ранг и стаж пропадут." % _faction_name(),
            [["Уволиться", _leave_faction], ["Отмена", _dialog.close]])


func _leave_faction() -> void:
    var old := _faction_name()
    _fmenu.close_menu()
    _despawn_faction_car()
    _set_faction("", 0)
    _dialog.close()
    _hud.show_toast("Ты ушёл из «%s»" % old)
    _save_game()


# ---------------------------------------------------------------- автопарк

func _open_garage(fid: String) -> void:
    if faction != fid:
        Sfx.play("error")
        var fname := String(FactionData.get_faction(fid).get("name", ""))
        if FactionData.is_gang(fid):
            _hud.show_toast("Это машины %s — только для своих. Вступить — у смотрящего в гараже" % fname)
        else:
            _hud.show_toast("Автопарк только для сотрудников: %s. Вступить — в отделе кадров внутри здания" % fname)
        return
    _touch.blocked = true
    _fmenu.open_menu(_fmenu_data(), "garage")


func _fill_garage_rows(rows: Array) -> void:
    var f := FactionData.get_faction(faction)
    var green := Color(0.45, 0.9, 0.5)
    var red := Color(1.0, 0.45, 0.4)
    for v: Dictionary in f.get("vehicles", []):
        var rank := int(v["rank"])
        var ok := faction_rank >= rank
        var kind := String(v["kind"])
        rows.append({"icon": "car" if kind == "car" else kind, "icon_col": Color(v["paint"]).lightened(0.25),
                "name": "%s · до %d км/ч" % [v["name"], int(v["speed"])],
                "value": "Доступно" if ok else "С ранга %d" % rank, "value_col": green if ok else red,
                "enabled": ok})
        _win_payload.append(v)


func _spawn_faction_car(v: Dictionary) -> void:
    if faction == "" or not _city.faction_sites.has(faction):
        return
    if faction_rank < int(v["rank"]):
        return
    _despawn_faction_car()
    var site: Dictionary = _city.faction_sites[faction]
    var at: Transform3D = site["spawn"]
    # место должно быть свободно (там может стоять чужая или своя машина)
    var q := PhysicsShapeQueryParameters3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(3.0, 2.5, 11.0)
    q.shape = box
    q.transform = Transform3D(at.basis, at.origin + Vector3(0, 1.5, 0))
    q.exclude = [_player.get_rid()]
    var hits := get_world_3d().direct_space_state.intersect_shape(q, 4)
    for h: Dictionary in hits:
        if not (h["collider"] is StaticBody3D):
            Sfx.play("error")
            _hud.show_toast("Место выдачи занято — отгоните машину со стоянки")
            return
    var c = CarScene.instantiate()
    c.owned = true
    c.price = 0
    c.uses_fuel = false
    c.kind = String(v["kind"])
    c.car_name = String(v["name"])
    c.paint = v["paint"]
    c.max_engine_force = float(v["force"])
    c.max_speed_kmh = float(v["speed"])
    if c.kind != "car":
        c.brake_force = 160.0
        c.max_steer = 0.5
    c.livery_text = String(v.get("livery", ""))
    c.livery_color = v.get("livery_col", Color(0.15, 0.3, 0.7))
    c.has_lights = bool(v.get("lights", false))
    if v.has("light_b"):
        c.light_a = v["light_b"]
        c.light_b = v["light_b"]
    c.transform = at
    add_child(c)
    c.touch = _touch
    c.set_night(_night_k > 0.4)
    _faction_car = c
    _traffic.obstacles.append(c)
    _peds.cars.append(c)
    Sfx.play("notify")
    _hud.show_toast("%s ждёт на стоянке — садись (жёлтая кнопка)" % c.car_name)


func _despawn_faction_car() -> void:
    var c = _faction_car
    if c == null:
        return
    if _driving == c:
        var pos: Vector3 = c.get_exit_position()
        c.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
    _traffic.obstacles.erase(c)
    _peds.cars.erase(c)
    _faction_car = null
    c.queue_free()


# ---------------------------------------------------------------- меню организации

func _open_faction_menu() -> void:
    if faction == "":
        return
    _touch.blocked = true
    _fmenu.open_menu(_fmenu_data(), "main")


func _fmenu_data() -> Dictionary:
    var f := FactionData.get_faction(faction)
    var gang := FactionData.is_gang(faction)
    var names := FactionData.ranks(faction)
    var lim := FactionData.limits(faction)
    var ranks := []
    for i in names.size():
        ranks.append([FactionData.rank_name(i + 1, faction), int(lim[i]),
                HudScript.format_money(FactionData.salary(faction, i + 1))])
    var site: Dictionary = _city.faction_sites[faction]
    var mk: Vector3 = site["marker"]
    var at_garage := _driving == null and Vector2(_focus().x - mk.x, _focus().z - mk.z).length() < 6.0
    return {"id": faction, "title": String(f.get("name", "")).to_upper(), "emblem": String(f.get("emblem", "")),
            "accent": f["color"] if gang else Color(1.0, 0.76, 0.18), "gang": gang,
            "rank": faction_rank, "rank_name": FactionData.rank_name(faction_rank, faction),
            "exp": faction_exp, "need": _need_exp(), "pay": HudScript.format_money(_salary()),
            "pay_word": "Доля из общака" if gang else "Зарплата",
            "payday_left": int(ceil(PAYDAY_MINUTES - _payday_acc)), "online": 1, "members": 1,
            "ranks": ranks, "vehicles": f.get("vehicles", []), "at_garage": at_garage,
            "nick": passport_name if passport_name != "" else "Без_Имени", "news": faction_news}


func _on_fmenu_closed() -> void:
    _touch.blocked = false


func _on_fmenu_gps(kind: String) -> void:
    if faction == "":
        return
    var site: Dictionary = _city.faction_sites[faction]
    var gang := FactionData.is_gang(faction)
    if kind == "garage":
        _faction_gps(site["marker"], "Автопарк")
    else:
        _faction_gps(site["door"], ("База: %s" if gang else "%s") % site["name"])
    _fmenu.close_menu()


func _on_fmenu_spawn(i: int) -> void:
    var list: Array = FactionData.get_faction(faction).get("vehicles", [])
    if i < 0 or i >= list.size():
        return
    if not bool(_fmenu_data()["at_garage"]):
        Sfx.play("error")
        _hud.show_toast("Встань на красную метку автопарка у базы — там выдают машины")
        return
    _fmenu.close_menu()
    _spawn_faction_car(list[i])


func _on_fmenu_news(text: String) -> void:
    var tag: String = FactionData.RANK_TAGS[clampi(faction_rank, 1, 6) - 1]
    faction_news.append([text, "%s (%s)" % [passport_name, tag] if tag != "" else passport_name])
    if faction_news.size() > 20:
        faction_news.pop_front()
    Sfx.play("notify")
    _fmenu.set_data(_fmenu_data())
    _save_game()


func _faction_gps(pos: Vector3, place: String) -> void:
    _dialog.close()
    _set_gps(pos, place, true)
    _hud.show_toast("Метка установлена: %s" % place)


# ================================================================ здоровье и голод

func _update_vitals(delta: float, speed: float) -> void:
    var game_min := delta * GAME_MINUTES_PER_SECOND
    hunger = maxf(0.0, hunger - HUNGER_PER_MINUTE * game_min * (1.6 if _driving == null and Input.is_action_pressed("sprint") else 1.0))
    if hunger <= 0.0:
        _starve_acc += delta
        if _starve_acc >= 3.0:
            _starve_acc = 0.0
            _hurt(1.0, "")
            if int(health) % 10 == 0:
                _hud.show_toast("Ты голоден! Поешь в ларьке (ЕДА) или дома")
    elif hunger > 60.0 and health < 100.0:
        _regen_acc += delta
        if _regen_acc >= 12.0:
            _regen_acc = 0.0
            health = minf(100.0, health + 1.0)
    # авария: резкая потеря скорости
    var kmh := absf(speed)
    if _driving and _last_kmh - kmh > 35.0 and _last_kmh > 45.0:
        var dmg := clampf((_last_kmh - kmh - 25.0) * 0.6, 5.0, 45.0)
        Sfx.play("hit")
        _hurt(dmg, "Авария! −%d здоровья" % int(dmg))
    _last_kmh = kmh if _driving else 0.0
    # падение с высоты
    if not _driving:
        var vy: float = _player.velocity.y
        if _last_vy < -14.0 and vy > -2.0:
            var fall := clampf((-_last_vy - 12.0) * 6.0, 5.0, 60.0)
            Sfx.play("hit")
            _hurt(fall, "Неудачное падение: −%d здоровья" % int(fall))
        _last_vy = vy
    # сердцебиение, когда здоровья мало
    if health < 25.0:
        _beat_t -= delta
        if _beat_t <= 0.0:
            _beat_t = 1.2
            Sfx.play("heartbeat", -6.0)


func _hurt(amount: float, text: String) -> void:
    health = maxf(0.0, health - amount)
    if text != "":
        _hud.show_toast(text)
    if health <= 0.0:
        _faint()


## Здоровье кончилось: игрок теряет сознание и приходит в себя у больницы.
func _faint() -> void:
    Sfx.play("faint")
    if _driving:
        var pos: Vector3 = _driving.get_exit_position()
        _driving.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
    _interior = ""
    _home_inside = -1
    var site: Dictionary = _city.faction_sites.get("hospital", {})
    var spot: Vector3 = site.get("out", PLAYER_SPAWN)
    _player.global_position = spot + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(float(site.get("out_yaw", PI)))
    var fee := mini(TREAT_PRICE, cash + bank)
    if fee > 0:
        var from_cash := mini(cash, fee)
        cash -= from_cash
        bank -= fee - from_cash
        if fee - from_cash > 0:
            _bank_log(-(fee - from_cash), "Больница: лечение")
    health = 60.0
    hunger = maxf(hunger, 40.0)
    _last_kmh = 0.0
    _last_vy = 0.0
    _open_dialog("Больница", ("Ты потерял сознание, и тебя доставили в больницу.\n\nЛечение: %s.\n"
            + "Следи за здоровьем и сытостью — полоски под деньгами.") % HudScript.format_money(fee), [["Понятно", _dialog.close]])
    _save_game()


func _open_food(kname: String) -> void:
    var items: Array = FOOD[kname]
    var buttons := []
    for it: Array in items:
        var gain := ""
        if int(it[2]) > 0:
            gain += " +%d сытости" % int(it[2])
        if int(it[3]) > 0:
            gain += " +%d здоровья" % int(it[3])
        buttons.append(["%s — %s (%s)" % [it[0], HudScript.format_money(int(it[1])), gain.strip_edges()], _buy_food.bind(kname, it)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog(kname.capitalize(), "Здоровье: %d / 100\nСытость: %d / 100" % [int(health), int(hunger)], buttons)


func _buy_food(kname: String, it: Array) -> void:
    if int(it[2]) > 0 and hunger >= 99.0 and int(it[3]) == 0:
        _hud.show_toast("Ты не голоден")
        return
    if int(it[3]) > 0 and int(it[2]) == 0 and health >= 100.0:
        _hud.show_toast("Ты здоров")
        return
    if not _pay(int(it[1]), String(it[0])):
        return
    hunger = minf(100.0, hunger + float(it[2]))
    health = minf(100.0, health + float(it[3]))
    Sfx.play("heal" if int(it[3]) > int(it[2]) else "eat")
    _hud.show_toast("%s: приятного аппетита!" % it[0] if int(it[2]) > 0 else "%s: здоровье %d" % [it[0], int(health)])
    _open_food(kname)


func _open_treatment() -> void:
    var free := faction == "hospital"
    var price := 0 if free else TREAT_PRICE
    if health >= 100.0:
        _open_dialog("Регистратура", "Здоровье: 100 / 100. Лечение не нужно.", [["Закрыть", _dialog.close]])
        return
    _open_dialog("Регистратура", "Здоровье: %d / 100\n\nПолное лечение: %s%s" % [int(health),
            "бесплатно" if free else HudScript.format_money(price), " (ты сотрудник больницы)" if free else ""],
            [["Лечиться", _treat.bind(price)], ["Закрыть", _dialog.close]])


func _treat(price: int) -> void:
    if price > 0 and not _pay(price, "Больница: лечение"):
        return
    health = 100.0
    Sfx.play("heal")
    _dialog.close()
    _hud.show_toast("Ты полностью здоров")


# ================================================================ жильё

func _home_text() -> String:
    if home < 0:
        return "Нет"
    return String(_city.homes[home]["addr"])


func _set_home(i: int) -> void:
    if i >= _city.homes.size():
        i = -1
    home = i
    if _home_map_point != null:
        _hud.minimap.points.erase(_home_map_point)
        _home_map_point = null
    if home >= 0:
        _home_map_point = [_city.homes[home]["pos"], Color(0.35, 0.95, 0.45)]
        _hud.minimap.points.append(_home_map_point)
    for k in _city.homes.size():
        var hm: Dictionary = _city.homes[k]
        var l: Label3D = hm["label"]
        if k == home:
            l.text = "ВАШ ДОМ"
            l.modulate = Color(0.45, 1.0, 0.5)
        else:
            l.text = "ПРОДАЁТСЯ\n%s" % HudScript.format_money(int(hm["price"]))
            l.modulate = Color(1.0, 0.85, 0.35)


func _home_kind_name(i: int) -> String:
    return "Квартира" if String(_city.homes[i]["kind"]) == "flat" else "Частный дом"


func _open_home(i: int) -> void:
    var hm: Dictionary = _city.homes[i]
    var title := "%s — %s" % [_home_kind_name(i), hm["addr"]]
    if home == i:
        _open_dialog(title, "Это твой дом.\nДома можно поесть из холодильника и отдохнуть (восстановить здоровье).",
                [["Войти", _enter_home.bind(i)], ["Продать государству за %s" % HudScript.format_money(int(hm["price"]) / 2), _confirm_sell_home],
                ["Закрыть", _dialog.close]])
        return
    var text := "Продаётся: %s\nЦена: %s\n\nПокупка — у государства, без посредников." % [_home_kind_name(i).to_lower(),
            HudScript.format_money(int(hm["price"]))]
    var buttons := []
    if home >= 0:
        text += "\n\nУ тебя уже есть жильё (%s). Сначала продай его." % _home_text()
    else:
        buttons.append(["Купить за %s" % HudScript.format_money(int(hm["price"])), _buy_home.bind(i)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog(title, text, buttons)


func _buy_home(i: int) -> void:
    if not _check_docs(false):
        return
    var hm: Dictionary = _city.homes[i]
    if not _pay(int(hm["price"]), "Покупка жилья"):
        return
    _set_home(i)
    _add_xp(40)
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Поздравляем с новосельем! %s" % hm["addr"])
    _save_game()


func _confirm_sell_home() -> void:
    var hm: Dictionary = _city.homes[home]
    _open_dialog("Продажа жилья", "Продать %s за %s? Деньги придут на карту." % [hm["addr"], HudScript.format_money(int(hm["price"]) / 2)],
            [["Продать", _sell_home], ["Отмена", _dialog.close]])


func _sell_home() -> void:
    if home < 0:
        return
    var pay := int(_city.homes[home]["price"]) / 2
    bank += pay
    _bank_log(pay, "Продажа жилья")
    _set_home(-1)
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Жильё продано: +%s на карту" % HudScript.format_money(pay))
    _save_game()


func _enter_home(i: int) -> void:
    _dialog.close()
    var hi: Dictionary = _city.home_interiors[String(_city.homes[i]["kind"])]
    _home_inside = i
    _player.global_position = hi["spawn"]
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(0.0)
    Sfx.play("door")


func _exit_home() -> void:
    var i := _home_inside if _home_inside >= 0 else home
    _home_inside = -1
    var p: Vector3 = _city.homes[i]["pos"] if i >= 0 else PLAYER_SPAWN
    _player.global_position = p + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    Sfx.play("door")


func _use_fridge() -> void:
    var now := day * 1440.0 + minutes
    if now - _fridge_at < 120.0:
        _hud.show_toast("Холодильник пуст — продукты будут через %d мин" % int(120.0 - (now - _fridge_at)))
        return
    _fridge_at = now
    hunger = minf(100.0, hunger + 50.0)
    Sfx.play("eat")
    _hud.show_toast("Поел дома: +50 сытости")


func _use_bed() -> void:
    _open_dialog("Отдых", "Поспать 2 часа? Здоровье восстановится полностью.", [["Поспать", _sleep], ["Закрыть", _dialog.close]])


func _sleep() -> void:
    _dialog.close()
    minutes += 120.0
    if minutes >= 1440.0:
        minutes -= 1440.0
        day += 1
    health = 100.0
    hunger = maxf(0.0, hunger - 10.0)
    _update_daylight()
    Sfx.play("heal")
    _hud.show_toast("Ты выспался: здоровье 100")
