extends Node3D
## Точка входа: небо, смена дня и ночи, район, игрок, машины, интерфейс,
## деньги (наличные и карта), документы, работы, заправки, сохранение.

const PlayerScene := preload("res://scenes/player.tscn")
const CarScene := preload("res://scenes/car.tscn")
const CityBuilder := preload("res://scripts/city_builder.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const HudScript := preload("res://scripts/hud.gd")
const Weapons := preload("res://scripts/weapons.gd")
const JobScript := preload("res://scripts/job.gd")
const MenuScript := preload("res://scripts/menu.gd")
const TrafficScript := preload("res://scripts/traffic.gd")
const PedestriansScript := preload("res://scripts/pedestrians.gd")
const CarModel := preload("res://scripts/car_model.gd")
const Clothes := preload("res://scripts/clothes.gd")
const ListWindowScript := preload("res://scripts/list_window.gd")
const MarkerScript := preload("res://scripts/marker.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const SpeedoScript := preload("res://scripts/speedo.gd")
const WelcomeScript := preload("res://scripts/welcome.gd")
const NpcScript := preload("res://scripts/npc.gd")
const TrainScript := preload("res://scripts/train.gd")
const WorkScript := preload("res://scripts/work.gd")
const FactionData := preload("res://scripts/faction_data.gd")
const FactionMenuScript := preload("res://scripts/faction_menu.gd")
const StartScreenScript := preload("res://scripts/start_screen.gd")
const DutyScript := preload("res://scripts/duty.gd")
const CarScript := preload("res://scripts/car.gd")

const VERSION := "Альфа 1.0"
const SAVE_PATH := "user://save_v2.cfg"   # новая карта (острова) — сохранения начинаются заново
const START_MONEY := 5000
const GAME_MINUTES_PER_SECOND := 1.0   # 1 реальная секунда = 1 игровая минута
## Машины на Общем рынке: название, цена, цвет, макс. скорость, мощность.
## Свой персонаж для ОПГ «Тяп-Ляп» (те же анимации, перенесены на его скелет).
const TYAP_SKIN := "res://models/character/tyap.gltf"
const CAR_MODELS := [
    {"name": "Шестёрка", "price": 8000, "color": Color(0.92, 0.92, 0.90), "speed": 110.0, "force": 4300.0, "model": "vaz2106"},
    {"name": "Комфорт", "price": 15000, "color": Color(0.15, 0.22, 0.45), "speed": 125.0, "force": 5000.0, "model": "sedan"},
    {"name": "Спорт", "price": 28000, "color": Color(0.45, 0.06, 0.10), "speed": 155.0, "force": 6500.0, "model": "sport"},
    {"name": "Люкс", "price": 45000, "color": Color(0.10, 0.10, 0.11), "speed": 175.0, "force": 7400.0, "model": "coupe"},
    {"name": "Мотоцикл", "price": 12000, "color": Color(0.75, 0.10, 0.10), "speed": 150.0, "force": 1500.0, "kind": "moto"},
    {"name": "Внедорожник", "price": 60000, "color": Color(0.12, 0.14, 0.12), "speed": 165.0, "force": 8200.0, "model": "suv"},
    # новые — только в конец: сохранения хранят машины по номеру в списке
    {"name": "Нива", "price": 22000, "color": Color(0.82, 0.78, 0.62), "speed": 130.0, "force": 6200.0, "model": "niva"},
    {"name": "Волга ГАЗ-3102", "price": 38000, "color": Color(0.85, 0.85, 0.83), "speed": 160.0, "force": 7000.0, "model": "volga"},
    {"name": "УАЗ «Аварийка» 04", "price": 26000, "color": Color(0.95, 0.80, 0.25), "speed": 110.0, "force": 6000.0, "model": "uaz_gas"},
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
## Задания новичка от Петера: [id, что сделать, награда, обязательное].
## Первые три (паспорт, права, работа) обязательны, от остальных можно отказаться.
const QUESTS := [
    ["passport", "Получи паспорт в мэрии (паспортный стол)", 1000, true],
    ["license", "Сдай на права категории B в автошколе у вокзала", 2000, true],
    ["earn", "Устройся на работу и заработай 2 000 ₽ (телефон → Работа)", 1000, true],
    ["eat", "Купи еду в ларьке и съешь её из сумки", 300, false],
    ["car", "Купи машину или мотоцикл на Общем рынке", 3000, false],
    ["faction", "Вступи во фракцию или ОПГ", 2000, false],
    ["home", "Купи жильё (Навигатор → Дом)", 5000, false],
    ["biz", "Получи лицензию на бизнес в мэрии", 3000, false],
]
## Что говорит Петер, выдавая задание.
const PETER_TALK := {
    "passport": "Первым делом — документы. Без паспорта тебя ни на работу не возьмут, ни права не дадут, ни квартиру не продадут. Иди в мэрию, там паспортный стол. Я отмечу тебе мэрию на карте.",
    "license": "Паспорт есть — уже человек! Теперь права. Автошкола ДОСААФ тут рядом, левее вокзала. Сначала теория, пять вопросов, потом вождение по городу. Не гони больше семидесяти — инструктор этого не любит.",
    "earn": "Права есть, а денег нет — непорядок. Открой телефон, раздел «Работа»: автобус, грузчик, лесоруб, дальнобой, такси. Заработай первые две тысячи — и считай, что в городе ты свой.",
    "eat": "Видишь шкалу голода? Если пустая — здоровье тает. В ларьке на площади возьми чего-нибудь поесть и съешь из сумки.",
    "car": "Пешком по Казани далеко не уйдёшь. На Общем рынке продают машины — «шестёрку» или «копейку» на первое время вполне хватит.",
    "faction": "Хочешь служить — милиция, больница, пожарные, мэрия, КГБ. Хочешь по-другому — есть и ОПГ. Зайди в любое здание фракции, в отдел кадров.",
    "home": "Своя квартира — своё место, где можно переодеться и отдохнуть. В навигаторе есть раздел «Дом», там всё, что продаётся.",
    "biz": "Ну и напоследок — для деловых. Лицензия на бизнес в мэрии, а с ней можно купить ларёк или автосалон и получать доход.",
}
const WEATHER_NAMES := {"clear": "Ясно", "cloudy": "Пасмурно", "rain": "Дождь", "snow": "Снег"}
const ENTER_DISTANCE := 3.2
const LAMP_LIGHTS := 8   # сколько фонарей рядом с игроком дают настоящий свет ночью
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
    "ПИРОЖКИ": [["Пирожок с картошкой", 60, 25, 0], ["Пирожок с мясом", 90, 35, 0], ["Чай", 40, 5, 2]],
    "ПРОДУКТЫ": [["Хлеб", 60, 15, 0], ["Бутерброд", 120, 25, 0], ["Кефир", 90, 15, 2], ["Пельмени", 300, 55, 0]],
    "КОФЕ": [["Кофе с молоком", 80, 10, 3], ["Ватрушка", 70, 20, 0], ["Эклер", 90, 25, 0]],
    "КВАС": [["Квас", 70, 8, 2], ["Пирожок", 80, 20, 0]],
    "ЧЕБУРЕКИ": [["Чебурек", 120, 30, 0], ["Чебурек с сыром", 160, 35, 0], ["Айран", 70, 8, 2]],
    "СЕЛЬПО": [["Хлеб", 50, 15, 0], ["Молоко", 60, 12, 2], ["Пряники", 80, 20, 0], ["Сало", 200, 40, 0]],
    "УНИВЕРСАМ": [["Батон", 50, 15, 0], ["Колбаса", 250, 40, 0], ["Комплексный обед", 450, 80, 5]],
    "АПТЕКА": [["Аптечка", 400, 0, 40], ["Бинт", 150, 0, 15], ["Витамины", 200, 5, 10]],
    "АЗС": [["Беляш", 100, 30, 0], ["Лимонад «Тархун»", 60, 5, 5], ["Канистра 10 л", 600, 0, 0]],
    "БУФЕТ": [["Пирожок с капустой", 60, 20, 0], ["Пирожок с мясом", 80, 25, 0], ["Беляш", 90, 30, 0],
            ["Чай в подстаканнике", 40, 5, 2], ["Лимонад «Буратино»", 60, 8, 2]],
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
    {"id": "cities", "name": "Города", "icon": "pin"},
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
## Что сказать в чате при смене погоды.
const WEATHER_TIPS := {"clear": "ясно, без осадков.", "cloudy": "облачно, возможен дождь.",
        "rain": "дождь — асфальт мокрый, тормозной путь длиннее.", "snow": "снег — дороги скользкие, одевайтесь теплее."}
## Городские новости и объявления (радио «Маяк» и горисполком).
const NEWS := [
    "Радио «Маяк»: на заводе перевыполнен план квартала. Слава труду!",
    "Горисполком: в субботу субботник во дворах. Явка обязательна.",
    "Милиция: участились угоны «Жигулей». Не оставляйте машины без присмотра.",
    "В универсам завезли колбасу. Очередь с восьми утра.",
    "Автошкола на площади набирает группы на права категорий B, A и C.",
    "Больница напоминает: при плохом самочувствии обращайтесь в регистратуру.",
    "Пожарная часть: не разводите костры во дворах.",
    "ДК приглашает на танцы в субботу вечером.",
    "КГБ: о подозрительных лицах сообщайте в приёмную.",
    "Требуются водители автобуса и таксисты — работа в телефоне.",
    "На рынке подешевели канистры с бензином.",
    "Сберкасса: храните деньги на карте — так надёжнее.",
]
const DAY_AMBIENT := Color(0.36, 0.40, 0.48)
const NIGHT_AMBIENT := Color(0.13, 0.14, 0.22)

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
var has_pistol := false      # купленный на рынке ПМ
var weapon_id := "fist"      # что в руках
var _fire_cd := 0.0
var _flash: OmniLight3D = null
var _tracer: MeshInstance3D = null
var _tracer_t := 0.0
var faction_exp := 0         # стаж: сколько получек получено на текущем ранге
var _payday_acc := 0.0       # игровых минут с последней получки
var _faction_car = null      # машина из автопарка (одна на игрока)
var _interior := ""          # в каком здании игрок ("" — на улице)
var health := 100.0          # здоровье 0..100
var hunger := 100.0          # сытость 0..100 (0 — голодный, теряешь здоровье)
var home := -1               # номер купленного жилья в _city.homes, -1 — нет
var _home_inside := -1       # в каком жилье сейчас игрок
var _podezd := -1            # в каком подъезде (номер двери в _city.entrances), -1 — на улице
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
var quest_active := false    # задание взято у Петера (иначе он его ещё не выдал)
var peter_met := false       # уже познакомились с Петером
var _peter = null            # Петер у вокзала (peter.gd)
var rent_free_used := false  # первый прокат мопеда у Геннадия — бесплатно
var _peter_call_t := -1.0    # через сколько секунд Петер «позвонит» с новым заданием
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
var _speedo: SpeedoScript
var _welcome: WelcomeScript = null
var welcome_seen := false     # окно «Добро пожаловать» уже показали
var quests_skipped := false   # отказался от квестовой линии (можно начать у Петера)
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
var _lamp_lights: Array[SpotLight3D] = []
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


## Стартовый экран: меню → выбор сервера → загрузка. Город строится после выбора сервера,
## потом сразу начинается игра (без второго меню).
var _start: StartScreenScript


func _ready() -> void:
    set_process(false)
    var layer := CanvasLayer.new()
    layer.layer = 30
    add_child(layer)
    _start = StartScreenScript.new()
    layer.add_child(_start)
    _start.server_chosen.connect(_on_server_chosen.bind(layer))
    Music.volume = _start_music_volume()
    Music.play_menu()


func _start_music_volume() -> float:
    var cfg := ConfigFile.new()
    var steps := [0.0, 0.25, 0.5, 0.75, 1.0]
    var idx := 2
    if cfg.load("user://settings.cfg") == OK:
        idx = int(cfg.get_value("settings", "music", 2))
    return float(steps[clampi(idx, 0, steps.size() - 1)])


func _on_server_chosen(_index: int, layer: CanvasLayer) -> void:
    await _start.progress(35.0, "Подключение к серверу...", 0.7)
    await _start.progress(45.0, "Загрузка города...", 0.2)
    await get_tree().process_frame
    await get_tree().process_frame
    _setup()
    await _start.progress(100.0, "Добро пожаловать!", 0.4)
    layer.queue_free()
    _start = null
    set_process(true)
    _on_play()


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
    _hud.chat("Добро пожаловать в City Alpha! Коснись чата, чтобы открыть историю сообщений.", "info")
    if faction != "":
        _hud.chat("Ты во фракции «%s», ранг: %s." % [_faction_name(), FactionData.rank_name(faction_rank, faction)], "faction")


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

    _follow_seat()
    var focus := _focus()
    var hcam := get_viewport().get_camera_3d()
    if hcam:
        _city.update_horizon(hcam.global_position, _view_far)
    var speed := 0.0
    if _driving:
        speed = _driving.speed_kmh()
    _update_vitals(delta, speed)
    if _driving and not Music.is_radio():
        Music.play_radio()
    elif not _driving and Music.is_radio():
        Music.stop()
    # саундтрек погони: розыск от двух звёзд, пешком (в машине — радио)
    if not _driving and wanted >= 2 and jail_left <= 0.0:
        Music.play_score("score_chase")
    elif Music.is_score() and (wanted < 2 or jail_left > 0.0):
        Music.stop_score()
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
    _update_station(delta)
    _update_rent(delta)
    if _peter_call_t > 0.0:
        _peter_call_t -= delta
        if _peter_call_t <= 0.0:
            if _dialog.visible or _interior != "" :
                _peter_call_t = 3.0   # занят — позвонит чуть позже
            else:
                _peter_call()
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
    Sfx.indoor = _interior != "" or _home_inside >= 0 or _podezd >= 0

    _update_weapons(delta)
    _update_chat_events(delta)
    var uk := _uniform_key()
    if uk != _last_uniform:
        _apply_look()

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
    if job_text == "" and quest_i < QUESTS.size() and not quests_skipped:
        if not peter_met:
            job_text = "Подойди к Петеру у входа в вокзал — он всё расскажет"
        elif quest_active:
            job_text = "Задание: %s · награда %s" % [QUESTS[quest_i][1], HudScript.format_money(int(QUESTS[quest_i][2]))]
        else:
            job_text = "У Петера новое задание — он скоро позвонит (или подойди к нему на вокзал)"
    _hud.set_job(job_text)
    if _hud.phone_open:
        _hud.update_phone(_job.active or _work.active, _phone_text(job_text))

    var mini := _hud.minimap
    mini.focus = focus
    if _interior != "":   # в здании карта показывает, где стоит само здание
        mini.focus = _city.faction_sites[_interior]["door"]
    elif _home_inside >= 0:
        mini.focus = _city.homes[_home_inside]["pos"]
    elif _podezd >= 0:
        mini.focus = _city.entrances[_podezd]["out"]
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

    _speed_label.visible = false
    _speedo.visible = _driving != null and not _touch.blocked
    _touch.xp_k = float(xp) / float(_need_xp())
    if _driving:
        var vp := get_viewport().get_visible_rect().size
        _speedo.position = SpeedoScript.rect_for(vp).position
        var fk: float = _driving.fuel / maxf(1.0, _driving.tank) if _driving.uses_fuel else 1.0
        _speedo.set_state(speed, fk, _driving.uses_fuel, _driving.condition / 100.0, _driving.braking,
                _driving.hand_on, _driving.locked, _driving.lights_on())
        if _driving.uses_fuel:
            var fuel: float = _driving.fuel
            var tank: float = _driving.tank
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
    if event is InputEventKey:
        var ke := event as InputEventKey
        if ke.pressed and not ke.echo and ke.keycode == KEY_Q and _driving == null:
            _on_weapon_switch()
        if ke.pressed and not ke.echo and ke.keycode == KEY_L and _driving != null:
            _toggle_lights()
        if ke.pressed and not ke.echo and ke.keycode == KEY_K and _driving != null:
            _toggle_lock()
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
    if not _started and not welcome_seen and not peter_met:
        _show_welcome.call_deferred()
    elif not _started and not peter_met and not quests_skipped:
        _hud.show_toast("Тебя встречает Петер — подойди к нему у входа в вокзал")
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
    quest_active = false
    peter_met = false
    welcome_seen = false
    quests_skipped = false
    rent_free_used = false
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
    _podezd = -1
    _clear_gps()
    _apply_look()
    _player.global_position = _spawn_pos()
    _player.set_camera_yaw(0.0)
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
    _hud.show_toast(text + " (на карту)", "money")
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


## Кнопка замка на спидометре: закрыть / открыть двери.
func _toggle_lock() -> void:
    if _driving == null:
        return
    _driving.locked = not _driving.locked
    Sfx.play("lock", -6.0)
    _hud.show_toast("Двери закрыты на замок" if _driving.locked else "Двери открыты")


## Кнопка фар на спидометре.
func _toggle_lights() -> void:
    if _driving == null:
        return
    var on: bool = _driving.toggle_lights()
    Sfx.play("click")
    _hud.show_toast("Фары включены" if on else "Фары выключены")


func _on_radio() -> void:
    if _driving:
        Sfx.play("radio_tune", -6.0, randf_range(0.9, 1.1))
        _hud.show_toast(Music.next_station())


func _on_step(run: bool) -> void:
    Sfx.play(["step", "step2", "step3"][randi() % 3], -17.0 if run else -21.0, randf_range(0.92, 1.08))


# ---------------------------------------------------------------- машины

## Кнопка действия: сначала работа, потом точка рядом, потом машина.
func _on_interact() -> void:
    if _hud.phone_open or _win.visible or _dialog.visible or _hud.profile.is_open() or _fmenu.visible:
        return
    if _work.action_text(_focus(), _driving != null) != "":
        _work.do_action()
        return
    if _duty.action_text(_focus(), _driving != null) != "":
        var truck: bool = _driving != null and _driving == _faction_car and FactionData.base(faction) == "fire" and _driving.kind == "truck"
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
        _player.set_seated("")
        _player.global_position = pos
        _player.set_active(true)
        _player.set_camera_yaw(yaw)
        Sfx.play("car_door", -6.0, randf_range(0.95, 1.05))
    else:
        var car = _nearest_car()
        if car == null:
            return
        if car.locked:   # своя машина: ключом открываем замок
            car.locked = false
            Sfx.play("lock", -6.0)
        if car.kind != "moto":
            Sfx.play("car_door", -6.0, randf_range(0.95, 1.05))
        Sfx.play("scooter_start" if car.kind == "moto" or car.scooter else "engine_start", -9.0, randf_range(0.95, 1.05))
        _player.set_active(false)
        if car.kind == "moto":
            var rider_col: Color = Clothes.colors(look)["jacket"]
            var rider_tex := String(Clothes.textures(look)["jacket"])
            if rider_tex.contains("red"):
                rider_col = Color(0.70, 0.10, 0.10)
            elif rider_tex.contains("leather_"):
                rider_col = Color(0.20, 0.14, 0.10) if rider_tex.contains("brown") else Color(0.08, 0.08, 0.08)
            car.set_rider_color(rider_col)
        car.set_driven(true)
        _driving = car
        _seat_driver()


func _sit_bench(i: int) -> void:
    var bn: Array = _city.benches[i]
    if _player.seated == "" and _player.sit_at(bn[0], bn[1]):
        _hud.show_toast("Сидишь на лавочке. Пошевели джойстиком, чтобы встать")


## Водитель виден в машине: модель игрока садится за руль с анимацией вождения.
var _seat_local := Transform3D()


func _seat_driver() -> void:
    if _driving == null or not _player.can_sit("drive"):
        return
    var seat: Array = _driving.driver_seat()
    if seat.is_empty():
        return
    _player.set_seated("drive")
    _player.set_seat_scale(float(seat[1]))
    _seat_local = _player.driver_transform(seat[0], float(seat[1]))
    _follow_seat()


func _follow_seat() -> void:
    if _player.seated != "drive":
        return
    if _driving == null:
        _player.set_seated("")
        _player.set_active(false)
        return
    _player.global_transform = (_driving.global_transform as Transform3D) * _seat_local


func _nearest_car():
    var best = null
    var best_d := ENTER_DISTANCE
    var all: Array = _cars.duplicate()
    if _work_vehicle != null:
        all.append(_work_vehicle)
    if _faction_car != null:
        all.append(_faction_car)
    if _rent_scooter != null:
        all.append(_rent_scooter)
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
    _rain_snd.bus = "Ambient"
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
        var l := SpotLight3D.new()   # конус вниз, как у настоящего фонаря
        l.spot_range = 13.0
        l.spot_angle = 62.0
        l.spot_attenuation = 1.2
        l.spot_angle_attenuation = 0.9
        l.rotation_degrees = Vector3(-90, 0, 0)
        l.light_energy = 2.2
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
            l.light_energy = 2.2 * _night_k


var _sort_focus := Vector3.ZERO


func _closer_to_focus(a: Vector3, b: Vector3) -> bool:
    return a.distance_squared_to(_sort_focus) < b.distance_squared_to(_sort_focus)


## Стоянка у рынка: сюда доставляют купленные машины.
func _car_spawn(i: int) -> Transform3D:
    var xs := [-16.0, -10.0, 10.0, 16.0, -4.0, 4.0, -22.0, 22.0, -28.0]
    return Transform3D(Basis(), Vector3(xs[i % xs.size()], 0.6, 20.0))


func _spawn_cars() -> void:
    var saved: Array = _loaded.get("cars", [])
    var owned: Array = _loaded.get("owned", [])
    for i in CAR_MODELS.size():
        var m: Dictionary = CAR_MODELS[i]
        var car = CarScene.instantiate()
        car.paint = m["color"]
        car.kind = String(m.get("kind", "car"))
        car.model_id = String(m.get("model", ""))
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
    _player.position = _spawn_pos()   # после входа в игру — всегда на вокзале
    add_child(_player)
    _player.set_camera_yaw(0.0)
    var peter = NpcScript.new()
    peter.position = _city.peter_pos
    add_child(peter)
    _peter = peter
    _update_peter()
    _spawn_station_life()


## Где появляется игрок: площадь у вокзала.
func _spawn_pos() -> Vector3:
    return _city.station_spawn if _city != null else PLAYER_SPAWN
    _player.touch = _touch
    _apply_look()
    _player.stepped.connect(_on_step)
    _player.set_camera_yaw(float(_loaded.get("player_yaw", PI)))
    _equip_weapon.call_deferred()


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
        _seat_driver()
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
    cfg.set_value("player", "has_pistol", has_pistol)
    cfg.set_value("player", "weapon", weapon_id)
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
    if _driving and (_driving == _work_vehicle or _driving == _faction_car or _driving == _rent_scooter):
        cfg.set_value("player", "pos", _driving.global_position + Vector3(3, 0.5, 0))
    if _interior != "":   # сохраняемся «у входа», а не в комнате
        cfg.set_value("player", "pos", _city.faction_sites[_interior]["out"])
    if _home_inside >= 0:
        cfg.set_value("player", "pos", _city.homes[_home_inside]["pos"] + Vector3(0, 0.3, 0))
    if _podezd >= 0:
        cfg.set_value("player", "pos", _city.entrances[_podezd]["out"] + Vector3(0, 0.3, 0))
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
    cfg.set_value("player", "quest_id", String(QUESTS[quest_i][0]) if quest_i < QUESTS.size() else "done")
    cfg.set_value("player", "quest_active", quest_active)
    cfg.set_value("player", "peter_met", peter_met)
    cfg.set_value("player", "welcome_seen", welcome_seen)
    cfg.set_value("player", "quests_skipped", quests_skipped)
    cfg.set_value("player", "rent_free_used", rent_free_used)
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
    has_pistol = bool(cfg.get_value("player", "has_pistol", false))
    weapon_id = String(cfg.get_value("player", "weapon", "fist"))
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
    if cfg.has_section_key("player", "quest_id"):
        var qid := String(cfg.get_value("player", "quest_id", ""))
        quest_i = QUESTS.size()
        for k in QUESTS.size():
            if String(QUESTS[k][0]) == qid:
                quest_i = k
        quest_active = bool(cfg.get_value("player", "quest_active", false))
        peter_met = bool(cfg.get_value("player", "peter_met", false))
    else:   # старое сохранение: задания шли в другом порядке
        var old := ["passport", "eat", "earn", "license", "car", "faction", "home", "biz"]
        var oid := String(old[quest_i]) if quest_i < old.size() else "done"
        quest_i = QUESTS.size()
        for k in QUESTS.size():
            if String(QUESTS[k][0]) == oid:
                quest_i = k
        peter_met = true
        quest_active = true
    welcome_seen = bool(cfg.get_value("player", "welcome_seen", peter_met))
    quests_skipped = bool(cfg.get_value("player", "quests_skipped", false))
    rent_free_used = bool(cfg.get_value("player", "rent_free_used", false))
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
        _sun.light_energy = 0.16   # лунный свет
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
    _env.tonemap_exposure = lerpf(0.75, 0.8, day_k)   # ночью чуть темнее, но всё видно
    _night_k = 1.0 - day_k
    if _city:
        if _city.lamp_mat:
            _city.lamp_mat.emission_energy_multiplier = lerpf(4.0, 0.4, day_k)
        _city.set_night(_night_k)
    CarModel.set_night(_night_k)
    for car in _cars:
        car.set_night(_night_k > 0.4)
    if _rent_scooter:
        _rent_scooter.set_night(_night_k > 0.4)


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
    _touch.lock_pressed.connect(_toggle_lock)
    _touch.lights_pressed.connect(_toggle_lights)
    _touch.chat_pressed.connect(func() -> void: _hud.toggle_chat_history())
    _touch.faction_pressed.connect(func() -> void:
        if faction == "":
            _hud.show_toast("Ты не во фракции. Вступить — в отделе кадров любого здания фракции или ОПГ")
        else:
            _open_faction_menu())
    _touch.weapon_pressed.connect(_on_weapon_switch)
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
    _speedo = SpeedoScript.new()
    _speedo.visible = false
    layer.add_child(_speedo)


# ================================================================ точки, документы, банк, АЗС, работы

func _add_point(pos: Vector3, r: float, text: String, cb: Callable, in_car := false, color := Color(1, 0.8, 0.1), on_map := true) -> void:
    _points.append({"pos": pos, "r": r, "text": text, "cb": cb, "car": in_car})
    if on_map:
        _hud.minimap.points.append([pos, color])


func _setup_points() -> void:
    _add_point(_city.kassa_point, 2.2, "КАССА", _open_kassa, false, Color(0.4, 0.8, 1.0))
    _add_point(_city.taxi_point, 2.4, "ТАКСИ", _open_station_taxi, false, Color(1.0, 0.8, 0.1))
    _add_point(_city.scooter_point, 2.2, "ПРОКАТ", _open_scooter_rent, false, Color(1.0, 0.5, 0.2))
    for sid: String in _city.rail_stops:
        var st: Dictionary = _city.rail_stops[sid]
        if sid == "kazan":
            _add_point(st["board"], 6.0, "В ПОЕЗД", _board_kazan_train, false, Color(0.3, 0.8, 0.4), false)
        else:
            _add_point(st["board"] + Vector3(-5.0, 0, 0), 3.0, "ЭЛЕКТРИЧКА", _open_rail_machine.bind(sid), false, Color(0.3, 0.8, 0.4))
    _add_point(_city.peter_pos + Vector3(0, 0, 1.2), 2.6, "ПЕТЕР", _talk_peter, false, Color(1.0, 0.82, 0.1))
    _add_point(_city.market, 4.0, "РЫНОК", _open_market, false, Color(1.0, 0.7, 0.1))
    _add_point(_city.autosalon, 4.0, "АВТОСАЛОН", _open_autosalon, false, Color(0.4, 0.6, 1.0))
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
    for hid: String in ["hospital", "hospital_p"]:
        if _city.interiors.has(hid):
            _add_point(_city.interiors[hid]["desk"], 2.0, "ЛЕЧЕНИЕ", _open_treatment, false, Color.WHITE, false)
    for i in _city.homes.size():
        var hm: Dictionary = _city.homes[i]
        _add_point(hm["pos"], 1.6, "ДОМ", _open_home.bind(i), false, Color.WHITE, false)
    for i in _city.entrances.size():
        var en: Dictionary = _city.entrances[i]
        _add_point(en["pos"], 1.2, "ПОДЪЕЗД", _enter_podezd.bind(i), false, Color(0.85, 0.85, 0.85), false)
    for bi in _city.benches.size():
        var bn: Array = _city.benches[bi]
        _add_point(bn[0] + bn[1] * 0.7, 0.9, "СЕСТЬ", _sit_bench.bind(bi), false, Color.WHITE, false)
    for sp: Vector3 in _city.soda_spots:
        _add_point(sp, 1.2, "ГАЗИРОВКА", _drink_soda, false, Color(1.0, 0.3, 0.25), false)
    if not _city.podezd.is_empty():
        _add_point(_city.podezd["exit"], 1.4, "ВЫЙТИ", _exit_podezd, false, Color.WHITE, false)
        _add_point(_city.podezd["flat"], 1.3, "КВАРТИРА", _podezd_flat, false, Color.WHITE, false)
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
    if _driving == null or _driving == _work_vehicle or _driving == _faction_car or _driving == _rent_scooter or absf(speed) < 30.0:
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
            v.model_id = "vaz2106"
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
    _seat_driver()
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
    _win.open_window("РЫНОК ПЯТИГОРСКА", "cart", MARKET_CATS.slice(1), false)


## Автосалон в Казани — только машины (рынок с одеждой и прочим — в Пятигорске).
func _open_autosalon() -> void:
    _touch.blocked = true
    _win_mode = "market"
    _preview_look = look.duplicate()
    _win.open_window("АВТОСАЛОН", "car", MARKET_CATS.slice(0, 1), false)


func _on_win_closed() -> void:
    if _win_mode == "market":
        _apply_look()   # снять примерку
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
        "pistol":
            if has_pistol:
                _hud.show_toast("Пистолет уже есть — кнопка оружия справа (на ПК клавиша Q)")
            elif _pay(Weapons.PISTOL_PRICE, "Рынок: пистолет ПМ"):
                has_pistol = true
                Sfx.play("coin")
                _hud.show_toast("Куплен ПМ. Смена оружия — кнопка справа (Q), огонь — красная кнопка (R)")
                _save_game()
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
    out.append({"cat": "market", "icon": "car", "col": gold, "name": "Автосалон (Казань)", "pos": c.autosalon})
    out.append({"cat": "market", "icon": "cart", "col": gold, "name": "Рынок (Пятигорск)", "pos": c.market})
    out.append({"cat": "fun", "icon": "house", "col": Color(0.55, 0.85, 0.45), "name": "Село Бусаево", "pos": c.village_center})
    out.append({"cat": "fun", "icon": "star", "col": Color(1.0, 0.75, 0.3), "name": "Город Пятигорск (через мост)", "pos": c.py_center})
    if c.village_park != Vector3.ZERO:
        out.append({"cat": "fun", "icon": "pin", "col": Color(0.55, 0.85, 0.45), "name": "Бусаево: парк имени Гагарина", "pos": c.village_park})
    out.append({"cat": "shops", "icon": "cart", "col": gold, "name": "Рынок (Пятигорск)", "pos": c.market})
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
        var ci: Array = cats.get(FactionData.base(fid), ["other", "dots"])
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
    # Города и сёла
    var city_col := Color(0.55, 0.8, 1.0)
    var green := Color(0.55, 0.85, 0.45)
    out.append({"cat": "cities", "icon": "star", "col": Color(1.0, 0.45, 0.4), "name": "Казань — центральная площадь", "pos": Vector3(0, 0, 0)})
    out.append({"cat": "cities", "icon": "pin", "col": Color(1.0, 0.82, 0.1), "name": "Вокзал «Казань» (Петер)", "pos": c.station_spawn})
    out.append({"cat": "cities", "icon": "star", "col": city_col, "name": "Пятигорск — площадь со стелой", "pos": c.py_center})
    if c.rail_stops.has("pyat"):
        out.append({"cat": "cities", "icon": "pin", "col": city_col, "name": "Вокзал «Пятигорск»", "pos": c.rail_stops["pyat"]["board"]})
    out.append({"cat": "cities", "icon": "pin", "col": city_col, "name": "Мост Дружбы (между городами)",
            "pos": c.bridge_center})
    out.append({"cat": "cities", "icon": "house", "col": green, "name": "Село Бусаево", "pos": c.village_center})
    out.append({"cat": "cities", "icon": "pin", "col": green, "name": "Мост в Бусаево", "pos": c.village_bridge})
    if c.village_park != Vector3.ZERO:
        out.append({"cat": "cities", "icon": "pin", "col": green, "name": "Бусаево — парк имени Гагарина", "pos": c.village_park})
    out.append({"cat": "cities", "icon": "house", "col": green, "name": "Дачный посёлок (коттеджи)", "pos": c.cottages_center})
    out.append({"cat": "cities", "icon": "axe", "col": green, "name": "Лес и лесопилка", "pos": c.log_pile})
    out.append({"cat": "fun", "icon": "star", "name": "Лес за городом", "pos": _city.log_pile + Vector3(0, 0, -6)})
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
                    rows.append({"icon": "shirt", "icon_col": Clothes.swatch(item), "name": "%s: %s" % [slot["name"], item[0]],
                            "value": value, "value_col": green if (worn or have) else gold})
                    _win_payload.append({"type": "cloth", "slot": id, "i": k, "price": price})
        _:
            rows.append({"icon": "fuel", "icon_col": Color(1.0, 0.35, 0.3), "name": "Канистра бензина 10 л",
                    "value": HudScript.format_money(CANISTER_PRICE), "value_col": gold})
            _win_payload.append({"type": "canister", "price": CANISTER_PRICE})
            rows.append({"icon": "star", "icon_col": Color(0.7, 0.7, 0.72), "name": "Пистолет Макарова (ПМ)",
                    "value": "Куплено" if has_pistol else HudScript.format_money(Weapons.PISTOL_PRICE),
                    "value_col": green if has_pistol else gold})
            _win_payload.append({"type": "pistol", "price": Weapons.PISTOL_PRICE})
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
    _apply_look()
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
    _hud.show_toast(text, "money")
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
    c.model_id = String(v.get("model", ""))
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
        _driving.shake = clampf(dmg / 30.0, 0.3, 1.0)
        if _driving.damage(dmg * 1.5):
            _hud.show_toast("Машина сломалась! Нужна СТО")
        _hurt(dmg, "Авария! −%d здоровья, машина %d%%" % [int(dmg), int(_driving.condition) if _driving else 0])
    _last_kmh = kmh if _driving else 0.0
    # сбила машина-бот: игрок отлетает и падает
    if not _driving and _player.visible and not _player.is_down():
        var pp: Vector3 = _player.global_position
        for a: Dictionary in _traffic._agents:
            var ap: Vector3 = a["pos"]
            var spd: float = a["speed"]
            if spd > 5.0 and absf(ap.x - pp.x) < 2.4 and absf(ap.z - pp.z) < 2.4:
                var fwd: Vector3 = a["fwd"]
                var rel := pp - ap
                rel.y = 0.0
                if rel.dot(fwd) > 0.3 and rel.length() < 2.3:
                    var side := Vector3(-fwd.z, 0, fwd.x) * signf(rel.dot(Vector3(-fwd.z, 0, fwd.x)) + 0.01)
                    _player.knockdown((fwd * 0.7 + side * 0.7).normalized() * spd * 0.8)
                    Sfx.play("hit")
                    Sfx.play_at("horn", ap, -2.0, 0.9)
                    _hurt(clampf(spd * 2.0, 8.0, 30.0), "Тебя сбила машина!")
                    a["speed"] = 0.0
                    break
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
    if amount >= 3.0 and not _driving:
        _player.play_hit()
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
    _podezd = -1
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
    var no_charge := FactionData.base(faction) == "hospital"
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
    _player.play_consume(false)
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
        Sfx.play("whistle", -9.0, randf_range(0.95, 1.05))
        _hud.show_toast("Розыск ★%d: %s" % [wanted, reason], "warn")


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
    if _arrest_cd > 0.0 or _interior != "" or _home_inside >= 0 or _podezd >= 0 or FactionData.base(faction) == "police" or faction == "kgb":
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
    _hud.show_toast(text + " (на карту)", "money")
    _add_xp(maxi(8, amount / 20))
    if _duty.calls_done % 2 == 0:
        faction_exp += 1
        var need := _need_exp()
        if need > 0 and faction_exp >= need:
            _hud.show_toast("Стаж набран — можно повыситься!")
    _save_game()


const CALL_WORDS := ["Вызов", "Оперативное", "ПОЖАР", "Проверка", "Есть дело", "Патруль", "Слежка", "Бабушка",
        "Субботник", "Ларёк", "Забили", "В мэрию", "В регистратуре"]


func _on_duty_message(text: String) -> void:
    var is_call := false
    for w: String in CALL_WORDS:
        if text.begins_with(w):
            is_call = true
    if is_call:
        Sfx.play("phone", -9.0)   # новый вызов — звонит телефон
    else:
        Sfx.play("notify", -4.0)
    _hud.show_toast(text)
    _sms_add(_faction_name(), text)


# ================================================================ СМС и телефон

func _sms_add(from: String, text: String) -> void:
    sms.append([from, text])
    _hud.chat("СМС от %s: %s" % [from, text], "sms")
    if sms.size() > 20:
        sms.pop_front()
    sms_unread += 1


func _on_app(id: String) -> void:
    match id:
        "emote":
            _hud.close_phone()
            _open_emotes()
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
    if jail_left > 0.0 or _interior != "" or _home_inside >= 0 or _podezd >= 0:
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
    Sfx.play("heal" if int(info[1]) > int(info[0]) else ("drink" if _is_drink(item) else "eat"))
    if not _driving and int(info[0]) > 0:
        _player.play_consume(_is_drink(item))
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

## Ключ района: "k:i,j" — квартал Казани, "p:i,j" — квартал Пятигорска.
func _turf_key(city: String, i: int, j: int) -> String:
    return "%s:%d,%d" % [city, i, j]


func _turf_rect(key: String) -> Rect2:
    var org := CityBuilder.PY_ORG if key.begins_with("p:") else Vector3.ZERO
    var ij := key.get_slice(":", 1)
    var i := int(ij.get_slice(",", 0))
    var j := int(ij.get_slice(",", 1))
    var half := CityBuilder.BLOCK * 0.5
    return Rect2(org.x + i * CityBuilder.PITCH - half, org.z + j * CityBuilder.PITCH - half, CityBuilder.BLOCK, CityBuilder.BLOCK)


## ОПГ города: в Казани — «Солнечные» и «Кавказ», в Пятигорске — «Тяп-Ляп» и «Универсам».
func _gang_ids(city := "") -> Array:
    var out := []
    for f: Dictionary in FactionData.LIST:
        if String(f.get("type", "")) == "gang" and (city == "" or String(f.get("city", "kazan")) == city):
            out.append(f["id"])
    return out


func _turf_city(key: String) -> String:
    return "pyat" if key.begins_with("p:") else "kazan"


## Раздел районов: дома банд и соседние кварталы. Квартал с площадью и госфракциями не делят.
## Каждый город делят только его ОПГ.
func _init_turf() -> void:
    if turf.is_empty():
        for cdef: Array in [["k", CityBuilder.GRID, CityBuilder.FACTION_BLOCKS, CityBuilder.GANG_BLOCKS],
                ["p", CityBuilder.PY_GRID, CityBuilder.PY_FACTION_BLOCKS, CityBuilder.PY_GANG_BLOCKS]]:
            var g: int = cdef[1]
            for i in range(-g, g + 1):
                for j in range(-g, g + 1):
                    var v := Vector2i(i, j)
                    if v == Vector2i.ZERO or (cdef[2] as Dictionary).has(v):
                        continue
                    turf[_turf_key(String(cdef[0]), i, j)] = String((cdef[3] as Dictionary).get(v, ""))
        for key: String in turf.keys():
            if turf[key] == "" and randf() < 0.5:
                var ids := _gang_ids(_turf_city(key))
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
        ids = _gang_ids(_turf_city(key))
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
    if car == null or not car.owned or car == _work_vehicle or car == _faction_car or car == _rent_scooter:
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
            _hud.show_toast("Погода: %s" % WEATHER_NAMES[weather], "weather")
            _hud.chat("Сводка погоды: " + String(WEATHER_TIPS.get(weather, "")), "weather")
            _update_daylight()
    var raining := weather == "rain"
    var snowing := weather == "snow"
    _wet = move_toward(_wet, 1.0 if raining else 0.0, delta / (20.0 if raining else 90.0))
    _snow = move_toward(_snow, 1.0 if snowing else 0.0, delta / (60.0 if snowing else 120.0))
    _city.set_weather(_wet, _snow)
    CarScript.grip = lerpf(1.0, 0.72, _wet) * lerpf(1.0, 0.6, _snow)
    var inside := _interior != "" or _home_inside >= 0 or _podezd >= 0
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
    if quest_i >= QUESTS.size() or not quest_active:
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
    _bank_log(reward, "Задание Петера")
    quest_i += 1
    quest_active = false
    Sfx.play("levelup")
    _add_xp(25)
    var text := "Задание выполнено! +%s на карту" % HudScript.format_money(reward)
    if quest_i >= QUESTS.size():
        text += ". Все задания новичка пройдены!"
        _sms_add("Петер", "Ну всё, земляк, дальше сам. Ты теперь настоящий казанец!")
    else:
        _peter_call_t = 4.0
    _hud.show_toast(text)
    _update_peter()
    _save_game()


# ---------------------------------------------------------------- окно «Добро пожаловать»

func _show_welcome() -> void:
    if _welcome != null:
        return
    _welcome = WelcomeScript.new()
    _hud.get_parent().add_child(_welcome)
    _touch.blocked = true
    _welcome.start_pressed.connect(_on_welcome.bind(true))
    _welcome.skip_pressed.connect(_on_welcome.bind(false))


func _on_welcome(start: bool) -> void:
    welcome_seen = true
    if _welcome:
        _welcome.queue_free()
        _welcome = null
    _touch.blocked = false
    if start:
        quests_skipped = false
        if _peter:
            _set_gps(_peter.global_position, "Петер", true)
        _talk_peter()   # Петер стоит у входа в вокзал и сразу подходит
    else:
        quests_skipped = true
        _open_dialog("Удачи!", "Удачи, товарищ! Город твой — разбирайся сам.\n\nЕсли передумаешь, квестовая линия ждёт у Петера на вокзале.",
                [["Спасибо", _dialog.close]])
    _save_game()


# ---------------------------------------------------------------- Петер: диалоги

## Подошёл к Петеру у вокзала.
func _talk_peter() -> void:
    quests_skipped = false   # подошёл к Петеру — квестовая линия снова идёт
    if not peter_met:
        _open_dialog("Петер", "Здорово, земляк! Ты, я вижу, только с поезда — чемодан ещё тёплый. Меня Петер зовут, я тут на вокзале всех новеньких встречаю.",
                [["Привет, Петер!", _peter_intro2]])
        return
    if quest_i >= QUESTS.size():
        _open_dialog("Петер", "А, это ты! Всё у тебя получилось, горжусь. Заглядывай, если что — я всегда тут, у вокзала.",
                [["Пока, Петер", _dialog.close]])
        return
    if quest_active:
        var q: Array = QUESTS[quest_i]
        var buttons := [["Понял, иду", _dialog.close]]
        if not bool(q[3]):
            buttons.append(["Не хочу это делать", _decline_quest])
        _open_dialog("Петер", "Ну что, как успехи? Напоминаю: %s.\n\n%s" % [String(q[1]).to_lower(), PETER_TALK.get(String(q[0]), "")], buttons)
        return
    _offer_quest("Петер")


func _peter_intro2() -> void:
    _open_dialog("Петер", "Это Казань — город большой, но по-своему уютный. Мы на острове: на запад, через Мост Дружбы, — Пятигорск, а на юг, по мосту, — село Бусаево. Работа есть, жильё есть, были бы руки и документы.\n\nДавай помогу освоиться: дам пару заданий, а за каждое — премия на карту.",
            [["Давай, рассказывай", _peter_intro_done]])


func _peter_intro_done() -> void:
    peter_met = true
    _offer_quest("Петер")


## Петер предлагает текущее задание. Первые три обязательные — отказаться нельзя.
func _offer_quest(title: String) -> void:
    if quest_i >= QUESTS.size():
        _dialog.close()
        return
    var q: Array = QUESTS[quest_i]
    var must := bool(q[3])
    var text := "%s\n\nЗадание: %s\nНаграда: %s" % [PETER_TALK.get(String(q[0]), ""), q[1], HudScript.format_money(int(q[2]))]
    if must:
        text += "\n\nЭто обязательное задание — без него в городе никуда."
    var buttons := [["Берусь!", _accept_quest]]
    if not must:
        buttons.append(["Нет, спасибо", _decline_quest])
        buttons.append(["Больше заданий не надо", _decline_all_quests])
    _open_dialog(title, text, buttons)


func _accept_quest() -> void:
    _dialog.close()
    peter_met = true
    quest_active = true
    var id := String(QUESTS[quest_i][0])
    match id:
        "passport":
            if _city.faction_sites.has("mayor"):
                _set_gps(_city.faction_sites["mayor"]["door"], "Мэрия", true)
        "license":
            _set_gps(_city.driving_school, "Автошкола", true)
    _hud.show_toast("Новое задание: %s" % QUESTS[quest_i][1])
    _update_peter()
    _save_game()


func _decline_quest() -> void:
    if quest_i < QUESTS.size() and bool(QUESTS[quest_i][3]):
        return
    quest_i += 1
    quest_active = false
    _update_peter()
    _save_game()
    if quest_i >= QUESTS.size():
        _open_dialog("Петер", "Как скажешь. Ты и так уже многое умеешь — дальше сам. Удачи, земляк!",
                [["Спасибо, Петер", _dialog.close]])
    else:
        _offer_quest("Петер")


func _decline_all_quests() -> void:
    quest_i = QUESTS.size()
    quest_active = false
    _update_peter()
    _save_game()
    _open_dialog("Петер", "Понял, понял — сам с усами. Если что, я тут, у вокзала. Удачи!", [["Пока!", _dialog.close]])


## «Звонок» от Петера после выполненного задания: сразу предлагает следующее.
func _peter_call() -> void:
    if quest_i >= QUESTS.size() or quest_active or quests_skipped:
        return
    Sfx.play("notify")
    _offer_quest("Звонит Петер")


func _update_peter() -> void:
    if _peter:
        _peter.set_has_quest(quest_i < QUESTS.size() and (not peter_met or not quest_active))


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



# ---------------------------------------------------------------- оружие

func _weapons_now() -> Array[String]:
    return Weapons.available(faction, faction_rank, has_pistol)


func _on_weapon_switch() -> void:
    if _driving != null or _player == null:
        return
    var list := _weapons_now()
    var i := list.find(weapon_id)
    weapon_id = list[(i + 1) % list.size()]
    _equip_weapon()
    _hud.show_toast("В руках: %s" % String(Weapons.info(weapon_id)["name"]))
    Sfx.play("click")


func _equip_weapon() -> void:
    var info := Weapons.info(weapon_id)
    var muzzle: Vector3 = info.get("muzzle", Vector3.ZERO)
    _player.set_weapon(Weapons.model_path(weapon_id), muzzle)
    _player.set_bat(weapon_id == "bat")


func _update_weapons(delta: float) -> void:
    _fire_cd -= delta
    if _tracer:
        _tracer_t -= delta
        _tracer.visible = _tracer_t > 0.0
    if _flash:
        _flash.visible = _tracer_t > 0.02
    if _driving != null or _interior != "" or _podezd >= 0 or _home_inside >= 0:
        _touch.weapon_text = ""
        return
    if not weapon_id in _weapons_now():    # уволили, понизили — оружие сдаём
        weapon_id = "fist"
        _equip_weapon()
    _touch.weapon_text = String(Weapons.info(weapon_id)["short"])
    var menus: bool = _hud.phone_open or _win.visible or _dialog.visible or _hud.profile.is_open() or _fmenu.visible
    var want: bool = _touch.attack_held or (Input.is_key_pressed(KEY_R) and not menus)
    if want and _fire_cd <= 0.0 and not menus:
        _attack()


func _attack() -> void:
    var info := Weapons.info(weapon_id)
    var melee := Weapons.is_melee(weapon_id)
    _fire_cd = float(info["rate"])
    _player.attack(melee)
    # люди вокруг пугаются: драка — рядом, выстрел — далеко; водители уезжают быстрее
    _peds.scare(_player.global_position, 14.0 if melee else 55.0)
    if not melee:
        _traffic.panic(_player.global_position, 70.0)
    var dir: Vector3 = _player.aim_direction()
    var origin: Vector3 = _player.global_position + Vector3(0, 1.3, 0)
    var hit_pos := _peds.hit(origin, dir, float(info["range"]), 35.0 if melee else 8.0)
    var lawful: bool = (FactionData.base(faction) == "police" or faction == "kgb") and _duty.active
    if melee:
        Sfx.play("swing", -10.0, randf_range(0.9, 1.15))
        if hit_pos != Vector3.INF:
            Sfx.play("hit", -2.0)
            if not lawful:
                _add_wanted(1, "драка")
        return
    Sfx.play("shot_heavy" if weapon_id in ["ak", "obrez"] else "shot", -2.0, randf_range(0.95, 1.05))
    var from: Vector3 = _player.muzzle_position()
    var to := hit_pos if hit_pos != Vector3.INF else from + dir * float(info["range"])
    _show_shot(from, to)
    if hit_pos != Vector3.INF:
        Sfx.play_at("hit", hit_pos)
        if not lawful:
            _add_wanted(2, "стрельба по людям")
    elif not lawful and wanted == 0:
        _add_wanted(1, "стрельба в городе")


## Вспышка у дула и короткий трассер до цели.
func _show_shot(from: Vector3, to: Vector3) -> void:
    if _flash == null:
        _flash = OmniLight3D.new()
        _flash.light_color = Color(1.0, 0.8, 0.45)
        _flash.light_energy = 3.0
        _flash.omni_range = 5.0
        add_child(_flash)
        _tracer = MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.02, 0.02, 1.0)
        _tracer.mesh = bm
        var tm := StandardMaterial3D.new()
        tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        tm.albedo_color = Color(1.0, 0.85, 0.5)
        _tracer.material_override = tm
        _tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_tracer)
    _flash.global_position = from
    var d := from.distance_to(to)
    if d > 0.1:
        _tracer.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
        _tracer.scale = Vector3(1, 1, d)
    _tracer_t = 0.07



# ---------------------------------------------------------------- чат: время суток, новости, зарплата

var _news_t := 90.0
var _was_night := false
var _last_hour := -1


var _in_city := ""


func _update_chat_events(delta: float) -> void:
    if _player != null:
        var fx := _focus().x
        var city_now := "pyat" if fx < CityBuilder.RIVER_X0 else ("kazan" if fx > CityBuilder.RIVER_X1 else _in_city)
        if _focus().z > CityBuilder.VILLAGE_BRIDGE.y:
            city_now = "village"
        elif city_now == "village" and _focus().z < CityBuilder.VILLAGE_BRIDGE.x:
            city_now = "kazan"
        if city_now != _in_city:
            if _in_city != "":
                _hud.chat("Добро пожаловать в %s!" % {"pyat": "Пятигорск", "kazan": "Казань", "village": "село Бусаево"}[city_now], "info")
            _in_city = city_now
    var hh := int(minutes) / 60
    _hud.chat_time_text = "[%02d:%02d]" % [hh, int(minutes) % 60]
    var night_now := _night_k > 0.5
    if night_now != _was_night:
        _was_night = night_now
        if night_now:
            _hud.chat("Наступает ночь — включились фонари. Будьте внимательны на дорогах.", "time")
        else:
            _hud.chat("Доброе утро! Город просыпается. День %d." % day, "time")
    if hh != _last_hour:
        if _last_hour >= 0 and faction != "":
            var left := PAYDAY_MINUTES - _payday_acc
            if left <= 60.0 and left > 0.0:
                _hud.chat("До получки во фракции меньше часа.", "faction")
        _last_hour = hh
    _news_t -= delta
    if _news_t <= 0.0:
        _news_t = randf_range(120.0, 220.0)
        _hud.chat(String(NEWS[randi() % NEWS.size()]), "news")



# ---------------------------------------------------------------- подъезд

func _enter_podezd(i: int) -> void:
    if _city.podezd.is_empty():
        return
    _podezd = i
    _player.global_position = _city.podezd["spawn"]
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(0.0)
    Sfx.play("door")


func _exit_podezd() -> void:
    var i := _podezd
    _podezd = -1
    if i < 0 or i >= _city.entrances.size():
        _player.global_position = _spawn_pos()
        return
    var en: Dictionary = _city.entrances[i]
    var out: Vector3 = en["out"]
    var door: Vector3 = en["pos"]
    var dir := out - door
    _player.global_position = out + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(atan2(-dir.x, -dir.z))
    Sfx.play("door")


## Дверь квартиры на площадке: своя — заходим, продаётся — подсказка, чужая — заперто.
func _podezd_flat() -> void:
    if _podezd < 0:
        return
    var door: Vector3 = _city.entrances[_podezd]["pos"]
    var idx := -1
    for i in _city.homes.size():
        var hp: Vector3 = _city.homes[i]["pos"]
        if String(_city.homes[i]["kind"]) == "flat" and hp.distance_to(door) < 3.0:
            idx = i
            break
    if idx >= 0 and idx == home:
        _podezd = -1
        _enter_home(idx)
    elif idx >= 0:
        Sfx.play("error")
        _hud.show_toast("Квартира продаётся — купить можно у подъезда (табличка «ДОМ») или через Навигатор")
    else:
        Sfx.play("error")
        _hud.show_toast("Заперто. Здесь живут соседи")



# ---------------------------------------------------------------- форма фракций (дресс-код)

var _last_uniform := "?"


## Форма надета: у ОПГ — всегда, у госслужб — на смене и в своём здании.
func _uniform_key() -> String:
    if faction == "" or _player == null:
        return ""
    var on := FactionData.is_gang(faction) or _duty.active or _interior == faction
    return "%s:%d" % [faction, faction_rank] if on else ""


func _apply_look() -> void:
    if _player == null:
        return
    _last_uniform = _uniform_key()
    # «Вор в законе» любой ОПГ — свой персонаж (мужчина в пальто и кепке), у остальных — обычный
    var gang_top := FactionData.is_gang(faction) and faction_rank >= FactionData.GANG_SKIN_RANK
    var skin := TYAP_SKIN if gang_top else ""
    if _player.set_skin(skin):
        _equip_weapon()
    if skin != "":
        return
    var u := {} if _last_uniform == "" else FactionData.uniform(faction, faction_rank)
    # головной убор формы: фуражка, шляпа, «петушок», каска, шапочка...
    _player.set_cap(String(u.get("cap", "")), u.get("cap_col", Color(0, 0, 0, 0)))
    if u.is_empty():
        _player.set_look(Clothes.colors(look), Clothes.textures(look))
        return
    var cols := Clothes.colors(look)
    var tex := Clothes.textures(look)
    for slot: String in ["jacket", "pants", "shoes"]:
        cols[slot] = Color(1, 1, 1)
        tex[slot] = String(u.get(slot, tex[slot]))
    var style: Array[String] = []
    if u.get("short", false):
        style.append("short")
    for flag: String in ["lampas", "tape", "vest"]:
        if u.get(flag, false):
            style.append(flag)
    if u.get("badge", false):
        style.append("badge:" + FactionData.base(faction))
    tex["jacket_style"] = ",".join(PackedStringArray(style))
    _player.set_look(cols, tex)



## Питьё или еда — по названию (для анимации: стакан или пирожок в руке).
func _is_drink(item: String) -> bool:
    var low := item.to_lower()
    for w: String in ["чай", "квас", "кефир", "лимонад", "айран", "молоко", "кофе", "газиров", "сок", "вода"]:
        if low.contains(w):
            return true
    return false


## Жесты: на корточки (как пацаны у подъезда), отдать честь, руки за спину.
func _open_emotes() -> void:
    var gang := FactionData.is_gang(faction)
    var buttons := [["Сесть на корточки", _do_emote.bind("squat")], ["Отдать честь", _do_emote.bind("salute")],
            ["Руки за спину", _do_emote.bind("rest")], ["Закрыть", _dialog.close]]
    if gang:
        buttons.push_front(["По-пацански: на корты", _do_emote.bind("squat")])
        buttons.remove_at(1)
    _open_dialog("Жесты", "Пошевели джойстиком — и жест закончится.", buttons)


func _do_emote(key: String) -> void:
    _dialog.close()
    if _driving or not _player.play_emote(key):
        Sfx.play("error")
        _hud.show_toast("Сейчас не получится")


## Автомат с газировкой: 3 ₽ — стакан газировки с сиропом.
func _drink_soda() -> void:
    if hunger >= 99.0:
        _hud.show_toast("Не хочется пить")
        return
    if not _pay(3, "Газировка"):
        return
    hunger = minf(100.0, hunger + 6.0)
    health = minf(100.0, health + 1.0)
    Sfx.play("drink")
    _player.play_consume(true)
    _hud.show_toast("Газировка с сиропом за 3 ₽. Освежает! +6 сытости", "money")


# ================================================================ вокзал: электричка, касса, такси

var _kazan_train = null        # train.gd у вокзала Казани
var _ticket := ""              # куда куплен билет ("pyat")
var _traveling := false
var _fade: ColorRect = null
var _fade_label: Label = null
var _announce_t := 40.0
const TICKET_PRICES := {"pyat": 50, "kazan": 50}
const STATION_ANNOUNCE := [
    "Уважаемые пассажиры! Курение на перроне строго запрещено.",
    "Внимание! Не оставляйте вещи без присмотра. О подозрительных предметах сообщайте в милицию.",
    "Уважаемые пассажиры! Билеты на электропоезд продаются в кассе вокзала.",
    "Граждане пассажиры! Переходите пути только по пешеходному настилу.",
]


func _spawn_station_life() -> void:
    var galya = NpcScript.new()
    galya.npc_name = "ТЁТЯ ГАЛЯ"
    galya.female = true
    galya.jacket = "cloth_chintz"
    galya.pants = "cloth_wool_gray"
    galya.shoes = "cloth_leather_brown"
    galya.hair_color = Color(0.55, 0.25, 0.12)
    galya.beard = false
    galya.anim = "sitting_idle"
    galya.collide = false
    galya.mark = false
    galya.name_y = 1.75
    galya.position = _city.galya_pos
    add_child(galya)
    var taxi = NpcScript.new()
    taxi.npc_name = "ТАКСИСТ"
    taxi.jacket = "cloth_leather_black"
    taxi.pants = "cloth_denim_blue"
    taxi.shoes = "cloth_leather_brown"
    taxi.hair_color = Color(0.12, 0.09, 0.07)
    taxi.beard = false
    taxi.alt_hair = true
    taxi.anim = "idle"
    taxi.mark = false
    taxi.position = _city.taxi_driver_pos
    taxi.rotation.y = -PI * 0.5
    add_child(taxi)
    _spawn_scooter_rent()
    _spawn_gang_crews()
    var tops := ["cloth_wool_gray", "cloth_quilted_navy", "cloth_cardigan", "cloth_check_blue", "cloth_bolonya_green",
            "cloth_sweater", "cloth_gabardine", "cloth_corduroy"]
    var bottoms := ["cloth_wool_black", "cloth_trousers_brown", "cloth_denim", "cloth_wool_gray"]
    var k := 0
    for p: Array in _city.passengers:
        var n = NpcScript.new()
        n.npc_name = ""
        n.mark = false
        n.female = k % 3 == 1
        n.jacket = tops[k % tops.size()]
        n.pants = bottoms[k % bottoms.size()]
        n.shoes = "cloth_leather_black" if k % 2 == 0 else "cloth_leather_brown"
        n.hair_color = [Color(0.15, 0.1, 0.07), Color(0.45, 0.3, 0.15), Color(0.6, 0.58, 0.55)][k % 3]
        n.beard = k % 4 == 2
        n.alt_hair = k % 5 == 3
        var sit := String(p[2]) == "sit"
        n.anim = "sitting_idle" if sit else ("idle_talking" if k % 3 == 2 else "idle")
        n.suitcase = not sit
        n.collide = not sit
        n.position = p[0]
        var f: Vector3 = p[1]
        n.rotation.y = atan2(f.x, f.z)
        add_child(n)
        k += 1
    # электричка у вокзала Казани
    if _city.rail_stops.has("kazan"):
        var st: Dictionary = _city.rail_stops["kazan"]
        var tr = TrainScript.new()
        tr.platform_x = float(st["platform_x"])
        tr.wagons = 4
        tr.title = "КАЗАНЬ — ПЯТИГОРСК"
        tr.position = Vector3(0, 0, float(st["track_z"]))
        add_child(tr)
        tr.arriving.connect(_on_train_arriving)
        tr.departing.connect(_on_train_departing)
        _kazan_train = tr


func _near_station(r: float) -> bool:
    return _player != null and _player.global_position.distance_to(_city.station_spawn) < r


func _announce(text: String, short := "") -> void:
    if not _near_station(260.0):
        return
    Sfx.play("station", -2.0)
    _hud.chat("Объявление: " + text, "news")
    if short != "" and _near_station(120.0):
        _hud.show_toast(short)


func _on_train_arriving() -> void:
    _announce("Внимание! Электропоезд «Казань — Пятигорск» прибывает на первый путь. Будьте осторожны!",
            "Электричка прибывает на 1-й путь")


func _on_train_departing() -> void:
    if _near_station(300.0):
        Sfx.play("train_horn", -3.0)
    _announce("Электропоезд отправляется. Просьба отойти от края платформы!", "Электричка отправляется")


## Время от времени — вокзальные объявления (зовётся из _process через _update_station).
func _update_station(delta: float) -> void:
    _announce_t -= delta
    if _announce_t <= 0.0:
        _announce_t = 75.0
        if _kazan_train and _kazan_train.state == "away":
            _announce(String(STATION_ANNOUNCE[randi() % STATION_ANNOUNCE.size()]))


# ---------------------------------------------------------------- касса: тётя Галя

func _open_kassa() -> void:
    var hello := "Здравствуй, милок! Куда едем? Электричка ходит часто, с первого пути — вон там, за вокзалом."
    if _ticket != "":
        hello = "У тебя уж есть билетик до %s, милок, не теряй! Электричка на первом пути." % _stop_name(_ticket)
    _open_dialog("Тётя Галя — касса", hello, [
            ["До Пятигорска — 50 ₽", _buy_ticket.bind("pyat")],
            ["Когда поезд?", _ask_train_time],
            ["Ничего, тётя Галя, спасибо", _dialog.close]])


func _buy_ticket(dest: String) -> void:
    if _ticket == dest:
        _open_kassa()
        return
    if not _pay(int(TICKET_PRICES[dest]), "Билет на электричку"):
        return
    _ticket = dest
    Sfx.play("coin")
    _open_dialog("Тётя Галя — касса", "Держи билетик до %s. Электричка на первом пути, за вокзалом — не опоздай, ждать не будет!" % _stop_name(dest),
            [["Спасибо!", _dialog.close]])


func _ask_train_time() -> void:
    var t := 0.0
    if _kazan_train:
        t = _kazan_train.time_to_arrival()
    var text := "Стоит уже на первом пути — беги, милок!" if t <= 0.0 else "Будет через %d секунд. Подожди на перроне, только к краю не подходи." % int(ceil(t))
    _open_dialog("Тётя Галя — касса", text, [["Понял", _open_kassa]])


func _stop_name(id: String) -> String:
    match id:
        "pyat":
            return "Пятигорска"
        "kazan":
            return "Казани"
    return id


# ---------------------------------------------------------------- поездка на электричке

func _board_kazan_train() -> void:
    if _ticket == "":
        Sfx.play("error")
        _hud.show_toast("Без билета нельзя — купи у тёти Гали в кассе вокзала")
        return
    if _kazan_train == null or not _kazan_train.is_standing():
        var t := 0.0 if _kazan_train == null else float(_kazan_train.time_to_arrival())
        _hud.show_toast("Поезда пока нет — прибудет через %d с" % int(ceil(t)))
        return
    var dest := _ticket
    _ticket = ""
    _ride_train("kazan", dest)


## Билетный автомат на маленькой станции: купить и сразу ехать.
func _open_rail_machine(sid: String) -> void:
    var buttons := []
    for dest: String in ["kazan", "pyat"]:
        if dest != sid:
            buttons.append(["До %s — %d ₽" % [_stop_name(dest), int(TICKET_PRICES[dest])], _machine_ride.bind(sid, dest)])
    buttons.append(["Отмена", _dialog.close])
    _open_dialog("Электричка — станция %s" % String(_city.rail_stops[sid]["name"]),
            "Билетный автомат. Электричка подходит сразу после покупки билета.", buttons)


func _machine_ride(from_id: String, dest: String) -> void:
    if not _pay(int(TICKET_PRICES[dest]), "Билет на электричку"):
        return
    _dialog.close()
    _ride_train(from_id, dest)


func _ride_train(from_id: String, dest: String) -> void:
    var st: Dictionary = _city.rail_stops[dest]
    var text := "Электричка «%s — %s»\n\nСледующая остановка — %s" % [String(_city.rail_stops[from_id]["name"]),
            String(st["name"]), String(st["name"])]
    Sfx.play("train_horn", -4.0)
    _travel(st["arrive"], text, 3.5, dest)


func _spawn_arrival_train(sid: String) -> void:
    var st: Dictionary = _city.rail_stops[sid]
    var tr = TrainScript.new()
    tr.one_shot = true
    tr.platform_x = float(st["platform_x"])
    tr.wagons = 3
    tr.title = "ЭЛЕКТРИЧКА"
    tr.position = Vector3(0, 0, float(st["track_z"]))
    add_child(tr)


# ---------------------------------------------------------------- пацаны у гаражей ОПГ

## У базы каждой ОПГ сидят «на кортах» и болтают пацаны в её форме (скорлупа, супера, молодые).
func _spawn_gang_crews() -> void:
    for f: Dictionary in FactionData.LIST:
        if String(f.get("type", "")) != "gang" or not _city.faction_sites.has(f["id"]):
            continue
        var site: Dictionary = _city.faction_sites[f["id"]]
        var out: Vector3 = site["out"]
        var yaw: float = float(site["out_yaw"])
        var fwd := -(Basis(Vector3.UP, yaw) * Vector3(0, 0, 1))   # от двери — на улицу
        var side := Vector3(fwd.z, 0, -fwd.x)
        for k in 3:
            var u: Dictionary = FactionData.uniform(f["id"], [1, 2, 3][k])
            var n = NpcScript.new()
            n.npc_name = String(f["title"]) if k == 1 else ""
            n.mark = false
            n.collide = true
            n.beard = false
            n.alt_hair = k == 2
            n.hair_color = [Color(0.12, 0.08, 0.06), Color(0.35, 0.25, 0.15), Color(0.2, 0.15, 0.1)][k]
            n.jacket = String(u.get("jacket", "cloth_tracksuit"))
            n.pants = String(u.get("pants", "cloth_tracksuit"))
            n.shoes = String(u.get("shoes", "cloth_sneaker"))
            n.hat = String(u.get("cap", ""))
            n.hat_col = u.get("cap_col", Color(0, 0, 0, 0))
            n.anim = "idle_talking" if k == 1 else "pose_squat"
            n.name_col = Color(f["color"]).lightened(0.3)
            n.position = out + fwd * 3.0 + side * (-2.2 + k * 2.2)
            var look := (side + fwd).normalized() if k == 0 else ((-side + fwd).normalized() if k == 2 else fwd)
            n.rotation.y = atan2(look.x, look.z)
            add_child(n)


# ---------------------------------------------------------------- прокат мопедов у вокзала (Геннадий)

const RENT_PRICE := 150
const RENT_TIME := 1200.0           # 20 минут
const SCOOTER_COLORS := [Color(0.42, 0.72, 0.66), Color(0.38, 0.58, 0.82), Color(0.62, 0.10, 0.14), Color(0.86, 0.62, 0.22)]
var _rent_scooter = null            # мопед, который сейчас у игрока
var _rent_slot := -1
var _rent_left := 0.0
var _rent_warned := false
var _rent_parked: Array = []        # стоящие мопеды у навеса (StaticBody3D)


func _spawn_scooter_rent() -> void:
    var gena = NpcScript.new()
    gena.npc_name = "ГЕННАДИЙ"
    gena.jacket = "cloth_quilted_navy"
    gena.pants = "cloth_trousers_brown"
    gena.shoes = "cloth_leather_black"
    gena.hair_color = Color(0.35, 0.3, 0.26)
    gena.beard = true
    gena.anim = "idle"
    gena.mark = false
    gena.position = _city.gena_pos
    add_child(gena)
    _rent_parked.clear()
    for i in _city.scooter_slots.size():
        var sl: Array = _city.scooter_slots[i]
        var body := StaticBody3D.new()
        body.position = sl[0]
        body.rotation.y = float(sl[1])
        add_child(body)
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(0.6, 1.0, 1.7)
        cs.shape = bs
        cs.position.y = 0.55
        body.add_child(cs)
        var mi := MeshInstance3D.new()
        mi.mesh = CarModel.scooter_parked_mesh(SCOOTER_COLORS[i % SCOOTER_COLORS.size()])
        body.add_child(mi)
        _rent_parked.append(body)


func _open_scooter_rent() -> void:
    if _rent_scooter != null:
        _open_dialog("Геннадий", "Ну как «Вятка», бегает? Осталось %d мин. Накатался — сдавай, я не в обиде." % ceili(_rent_left / 60.0),
                [["Сдать мопед", _rent_return], ["Ещё покатаюсь", _dialog.close]])
        return
    var free := not rent_free_used
    var text := "Здорово! Я Геннадий, прокат мопедов. «Вятка» — машина надёжная: ни прав, ни бензина не надо, катайся по городу.\n\n"
    text += "Тебе как новенькому — первый раз бесплатно, на 20 минут!" if free else "20 минут — %d ₽. Где бросишь — там и заберу." % RENT_PRICE
    _open_dialog("Геннадий", text, [["Взять мопед" + ("" if free else " — %d ₽" % RENT_PRICE), _rent_take], ["Не сейчас", _dialog.close]])


func _rent_take() -> void:
    var slot := -1
    for i in _rent_parked.size():
        if (_rent_parked[i] as Node3D).visible:
            slot = i
            break
    if slot < 0:
        _dialog.close()
        _hud.show_toast("Все мопеды разобрали")
        return
    if rent_free_used and not _pay(RENT_PRICE, "Прокат мопеда"):
        return
    rent_free_used = true
    _dialog.close()
    var parked: StaticBody3D = _rent_parked[slot]
    parked.visible = false
    parked.process_mode = Node.PROCESS_MODE_DISABLED
    var v = CarScript.new()
    v.kind = "moto"
    v.scooter = true
    v.car_name = "Вятка (прокат)"
    v.paint = SCOOTER_COLORS[slot % SCOOTER_COLORS.size()]
    v.max_engine_force = 1100.0
    v.max_speed_kmh = 75.0
    v.brake_force = 18.0
    v.max_steer = 0.6
    v.owned = true
    v.transform = parked.global_transform.translated(Vector3(0, 0.15, 0))
    add_child(v)
    v.uses_fuel = false
    v.touch = _touch
    v.set_night(_night_k > 0.4)
    _traffic.obstacles.append(v)
    _peds.cars.append(v)
    _rent_scooter = v
    _rent_slot = slot
    _rent_left = RENT_TIME
    _rent_warned = false
    Sfx.play("cash")
    _hud.show_toast("Мопед твой на 20 минут! Подойди и садись")
    _hud.chat("Геннадий: Права не нужны, бензин не нужен. Аккуратней на поворотах!", "news")


func _rent_return() -> void:
    _dialog.close()
    _rent_end()
    _hud.show_toast("Мопед сдан. Приходи ещё!")


func _update_rent(delta: float) -> void:
    if _rent_scooter == null:
        return
    _rent_left -= delta
    if _rent_left < 120.0 and not _rent_warned:
        _rent_warned = true
        _hud.chat("Прокат: до конца аренды мопеда 2 минуты", "warn")
    if _rent_left <= 0.0:
        if _driving == _rent_scooter:
            if _rent_left > -delta * 1.5:
                _hud.show_toast("Аренда закончилась — слезай, Геннадий заберёт мопед")
            return
        _rent_end()
        _hud.chat("Прокат: время вышло, Геннадий забрал мопед", "news")


func _rent_end() -> void:
    var v = _rent_scooter
    if v == null:
        return
    if _driving == v:
        var pos: Vector3 = v.get_exit_position()
        v.set_driven(false)
        _driving = null
        _player.set_seated("")
        _player.global_position = pos
        _player.set_active(true)
    _traffic.obstacles.erase(v)
    _peds.cars.erase(v)
    _rent_scooter = null
    v.queue_free()
    if _rent_slot >= 0 and _rent_slot < _rent_parked.size():
        var parked: StaticBody3D = _rent_parked[_rent_slot]
        parked.visible = true
        parked.process_mode = Node.PROCESS_MODE_INHERIT
    _rent_slot = -1


# ---------------------------------------------------------------- такси у вокзала

func _open_station_taxi() -> void:
    var dests := [["Центральная площадь", Vector3(0, 0.4, 14), 150], ["Мэрия", _city.faction_sites["mayor"]["door"] + Vector3(0, 0.4, 3) if _city.faction_sites.has("mayor") else Vector3(0, 0.4, 14), 150],
            ["Автосалон", _city.autosalon + Vector3(0, 0.4, -3), 150], ["Автошкола", _city.driving_school + Vector3(0, 0.4, 2), 80],
            ["Пятигорск", _city.py_center + Vector3(6, 0.4, 6), 500], ["Село Бусаево", _city.village_center + Vector3(4, 0.4, 0), 350]]
    var buttons := []
    for d: Array in dests:
        buttons.append(["%s — %d ₽" % [d[0], int(d[2])], _taxi_go.bind(d[1], int(d[2]), String(d[0]))])
    buttons.append(["Не надо", _dialog.close])
    _open_dialog("Таксист", "Куда едем, командир? Счётчик не включаю — по таксе, без обмана!", buttons)


func _taxi_go(dest: Vector3, price: int, place: String) -> void:
    if not _pay(price, "Такси"):
        return
    _dialog.close()
    _travel(dest, "Такси «Волга» · едем: %s\n\n«Музыку погромче сделать?»" % place, 3.0, "")


# ---------------------------------------------------------------- переезд с затемнением экрана

func _travel(dest: Vector3, text: String, secs: float, train_stop: String) -> void:
    if _traveling or _driving != null:
        return
    _traveling = true
    if _fade == null:
        var layer := CanvasLayer.new()
        layer.layer = 20
        add_child(layer)
        _fade = ColorRect.new()
        _fade.color = Color(0.02, 0.02, 0.03)
        _fade.mouse_filter = Control.MOUSE_FILTER_STOP
        layer.add_child(_fade)
        _fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _fade_label = Label.new()
        var ls := LabelSettings.new()
        ls.font_size = 34
        ls.font_color = Color(1, 0.95, 0.85)
        ls.outline_size = 6
        ls.outline_color = Color(0, 0, 0)
        _fade_label.label_settings = ls
        _fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _fade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _fade.add_child(_fade_label)
        _fade_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 60)
    _fade_label.text = text
    _fade.visible = true
    _fade.modulate.a = 0.0
    _touch.blocked = true
    var tw := create_tween()
    tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
    await tw.finished
    _player.global_position = dest
    _player.velocity = Vector3.ZERO
    await get_tree().create_timer(secs).timeout
    if train_stop != "":
        _spawn_arrival_train(train_stop)
    var tw2 := create_tween()
    tw2.tween_property(_fade, "modulate:a", 0.0, 0.8)
    await tw2.finished
    _fade.visible = false
    _touch.blocked = false
    _traveling = false
