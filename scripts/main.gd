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
const DutyScript := preload("res://scripts/duty.gd")
const CarScript := preload("res://scripts/car.gd")

const VERSION := "v0.19"
const SAVE_PATH := "user://save.cfg"
const START_MONEY := 5000
const GAME_MINUTES_PER_SECOND := 1.0   # 1 реальная секунда = 1 игровая минута
## Машины на Общем рынке: название, цена, цвет, макс. скорость, мощность.
const CAR_MODELS := [
    {"name": "Классика", "price": 8000, "color": Color(0.92, 0.92, 0.90), "speed": 105.0, "force": 4200.0},
    {"name": "Комфорт", "price": 15000, "color": Color(0.15, 0.22, 0.45), "speed": 125.0, "force": 5000.0},
    {"name": "Спорт", "price": 28000, "color": Color(0.45, 0.06, 0.10), "speed": 155.0, "force": 6500.0},
    {"name": "Люкс", "price": 45000, "color": Color(0.10, 0.10, 0.11), "speed": 175.0, "force": 7400.0},
    {"name": "Мотоцикл", "price": 12000, "color": Color(0.75, 0.10, 0.10), "speed": 150.0, "force": 1500.0, "kind": "moto"},
]
## Тюнинг на СТО
const PAINTS := [["Белый", Color(0.92, 0.92, 0.90)], ["Чёрный", Color(0.06, 0.06, 0.07)], ["Красный", Color(0.65, 0.06, 0.08)],
        ["Синий", Color(0.10, 0.20, 0.55)], ["Зелёный", Color(0.10, 0.40, 0.20)], ["Серебро", Color(0.65, 0.66, 0.68)],
        ["Жёлтый", Color(0.95, 0.70, 0.10)], ["Вишня", Color(0.35, 0.03, 0.08)]]
const RIMS := [["Хром", Color(0.85, 0.85, 0.88)], ["Чёрные", Color(0.05, 0.05, 0.06)], ["Золото", Color(0.85, 0.65, 0.2)],
        ["Красные", Color(0.75, 0.08, 0.08)]]
const PAINT_PRICE := 1500
const RIM_PRICE := 2000
const TINT_PRICE := 3000
const PLATE_PRICE := 2500
const PLATE_LETTERS := "АВЕКМНОРСТУХ"
## Задания новичка: [id, что сделать, награда].
const QUESTS := [
    ["passport", "Получи паспорт в мэрии (паспортный стол)", 1000],
    ["eat", "Купи еду в ларьке и съешь её из сумки", 300],
    ["earn", "Заработай первые 2 000 ₽ (телефон → Работа)", 1000],
    ["license", "Сдай на права категории B в автошколе", 2000],
    ["car", "Купи машину или мотоцикл на Общем рынке", 3000],
    ["faction", "Вступи во фракцию или ОПГ", 2000],
    ["home", "Купи жильё (Навигатор → Дом)", 5000],
    ["biz", "Получи лицензию на бизнес в мэрии", 3000],
]
const WEATHER_NAMES := {"clear": "Ясно", "cloudy": "Пасмурно", "rain": "Дождь", "snow": "Снег"}
const ENTER_DISTANCE := 3.2
const LAMP_LIGHTS := 6   # сколько фонарей рядом с игроком дают настоящий свет ночью
const PLAYER_SPAWN := Vector3(0, 0.4, 14)
const FUEL_PRICE := 50          # ₽ за литр
const EXAM_PRICE := 2000
const DPS_FINE := 1500
const PAYDAY_MINUTES := 180.0   # получка во фракции — раз в 3 игровых часа
const HUNGER_PER_MINUTE := 0.12  # сытость тратится: 100 -> 0 примерно за 14 игровых часов (14 мин)
const TREAT_PRICE := 300         # лечение в больнице
const BAG_SIZE := 20             # сколько вещей влезает в сумку
const LICENSE_PRICE := 5000      # лицензия на бизнес (мэрия)
const MAX_BIZ := 3
const TAXI_BASE := 100
## Еда и лекарства в ларьках: [название, цена, +сытость, +здоровье].
const FOOD := {
    "ШАУРМА": [["Шаурма", 250, 45, 0], ["Шаурма двойная", 380, 70, 0], ["Чай", 50, 5, 2]],
    "ПРОДУКТЫ": [["Хлеб", 60, 15, 0], ["Бутерброд", 120, 25, 0], ["Кефир", 90, 15, 2], ["Пельмени", 300, 55, 0]],
    "КОФЕ": [["Кофе", 120, 10, 3], ["Пирожок", 80, 20, 0], ["Круассан", 150, 25, 0]],
    "КВАС": [["Квас", 70, 8, 2], ["Пирожок", 80, 20, 0]],
    "УНИВЕРСАМ": [["Батон", 50, 15, 0], ["Колбаса", 250, 40, 0], ["Комплексный обед", 450, 80, 5]],
    "АПТЕКА": [["Аптечка", 400, 0, 40], ["Бинт", 150, 0, 15], ["Витамины", 200, 5, 10]],
    "АЗС": [["Хот-дог", 150, 30, 0], ["Энергетик", 120, 5, 5], ["Канистра 10 л", 600, 0, 0]],
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
var wanted := 0              # розыск 0..5 звёзд
var jail_left := 0.0         # сколько секунд ещё сидеть в КПЗ
var inventory := {}          # сумка: название -> количество
var sms: Array = []          # [от кого, текст]
var sms_unread := 0
var has_biz_license := false
var biz_owned := {}          # номер бизнеса (строкой) -> выручка в кассе
var turf := {}               # территории ОПГ: "i,j" -> id банды ("" — ничья)
var _duty: DutyScript
var _biz: Array = []         # все бизнесы города: {title, name, pos, price, income}
var _biz_acc := 0.0
var _wanted_t := 0.0
var _arrest_cd := 30.0
var _capt := {}              # идёт захват: {"key", "left", "warned"}
var _capt_cd := 0.0
var _ai_turf_t := 0.0
var _turf_labels := {}
var licenses := {"A": false, "C": false}   # права кроме B (B — has_license)
var quest_i := 0             # номер текущего задания новичка
var earned_total := 0        # сколько всего заработано (для задания)
var _ate_once := false
var _quest_t := 0.0
var _exam_cat := "B"
var weather := "clear"
var _weather_t := 240.0
var _wet := 0.0
var _snow := 0.0
var _rain_fx: CPUParticles3D
var _snow_fx: CPUParticles3D
var _rain_snd: AudioStreamPlayer
var _thunder_t := 30.0
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


## Сначала показываем экран загрузки, потом строим город (это занимает пару секунд).
func _ready() -> void:
    set_process(false)
    var load_layer := CanvasLayer.new()
    load_layer.layer = 30
    add_child(load_layer)
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.02, 0.03)
    load_layer.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if ResourceLoader.exists("res://textures/loading.jpg"):
        var pic := TextureRect.new()
        pic.texture = load("res://textures/loading.jpg")
        pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        load_layer.add_child(pic)
        pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var lbl := Label.new()
    lbl.text = "Загрузка города..."
    var ls := LabelSettings.new()
    ls.font_size = 34
    ls.outline_size = 10
    ls.outline_color = Color(0, 0, 0, 0.8)
    lbl.label_settings = ls
    load_layer.add_child(lbl)
    lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    lbl.position.y -= 90.0
    lbl.position.x -= 150.0
    await get_tree().process_frame
    await get_tree().process_frame
    _setup()
    load_layer.queue_free()
    set_process(true)


func _setup() -> void:
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
    _duty = DutyScript.new()
    _duty.city = _city
    _duty.paid.connect(_on_duty_paid)
    _duty.message.connect(_on_duty_message)
    _duty.crime.connect(func(n: int) -> void: _add_wanted(n, "засветился с грузом"))
    add_child(_duty)
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
    _duty.update(focus, _driving != null, delta)
    _update_law(delta, focus)
    _update_turf(delta, focus)
    _update_business(delta)
    _update_weather(delta, focus)
    _quest_t -= delta
    if _quest_t <= 0.0:
        _quest_t = 1.0
        _check_quest()
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
    if work_action == "":
        work_action = _duty.action_text(focus, _driving != null)
    var near = null if _driving or jail_left > 0.0 else _nearest_car()
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
    _hud.set_wanted(wanted)
    _hud.set_weather(String({"clear": "sun", "cloudy": "cloud", "rain": "rain", "snow": "snow"}.get(weather, "sun")))
    _hud.set_sms_badge(sms_unread)
    _hud.set_nick(passport_name)
    if _hud.profile.is_open():
        _hud.profile.set_data(_profile_data())
    if _fmenu.visible:
        _fmenu.set_data(_fmenu_data())
    var hh := int(minutes) / 60
    var mm := int(minutes) % 60
    var clock := "%02d:%02d   День %d   %s" % [hh, mm, day, WEATHER_NAMES.get(weather, "")]
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
    if _duty.active and not _work.active and not _job.active:
        job_text = _duty.status_text(focus)
    if not _capt.is_empty():
        job_text = "ЗАХВАТ КВАРТАЛА: %d с — не уходи с территории" % int(_capt["left"])
    if jail_left > 0.0:
        job_text = "КПЗ: осталось %d с" % int(ceil(jail_left))
    if job_text == "" and quest_i < QUESTS.size():
        job_text = "Задание: %s · награда %s" % [QUESTS[quest_i][1], HudScript.format_money(int(QUESTS[quest_i][2]))]
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
    elif _duty.active and not _job.active:
        mini.has_target = _duty.has_target()
        mini.target = _duty.target
        mini.target_color = _duty.target_color()
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
    if _player == null:
        return
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
    if _hud == null:
        return
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
    _duty.stop()
    wanted = 0
    jail_left = 0.0
    inventory = {}
    sms = []
    sms_unread = 0
    has_biz_license = false
    biz_owned = {}
    turf = {}
    licenses = {"A": false, "C": false}
    quest_i = 0
    earned_total = 0
    _ate_once = false
    for car in _cars:
        car.tint = false
        car.rim_color = Color(0, 0, 0, 0)
        car.plate_text = ""
        car.repair()
        car.apply_tuning()
    _capt = {}
    _init_turf()
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
            _licenses_text() if has_license or bool(licenses.get("A", false)) else "нет (автошкола на площади)"]
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
    if best.condition <= 0.0:
        _hud.close_phone()
        _open_dialog("Эвакуатор", "%s сломана. Эвакуатор отвезёт её на ближайшую СТО за 1 000 ₽." % best.car_name,
                [["Вызвать эвакуатор", _tow_to_sto.bind(best)], ["Закрыть", _dialog.close]])
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
    earned_total += amount
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
    if _duty.action_text(_focus(), _driving != null) != "":
        var truck: bool = _driving != null and _driving == _faction_car and faction == "fire" and _driving.kind == "truck"
        _duty.do_action(truck)
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
        if car.kind == "moto":
            car.set_rider_color(Clothes.colors(look)["jacket"])
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
func _spawn_weather_fx() -> void:
    var q := QuadMesh.new()
    q.size = Vector2(0.08, 0.9)
    var rm := StandardMaterial3D.new()
    rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rm.albedo_color = Color(0.8, 0.86, 1.0, 0.6)
    if ResourceLoader.exists("res://textures/fx/raindrop.png"):
        rm.albedo_texture = load("res://textures/fx/raindrop.png")
    rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
    rm.billboard_keep_scale = true
    q.material = rm
    _rain_fx = CPUParticles3D.new()
    _rain_fx.amount = 500
    _rain_fx.lifetime = 1.0
    _rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _rain_fx.emission_box_extents = Vector3(28, 1, 28)
    _rain_fx.direction = Vector3.DOWN
    _rain_fx.spread = 4.0
    _rain_fx.initial_velocity_min = 20.0
    _rain_fx.initial_velocity_max = 24.0
    _rain_fx.gravity = Vector3(0, -10, 0)
    _rain_fx.mesh = q
    _rain_fx.local_coords = false
    _rain_fx.emitting = false
    add_child(_rain_fx)
    var sq := QuadMesh.new()
    sq.size = Vector2(0.14, 0.14)
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.albedo_color = Color(1, 1, 1, 0.95)
    if ResourceLoader.exists("res://textures/fx/snowflake.png"):
        sm.albedo_texture = load("res://textures/fx/snowflake.png")
    sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    sq.material = sm
    _snow_fx = CPUParticles3D.new()
    _snow_fx.amount = 450
    _snow_fx.lifetime = 7.0
    _snow_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _snow_fx.emission_box_extents = Vector3(28, 1, 28)
    _snow_fx.direction = Vector3.DOWN
    _snow_fx.spread = 30.0
    _snow_fx.initial_velocity_min = 1.2
    _snow_fx.initial_velocity_max = 2.0
    _snow_fx.gravity = Vector3(0.3, -0.6, 0.2)
    _snow_fx.mesh = sq
    _snow_fx.local_coords = false
    _snow_fx.emitting = false
    add_child(_snow_fx)
    _rain_snd = AudioStreamPlayer.new()
    _rain_snd.stream = Sfx.get_sound("rain")
    _rain_snd.volume_db = -80.0
    add_child(_rain_snd)


func _spawn_life() -> void:
    _spawn_weather_fx()
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
    _peds.knocked.connect(func(_p: Vector3) -> void: _add_wanted(1, "сбил пешехода"))

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
    var xs := [-16.0, -10.0, 10.0, 16.0, -4.0]
    return Transform3D(Basis(), Vector3(xs[i % xs.size()], 0.6, 20.0))


func _spawn_cars() -> void:
    var saved: Array = _loaded.get("cars", [])
    var owned: Array = _loaded.get("owned", [])
    for i in CAR_MODELS.size():
        var m: Dictionary = CAR_MODELS[i]
        var car = CarScene.instantiate()
        car.paint = m["color"]
        car.kind = String(m.get("kind", "car"))
        car.car_name = m["name"]
        car.price = m["price"]
        car.max_speed_kmh = m["speed"]
        car.max_engine_force = m["force"]
        car.owned = i < owned.size() and bool(owned[i])
        var fuels: Array = _loaded.get("fuel", [])
        if i < fuels.size():
            car.fuel = float(fuels[i])
        car.transform = _car_spawn(i)
        var tun: Array = _loaded.get("tuning", [])
        if i < tun.size() and tun[i] is Array and (tun[i] as Array).size() >= 5:
            var t: Array = tun[i]
            car.paint = Color.html(String(t[0]))
            car.tint = bool(t[1])
            car.rim_color = Color.html(String(t[2])) if String(t[2]) != "" else Color(0, 0, 0, 0)
            car.plate_text = String(t[3])
            car.condition = float(t[4])
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
    if jail_left > 0.0 and _city.kpz_cell != Vector3.ZERO:   # досиживаем срок
        _interior = "police"
        _player.global_position = _city.kpz_cell
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
    cfg.set_value("player", "wanted", wanted)
    cfg.set_value("player", "jail", jail_left)
    cfg.set_value("player", "inventory", inventory)
    cfg.set_value("player", "sms", sms)
    cfg.set_value("player", "biz_license", has_biz_license)
    cfg.set_value("world", "biz", biz_owned)
    cfg.set_value("world", "turf", turf)
    var tun := []
    for car in _cars:
        tun.append([car.paint.to_html(), car.tint, car.rim_color.to_html() if car.rim_color.a > 0.0 else "", car.plate_text, car.condition])
    cfg.set_value("world", "tuning", tun)
    cfg.set_value("player", "licenses", licenses)
    cfg.set_value("player", "quest", quest_i)
    cfg.set_value("player", "earned", earned_total)
    cfg.set_value("player", "ate", _ate_once)
    cfg.set_value("world", "weather", weather)
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
    wanted = clampi(int(cfg.get_value("player", "wanted", 0)), 0, 5)
    jail_left = float(cfg.get_value("player", "jail", 0.0))
    var inv = cfg.get_value("player", "inventory", {})
    if inv is Dictionary:
        inventory = inv
    var saved_sms = cfg.get_value("player", "sms", [])
    if saved_sms is Array:
        sms = saved_sms
    has_biz_license = bool(cfg.get_value("player", "biz_license", false))
    var bo = cfg.get_value("world", "biz", {})
    if bo is Dictionary:
        biz_owned = bo
    _loaded["tuning"] = cfg.get_value("world", "tuning", [])
    var lic = cfg.get_value("player", "licenses", {})
    if lic is Dictionary:
        licenses.merge(lic, true)
    quest_i = int(cfg.get_value("player", "quest", 0))
    earned_total = int(cfg.get_value("player", "earned", 0))
    _ate_once = bool(cfg.get_value("player", "ate", false))
    weather = String(cfg.get_value("world", "weather", "clear"))
    var tf = cfg.get_value("world", "turf", {})
    if tf is Dictionary:
        turf = tf
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
        _sun.light_energy = lerpf(0.2, 0.95, clampf(elev * 2.0, 0.0, 1.0)) * _weather_light()
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
        if weather != "clear":   # пасмурно: облака серые и плотные
            var gray := Color(0.62, 0.64, 0.68).lerp(Color(0.2, 0.22, 0.28), 1.0 - day_k)
            _sky_sh.set_shader_parameter("cloud_light", cl.lerp(gray, 0.8))
            _sky_sh.set_shader_parameter("cloud_dark", gray.darkened(0.3))
            _sky_sh.set_shader_parameter("sun_strength", clampf(elev * 3.0, 0.0, 1.0) * 0.2)
        _sky_sh.set_shader_parameter("stars", clampf((1.0 - day_k) * 1.3 - 0.3, 0.0, 1.0))
        _sky_sh.set_shader_parameter("sun_dir", _sun.global_transform.basis.z)
        _sky_sh.set_shader_parameter("sun_color", _sun.light_color)
        _sky_sh.set_shader_parameter("sun_strength", clampf(elev * 3.0, 0.0, 1.0))
        _sky_sh.set_shader_parameter("drift", minutes / 1440.0 * 0.5)  # облака медленно плывут
    _env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, day_k) * (0.85 if weather == "rain" else 1.0)
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
    _hud.app_pressed.connect(_on_app)
    _hud.profile.inventory_requested.connect(_open_inventory)
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
    _fmenu.duty_toggled.connect(_toggle_duty)

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
    _build_business()
    for i in _biz.size():
        var bz: Dictionary = _biz[i]
        var kname := String(bz["name"])
        var label := "КИОСК"
        if kname == "АПТЕКА":
            label = "АПТЕКА"
        elif kname == "АЗС":
            label = "МАГАЗИН"
        elif FOOD.has(kname):
            label = "ЕДА"
        _add_point(bz["pos"], 2.4, label, _open_kiosk.bind(i), false, Color(1.0, 0.5, 0.2), false)
    _init_turf()
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
    for p: Vector3 in _city.service_stations:
        _add_point(p, 7.0, "СТО", _open_sto, true, Color(0.3, 0.5, 1.0))
    for p: Vector3 in _city.fuel_pumps:
        _add_point(p, 5.5, "ЗАПРАВИТЬ", _open_fuel, true, Color(0.9, 0.2, 0.2))
    _add_point(_city.bus_depot, 3.0, "АВТОБУС", _start_work.bind("bus"))
    _add_point(_city.warehouse_drop + Vector3(4, 0, 0), 2.5, "ГРУЗЧИК", _start_work.bind("loader"))
    _add_point(_city.truck_depot, 3.0, "ДАЛЬНОБОЙ", _start_work.bind("truck"))
    _add_point(_city.log_pile + Vector3(4, 0, 0), 3.0, "ЛЕСОРУБ", _start_work.bind("lumber"))


## Ближайшая доступная точка: пешком — «пешие», в своей машине на месте — «машинные».
func _find_point(focus: Vector3, speed: float):
    if _dialog.visible or _win.visible or _fmenu.visible or jail_left > 0.0:
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
        if pt.get("gang_only", false) and not FactionData.is_gang(faction):
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
        var buttons := []
        if not has_biz_license:
            buttons.append(["Лицензия на бизнес — %s" % HudScript.format_money(LICENSE_PRICE), _buy_license])
        buttons.append(["Закрыть", _dialog.close])
        _open_dialog("Мэрия", "Паспорт уже выдан.\nГражданин: %s\n\nЛицензия на бизнес: %s" % [passport_name,
                "есть" if has_biz_license else "нет (нужна, чтобы купить ларёк, магазин или АЗС)"], buttons)
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
    if passport_name == "":
        _open_dialog("Автошкола", "Для записи нужен паспорт. Получи его в мэрии (синяя точка на карте).",
                [["Закрыть", _dialog.close]])
        return
    var buttons := []
    if not has_license:
        buttons.append(["Категория B (легковые) — %s" % HudScript.format_money(EXAM_PRICE), _start_quiz])
    if not bool(licenses.get("A", false)):
        buttons.append(["Категория A (мотоциклы) — 1 500 ₽", _start_exam_cat.bind("A", 1500)])
    if not bool(licenses.get("C", false)):
        buttons.append(["Категория C (грузовики, автобусы) — 3 000 ₽", _start_exam_cat.bind("C", 3000)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Автошкола", ("Твои права: %s\n\nB — теория (5 вопросов) и вождение.\nA и C — только вождение по меткам "
            + "вокруг площади, не быстрее 70 км/ч. Для C нужны права B.") % _licenses_text(), buttons)


func _licenses_text() -> String:
    var l := []
    if has_license:
        l.append("B")
    if bool(licenses.get("A", false)):
        l.append("A")
    if bool(licenses.get("C", false)):
        l.append("C")
    return ", ".join(l) if not l.is_empty() else "нет"


func _start_exam_cat(cat: String, price: int) -> void:
    if cat == "C" and not has_license:
        Sfx.play("error")
        _hud.show_toast("Сначала получи права категории B")
        return
    if not _pay(price, "Автошкола: категория " + cat):
        return
    _exam_cat = cat
    _dialog.close()
    _job.stop()
    _work.stop()
    _work.exam_vehicle = "school_moto" if cat == "A" else "school_truck"
    _work.start("exam")


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
    _exam_cat = "B"
    _work.exam_vehicle = "school"
    _work.start("exam")


func _on_exam_finished(passed: bool, text: String) -> void:
    if passed:
        match _exam_cat:
            "A":
                licenses["A"] = true
                text = "Экзамен сдан! Права категории A получены"
            "C":
                licenses["C"] = true
                text = "Экзамен сдан! Права категории C получены"
            _:
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
    if _driving == null or _driving == _work_vehicle or _driving == _faction_car or absf(speed) < 30.0:
        return
    if (_driving.kind == "moto" and bool(licenses.get("A", false))) or (_driving.kind != "moto" and has_license):
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
    if (kind == "bus" or kind == "truck") and not bool(licenses.get("C", false)):
        Sfx.play("error")
        _hud.show_toast("Нужны права категории C — экзамен в автошколе")
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
        "school_moto":
            v.kind = "moto"
            v.car_name = "Учебный мотоцикл"
            v.paint = Color(0.95, 0.55, 0.1)
            v.max_engine_force = 1500.0
            v.max_speed_kmh = 110.0
        "school_truck":
            v.kind = "truck"
            v.car_name = "Учебный грузовик"
            v.paint = Color(0.95, 0.55, 0.1)
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
    if _win_mode == "gps" or _win_mode == "taxi":
        _fill_gps_rows(rows)
    elif _win_mode == "inv":
        _fill_inv_rows(rows)
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
    if _win_mode == "taxi":
        if p == null:
            _win.set_buttons("Закрыть", "Выбери, куда ехать", true, false)
        else:
            _win.set_buttons("Закрыть", "Поехать — %s" % HudScript.format_money(_taxi_price(p["pos"])), true, true)
        return
    if _win_mode == "inv":
        _win.set_buttons("Выбросить" if p != null else "Закрыть", "Использовать", true, p != null)
        return
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
    if _win_mode == "inv" and _selected_payload() != null:
        _take_item(String(_selected_payload()))
        _hud.show_toast("Выброшено")
        _refresh_win(false)
        return
    if _win_mode == "market" or _win_mode == "garage" or _win_mode == "taxi" or _win_mode == "inv":
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
    if _win_mode == "taxi":
        _ride_taxi(p["pos"], String(p["name"]))
        return
    if _win_mode == "inv":
        _use_item(String(p))
        _refresh_win(false)
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
    for p: Vector3 in c.service_stations:
        out.append({"cat": "service", "icon": "wrench", "name": "СТО — ремонт и тюнинг", "pos": p})
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
    _refresh_turf()
    _hud.profile.set_faction_visible(fid != "")


func _faction_name() -> String:
    var f := FactionData.get_faction(faction)
    return String(f.get("name", ""))


func _org_text() -> String:
    if faction == "":
        return "Нет"
    return "%s · %s" % [_faction_name(), FactionData.rank_name(faction_rank, faction)]


func _salary() -> int:
    var base := FactionData.salary(faction, faction_rank)
    if FactionData.is_gang(faction):
        base += 150 * _turf_count(faction)   # каждый район приносит в общак
    return base


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
    _sms_add(_faction_name(), text)
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
    _duty.stop()
    _hud.minimap.turf = []
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
    if String(v["kind"]) != "car" and not bool(licenses.get("C", false)):
        Sfx.play("error")
        _hud.show_toast("Для автобуса и грузовика нужны права категории C (автошкола)")
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
            "nick": passport_name if passport_name != "" else "Без_Имени", "news": faction_news,
            "on_duty": _duty.active}


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
        if _driving.damage(dmg * 1.5):
            _hud.show_toast("Машина сломалась! Нужна СТО")
        _hurt(dmg, "Авария! −%d здоровья, машина %d%%" % [int(dmg), int(_driving.condition) if _driving else 0])
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


func _open_treatment() -> void:
    var no_charge := faction == "hospital"
    var price := 0 if no_charge else TREAT_PRICE
    if health >= 100.0:
        _open_dialog("Регистратура", "Здоровье: 100 / 100. Лечение не нужно.", [["Закрыть", _dialog.close]])
        return
    _open_dialog("Регистратура", "Здоровье: %d / 100\n\nПолное лечение: %s%s" % [int(health),
            "бесплатно" if no_charge else HudScript.format_money(price), " (ты сотрудник больницы)" if no_charge else ""],
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


# ================================================================ закон: розыск и КПЗ

func _add_wanted(n: int, reason: String) -> void:
    if jail_left > 0.0:
        return
    var old := wanted
    wanted = mini(5, wanted + n)
    _wanted_t = 0.0
    if wanted > old:
        Sfx.play("error")
        _hud.show_toast("Розыск ★%d: %s" % [wanted, reason])


func _update_law(delta: float, focus: Vector3) -> void:
    if jail_left > 0.0:
        jail_left -= delta
        if jail_left <= 0.0:
            jail_left = 0.0
            _interior = ""
            var site: Dictionary = _city.faction_sites["police"]
            _player.global_position = site["out"] + Vector3(0, 0.3, 0)
            _player.velocity = Vector3.ZERO
            _player.set_camera_yaw(float(site["out_yaw"]))
            Sfx.play("door")
            _hud.show_toast("Ты вышел на свободу. Больше не нарушай!")
            _save_game()
        return
    if wanted <= 0:
        return
    _wanted_t += delta
    if _wanted_t >= 180.0:
        _wanted_t = 0.0
        wanted -= 1
        _hud.show_toast("Розыск снижен: ★%d" % wanted if wanted > 0 else "Розыск снят")
        return
    _arrest_cd -= delta
    if _arrest_cd > 0.0 or _interior != "" or _home_inside >= 0 or faction == "police" or faction == "kgb":
        return
    _arrest_cd = 25.0
    var near_station: bool = focus.distance_to(_city.faction_sites["police"]["door"]) < 150.0
    var chance := 0.06 * wanted * (2.0 if near_station else 1.0)
    if randf() < chance:
        _arrest()


func _arrest() -> void:
    if _driving:
        var pos: Vector3 = _driving.get_exit_position()
        _driving.set_driven(false)
        _driving = null
        _player.global_position = pos
        _player.set_active(true)
    _job.stop()
    _work.stop()
    _duty.stop()
    _capt = {}
    var fine := mini(500 * wanted, cash + bank)
    var from_cash := mini(cash, fine)
    cash -= from_cash
    bank -= fine - from_cash
    if fine - from_cash > 0:
        _bank_log(-(fine - from_cash), "Штраф милиции")
    jail_left = 30.0 * wanted
    _open_dialog("Задержание", "Тебя задержал наряд милиции.\nРозыск: ★%d\nШтраф: %s\n\nКПЗ: %d секунд." % [wanted,
            HudScript.format_money(fine), int(jail_left)], [["Понятно", _dialog.close]])
    wanted = 0
    _interior = "police"
    _player.global_position = _city.kpz_cell
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(PI * 0.5)
    _sms_add("Милиция", "Вы задержаны и помещены в КПЗ. Штраф: %s" % HudScript.format_money(fine))
    _save_game()


# ================================================================ служба во фракции

func _toggle_duty() -> void:
    _dialog.close()
    if _duty.active:
        _duty.stop()
        _hud.show_toast("Смена закончена")
    else:
        if faction == "":
            return
        _job.stop()
        _work.stop()
        _duty.start(faction)
    _fmenu.close_menu()


func _on_duty_paid(amount: int, text: String) -> void:
    earned_total += amount
    bank += amount
    _bank_log(amount, "Служба: " + _faction_name())
    Sfx.play("coin")
    _hud.show_toast(text + " (на карту)")
    _add_xp(maxi(8, amount / 20))
    if _duty.calls_done % 2 == 0:
        faction_exp += 1
        var need := _need_exp()
        if need > 0 and faction_exp >= need:
            _hud.show_toast("Стаж набран — можно повыситься!")
    _save_game()


func _on_duty_message(text: String) -> void:
    Sfx.play("notify", -4.0)
    _hud.show_toast(text)
    _sms_add(_faction_name(), text)


# ================================================================ СМС и телефон

func _sms_add(from: String, text: String) -> void:
    sms.append([from, text])
    if sms.size() > 20:
        sms.pop_front()
    sms_unread += 1


func _on_app(id: String) -> void:
    match id:
        "work":
            _hud.close_phone()
            if _job.active or _work.active or _duty.active:
                _open_dialog("Работа", "Сейчас идёт смена. Закончить?", [["Закончить смену", _stop_all_work], ["Закрыть", _dialog.close]])
            else:
                var buttons := [["Курьер", _job_from_dialog.bind("courier")], ["Таксист (нужна своя машина)", _job_from_dialog.bind("taxi")]]
                if faction != "":
                    buttons.append(["Смена во фракции", _toggle_duty])
                buttons.append(["Закрыть", _dialog.close])
                _open_dialog("Работа", "Курьер и таксист — прямо отсюда. Автобус, грузчик, дальнобойщик, лесоруб — на месте (жёлтые точки на карте).", buttons)
        "bank":
            _hud.close_phone()
            _touch.blocked = true
            _hud.profile.open_bank()
        "gps":
            _hud.close_phone()
            _open_gps()
        "bag":
            _hud.close_phone()
            _open_inventory()
        "sms":
            _hud.close_phone()
            sms_unread = 0
            var text := ""
            for k in mini(6, sms.size()):
                var m: Array = sms[sms.size() - 1 - k]
                text += "%s: %s\n\n" % [m[0], m[1]]
            _open_dialog("СМС", text if text != "" else "Сообщений нет.", [["Закрыть", _dialog.close]])
        "taxi":
            _hud.close_phone()
            _open_taxi()
        "car":
            _on_summon_car()
        "biz":
            _hud.close_phone()
            _open_biz_app()


func _job_from_dialog(kind: String) -> void:
    _dialog.close()
    _on_job_selected(kind)


func _stop_all_work() -> void:
    _dialog.close()
    _job.stop()
    _work.stop()
    _duty.stop()
    _hud.show_toast("Смена закончена")


# ---------------------------------------------------------------- такси

func _open_taxi() -> void:
    if _driving:
        _hud.show_toast("Ты за рулём — такси не нужно")
        return
    if jail_left > 0.0 or _interior != "" or _home_inside >= 0:
        _hud.show_toast("Выйди на улицу, чтобы вызвать такси")
        return
    _touch.blocked = true
    _win_mode = "taxi"
    _win.open_window("ТАКСИ", "car", NAV_CATS, true, "Куда едем?")


func _taxi_price(to: Vector3) -> int:
    var d := Vector2(_focus().x - to.x, _focus().z - to.z).length()
    return int(round((TAXI_BASE + d * 0.8) / 10.0)) * 10


func _ride_taxi(to: Vector3, place: String) -> void:
    var price := _taxi_price(to)
    if not _pay(price, "Такси"):
        return
    _win.close_window()
    var spot = _free_spot_near(to, 0.0)
    var p: Vector3 = to + Vector3(1.5, 0.3, 1.5)
    if spot != null:
        var st: Transform3D = spot
        p = st.origin
    _player.global_position = p
    _player.velocity = Vector3.ZERO
    Sfx.play("door")
    _hud.show_toast("Такси довезло: %s (%s)" % [place, HudScript.format_money(price)])


# ================================================================ сумка

func _bag_count() -> int:
    var n := 0
    for k in inventory:
        n += int(inventory[k])
    return n


func _give_item(item: String) -> bool:
    if _bag_count() >= BAG_SIZE:
        Sfx.play("error")
        _hud.show_toast("Сумка полная (%d/%d)" % [BAG_SIZE, BAG_SIZE])
        return false
    inventory[item] = int(inventory.get(item, 0)) + 1
    return true


func _take_item(item: String) -> void:
    var n := int(inventory.get(item, 0)) - 1
    if n <= 0:
        inventory.erase(item)
    else:
        inventory[item] = n


## [+сытость, +здоровье] вещи (из меню ларьков).
func _item_info(item: String) -> Array:
    for list: Array in FOOD.values():
        for it: Array in list:
            if String(it[0]) == item:
                return [int(it[2]), int(it[3])]
    return [0, 0]


func _open_inventory() -> void:
    _touch.blocked = true
    _win_mode = "inv"
    _win.open_window("СУМКА  %d/%d" % [_bag_count(), BAG_SIZE], "bag", [{"id": "all", "name": "Вещи", "icon": "bag"}], false)


func _fill_inv_rows(rows: Array) -> void:
    for item: String in inventory:
        var info := _item_info(item)
        var icon := _item_icon(item)
        var what := ""
        if int(info[0]) > 0:
            what += "+%d сытости " % int(info[0])
        if int(info[1]) > 0:
            what += "+%d здоровья" % int(info[1])
        if item.begins_with("Канистра"):
            what = "+10 л в бак"
        rows.append({"icon": icon, "name": "%s · %s" % [item, what.strip_edges()], "value": "×%d" % int(inventory[item])})
        _win_payload.append(item)
    if rows.is_empty():
        rows.append({"icon": "bag", "name": "Сумка пуста — купи еду в ларьках", "value": "", "enabled": false})
        _win_payload.append(null)


func _use_item(item: String) -> void:
    if not inventory.has(item):
        return
    if item.begins_with("Канистра"):
        var car = _driving if _driving and _driving.uses_fuel else null
        if car == null:
            for c in _cars:
                if c.owned and c.visible and c.global_position.distance_to(_focus()) < 8.0:
                    car = c
        if car == null:
            _hud.show_toast("Подойди к своей машине, чтобы залить бензин")
            return
        car.fuel = minf(car.tank, car.fuel + 10.0)
        _take_item(item)
        Sfx.play("click")
        _hud.show_toast("+10 л в бак: %s" % car.car_name)
        return
    var info := _item_info(item)
    if int(info[1]) > 0 and int(info[0]) == 0 and health >= 100.0:
        _hud.show_toast("Ты здоров")
        return
    if int(info[0]) > 0 and int(info[1]) == 0 and hunger >= 99.0:
        _hud.show_toast("Ты не голоден")
        return
    hunger = minf(100.0, hunger + float(info[0]))
    health = minf(100.0, health + float(info[1]))
    if int(info[0]) > 0:
        _ate_once = true
    _take_item(item)
    Sfx.play("heal" if int(info[1]) > int(info[0]) else "eat")
    _hud.show_toast("%s: здоровье %d, сытость %d" % [item, int(health), int(hunger)])


# ================================================================ бизнес

func _build_business() -> void:
    _biz = []
    for pk: Dictionary in _city.pickups:
        var n := String(pk["name"])
        var price := 60000
        var income := 140
        if n == "УНИВЕРСАМ":
            price = 150000
            income = 320
        elif n == "АПТЕКА":
            price = 80000
            income = 180
        var title := ("Магазин «%s»" if n == "УНИВЕРСАМ" else "Ларёк «%s»") % n.capitalize()
        _biz.append({"title": title, "name": n, "pos": pk["pos"], "price": price, "income": income})
    for g: Vector3 in _city.gas_shops:
        _biz.append({"title": "АЗС", "name": "АЗС", "pos": g, "price": 220000, "income": 450})


func _biz_mine(i: int) -> bool:
    return biz_owned.has(str(i))


func _open_kiosk(i: int) -> void:
    var bz: Dictionary = _biz[i]
    var kname := String(bz["name"])
    var buttons := []
    if FOOD.has(kname):
        for it: Array in FOOD[kname]:
            var gain := ""
            if int(it[2]) > 0:
                gain += " +%d сытости" % int(it[2])
            if int(it[3]) > 0:
                gain += " +%d здоровья" % int(it[3])
            if String(it[0]).begins_with("Канистра"):
                gain = "в бак"
            buttons.append(["%s — %s (%s)" % [it[0], HudScript.format_money(int(it[1])), gain.strip_edges()], _buy_food.bind(i, it)])
    var text := "Здоровье: %d · Сытость: %d · Сумка: %d/%d" % [int(health), int(hunger), _bag_count(), BAG_SIZE]
    if _biz_mine(i):
        var till := int(biz_owned[str(i)])
        text += "\n\nТвой бизнес. Доход: %s в час, в кассе: %s" % [HudScript.format_money(int(bz["income"])), HudScript.format_money(till)]
        buttons.append(["Забрать выручку (%s)" % HudScript.format_money(till), _biz_collect.bind(i)])
        buttons.append(["Продать за %s" % HudScript.format_money(int(bz["price"]) / 2), _biz_sell.bind(i)])
    else:
        text += "\n\nБизнес продаётся: %s, доход ~%s в час" % [HudScript.format_money(int(bz["price"])), HudScript.format_money(int(bz["income"]))]
        buttons.append(["Купить бизнес — %s" % HudScript.format_money(int(bz["price"])), _biz_buy.bind(i)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog(String(bz["title"]), text, buttons)


func _buy_food(i: int, it: Array) -> void:
    if _bag_count() >= BAG_SIZE:
        Sfx.play("error")
        _hud.show_toast("Сумка полная")
        return
    if not _pay(int(it[1]), String(it[0])):
        return
    _give_item(String(it[0]))
    Sfx.play("coin")
    _hud.show_toast("%s в сумке (меню → Инвентарь или телефон → Сумка)" % it[0])
    _open_kiosk(i)


func _buy_license() -> void:
    if not _pay(LICENSE_PRICE, "Мэрия: лицензия на бизнес"):
        return
    has_biz_license = true
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Лицензия на бизнес получена")
    _save_game()


func _biz_buy(i: int) -> void:
    if not _check_docs(false):
        return
    if not has_biz_license:
        Sfx.play("error")
        _hud.show_toast("Нужна лицензия на бизнес — в мэрии, у паспортного стола")
        return
    if biz_owned.size() >= MAX_BIZ:
        Sfx.play("error")
        _hud.show_toast("Можно владеть не больше чем %d бизнесами" % MAX_BIZ)
        return
    var bz: Dictionary = _biz[i]
    if not _pay(int(bz["price"]), "Покупка бизнеса"):
        return
    biz_owned[str(i)] = 0
    Sfx.play("cash")
    _add_xp(50)
    _hud.show_toast("Теперь это твой бизнес: %s. Выручка копится в кассе" % bz["title"])
    _sms_add("Налоговая", "Бизнес «%s» оформлен на вас. Налог 10%% удерживается автоматически." % bz["title"])
    _save_game()
    _open_kiosk(i)


func _biz_collect(i: int) -> void:
    var till := int(biz_owned.get(str(i), 0))
    if till <= 0:
        _hud.show_toast("Касса пуста")
        return
    biz_owned[str(i)] = 0
    bank += till
    _bank_log(till, "Выручка: %s" % _biz[i]["title"])
    Sfx.play("cash")
    _hud.show_toast("Выручка +%s на карту" % HudScript.format_money(till))
    _save_game()
    _open_kiosk(i)


func _biz_sell(i: int) -> void:
    var bz: Dictionary = _biz[i]
    var pay := int(bz["price"]) / 2 + int(biz_owned.get(str(i), 0))
    biz_owned.erase(str(i))
    bank += pay
    _bank_log(pay, "Продажа бизнеса")
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Бизнес продан: +%s" % HudScript.format_money(pay))
    _save_game()


## Выручка капает каждый игровой час (минус 10% налога), касса вмещает 24 часа.
func _update_business(delta: float) -> void:
    if biz_owned.is_empty():
        return
    _biz_acc += delta * GAME_MINUTES_PER_SECOND
    if _biz_acc < 60.0:
        return
    _biz_acc -= 60.0
    for key: String in biz_owned.keys():
        var i := int(key)
        if i < 0 or i >= _biz.size():
            continue
        var income := int(_biz[i]["income"])
        var cap := income * 24
        var before := int(biz_owned[key])
        biz_owned[key] = mini(cap, before + int(income * 0.9))
        if before < cap and int(biz_owned[key]) >= cap:
            _sms_add("Бизнес", "Касса «%s» полная — забери выручку" % _biz[i]["title"])


func _open_biz_app() -> void:
    if biz_owned.is_empty():
        _open_dialog("Бизнес", ("У тебя нет бизнеса.\n\n1) Купи лицензию в мэрии (%s).\n2) Подойди к любому ларьку, магазину или АЗС "
                + "и нажми «Купить бизнес». Доход капает каждый час в кассу.") % HudScript.format_money(LICENSE_PRICE),
                [["Закрыть", _dialog.close]])
        return
    var text := ""
    var buttons := []
    for key: String in biz_owned:
        var i := int(key)
        var bz: Dictionary = _biz[i]
        text += "%s — в кассе %s (доход %s/ч)\n" % [bz["title"], HudScript.format_money(int(biz_owned[key])),
                HudScript.format_money(int(bz["income"]))]
        buttons.append(["Метка: %s" % bz["title"], _faction_gps.bind(bz["pos"], String(bz["title"]))])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Мой бизнес", text + "\nВыручку забирай на месте.", buttons)


# ================================================================ территории ОПГ

func _turf_key(i: int, j: int) -> String:
    return "%d,%d" % [i, j]


func _turf_rect(key: String) -> Rect2:
    var i := int(key.get_slice(",", 0))
    var j := int(key.get_slice(",", 1))
    var half := CityBuilder.BLOCK * 0.5
    return Rect2(i * CityBuilder.PITCH - half, j * CityBuilder.PITCH - half, CityBuilder.BLOCK, CityBuilder.BLOCK)


func _gang_ids() -> Array:
    var out := []
    for f: Dictionary in FactionData.LIST:
        if String(f.get("type", "")) == "gang":
            out.append(f["id"])
    return out


## Раздел районов: дома банд и соседние кварталы. Квартал с площадью и госфракциями не делят.
func _init_turf() -> void:
    var g := CityBuilder.GRID
    if turf.is_empty():
        for i in range(-g, g + 1):
            for j in range(-g, g + 1):
                var v := Vector2i(i, j)
                if v == Vector2i.ZERO or CityBuilder.FACTION_BLOCKS.has(v):
                    continue
                turf[_turf_key(i, j)] = String(CityBuilder.GANG_BLOCKS.get(v, ""))
        for key: String in turf.keys():
            if turf[key] == "" and randf() < 0.5:
                var ids := _gang_ids()
                turf[key] = ids[randi() % ids.size()]
    if _turf_labels.is_empty():
        for key: String in turf:
            var r := _turf_rect(key)
            var spot := Vector3(r.position.x + 2.0, CityBuilder.SIDE_H, r.position.y + 2.0)
            var l := Label3D.new()
            l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            l.font_size = 40
            l.pixel_size = 0.006
            l.outline_size = 10
            l.position = spot + Vector3(0, 2.6, 0)
            l.visibility_range_end = 45.0
            add_child(l)
            _turf_labels[key] = l
            _points.append({"pos": spot, "r": 2.5, "text": "ЗАХВАТ", "cb": _start_capture.bind(key), "car": false, "gang_only": true})
    _refresh_turf()


func _refresh_turf() -> void:
    var turf_on := FactionData.is_gang(faction)
    var list := []
    for key: String in turf:
        var gid := String(turf[key])
        var f := FactionData.get_faction(gid)
        var col: Color = f.get("color", Color(0.6, 0.6, 0.6))
        if _turf_labels.has(key):
            var l: Label3D = _turf_labels[key]
            l.visible = turf_on
            l.text = "Район: %s" % (f.get("name", "ничей") if gid != "" else "ничей")
            l.modulate = col if gid != "" else Color(0.85, 0.85, 0.85)
        if turf_on and gid != "":
            list.append([_turf_rect(key), col])
    _hud.minimap.turf = list


func _start_capture(key: String) -> void:
    if not FactionData.is_gang(faction):
        return
    if String(turf.get(key, "")) == faction:
        _hud.show_toast("Это уже ваш район")
        return
    if not _capt.is_empty():
        return
    if _capt_cd > 0.0:
        _hud.show_toast("Братва ещё не готова: следующий захват через %d с" % int(_capt_cd))
        return
    _capt = {"key": key, "left": 60.0, "warned": false}
    Sfx.play("notify")
    _hud.show_toast("ЗАХВАТ! Продержись в квартале 60 секунд")
    _add_wanted(1, "захват территории")


func _update_turf(delta: float, focus: Vector3) -> void:
    _capt_cd = maxf(0.0, _capt_cd - delta)
    if not _capt.is_empty():
        var key := String(_capt["key"])
        if not _turf_rect(key).grow(10.0).has_point(Vector2(focus.x, focus.z)):
            _capt = {}
            _capt_cd = 60.0
            Sfx.play("error")
            _hud.show_toast("Захват сорван: ты ушёл с территории")
        else:
            _capt["left"] = float(_capt["left"]) - delta
            if float(_capt["left"]) < 30.0 and not bool(_capt["warned"]):
                _capt["warned"] = true
                var holder := String(turf.get(key, ""))
                if holder != "":
                    _capt["left"] = float(_capt["left"]) + 15.0
                    _hud.show_toast("%s подтягивают своих! Держись ещё" % FactionData.get_faction(holder).get("name", ""))
            if float(_capt["left"]) <= 0.0:
                turf[key] = faction
                _capt = {}
                _capt_cd = 300.0
                bank += 1500
                _bank_log(1500, "Захват района")
                faction_exp += 1
                Sfx.play("levelup")
                _hud.show_toast("Район наш! +1 500 ₽ из общака, +1 стаж")
                _sms_add(_faction_name(), "Район взят под контроль. Каждая получка — больше на 150 ₽ за район.")
                _refresh_turf()
                _save_game()
    # другие банды тоже не спят: раз в 5 минут кто-то что-то отжимает
    _ai_turf_t += delta
    if _ai_turf_t >= 300.0:
        _ai_turf_t = 0.0
        var keys := turf.keys()
        var ids := _gang_ids()
        var key: String = keys[randi() % keys.size()]
        var gid: String = ids[randi() % ids.size()]
        var old := String(turf[key])
        if old != gid and (_capt.is_empty() or String(_capt["key"]) != key):
            turf[key] = gid
            if FactionData.is_gang(faction) and old == faction:
                _sms_add(_faction_name(), "%s отжали наш район. Верните его!" % FactionData.get_faction(gid).get("name", ""))
                _hud.show_toast("Наш район захватили: %s" % FactionData.get_faction(gid).get("name", ""))
            _refresh_turf()


func _turf_count(gid: String) -> int:
    var n := 0
    for key: String in turf:
        if turf[key] == gid:
            n += 1
    return n


# ================================================================ СТО: ремонт и тюнинг

func _open_sto() -> void:
    var car = _driving
    if car == null or not car.owned or car == _work_vehicle or car == _faction_car:
        return
    var repair := int(ceil((100.0 - car.condition) * 15.0))
    var buttons := []
    if repair > 0:
        buttons.append(["Ремонт — %s" % HudScript.format_money(repair), _sto_repair.bind(repair)])
    buttons.append(["Покраска — %s" % HudScript.format_money(PAINT_PRICE), _sto_paint_menu])
    if car.kind == "car":
        buttons.append(["Диски — %s" % HudScript.format_money(RIM_PRICE), _sto_rim_menu])
        buttons.append(["%s — %s" % ["Снять тонировку" if car.tint else "Тонировка", HudScript.format_money(TINT_PRICE)], _sto_tint])
        buttons.append(["Красивые номера — %s" % HudScript.format_money(PLATE_PRICE), _sto_plate])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("СТО — %s" % car.car_name, "Состояние: %d%%\nНомер: %s" % [int(car.condition),
            car.plate_text if car.plate_text != "" else "—"], buttons)


func _sto_repair(price: int) -> void:
    if _driving == null or not _pay(price, "СТО: ремонт"):
        return
    _driving.repair()
    Sfx.play("cash")
    _hud.show_toast("Машина как новая")
    _save_game()
    _open_sto()


func _sto_paint_menu() -> void:
    var buttons := []
    for pc: Array in PAINTS:
        buttons.append([String(pc[0]), _sto_paint.bind(pc[1])])
    buttons.append(["Назад", _open_sto])
    _open_dialog("Покраска — %s" % HudScript.format_money(PAINT_PRICE), "Выбери цвет", buttons)


func _sto_paint(col: Color) -> void:
    if _driving == null or not _pay(PAINT_PRICE, "СТО: покраска"):
        return
    _driving.repaint(col)
    Sfx.play("cash")
    _save_game()
    _open_sto()


func _sto_rim_menu() -> void:
    var buttons := []
    for rc: Array in RIMS:
        buttons.append([String(rc[0]), _sto_rim.bind(rc[1])])
    buttons.append(["Стандартные (бесплатно)", _sto_rim.bind(Color(0, 0, 0, 0))])
    buttons.append(["Назад", _open_sto])
    _open_dialog("Диски — %s" % HudScript.format_money(RIM_PRICE), "Выбери цвет дисков", buttons)


func _sto_rim(col: Color) -> void:
    if _driving == null:
        return
    if col.a > 0.0 and not _pay(RIM_PRICE, "СТО: диски"):
        return
    _driving.rim_color = col
    _driving.apply_tuning()
    Sfx.play("cash")
    _save_game()
    _open_sto()


func _sto_tint() -> void:
    if _driving == null or not _pay(TINT_PRICE, "СТО: тонировка"):
        return
    _driving.tint = not _driving.tint
    _driving.apply_tuning()
    Sfx.play("cash")
    _save_game()
    _open_sto()


## Красивый номер: одинаковые цифры и буквы, например «А777АА 99».
func _sto_plate() -> void:
    if _driving == null or not _pay(PLATE_PRICE, "СТО: номера"):
        return
    var ch := PLATE_LETTERS[randi() % PLATE_LETTERS.length()]
    var d := randi() % 9 + 1
    var regions := [77, 99, 177, 197]
    _driving.plate_text = "%s%d%d%d%s%s %d" % [ch, d, d, d, ch, ch, regions[randi() % regions.size()]]
    _driving.apply_tuning()
    Sfx.play("cash")
    _hud.show_toast("Новый номер: %s" % _driving.plate_text)
    _save_game()
    _open_sto()


# ================================================================ погода

func _weather_light() -> float:
    match weather:
        "rain":
            return 0.45
        "snow":
            return 0.6
        "cloudy":
            return 0.7
    return 1.0


func _update_weather(delta: float, focus: Vector3) -> void:
    _weather_t -= delta
    if _weather_t <= 0.0:
        _weather_t = randf_range(300.0, 540.0)
        var r := randf()
        var next := "clear"
        if r < 0.22:
            next = "rain"
        elif r < 0.30:
            next = "snow"
        elif r < 0.50:
            next = "cloudy"
        if next != weather:
            weather = next
            _hud.show_toast("Погода: %s" % WEATHER_NAMES[weather])
            _update_daylight()
    var raining := weather == "rain"
    var snowing := weather == "snow"
    _wet = move_toward(_wet, 1.0 if raining else 0.0, delta / (20.0 if raining else 90.0))
    _snow = move_toward(_snow, 1.0 if snowing else 0.0, delta / (60.0 if snowing else 120.0))
    _city.set_weather(_wet, _snow)
    CarScript.grip = lerpf(1.0, 0.72, _wet) * lerpf(1.0, 0.6, _snow)
    var inside := _interior != "" or _home_inside >= 0
    var top := focus + Vector3(0, 16, 0)
    _rain_fx.emitting = raining and not inside
    _snow_fx.emitting = snowing and not inside
    if raining:
        _rain_fx.global_position = top
    if snowing:
        _snow_fx.global_position = top
    _env.fog_density = _base_fog() * (2.2 if raining or snowing else (1.3 if weather == "cloudy" else 1.0))
    if _rain_snd.stream != null:
        var want := -14.0 if raining else -80.0
        if inside and raining:
            want = -24.0
        _rain_snd.volume_db = move_toward(_rain_snd.volume_db, want, delta * 20.0)
        if _rain_snd.volume_db > -70.0 and not _rain_snd.playing:
            _rain_snd.play()
        elif _rain_snd.volume_db <= -70.0 and _rain_snd.playing:
            _rain_snd.stop()
    if raining:
        _thunder_t -= delta
        if _thunder_t <= 0.0:
            _thunder_t = randf_range(25.0, 60.0)
            Sfx.play("thunder", -4.0 if not inside else -12.0, randf_range(0.85, 1.1))


func _base_fog() -> float:
    var fogs := [0.007, 0.0035, 0.0015]
    return fogs[clampi(int(_menu.settings["view"]), 0, 2)]


# ================================================================ задания новичка

func _check_quest() -> void:
    if quest_i >= QUESTS.size():
        return
    var q: Array = QUESTS[quest_i]
    var done := false
    match String(q[0]):
        "passport":
            done = passport_name != ""
        "eat":
            done = _ate_once
        "earn":
            done = earned_total >= 2000
        "license":
            done = has_license
        "car":
            done = _has_owned_car()
        "faction":
            done = faction != ""
        "home":
            done = home >= 0
        "biz":
            done = has_biz_license
    if not done:
        return
    var reward := int(q[2])
    bank += reward
    _bank_log(reward, "Задание новичка")
    quest_i += 1
    Sfx.play("levelup")
    _add_xp(25)
    var text := "Задание выполнено! +%s на карту" % HudScript.format_money(reward)
    if quest_i >= QUESTS.size():
        text += ". Все задания новичка пройдены!"
        _sms_add("Помощник", "Ты прошёл все задания новичка. Добро пожаловать в город!")
    else:
        _sms_add("Помощник", "Следующее задание: %s" % QUESTS[quest_i][1])
    _hud.show_toast(text)
    _save_game()


func _tow_to_sto(car) -> void:
    if not _pay(1000, "Эвакуатор"):
        return
    _dialog.close()
    var best: Vector3 = _city.service_stations[0]
    for p: Vector3 in _city.service_stations:
        if p.distance_to(_focus()) < best.distance_to(_focus()):
            best = p
    car.reset_to(Transform3D(Basis(), best + Vector3(0, 0.6, 3.0)))
    _set_gps(best, "СТО", true)
    _hud.show_toast("Машина на СТО. Сядь в неё там и нажми «СТО» — ремонт")


const ITEM_ICONS := {"Шаурма": "shawarma", "Шаурма двойная": "shawarma", "Хлеб": "bread", "Батон": "bread",
        "Бутерброд": "sandwich", "Пирожок": "sandwich", "Круассан": "sandwich", "Кофе": "coffee", "Чай": "coffee",
        "Квас": "bottle", "Кефир": "bottle", "Энергетик": "bottle", "Пельмени": "dumplings", "Колбаса": "dumplings",
        "Комплексный обед": "dumplings", "Хот-дог": "hotdog", "Аптечка": "firstaid", "Бинт": "bandage",
        "Витамины": "vitamins", "Канистра 10 л": "canister"}


func _item_icon(item: String) -> String:
    return String(ITEM_ICONS.get(item, "bag"))
