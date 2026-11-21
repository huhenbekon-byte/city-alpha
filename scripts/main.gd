extends Node3D
## Точка входа: небо, смена дня и ночи, район, игрок, машины, интерфейс,
## деньги (наличные и карта), документы, работы, заправки, сохранение.

const PlayerScene := preload("res://scenes/player.tscn")
const PlayerScript := preload("res://scripts/player.gd")
const CarScene := preload("res://scenes/car.tscn")
const CityBuilder := preload("res://scripts/city_builder.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const HudScript := preload("res://scripts/hud.gd")
const Weapons := preload("res://scripts/weapons.gd")
const JobScript := preload("res://scripts/job.gd")
const MenuScript := preload("res://scripts/menu.gd")
const TrafficScript := preload("res://scripts/traffic.gd")
const PedestriansScript := preload("res://scripts/pedestrians.gd")
const UssrUi := preload("res://scripts/ussr_ui.gd")
const VibeScript := preload("res://scripts/vibe.gd")
const CarModel := preload("res://scripts/car_model.gd")
const Clothes := preload("res://scripts/clothes.gd")
const ListWindowScript := preload("res://scripts/list_window.gd")
const MarkerScript := preload("res://scripts/marker.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const SpeedoScript := preload("res://scripts/speedo.gd")
const WelcomeScript := preload("res://scripts/welcome.gd")
const TramScript := preload("res://scripts/tram.gd")
const BagScript := preload("res://scripts/bag.gd")
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
var _save_path := SAVE_PATH               # онлайн: user://acc_<ник>.cfg — копия облачного сохранения
const START_MONEY := 5000
const GAME_MINUTES_PER_SECOND := 1.0   # таймеры экономики (получка, бизнес, сытость) — в секундах; часы — московские
## Машины на Общем рынке: название, цена, цвет, макс. скорость, мощность.
## Свой персонаж для ОПГ «Тяп-Ляп» (те же анимации, перенесены на его скелет).
const TYAP_SKIN := "res://models/character/tyap.gltf"
const CAR_MODELS := [
    {"name": "Шестёрка", "price": 8000, "color": Color(0.92, 0.92, 0.90), "speed": 110.0, "force": 4300.0, "model": "vaz2106"},
    {"name": "Москвич-412", "price": 12000, "color": Color(0.15, 0.22, 0.45), "speed": 125.0, "force": 5000.0, "model": "moskvich"},
    {"name": "ВАЗ-2108 «Восьмёрка»", "price": 24000, "color": Color(0.45, 0.06, 0.10), "speed": 150.0, "force": 6200.0, "model": "vaz2108"},
    {"name": "ВАЗ-2101 «Копейка»", "price": 6000, "color": Color(0.85, 0.82, 0.70), "speed": 110.0, "force": 4300.0, "model": "vaz2101"},
    {"name": "Мотоцикл ИЖ «Планета»", "price": 12000, "color": Color(0.25, 0.35, 0.65), "speed": 140.0, "force": 1500.0, "kind": "moto", "model": "izh"},
    {"name": "УАЗ-469", "price": 32000, "color": Color(0.30, 0.36, 0.25), "speed": 120.0, "force": 7600.0, "model": "uaz469"},
    # новые — только в конец: сохранения хранят машины по номеру в списке
    {"name": "Нива", "price": 22000, "color": Color(0.82, 0.78, 0.62), "speed": 130.0, "force": 6200.0, "model": "niva"},
    {"name": "Волга ГАЗ-3102", "price": 38000, "color": Color(0.85, 0.85, 0.83), "speed": 160.0, "force": 7000.0, "model": "volga"},
    {"name": "УАЗ «Аварийка» 04", "price": 26000, "color": Color(0.95, 0.80, 0.25), "speed": 110.0, "force": 6000.0, "model": "uaz_gas"},
    {"name": "УАЗ-452 «Буханка»", "price": 21000, "color": Color(0.30, 0.36, 0.25), "speed": 110.0, "force": 6400.0, "model": "uaz452n"},
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
const PAYDAY_MINUTES := 180.0   # получка во фракции — раз в 3 минуты (в секундах)
const HUNGER_PER_MINUTE := 0.0111  # сытость тратится медленно: 100 -> 0 примерно за 2.5 часа игры
const STARVE_EVERY := 20.0         # голодный теряет 1 здоровья раз в 20 секунд
const MSK_OFFSET := 3 * 3600       # время в игре — московское, как в жизни
const DAY_EPOCH := 20687           # «День 1» — 22 августа 2026 (дни с 1970 года): 17 ноября 2026 — день 88
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
    "_РЫБА": [["Вобла", 80, 15, 0], ["Лещ", 200, 25, 0], ["Судак", 450, 35, 0], ["Сом", 1200, 50, 0]],   # улов (не продаётся в ларьках)
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
const NIGHT_TOP := Color(0.04, 0.06, 0.14)
const NIGHT_HORIZON := Color(0.13, 0.16, 0.27)
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
const NIGHT_AMBIENT := Color(0.33, 0.34, 0.42)   # ночью светлее: улицы и люди видны

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
var minutes := 9.0 * 60.0   # время суток в минутах — реальное московское (см. _real_clock)
var fixed_minutes := -1.0   # >= 0 — часы стоят на этом времени (проверки, скриншоты)
var look := Clothes.default_look()   # что надето: slot -> номер вещи
var owned_clothes := {}              # slot -> Array купленных номеров
var faction := ""            # id фракции ("mayor", "police"...), пусто — не во фракции
var faction_rank := 0        # 1..6
var has_pistol := false      # купленный на рынке ПМ
var weapon_id := "fist"      # что в руках
var _fire_cd := 0.0
var _attack_n := 0
var _horn_t := 0.0
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
var player_female := false   # пол персонажа: выбирается при регистрации (онлайн — хранится на сервере)
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
var rules_ok := false         # правила сервера приняты
var hints_seen := {}          # какие подсказки новичку уже показаны
var quests_skipped := false   # отказался от квестовой линии (можно начать у Петера)
var furniture: Array = []     # купленная мебель (id), стоит дома — и в квартире, и в частном доме
var _tram: TramScript = null
var _bag: BagScript = null
var _tram_ride = null         # вагон, в котором едем (словарь из tram.gd)
var _tram_seat := Transform3D()
var _tram_wait := -1          # ждём трамвай на остановке №
var _rob := {}                # идущее ограбление: {"key", "tier", "left", "pos", "name"}
var _loot := 0                # добыча в сумке — нести в общак
var _rob_cd := {}             # цель -> игровая минута, когда снова можно
var skills := {"strength": 0.0, "driving": 0.0, "shooting": 0.0}   # навыки 0..100
var stats := {"rob": 0, "steal": 0, "turf": 0, "tram": 0, "drive_m": 0.0, "workouts": 0}
var achievements: Array = []  # открытые достижения (id)
var _steal_car = null         # машина под заказ (угон)
var _steal_order := {}        # {"model", "name", "pay"}
var _steal_cd := 0.0
var _ach_t := 0.0
var _train_t := 0.0           # идёт подход на турнике
var _train_pos := Vector3.ZERO
var _taxi_cond := 100.0
var has_rod := false
var _fish_t := 0.0
var _fish_pos := Vector3.ZERO
var _court_work_cd := 0.0
var _player
var _cars: Array = []
var _driving = null
var _menu: MenuScript
var _started := false
var _shadows_on := true
var _film_fx: ColorRect = null
const GearScript := preload("res://scripts/gear.gd")
# порт и патроны ОПГ
var ammo := 60                     # патроны к оружию ОПГ (наган, обрез, АК)
var port_owner := "tyap"           # какая ОПГ держит склад в порту
var port_ammo := 200
var port_cap := {}                 # идёт захват: {gid, left}
var gang_stock := 0                # патроны в общаке своей ОПГ
var _port_box := false             # несу ящик патронов
var _port_t := 0.0
var _port_toast_t := 0.0
# банк и лотерея (онлайн — данные с сервера)
var loan_due := 0
var loan_until := 0                # unix-время, до которого вернуть
var dep_sum := 0
var dep_t := 0                     # unix-время открытия вклада
var dep_gain := 0
var lotto := {}                    # состояние лотереи с сервера
var lotto_mine: Array = []         # офлайн: свои билеты
var _evac_t := 0.0
var _bank_tick_t := 5.0
const GAI_REG_PRICE := 3000
const GAI_TO_PRICE := 1500
const GAI_TO_DAYS := 30
const IMPOUND_PRICE := 2000
const LOTTO_PRICE := 200
const LOAN_MAX := 50000        # зерно и виньетка «плёнка 80-х»
var _fps_low_t := 0.0              # сколько секунд подряд FPS слишком низкий
var _auto_scale := 1.0             # авто-снижение разрешения 3D при лагах
var _win: ListWindowScript     # большое окно: Навигатор или Общий рынок
var _win_mode := ""            # "gps" / "market"
var _win_payload: Array = []   # что стоит за каждой строкой списка
var _preview_look := {}
var _gps_target = null         # Vector3 — куда ведёт навигатор
var _gps_name := ""
var _gps_marker: MarkerScript
var _traffic: TrafficScript
var _peds: PedestriansScript
var _vibe: VibeScript
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
    get_tree().root.theme = UssrUi.theme()   # общий стиль интерфейса: красное, золото, крем
    set_process(false)
    if Net.is_server:
        return   # выделенный сервер: город не строим, Net всё делает сам
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
    var host := _start.chosen_host
    var net_failed := false
    if host != "":
        await _start.progress(20.0, "Подключение к %s... (если сервер спал — до минуты)" % host, 0.3)
        _start.show_offline_button(true)
        var ok: bool = await Net.join(host)
        _start.show_offline_button(false)
        net_failed = not ok and not Net.cancel_join
        if ok:
            await _start.progress(30.0, "Вход в аккаунт", 0.2)
            var acc: Array = await _start.ask_login()
            if bool(acc[0]):
                _use_account(String(acc[1]), String(acc[2]))
            else:
                Net.leave()
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
    if Net.online:
        _net_start()
    elif net_failed:
        _hud.chat("Сервер %s не отвечает — играешь офлайн." % host, "warn")


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
    _hud.chat("Добро пожаловать в СССР РП! Коснись чата, чтобы открыть историю сообщений.", "info")
    if faction != "":
        _hud.chat("Ты во фракции «%s», ранг: %s." % [_faction_name(), FactionData.rank_name(faction_rank, faction)], "faction")


## Московское время: минуты от полуночи и номер дня (с 20 августа 2025).
func _real_clock() -> void:
    if fixed_minutes >= 0.0:
        minutes = fixed_minutes
        return
    var t := Time.get_unix_time_from_system() + MSK_OFFSET
    minutes = fmod(t / 60.0, 1440.0)
    day = int(floor(t / 86400.0)) - DAY_EPOCH + 1


func _process(delta: float) -> void:
    # Часы: сутки в игре идут как в жизни — по московскому времени, у всех игроков одинаково
    _real_clock()
    _light_timer -= delta
    if _light_timer <= 0.0:
        _light_timer = 0.25
        _update_daylight()

    _follow_seat()
    _fps_guard(delta)
    _update_port(delta)
    _update_evac(delta)
    _bank_tick_t -= delta
    if _bank_tick_t <= 0.0:
        _bank_tick_t = 20.0
        _check_loan_local()
        _lotto_local_tick()
    _event_tick(delta)
    _update_faction_rooms(delta)
    _update_rp(delta)
    var fire_search: bool = _duty.fire_active() and not _duty._fire_found
    _hud.radar.visible = fire_search and not _hud.phone_open
    if fire_search:
        _hud.radar.from = _focus()
        _hud.radar.to = _duty.fire_pos
    _hint_t -= delta
    if _hint_t <= 0.0:
        _hint_t = 2.0
        _check_hints()
        _hud.set_app_visible("radio", faction != "" and not FactionData.is_gang(faction))
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
    _player.set_carry(_work.carrying if _work.carrying != "" else ("box" if _port_box else ""))
    _check_dps(delta, speed)
    _traffic.focus = focus
    _peds.focus = focus
    if _tram:
        _tram.focus = focus
        _update_tram()
    _update_rob(delta, focus)
    _update_part1(delta, focus)
    _update_part2(delta)
    _update_part3(delta)
    _update_online(delta)
    _lamp_timer -= delta
    if _lamp_timer <= 0.0:
        _lamp_timer = 0.5
        _update_lamp_lights(focus)

    Sfx.night = _night_k
    Sfx.indoor = _interior != "" or _home_inside >= 0 or _podezd >= 0
    if _vibe:
        _vibe.update(focus, _night_k, Sfx.indoor, weather, delta)

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
    elif _ride_id >= 0:
        _touch.interact_text = "ВЫЙТИ"
    elif near:
        _touch.interact_text = "СЕСТЬ"
    elif Net.online and _driving == null and _remote_car_near() >= 0:
        _touch.interact_text = "ПАССАЖИР"
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
    if not _rob.is_empty():
        job_text = "ГРАБЁЖ: %s — ещё %d с, не уходи!" % [_rob["name"], int(ceil(float(_rob["left"])))]
    elif _loot > 0:
        job_text = "Добыча %s — отнеси в общак на базу (не попадись милиции!)" % HudScript.format_money(_loot)
    if _tram_ride != null:
        job_text = "Едешь в трамвае №1. Выйти — джойстиком на остановке"
    if not _steal_order.is_empty() and _rob.is_empty() and _loot == 0:
        job_text = ("Угон: %s — гони в гараж ОПГ" if bool(_steal_order.get("taken", false)) else "Заказ: угнать %s (метка на карте)") % _steal_order["name"]
    if _train_t > 0.0:
        job_text = "Подход на турнике: %d с" % int(ceil(_train_t))
    var p3_text := _part3_job_text()
    if p3_text != "":
        job_text = p3_text
    if jail_left > 0.0:
        job_text = "Срок: осталось %d с — «РАБОТАТЬ» у стены сокращает срок" % int(ceil(jail_left))
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

    var text := "СССР РП · %s   FPS %d" % [VERSION, Engine.get_frames_per_second()]
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
        _arrival_intro.call_deferred()   # первый вход: пролёт камеры над вокзалом, потом «Добро пожаловать»
    elif not _started and not peter_met and not quests_skipped:
        _hud.show_toast("Тебя встречает Петер — подойди к нему у входа в вокзал")
    _started = true
    _menu.visible = false
    _touch.visible = true
    get_tree().paused = false
    Music.stop()
    Crash.mark("игра: старт")
    _maybe_rules.call_deferred()
    if Crash.report != "":
        _show_crash_report.call_deferred()


## Прошлый запуск оборвался: показываем хвост журнала и отправляем его на сервер (Render → Logs).
func _show_crash_report() -> void:
    var rep: String = Crash.report
    Crash.report = ""
    if Net.authed:
        Net.send_msg({"t": "crash", "dev": OS.get_model_name(), "log": rep.right(6000)})
    var lines := rep.split("\n")
    var short := "\n".join(lines.slice(maxi(0, lines.size() - 12)))
    _open_dialog("Игра закрылась в прошлый раз", ("Журнал отправлен разработчику. " if Net.authed else "") +
            "Сделай скриншот и пришли его — так найдём причину:\n\n" + short, [["Понятно", _dialog.close]])


func _on_quit() -> void:
    _save_game()
    Crash.mark("[выход]")
    Crash._set_flag(false)
    get_tree().quit()


func _on_reset() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
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
    furniture = []
    _loot = 0
    skills = {"strength": 0.0, "driving": 0.0, "shooting": 0.0}
    stats = {"rob": 0, "steal": 0, "turf": 0, "tram": 0, "drive_m": 0.0, "workouts": 0}
    achievements = []
    has_rod = false
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
    var lite := bool(st.get("lite", false))
    get_viewport().scaling_3d_scale = (0.5 if lite else [0.6, 0.75, 1.0][q]) * _auto_scale
    GearScript.enabled = not lite and q > 0   # объёмные детали формы — не на слабых телефонах
    _set_film(bool(st.get("film", true)) and not lite and q > 0)
    Engine.max_fps = 30 if lite else 60   # слабому устройству ровные 30 кадров легче, меньше греется
    _sun.directional_shadow_max_distance = [30.0, 45.0, 70.0][q]
    _shadows_on = bool(st["shadows"]) and not lite
    _env.fog_density = [0.007, 0.0035, 0.0015][v]
    var far: float = 130.0 if lite else [170.0, 300.0, 550.0][v]
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
        if not car.owned or car.impounded:
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
var _earn_pending := {}


## Заработок с указанием источника: сервер проверяет темп каждого вида дохода отдельно.
func _earned(src: String, amount: int) -> void:
    if amount > 0 and Net.authed:
        _earn_pending[src] = int(_earn_pending.get(src, 0)) + amount


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
        # награда за уровень: премия на карту, чтобы рост чувствовался
        var prize := 250 * level
        bank += prize
        _earned("reward", prize)
        _bank_log(prize, "Премия за %d уровень" % level)
        _hud.show_toast("Новый уровень: %d! Премия %s на карту" % [level, HudScript.format_money(prize)], "money")


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
        "post":
            return "Почтальон"
        "sweep":
            return "Дворник"
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
    # такси: аккуратно довёз (машина не побилась) — чаевые
    if _job.active and _job.kind == "taxi" and _driving != null:
        var cond: float = _driving.condition
        if cond >= _taxi_cond - 0.5:
            var tip := int(amount * 0.3 / 10.0) * 10
            amount += tip
            text += " · чаевые +%d ₽" % tip
        _taxi_cond = cond
    if _holiday != "":   # в праздник — праздничные: +50 %
        var bonus := int(amount * 0.5 / 10.0) * 10
        amount += bonus
        text += " · праздничные +%d ₽" % bonus
    earned_total += amount
    bank += amount   # зарплата приходит на карту
    _earned("job", amount)
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
        _horn_t = 0.5     # другие игроки тоже услышат гудок (флаг в состоянии)


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
    if _player.frozen and _driving == null and _ride_id < 0:
        _hud.show_toast("Ты ранен" if _injured else ("Ты в наручниках" if _cuffed_by >= 0 else "Ты заморожен администратором"))
        return
    if _ride_id >= 0:
        _leave_ride()
        return
    if _driving == null and Net.online:
        var rid := _remote_car_near()
        var own = _nearest_car()
        if rid >= 0 and (own == null or (own as Node3D).global_position.distance_to(_player.global_position) >
                (_remote[rid]["car"] as Node3D).global_position.distance_to(_player.global_position)):
            _board_ride(rid)
            return
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
        if car.impounded:
            Sfx.play("error")
            _hud.show_toast("Машина на штрафстоянке ГАИ — сначала оплати %s в будке" % HudScript.format_money(IMPOUND_PRICE))
            return
        if car == _steal_car and not bool(_steal_order.get("taken", false)):
            _steal_order["taken"] = true
            Sfx.play_at("siren", car.global_position, -10.0, 1.6)
            _hud.show_toast("Вскрыл! Гони в гараж своей ОПГ (метка на автопарк)")
            if randf() < 0.5:
                _add_wanted(1, "угон автомобиля")
            if _city.faction_sites.has(faction):
                _set_gps(_city.faction_sites[faction]["marker"], "Гараж: сдать машину", true)
        if car.locked:   # своя машина: ключом открываем замок
            car.locked = false
            Sfx.play("lock", -6.0)
        if car.kind != "moto":
            Sfx.play("car_door", -6.0, randf_range(0.95, 1.05))
        Sfx.play("scooter_start" if car.kind == "moto" or car.scooter else "engine_start", -9.0, randf_range(0.95, 1.05))
        # навык вождения: до +20% тяги у опытного водителя
        if not car.has_meta("base_force"):
            car.set_meta("base_force", car.max_engine_force)
        car.max_engine_force = float(car.get_meta("base_force")) * (1.0 + float(skills["driving"]) * 0.002)
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


var _bench_sitters: Array[Vector3] = []   # где на лавках уже сидят люди (НПС)


func _sit_bench(i: int) -> void:
    var bn: Array = _city.benches[i]
    var center: Vector3 = bn[0]
    var f: Vector3 = bn[1]
    # место занято — садимся рядом (слева или справа), а не на колени
    var side := Vector3(-f.z, 0, f.x).normalized()
    var best := center
    var best_d := _sitter_gap(center)
    if best_d < 0.55:
        for cand: Vector3 in [center + side * 0.68, center - side * 0.68]:
            var d := _sitter_gap(cand)
            if d > best_d:
                best_d = d
                best = cand
        if best_d < 0.5:
            _hud.show_toast("Лавочка занята")
            return
    if _player.seated == "" and _player.sit_at(best, f):
        _hud.show_toast("Сидишь на лавочке. Пошевели джойстиком, чтобы встать")


func _sitter_gap(p: Vector3) -> float:
    var d := 99.0
    for s: Vector3 in _bench_sitters:
        d = minf(d, Vector2(s.x - p.x, s.z - p.z).length())
    for id: int in _remote:   # другие игроки, сидящие на этой лавке
        var r: Dictionary = _remote[id]
        if String(r.get("anim", "")).to_lower().contains("sit") and r["npc"] != null:
            var q: Vector3 = (r["npc"] as Node3D).global_position
            d = minf(d, Vector2(q.x - p.x, q.z - p.z).length())
    return d


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
    if _steal_car != null:
        all.append(_steal_car)
    for car in all:
        if (not car.owned and car != _steal_car) or not car.visible:
            continue
        var d: float = car.global_position.distance_to(_player.global_position)
        if d < best_d:
            best_d = d
            best = car
    return best


func _on_look(relative: Vector2) -> void:
    if _driving:
        _driving.look(relative)
    elif _ride_id >= 0 and _remote.has(_ride_id) and _remote[_ride_id]["car"] != null and is_instance_valid(_remote[_ride_id]["car"]):
        _remote[_ride_id]["car"].look(relative)
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
    var lite := bool(_menu.settings.get("lite", false))
    if lite:   # слабое устройство: вдвое меньше машин и прохожих
        _traffic.count = 11
    add_child(_traffic)
    _traffic.obstacles = [_player] + _cars
    _traffic.honk.connect(func(pos: Vector3) -> void: Sfx.play_at("horn", pos, -2.0, 0.9))
    _traffic.setup()
    _tram = TramScript.new()
    _tram.traffic = _traffic
    _tram.obstacles = _traffic.obstacles
    add_child(_tram)

    _peds = PedestriansScript.new()
    if lite:
        _peds.count = 20
    add_child(_peds)
    _peds.player = _player
    _peds.cars = _cars.duplicate()  # копия: туда добавляются и рабочие машины
    _peds.setup()
    _peds.knocked.connect(func(_p: Vector3) -> void: _add_wanted(1, "сбил пешехода"))
    _vibe = VibeScript.new()   # листья осенью, радио из ларьков и дворов, далёкие звуки, мигающие фонари
    _vibe.city = _city
    _vibe.lite = lite
    add_child(_vibe)
    _vibe.setup()

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
            l.light_energy = 2.2 * _night_k * (_vibe.flicker(i, lamps[i]) if _vibe else 1.0)


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
            if t.size() >= 8:
                car.freshener = bool(t[5])
                car.loud = bool(t[6])
                car.lowered = bool(t[7])
            if t.size() >= 11:
                car.registered = bool(t[8])
                car.inspect_day = int(t[9])
                car.impounded = bool(t[10])
            elif car.owned:   # машины, купленные до ГАИ, считаются на учёте с техосмотром
                car.registered = true
                car.inspect_day = 100000   # техосмотр без срока — купили до появления ГАИ
                if car.plate_text == "":
                    car.plate_text = _gai_plate()
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
    _player.touch = _touch            # джойстик на телефоне управляет игроком
    _apply_look()
    _player.stepped.connect(_on_step)  # звук шагов
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
    cfg.set_value("player", "ammo", ammo)
    cfg.set_value("player", "bankx", [loan_due, loan_until, dep_sum, dep_t])
    cfg.set_value("world", "port", [port_owner, port_ammo, gang_stock])
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
    cfg.set_value("player", "female", player_female)
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
        tun.append([car.paint.to_html(), car.tint, car.rim_color.to_html() if car.rim_color.a > 0.0 else "", car.plate_text, car.condition,
                car.freshener, car.loud, car.lowered, car.registered, car.inspect_day, car.impounded])
    cfg.set_value("world", "tuning", tun)
    cfg.set_value("player", "licenses", licenses)
    cfg.set_value("player", "quest", quest_i)
    cfg.set_value("player", "quest_id", String(QUESTS[quest_i][0]) if quest_i < QUESTS.size() else "done")
    cfg.set_value("player", "quest_active", quest_active)
    cfg.set_value("player", "peter_met", peter_met)
    cfg.set_value("player", "welcome_seen", welcome_seen)
    cfg.set_value("player", "rules_ok", rules_ok)
    cfg.set_value("player", "hints", hints_seen)
    cfg.set_value("player", "gang_goods", gang_goods)
    cfg.set_value("player", "med_card", med_card)
    cfg.set_value("player", "gun_license", gun_license)
    cfg.set_value("player", "furniture", furniture)
    cfg.set_value("player", "skills", skills)
    cfg.set_value("player", "has_rod", has_rod)
    cfg.set_value("player", "stats", stats)
    cfg.set_value("player", "achievements", achievements)
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
    cfg.save(_save_path)
    if Net.authed:
        Net.cloud_save(cfg.encode_to_text())


func _load_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(_save_path) != OK:
        return
    cash = int(cfg.get_value("player", "money", START_MONEY))
    bank = int(cfg.get_value("player", "bank", 0))
    passport_name = String(cfg.get_value("player", "passport", ""))
    has_license = bool(cfg.get_value("player", "license", false))
    has_pistol = bool(cfg.get_value("player", "has_pistol", false))
    ammo = int(cfg.get_value("player", "ammo", 60))
    var bx: Array = cfg.get_value("player", "bankx", [0, 0, 0, 0])
    if bx.size() >= 4:
        loan_due = int(bx[0]); loan_until = int(bx[1]); dep_sum = int(bx[2]); dep_t = int(bx[3])
    var pt: Array = cfg.get_value("world", "port", ["tyap", 200, 0])
    if pt.size() >= 3:
        port_owner = String(pt[0]); port_ammo = int(pt[1]); gang_stock = int(pt[2])
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
    _loaded["female"] = cfg.get_value("player", "female", false) == true
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
    rules_ok = bool(cfg.get_value("player", "rules_ok", false))
    var hs: Variant = cfg.get_value("player", "hints", {})
    hints_seen = hs if hs is Dictionary else {}
    gang_goods = int(cfg.get_value("player", "gang_goods", 0))
    med_card = bool(cfg.get_value("player", "med_card", false))
    gun_license = bool(cfg.get_value("player", "gun_license", false))
    furniture = Array(cfg.get_value("player", "furniture", []))
    var sk = cfg.get_value("player", "skills", {})
    if sk is Dictionary:
        for k in sk:
            skills[k] = float(sk[k])
    var st = cfg.get_value("player", "stats", {})
    if st is Dictionary:
        for k in st:
            stats[k] = st[k]
    achievements = Array(cfg.get_value("player", "achievements", []))
    has_rod = bool(cfg.get_value("player", "has_rod", false))
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
    # тёплая «советская плёнка»: тени чуть приподняты и тёплые, светлое — кремовое
    var grad := Gradient.new()
    grad.set_offset(0, 0.0)
    grad.set_color(0, Color(0.035, 0.03, 0.04))
    grad.set_offset(1, 1.0)
    grad.set_color(1, Color(1.0, 0.97, 0.9))
    grad.add_point(0.5, Color(0.52, 0.49, 0.45))
    var gt := GradientTexture1D.new()
    gt.gradient = grad
    gt.width = 256
    _env.adjustment_color_correction = gt

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
        _sun.light_color = Color(0.68, 0.74, 0.92)
        _sun.light_energy = 0.42   # лунный свет
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
        _sky_sh.set_shader_parameter("drift", fmod(Time.get_unix_time_from_system() / 2880.0, 1000.0))  # облака медленно плывут
    _env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, day_k) * (0.85 if weather == "rain" else 1.0)
    _env.tonemap_exposure = lerpf(0.92, 0.8, day_k)   # ночью экспозиция выше — темно, но всё видно
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
    _touch.chat_pressed.connect(_on_chat_button)
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

    _bag = BagScript.new()
    layer.add_child(_bag)
    _bag.closed.connect(func() -> void: _touch.blocked = false)
    _bag.use_requested.connect(func(item: String) -> void:
        _use_item(item)
        _refresh_bag())
    _bag.drop_requested.connect(func(item: String) -> void:
        _take_item(item)
        Sfx.play("click")
        _hud.show_toast("Выброшено: %s" % item)
        _refresh_bag())

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
        if hi.has("shop"):
            _add_point(hi["shop"], 1.3, "МЕБЕЛЬ", _open_furniture, false, Color.WHITE, false)
            _add_point(hi["radiola"], 1.3, "РАДИОЛА", _use_radiola, false, Color.WHITE, false)
    if _tram:
        for ti in _tram.stops.size():
            _add_point(_tram.stops[ti]["sign"], 3.0, "ТРАМВАЙ", _tram_board.bind(ti), false, Color(0.95, 0.35, 0.3))
    _setup_rob_points()
    _setup_interior_points()
    _setup_part2_points()
    _setup_part3_points()
    for wp: Vector3 in _city.workout_spots:
        _add_point(wp, 1.3, "КАЧАТЬСЯ", _workout, false, Color.WHITE, false)
    for gid: String in _city.faction_sites:
        if FactionData.is_gang(gid):
            _points.append({"pos": _city.faction_sites[gid]["marker"] + Vector3(3.0, 0, 0), "r": 2.0, "text": "ЗАКАЗ НА УГОН",
                    "cb": _steal_menu.bind(gid), "car": false, "gang_only": true})
    _set_home(int(_loaded.get("home", -1)))
    _set_female(_loaded.get("female", false) == true)
    _apply_furniture()
    for p: Vector3 in _city.service_stations:
        _add_point(p, 7.0, "СТО", _open_sto, true, Color(0.3, 0.5, 1.0))
    for p: Vector3 in _city.fuel_pumps:
        _add_point(p, 5.5, "ЗАПРАВИТЬ", _open_fuel, true, Color(0.9, 0.2, 0.2))
    _add_point(_city.bus_depot, 3.0, "АВТОБУС", _start_work.bind("bus"))
    _add_point(_city.warehouse_drop + Vector3(4, 0, 0), 2.5, "ГРУЗЧИК", _start_work.bind("loader"))
    _add_point(_city.truck_depot, 3.0, "ДАЛЬНОБОЙ", _start_work.bind("truck"))
    _add_point(_city.log_pile + Vector3(4, 0, 0), 3.0, "ЛЕСОРУБ", _start_work.bind("lumber"))
    _add_point(_city.post_office + Vector3(0, 0, 3.0), 2.5, "ПОЧТАЛЬОН", _start_work.bind("post"))
    _add_point(_city.post_office + Vector3(0, 0, -3.0), 2.5, "ДВОРНИК", _start_work.bind("sweep"))
    if _city.port_store != Vector3.ZERO:
        _add_point(_city.port_store, 3.0, "СКЛАД ПОРТА", _open_port, false, Color(0.9, 0.3, 0.2))
        _add_point(_city.impound_lot + Vector3(8.0, 0, -1.0), 2.5, "ШТРАФСТОЯНКА", _open_impound, false, Color(0.3, 0.5, 0.9))
    if _city.faction_sites.has("police") and (_city.faction_sites["police"] as Dictionary).has("out"):
        var ps: Dictionary = _city.faction_sites["police"]
        var fwd := -(Basis(Vector3.UP, float(ps.get("out_yaw", 0.0))) * Vector3(0, 0, 1))
        var side := Vector3(fwd.z, 0, -fwd.x)
        _add_point(ps["out"] + fwd * 5.0 - side * 9.0, 6.0, "ГАИ", _open_gai, true, Color(0.3, 0.5, 0.9))
    for pk: Dictionary in _city.pickups:
        if String(pk["name"]) == "ПЕЧАТЬ" and pk.has("dir"):
            var d: Vector3 = pk["dir"]
            _add_point(pk["pos"] + Vector3(d.z, 0, -d.x) * 2.4, 2.0, "СПОРТЛОТО", _open_lotto, false, Color(0.9, 0.75, 0.2))


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
    _dialog.set_meta("title", title)
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
            ["Кредит, вклад, бизнес", _open_bank_services], ["Закрыть", _dialog.close]])


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


## Название открытого окна (чтобы обновить его, когда пришли данные с сервера).
func _dialog_title() -> String:
    return String(_dialog.get_meta("title", "")) if _dialog.has_meta("title") else ""


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
    var no_lic: bool = not ((_driving.kind == "moto" and bool(licenses.get("A", false))) or (_driving.kind != "moto" and has_license))
    var no_reg: bool = _driving.owned and not _driving.registered
    var no_to: bool = _driving.owned and _driving.registered and day - int(_driving.inspect_day) > GAI_TO_DAYS
    if not no_lic and not no_reg and not no_to:
        return
    _dps_timer -= delta
    if _dps_timer <= 0.0 and not no_lic:
        _dps_timer = 40.0
        if randf() < 0.35:
            var f2 := 800 if no_reg else 500
            f2 = mini(f2, cash + bank)
            _pay(f2, "Штраф ДПС")
            Sfx.play("error")
            _hud.show_toast("ДПС: %s. Штраф %d ₽ — ГАИ у УВД" % ["машина без номеров" if no_reg else "просрочен техосмотр", f2])
        return
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
    if _work_vehicle != null:
        _on_work_vehicle_done()
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
            v.model_id = "laz695"
            v.car_name = "ЛАЗ-695"
            v.paint = Color(0.95, 0.75, 0.15)
            v.max_engine_force = 18000.0
            v.max_speed_kmh = 80.0
            v.brake_force = 150.0
            v.max_steer = 0.5
        "truck":
            v.kind = "truck"
            v.model_id = "zil130"
            v.car_name = "ЗИЛ-130"
            v.paint = Color(0.15, 0.30, 0.65)
            v.max_engine_force = 22000.0
            v.max_speed_kmh = 90.0
            v.brake_force = 180.0
            v.max_steer = 0.5
        "school_moto":
            v.kind = "moto"
            v.model_id = "izh"
            v.car_name = "Учебный ИЖ"
            v.paint = Color(0.95, 0.55, 0.1)
            v.max_engine_force = 1500.0
            v.max_speed_kmh = 110.0
        "taxi_volga":
            v.model_id = "volga"
            v.car_name = "«Волга»-такси"
            v.paint = Color(0.95, 0.78, 0.12)
            v.livery_text = "ТАКСИ"
            v.livery_color = Color(0.08, 0.08, 0.08)
            v.max_engine_force = 7000.0
            v.max_speed_kmh = 150.0
        "school_truck":
            v.kind = "truck"
            v.model_id = "gaz53"
            v.car_name = "Учебный ГАЗ-53"
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
                _win.set_buttons("Продать за %s" % HudScript.format_money(_car_sell_price(car)), "Подогнать к рынку", true, true)
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
    if _win_mode == "market":
        var sp = _selected_payload()
        if sp is Dictionary and String(sp["type"]) == "car" and _cars[int(sp["i"])].owned:
            _ask_sell_car(int(sp["i"]))
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
    out.append({"cat": "work", "icon": "box", "name": "Почта — почтальон и дворник", "pos": c.post_office})
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
    car.registered = false
    car.impounded = false
    car.inspect_day = day
    car.plate_text = ""
    car.apply_tuning()
    Sfx.play("coin")
    _hud.show_toast("Куплено: %s! Поставь на учёт в ГАИ у УВД — без номеров ДПС штрафует и эвакуирует" % car.car_name)
    _save_game()


## Своя машина уходит обратно на рынок за 60% цены (в машине сидеть нельзя).
func _car_sell_price(car) -> int:
    return int(int(car.price) * 0.6 / 100.0) * 100


func _ask_sell_car(i: int) -> void:
    var car = _cars[i]
    _win.close_window()
    _open_dialog("Продажа машины", "Продать %s за %s? Деньги придут на карту." % [car.car_name, HudScript.format_money(_car_sell_price(car))],
            [["Продать", _sell_car.bind(i)], ["Отмена", _dialog.close]])


func _sell_car(i: int) -> void:
    _dialog.close()
    var car = _cars[i]
    if not car.owned:
        return
    if car == _driving:
        _hud.show_toast("Сначала выйди из машины")
        return
    var money := _car_sell_price(car)
    car.set_owned(false)
    car.set_available(false)
    if Net.authed:
        Net.send_msg({"t": "refund", "amount": money})   # сервер разрешит этот доход (как продажу бизнеса)
    bank += money
    _bank_log(money, "Продажа: " + String(car.car_name))
    Sfx.play("cash")
    _hud.show_toast("%s продана: +%s на карту" % [car.car_name, HudScript.format_money(money)], "money")
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
    if Net.online and city_tax > 0 and not FactionData.is_gang(faction):   # подоходный налог — в казну города
        var tax := int(pay * city_tax / 100.0)
        pay -= tax
        if tax > 0:
            Net.send_msg({"t": "tax", "n": tax})
    bank += pay
    _earned("pay", pay)
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
    if _tape_on:
        _tape_on = false
        Music.stop_place()
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
        var intro := ("Хочешь к нам на район?\n\n%s\nДоля из общака приходит на карту раз в 3 минуты. "
                + "Машины братвы — красная метка у гаража.") if gang else ("Хочешь работать у нас?\n\n%s\n"
                + "Зарплата приходит на карту раз в 3 минуты, свой автопарк — красная метка у здания.")
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
    if Net.authed:
        Net.send_msg({"t": "roster"})
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
            "on_duty": _duty.active}.merged(_org_info(), true)


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
        if _starve_acc >= STARVE_EVERY:
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
        if Net.online and Net.authed and not _injured:
            _injure()
        elif not _injured:
            _faint()


## Здоровье кончилось: игрок теряет сознание и приходит в себя у больницы.
func _faint() -> void:
    Sfx.play("faint")
    _lose_loot("Пока ты был без сознания, сумку с добычей унесли")
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
    if Net.authed and _homes_taken.has(i):
        text = "Здесь уже живёт другой игрок."
    elif home >= 0:
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
    if Net.authed:
        Net.send_msg({"t": "home", "i": i, "buy": true, "price": int(hm["price"])})
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
    if Net.authed:
        Net.send_msg({"t": "home", "i": home, "buy": false, "price": int(_city.homes[home]["price"])})
    bank += pay
    _bank_log(pay, "Продажа жилья")
    _set_home(-1)
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Жильё продано: +%s на карту" % HudScript.format_money(pay))
    _save_game()


func _enter_home(i: int) -> void:
    _dialog.close()
    _apply_furniture()
    var hi: Dictionary = _city.home_interiors[String(_city.homes[i]["kind"])]
    _home_inside = i
    _player.global_position = hi["spawn"]
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(0.0)
    Sfx.play("door")


func _exit_home() -> void:
    Music.stop_home()
    var i := _home_inside if _home_inside >= 0 else home
    _home_inside = -1
    var p: Vector3 = _city.homes[i]["pos"] if i >= 0 else PLAYER_SPAWN
    _player.global_position = p + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    Sfx.play("door")


func _use_fridge() -> void:
    var now := _now_min()
    if now - _fridge_at < 120.0:
        _hud.show_toast("Холодильник пуст — продукты будут через %d с" % int(120.0 - (now - _fridge_at)))
        return
    _fridge_at = now
    hunger = minf(100.0, hunger + 50.0)
    Sfx.play("eat")
    _player.play_consume(false)
    _hud.show_toast("Поел дома: +50 сытости")


func _use_bed() -> void:
    _open_dialog("Отдых", "Поспать? Здоровье восстановится полностью.", [["Поспать", _sleep], ["Закрыть", _dialog.close]])


func _sleep() -> void:
    _dialog.close()
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
    _lose_loot("Добычу изъяли при задержании")
    if wanted >= 4:
        # серьёзно: суд и колония — срок дольше, можно нанять адвоката или работать в колонии
        jail_left = 75.0 * wanted
        var lawyer := 2500 * wanted
        _open_dialog("Народный суд", "Розыск ★%d — дело передано в суд.\nШтраф: %s\n\nПриговор: %d секунд колонии общего режима.\nВ колонии можно работать на швейке — срок идёт быстрее." % [
                wanted, HudScript.format_money(fine), int(jail_left)],
                [["Адвокат — срок вдвое меньше (%s)" % HudScript.format_money(lawyer), _hire_lawyer.bind(lawyer)], ["Принять приговор", _dialog.close]])
    else:
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
    _earned("duty", amount)
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
        "docs":
            _hud.close_phone()
            _open_passport()
        "emote":
            _hud.close_phone()
            _open_emotes()
        "skills":
            _hud.close_phone()
            _open_skills()
        "achieve":
            _hud.close_phone()
            _open_achievements()
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
        "players":
            _hud.close_phone()
            _open_players()
        "radio":
            _hud.close_phone()
            _open_radio()
        "admin":
            _hud.close_phone()
            if Net.online and _net_admin > 0:
                Net.send_msg({"t": "adm"})


# ---------------------------------------------------------------- RP: ранения, наручники, документы (как на CRMP)

var med_card := false            # медкарта (выдаёт врач)
var city_tax := 0                # подоходный налог города, % (устанавливает мэр)
var family_name := ""            # семья (с сервера)
var gun_license := false         # лицензия на оружие (выдаёт милиция)
var _injured := false            # ранен: лежит и ждёт врача
var _injured_t := 0.0
var _cuffed_by := -1             # кто надел наручники (id игрока)
var _escort_by := -1             # кто ведёт за собой
var _docs_sent := ""
var _docs_t := 0.0
const INJURED_WAIT := 120.0


## Здоровье кончилось в онлайне: персонаж лежит раненый, врачи получают вызов. Можно ждать или ехать в больницу.
func _injure() -> void:
    if _injured:
        return
    if _driving != null or _ride_id >= 0:
        _toggle_vehicle()
    _injured = true
    _injured_t = INJURED_WAIT
    health = 1.0
    _player.set_seated("")
    _player.pose_at(_player.global_position, -_player._visual.global_basis.z, "lie")
    _player.frozen = true
    Sfx.play("faint")
    var p := _focus()
    Net.send_msg({"t": "injured", "on": true, "x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1)})
    _open_dialog("Ты тяжело ранен", "Ты лежишь без сил. Врачи получили вызов — подожди помощи до %d секунд.\n" % int(INJURED_WAIT)
            + "Или очнёшься в больнице (лечение платное).", [["Ждать врача", _dialog.close], ["В больницу", _injured_to_hospital]])


func _end_injured() -> void:
    if not _injured:
        return
    _injured = false
    _player.frozen = _cuffed_by >= 0
    _player.set_seated("")
    Net.send_msg({"t": "injured", "on": false})


func _injured_to_hospital() -> void:
    _dialog.close()
    _end_injured()
    _faint()


func _update_rp(delta: float) -> void:
    if _injured:
        _injured_t -= delta
        if _injured_t <= 0.0:
            _injured_to_hospital()
    # ведут под руку: идём за милиционером, держась в метре позади
    _player.escort_vel = Vector3.ZERO
    if _escort_by >= 0:
        if not _remote.has(_escort_by):
            _escort_by = -1
        else:
            var cop: Vector3 = (_remote[_escort_by]["npc"] as Node3D).global_position
            var to: Vector3 = cop - _player.global_position
            to.y = 0.0
            if to.length() > 25.0:
                _player.global_position = cop + Vector3(0, 0.3, 0)
            elif to.length() > 1.3:
                _player.escort_vel = to.normalized() * clampf(to.length() * 1.6, 1.2, 6.0)
    if _cuffed_by >= 0 and _player.emote == "" and _player.escort_vel.length() < 0.1 and not _injured:
        _player.play_emote("rest")   # руки за спиной
    # документы — серверу, чтобы показывать их другим (/pass /lic /med)
    _docs_t -= delta
    if _docs_t <= 0.0 and Net.authed:
        _docs_t = 5.0
        var lic := []
        if has_license:
            lic.append("B")
        for k: String in ["A", "C"]:
            if bool(licenses.get(k, false)):
                lic.append(k)
        var d := {"t": "docs", "name": passport_name, "city": "Казань", "lic": lic, "gun": gun_license, "med": med_card}
        var key := JSON.stringify(d)
        if key != _docs_sent:
            _docs_sent = key
            Net.send_msg(d)


## Что найдут при обыске: оружие, товар ОПГ, добыча.
func _search_items() -> Array:
    var out := []
    if has_pistol:
        out.append("пистолет ПМ" + ("" if gun_license else " (без лицензии!)"))
    if weapon_id != "fist" and weapon_id != "pm":
        out.append("в руках: " + weapon_id)
    if gang_goods > 0:
        out.append("товар: %d шт." % gang_goods)
    if cash >= 3000:
        out.append("наличные: %d ₽" % cash)
    return out


## Меню «ИГРОК»: RP-действия (документы, наручники, обыск, штраф, розыск, помощь раненому).
func _rp_player_buttons(id: int, r: Dictionary) -> Array:
    var b := [["Показать паспорт", _rp_say.bind("/pass %d" % id)], ["Показать права", _rp_say.bind("/lic %d" % id)],
            ["Показать медкарту", _rp_say.bind("/med %d" % id)], ["Продать / подарить вещь", _trade_menu.bind(id)],
            ["Позвонить", _rp_say.bind("/call %d" % id)], ["СМС", _rp_input.bind("СМС", "Текст сообщения", "/sms %d %%s" % id)]]
    if family_name != "":
        b.append(["Позвать в семью", _rp_say.bind("/finvite %d" % id)])
    if FactionData.base(faction) == "mayor" and faction_rank >= 3:
        b.append(["Приговор суда", _rp_input.bind("Приговор", "минуты статья, например: 10 кража", "/sentence %d %%s" % id)])
    var fk := FactionData.base(faction)
    if fk == "police" or fk == "kgb":
        b.append(["Наручники", _rp_say.bind("/cuff %d" % id)])
        b.append(["Снять наручники", _rp_say.bind("/uncuff %d" % id)])
        b.append(["Вести за собой", _rp_say.bind("/follow %d" % id)])
        b.append(["Обыскать", _rp_say.bind("/search %d" % id)])
        b.append(["Штраф 500 ₽", _rp_say.bind("/ticket %d 500 нарушение порядка" % id)])
        b.append(["Объявить в розыск", _rp_say.bind("/su %d 1 нарушение" % id)])
        if faction_rank >= 3:
            b.append(["Лицензия на оружие", _rp_say.bind("/givegun %d" % id)])
    if fk == "hospital":
        if int(r.get("hp", 100)) <= 1:
            b.push_front(["Поднять раненого", _rp_say.bind("/revive %d" % id)])
        b.append(["Выдать медкарту", _rp_say.bind("/givemed %d" % id)])
    return b


## Приговор суда: колония на sec секунд (сервер помнит срок — после перезахода он продолжится).
func _court_jail(sec: float, why: String) -> void:
    if _driving:
        _toggle_vehicle()
    _end_injured()
    _job.stop()
    _work.stop()
    _duty.stop()
    wanted = 0
    jail_left = sec
    _interior = "police"
    _player.global_position = _city.kpz_cell
    _player.velocity = Vector3.ZERO
    _open_dialog("Народный суд", "Приговор: %d мин колонии.\nСтатья: %s\n\nМожно работать у стены — срок идёт быстрее." % [int(ceil(sec / 60.0)),
            why if why != "" else "по решению суда"], [["Понятно", _dialog.close]])
    _save_game()


func _rp_input(title: String, hint: String, fmt: String) -> void:
    _open_dialog(title, "", [["Отправить", func() -> void:
            var t := _dialog.input_text()
            if t == "":
                return
            _rp_say(fmt % t)],
        ["Отмена", _dialog.close]], hint)


## Продать или подарить вещь из сумки игроку рядом.
func _trade_menu(id: int) -> void:
    var buttons := []
    for it: String in inventory:
        if int(inventory[it]) > 0:
            buttons.append([it, _trade_price.bind(id, it)])
        if buttons.size() >= 10:
            break
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Продать / подарить", "Что предложить?" if buttons.size() > 1 else "Сумка пуста.", buttons)


func _trade_price(id: int, item: String) -> void:
    _open_dialog("«%s»" % item, "Цена в рублях (0 — подарить):", [["Предложить", func() -> void:
            var price := maxi(0, int(_dialog.input_text()))
            _dialog.close()
            Net.send_msg({"t": "trade", "to": id, "item": item, "price": price})],
        ["Отмена", _dialog.close]], "Цена, ₽")


func _rp_say(cmd: String) -> void:
    _dialog.close()
    Net.say(cmd)


# ---------------------------------------------------------------- интерьеры фракций: пульты, лифт, койки, база ОПГ

var gang_goods := 0              # товар своего «цеха» (ОПГ): варёнки, кассеты, запчасти, мандарины
var _craft_t := 0.0              # идёт работа в цехе
var _craft_cd := 0.0             # цех остывает (новая партия — позже)
var _heal_bed := false           # лежит на больничной койке
var _tape_on := false
var _safe_cd := 0.0

## [товар (мн. ч.), что делаем в цехе, цена за штуку, трек магнитофона]
const GANG_GOODS := {
    "tyap": ["пары варёнок", "Шьём и варим джинсы-«варёнки»", 380, "radio_rock"],
    "universam": ["импортных кассет", "Переписываем кассеты на двухкассетнике", 340, "radio_disco"],
    "solnce": ["комплектов запчастей", "Разбираем машину на запчасти", 420, "radio_phonk"],
    "kavkaz": ["ящиков мандаринов", "Принимаем ящики мандаринов с юга", 320, "radio_kavkaz"],
}
const CRAFT_TIME := 25.0
const CRAFT_BATCH := 5


func _setup_interior_points() -> void:
    for fid: String in _city.interiors:
        var inn: Dictionary = _city.interiors[fid]
        var fc: Color = FactionData.get_faction(fid).get("color", Color.WHITE)
        if inn.has("console"):
            for seat: Array in inn["console"]:
                _add_point(seat[0], 0.9, "ПУЛЬТ", _use_console.bind(seat), false, fc, false)
        if inn.has("radio"):
            _add_point(inn["radio"][0], 1.1, "ПУЛЬТ СВЯЗИ", _use_seat_radio.bind(inn["radio"]), false, fc, false)
        if inn.has("dispatch"):
            _add_point(inn["dispatch"][0], 1.1, "ДИСПЕТЧЕР", _use_seat_radio.bind(inn["dispatch"]), false, fc, false)
        if inn.has("wardrobe"):
            _add_point(inn["wardrobe"], 1.4, "ГАРДЕРОБ", _open_disguise, false, fc, false)
        if inn.has("lift"):
            _add_point(inn["lift"], 1.4, "ЛИФТ НА 2 ЭТАЖ", _ride_lift.bind(inn["floor2"], Vector3(0, 0, -1)), false, fc, false)
            _add_point(inn["lift2"], 1.4, "ЛИФТ НА 1 ЭТАЖ", _ride_lift.bind(inn["lift"] + Vector3(0, 0.3, 0), Vector3(-1, 0, 0)), false, fc, false)
            for bed: Array in inn["beds"]:
                _add_point(bed[0] - (bed[1] as Vector3) * 0.1 + Vector3(0, 0, 0.9), 1.0, "ЛЕЧЬ", _lie_bed.bind(bed), false, fc, false)
        if inn.has("sofa"):
            _add_point(inn["sofa"][0], 1.0, "СЕСТЬ", _pose_here.bind(inn["sofa"], "chair", ""), false, fc, false)
            for seat: Array in inn["cards"]:
                _add_point(seat[0], 0.7, "КАРТЫ", _play_cards.bind(seat), false, fc, false)
            _add_point(inn["bench"][0], 1.0, "ЖИМ ЛЁЖА", _gym_pose.bind(inn["bench"], "bench"), false, fc, false)
            _add_point(inn["bag"][0], 1.0, "ГРУША", _gym_pose.bind(inn["bag"], "boxing"), false, fc, false)
            _add_point(inn["armchair"][0], 1.0, "ТЕЛЕВИЗОР", _pose_here.bind(inn["armchair"], "chair",
                    "По телевизору — «Спокойной ночи, малыши!» и футбол: «Спартак» — «Динамо»"), false, fc, false)
            _add_point(inn["safe"], 1.0, "ОБЩАК", _open_obshak.bind(fid), false, fc, false)
            _add_point(inn["craft"][0], 1.1, "ЦЕХ", _open_craft.bind(fid), false, fc, false)
            _add_point(inn["tape"], 1.0, "МАГНИТОФОН", _toggle_tape.bind(fid), false, fc, false)
    if _city.market != Vector3.ZERO:
        _points.append({"pos": _city.market + Vector3(-6.0, 0, 3.0), "r": 2.0, "text": "БАРЫГА", "cb": _sell_goods,
                "car": false, "gang_only": true})


## Сесть/лечь в точке seat = [точка, куда смотреть] с позой key; note — что показать.
func _pose_here(seat: Array, key: String, note: String) -> void:
    if _player.pose_at(seat[0], seat[1], key):
        if note != "":
            _hud.show_toast(note)
    else:
        Sfx.play("error")


func _use_console(seat: Array) -> void:
    _player.pose_at(seat[0], seat[1], "typing")
    _open_lookup()


func _use_seat_radio(seat: Array) -> void:
    _player.pose_at(seat[0], seat[1], "chair")
    if faction == "" or FactionData.is_gang(faction):
        _hud.show_toast("Пульт связи — только для сотрудников")
        return
    _open_radio()


func _ride_lift(to: Vector3, facing: Vector3) -> void:
    Sfx.play("click")
    _player.global_position = to + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(atan2(-facing.x, -facing.z))
    _hud.show_toast("Лифт: приехали")


## Больничная койка: лёжа здоровье быстро восстанавливается (бесплатно — для всех).
func _lie_bed(bed: Array) -> void:
    if _player.pose_at(bed[0], bed[1], "lie_bed"):
        _heal_bed = true
        _hud.show_toast("Лёг на койку: здоровье восстанавливается. Пошевели джойстиком, чтобы встать")


## Штанга и груша: подход 8 секунд, сила растёт (как на турнике во дворе).
func _gym_pose(seat: Array, key: String) -> void:
    if _train_t > 0.0:
        return
    if hunger < 15.0:
        _hud.show_toast("Голодный не накачаешься — сначала поешь")
        return
    var ok: bool = _player.pose_at(seat[0], seat[1], key) if key == "bench" else _player.play_emote(key)
    if not ok:
        Sfx.play("error")
        return
    _train_t = 8.0
    _train_pos = _focus()
    _hud.show_toast("Жим лёжа: не вставай 8 секунд" if key == "bench" else "Бьёшь грушу: не двигайся 8 секунд")


## Карты за столом в базе ОПГ: «бура» на деньги. Шанс чуть меньше половины.
func _play_cards(seat: Array) -> void:
    _player.pose_at(seat[0], seat[1], "cards")
    _open_dialog("Бура", "Пацаны сдают карты. Ставка?\nВыигрыш — вдвое больше ставки, шанс — как повезёт.",
            [["Ставка 100 ₽", _cards_bet.bind(seat, 100)], ["Ставка 500 ₽", _cards_bet.bind(seat, 500)],
            ["Ставка 1 000 ₽", _cards_bet.bind(seat, 1000)], ["Просто посидеть", _dialog.close]])


func _cards_bet(seat: Array, bet: int) -> void:
    _dialog.close()
    if cash < bet:
        Sfx.play("error")
        _hud.show_toast("Ставят наличными — не хватает")
        return
    cash -= bet
    if randf() < 0.46:
        cash += bet * 2
        _earned("casino", bet * 2)
        Sfx.play("coin")
        _hud.show_toast("Взял партию! +%s" % HudScript.format_money(bet), "money")
    else:
        Sfx.play("error", -6.0)
        _hud.show_toast("Не повезло: −%s" % HudScript.format_money(bet))
    _play_cards.call_deferred(seat)


## Общак: взнос растит уважение в ОПГ (опыт для повышения).
func _open_obshak(fid: String) -> void:
    if faction != fid:
        _hud.show_toast("Чужой общак не трогай")
        Sfx.play("error")
        return
    var buttons := [["Положить 1 000 ₽", _obshak_put.bind(1000)], ["Положить 5 000 ₽", _obshak_put.bind(5000)]]
    if _port_box:
        buttons.push_front(["Сдать ящик патронов (+50)", _port_deliver])
    buttons.append(["Взять 30 патронов", _port_take])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Общак", "Положи в общак — пацаны уважать будут (опыт для повышения). Раз в 5 минут.\nПатроны в общаке: %d. У тебя: %d.\nПатроны везут ящиками со склада в порту — если склад ваш." % [gang_stock, ammo],
            buttons)


func _obshak_put(amount: int) -> void:
    _dialog.close()
    if _safe_cd > 0.0:
        _hud.show_toast("Недавно уже клал — загляни через %d с" % int(_safe_cd))
        return
    if not _pay(amount, "Общак"):
        return
    _safe_cd = 300.0
    faction_exp += 1 if amount < 5000 else 3
    Sfx.play("coin")
    _hud.show_toast("Положил в общак %s. Уважение растёт" % HudScript.format_money(amount), "money")
    _save_game()


## Цех ОПГ: у каждой группировки свой товар. Партия за 25 секунд работы, продаётся барыге на рынке.
func _open_craft(fid: String) -> void:
    if faction != fid:
        _hud.show_toast("Это цех чужой группировки")
        Sfx.play("error")
        return
    var g: Array = GANG_GOODS.get(fid, ["товара", "Работаем", 300, ""])
    var text := "%s.\nНа руках: %d %s (максимум %d).\nПродать — барыге на рынке в Казани (метка «БАРЫГА»). Можно засветиться перед милицией." % [
            g[1], gang_goods, g[0], CRAFT_BATCH * 3]
    var buttons := []
    if _craft_cd > 0.0:
        text += "\n\nНовая партия будет через %d с." % int(_craft_cd)
    elif gang_goods < CRAFT_BATCH * 3:
        buttons.append(["Работать (%d с)" % int(CRAFT_TIME), _start_craft.bind(fid)])
    if gang_goods > 0:
        buttons.append(["Метка на барыгу", func() -> void:
                _dialog.close()
                _set_gps(_city.market + Vector3(-6.0, 0, 3.0), "Барыга", true)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Цех — %s" % FactionData.get_faction(fid).get("title", ""), text, buttons)


func _start_craft(fid: String) -> void:
    _dialog.close()
    var inn: Dictionary = _city.interiors[fid]
    _player.global_position = (inn["craft"][0] as Vector3) + Vector3(0, 0.3, 0)
    _player.set_camera_yaw(atan2(-(inn["craft"][1] as Vector3).x, -(inn["craft"][1] as Vector3).z))
    _player._visual.rotation.y = atan2(-(inn["craft"][1] as Vector3).x, -(inn["craft"][1] as Vector3).z)
    _player.play_emote("work")
    _craft_t = CRAFT_TIME
    _train_pos = _focus()
    _hud.show_toast("Работаем! Не отходи от верстака %d секунд" % int(CRAFT_TIME))


func _update_faction_rooms(delta: float) -> void:
    _craft_cd = maxf(0.0, _craft_cd - delta)
    _safe_cd = maxf(0.0, _safe_cd - delta)
    if _craft_t > 0.0:
        _craft_t -= delta
        var me := _focus()
        if Vector2(me.x - _train_pos.x, me.z - _train_pos.z).length() > 1.0 or _player.emote != "work":
            _craft_t = 0.0
            _hud.show_toast("Работу бросил — партия не готова")
        elif _craft_t <= 0.0:
            _player.emote = ""
            gang_goods = mini(CRAFT_BATCH * 3, gang_goods + CRAFT_BATCH)
            _craft_cd = 120.0
            var g: Array = GANG_GOODS.get(faction, ["товара"])
            Sfx.play("levelup", -8.0)
            _hud.show_toast("Партия готова: +%d %s (всего %d). Неси барыге на рынок" % [CRAFT_BATCH, g[0], gang_goods], "money")
            _save_game()
    if _heal_bed:
        if _player.seated != "pose":
            _heal_bed = false
        elif health < 100.0:
            health = minf(100.0, health + 4.0 * delta)
            if health >= 100.0:
                Sfx.play("heal")
                _hud.show_toast("Здоровье восстановлено")


func _sell_goods() -> void:
    if gang_goods <= 0:
        _hud.show_toast("Барыга: «Принесёшь товар — поговорим»")
        return
    var g: Array = GANG_GOODS.get(faction, ["товара", "", 300])
    var each := int(int(g[2]) * randf_range(0.85, 1.2))
    var total := each * gang_goods
    _open_dialog("Барыга", "«Беру %d %s по %d ₽. Итого %s. По рукам?»" % [gang_goods, g[0], each, HudScript.format_money(total)],
            [["По рукам", _sell_goods_ok.bind(total)], ["Не сейчас", _dialog.close]])


func _sell_goods_ok(total: int) -> void:
    _dialog.close()
    gang_goods = 0
    cash += total
    _earned("crime", total)
    Sfx.play("coin")
    _hud.show_toast("Сбыл товар: +%s" % HudScript.format_money(total), "money")
    if randf() < 0.25:
        _add_wanted(1, "спекуляция")
    _save_game()


func _toggle_tape(fid: String) -> void:
    _tape_on = not _tape_on
    if _tape_on:
        var g: Array = GANG_GOODS.get(fid, ["", "", 0, "radio_retro"])
        var track := String(g[3])
        if not ResourceLoader.exists("res://music/%s.ogg" % track):
            track = "radio_retro"
        Music.play_place(track)
        _hud.show_toast("Магнитофон «Электроника» играет")
    else:
        Music.stop_place()
        _hud.show_toast("Магнитофон выключен")


# ---------------------------------------------------------------- рация госслужб, база данных, маскировка КГБ

var _calls: Array = []           # вызовы милиции, пришедшие по рации: {id, from, fac, pos, text, t}
var kgb_disguise := ""           # КГБ: чужая форма "police:2" / "civil" (гражданское) / "" — своя


func _open_radio() -> void:
    if faction == "" or FactionData.is_gang(faction):
        return
    var fk := FactionData.base(faction)
    var text := "Канал: %s.\n" % String(FactionData.get_faction(faction).get("name", ""))
    var buttons := []
    if fk == "police" or fk == "kgb" or fk == "hospital":
        var fresh := _calls.filter(func(c: Dictionary) -> bool: return Time.get_ticks_msec() / 1000.0 - float(c["t"]) < 900.0)
        text += "Вызовов за 15 минут: %d." % fresh.size()
        buttons.append(["Вызовы (%d)" % fresh.size(), _show_calls])
    if fk != "police":
        buttons.append(["Вызвать милицию сюда", _radio_call_input])
    if fk == "fire":
        text += "\nРадар пожаров включается сам на вызове «пожар»: зелёный экран справа ведёт к очагу."
        if _duty.fire_active():
            buttons.append(["Где пожар?", func() -> void:
                    _dialog.close()
                    _hud.show_toast("Радар: очаг %s, %d м" % [_duty._place(_duty.fire_pos), int(_focus().distance_to(_duty.fire_pos))])])
    if fk == "kgb":
        buttons.append(["Маскировка", _open_disguise])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Рация", text, buttons)


func _radio_call_input() -> void:
    _open_dialog("Вызов милиции", "Что случилось? Милиция увидит метку там, где ты стоишь.", [
        ["Передать", func() -> void:
            var t := _dialog.input_text()
            _dialog.close()
            _radio_call(t if t != "" else "Нужна помощь")],
        ["Отмена", _dialog.close]], "Например: драка у мэрии")


func _radio_call(text: String) -> void:
    var p := _focus()
    Sfx.play("notify")
    if Net.online:
        Net.send_msg({"t": "call", "x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1), "text": text})
        _hud.chat("Рация: «%s» — вызов милиции %s" % [text, _duty._place(p)], "faction")
    else:
        _hud.show_toast("Вызов передан. В одиночной игре милиция — только у игроков онлайн")


func _on_police_call(m: Dictionary) -> void:
    var pos := Vector3(float(m.get("x", 0)), 0, float(m.get("z", 0)))
    var c := {"id": int(m.get("id", 0)), "from": String(m.get("from", "")), "fac": String(m.get("fac", "")), "pos": pos,
            "text": String(m.get("text", "")), "t": Time.get_ticks_msec() / 1000.0}
    _calls.push_front(c)
    if _calls.size() > 10:
        _calls.resize(10)
    var who := String(FactionData.get_faction(String(c["fac"])).get("title", c["fac"]))
    _hud.chat("РАЦИЯ (%s, %s): «%s» %s — %s" % [who, c["from"], c["text"], _duty._place(pos), _dist_text(_focus().distance_to(pos))], "warn")
    _hud.show_toast("Вызов по рации: %s — %s" % [c["text"], _dist_text(_focus().distance_to(pos))], "warn")
    Sfx.play("siren", -14.0, 1.4)


func _show_calls() -> void:
    var text := ""
    var buttons := []
    for c: Dictionary in _calls.slice(0, 6):
        var ago := int((Time.get_ticks_msec() / 1000.0 - float(c["t"])) / 60.0)
        text += "• %s (%s), %d мин назад: «%s» %s\n" % [c["from"], FactionData.get_faction(String(c["fac"])).get("title", ""), ago,
                c["text"], _duty._place(c["pos"])]
        buttons.append(["Принять: %s" % c["from"], _take_call.bind(c)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Вызовы по рации", text if text != "" else "Вызовов нет.", buttons)


func _take_call(c: Dictionary) -> void:
    _dialog.close()
    Net.send_msg({"t": "call_take", "id": c["id"]})
    _set_gps(c["pos"], "Вызов: " + String(c["from"]), true)
    _hud.show_toast("Вызов принят — метка на карте")


## Пульт наблюдения (милиция и КГБ): кто в городе, где он, в розыске ли.
func _open_lookup() -> void:
    var fk := FactionData.base(faction)
    if fk != "police" and fk != "kgb":
        _hud.show_toast("Пульт — только для сотрудников милиции и КГБ")
        Sfx.play("error")
        return
    Sfx.play("click")
    if not Net.online:
        _open_dialog("Пульт наблюдения", "Нет связи с центральной базой: она работает только в онлайне.\n\n" +
                "Здесь видно всех игроков в городе: где они сейчас, в розыске ли, в машине ли, сколько в игре.",
                [["Закрыть", _dialog.close]])
        return
    Net.send_msg({"t": "lookup"})
    _hud.show_toast("Запрос в базу…")


var _lookup_list: Array = []


func _show_lookup(list: Array) -> void:
    _lookup_list = list
    _lookup_page(0, "")


## Страница базы: по 6 человек, можно искать по нику (в онлайне бывает много игроков).
func _lookup_page(page: int, query: String) -> void:
    var q := query.strip_edges().to_lower()
    var flt: Array = _lookup_list.filter(func(e: Array) -> bool: return q == "" or String(e[0]).to_lower().contains(q))
    var per := 6
    var pages := maxi(1, int(ceil(flt.size() / float(per))))
    page = clampi(page, 0, pages - 1)
    var text := "В городе: %d. Сначала — те, кто в розыске." % _lookup_list.size()
    if q != "":
        text += "\nПоиск «%s»: найдено %d." % [query, flt.size()]
    if pages > 1:
        text += " Стр. %d из %d." % [page + 1, pages]
    var buttons := []
    for e: Array in flt.slice(page * per, page * per + per):
        var pos := Vector3(float(e[4]), 0, float(e[5]))
        var fac := String(e[1])
        var stars := int(e[2])
        var nick := String(e[0])
        text += "\n%s%s — %s%s%s, %d мин в игре" % [nick,
                (" (%s)" % FactionData.get_faction(fac).get("title", fac)) if fac != "" else "",
                _duty._place(pos).trim_prefix("в районе: "), ", в машине" if int(e[6]) == 1 else "",
                (", РОЗЫСК %s" % "★".repeat(stars)) if stars > 0 else "", int(e[7])]
        buttons.append(["Метка: %s" % nick, _lookup_mark.bind(pos, nick)])
    if flt.is_empty() and q != "":
        text += "\nНикого с таким ником нет."
    if page + 1 < pages:
        buttons.append(["Дальше →", _lookup_page.bind(page + 1, query)])
    if page > 0:
        buttons.append(["← Назад", _lookup_page.bind(page - 1, query)])
    buttons.append(["Найти по нику", _lookup_search])
    buttons.append(["Обновить", _open_lookup])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Пульт наблюдения", text, buttons)


func _lookup_search() -> void:
    _open_dialog("Поиск в базе", "Введи ник или его часть.", [["Найти", func() -> void:
            _lookup_page(0, _dialog.input_text())],
        ["Отмена", _lookup_page.bind(0, "")]], "Ник")


func _lookup_mark(pos: Vector3, nick: String) -> void:
    _dialog.close()
    _set_gps(pos, "Пробит: %s" % nick, true)
    _hud.show_toast("%s — метка на карте (где был при запросе)" % nick)


## КГБ: переодеться в форму другой службы, ОПГ или в гражданское (видят все игроки).
const DISGUISES := [["civil", "Гражданское"], ["police:2", "Форма милиции"], ["hospital:2", "Халат врача"],
        ["fire:1", "Пожарный"], ["mayor:2", "Чиновник мэрии"], ["tyap:2", "Пацан «Тяп-Ляп»"], ["kavkaz:2", "Кавказское ОПГ"],
        ["", "Своя форма КГБ"]]


func _open_disguise() -> void:
    if FactionData.base(faction) != "kgb":
        return
    if _interior != faction:
        _dialog.close()
        _hud.show_toast("Переодеться можно в гардеробе управления КГБ")
        Sfx.play("error")
        return
    var buttons := []
    for d: Array in DISGUISES:
        buttons.append([String(d[1]), _set_disguise.bind(String(d[0]), String(d[1]))])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Маскировка", "Чужая форма видна всем игрокам. В базе милиции сотрудники КГБ не числятся.", buttons)


func _set_disguise(key: String, title: String) -> void:
    _dialog.close()
    kgb_disguise = key
    _apply_look()
    Sfx.play("click")
    _hud.show_toast(("Маскировка: %s" % title) if key != "" else "Снова в своей форме", "money")


# ---------------------------------------------------------------- панель администратора

var _adm := {}          # последний ответ сервера: игроки и репорты


func _show_admin_panel(m: Dictionary) -> void:
    _adm = m
    var players: Array = m.get("players", [])
    var reports: Array = m.get("reports", [])
    var text := "Уровень: %d · онлайн: %d · репортов: %d\n" % [int(m.get("lvl", 0)), players.size(), reports.size()]
    for r: Array in reports.slice(0, 4):
        text += "\n#%d %s (%d мин назад): %s" % [int(r[0]), r[1], int(r[3]), String(r[2]).left(70)]
    var buttons := []
    if not reports.is_empty():
        buttons.append(["Ответить на репорты", _admin_reports])
    buttons.append(["Игроки онлайн", _admin_players.bind(0)])
    buttons.append(["Объявление всем", _admin_input.bind("Объявление всем", "Текст объявления", "/ann %s")])
    buttons.append(["Админ-чат", _admin_input.bind("Админ-чат", "Сообщение администраторам", "/a %s")])
    buttons.append(["Журнал действий", _admin_cmd.bind("/logs")])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Панель администратора", text, buttons)


func _admin_reports() -> void:
    var reports: Array = _adm.get("reports", [])
    var text := ""
    var buttons := []
    for r: Array in reports.slice(0, 6):
        text += "#%d %s: %s\n" % [int(r[0]), r[1], String(r[2]).left(90)]
        buttons.append(["Ответить: %s" % r[1], _admin_input.bind("Ответ для %s" % r[1], "Текст ответа", "/ans %s %%s" % r[1])])
    buttons.append(["Назад", Net.send_msg.bind({"t": "adm"})])
    _open_dialog("Репорты", text if text != "" else "Открытых репортов нет.", buttons)


func _admin_players(page: int) -> void:
    var players: Array = _adm.get("players", [])
    var per := 8
    var text := ""
    var buttons := []
    for i in range(page * per, mini(players.size(), page * per + per)):
        var e: Array = players[i]
        var tags := ""
        if String(e[1]) != "":
            tags += " · " + String(FactionData.get_faction(String(e[1])).get("title", e[1]))
        if int(e[2]) > 0:
            tags += " · варн %d/3" % int(e[2])
        if int(e[3]) > 0:
            tags += " · админ %d" % int(e[3])
        if e[4] == true:
            tags += " · мут"
        if e[5] == true:
            tags += " · заморожен"
        text += "%s%s\n" % [e[0], tags]
        buttons.append([String(e[0]), _admin_player.bind(e)])
    if players.size() > (page + 1) * per:
        buttons.append(["Дальше →", _admin_players.bind(page + 1)])
    buttons.append(["Назад", Net.send_msg.bind({"t": "adm"})])
    _open_dialog("Игроки (%d)" % players.size(), text, buttons)


func _admin_player(e: Array) -> void:
    var nick := String(e[0])
    var lvl := int(_adm.get("lvl", 0))
    var text := "Ник: %s\nНаличные: %d ₽\nПредупреждений: %d/3%s%s" % [nick, int(e[6]), int(e[2]),
            "\nЧат заблокирован" if e[4] == true else "", "\nЗаморожен" if e[5] == true else ""]
    var buttons := [
        ["ТП к нему", _admin_cmd.bind("/tp " + nick)],
        ["ТП к себе", _admin_cmd.bind("/tphere " + nick)],
        ["Разморозить" if e[5] == true else "Заморозить", _admin_cmd.bind("/freeze " + nick)],
        ["Вылечить", _admin_cmd.bind("/hp " + nick)],
        ["Написать", _admin_input.bind("Сообщение для " + nick, "Текст", "/ans " + nick + " %s")],
        ["Мут 10 мин", _admin_cmd.bind("/mute %s 10" % nick)],
        ["Предупреждение", _admin_input.bind("Предупреждение " + nick, "Причина", "/warn " + nick + " %s")],
        ["Кикнуть", _admin_cmd.bind("/kick " + nick)],
        ["Логи игрока", _admin_cmd.bind("/logs " + nick)],
    ]
    if lvl >= 2:
        buttons.append(["Забанить", _admin_input.bind("Бан " + nick, "Причина бана", "/ban " + nick + " %s")])
    if lvl >= 4:
        buttons.append(["Выдать деньги", _admin_input.bind("Деньги для " + nick, "Сумма (можно с минусом)", "/givemoney " + nick + " %s")])
    buttons.append(["Назад", _admin_players.bind(0)])
    _open_dialog("Игрок " + nick, text, buttons)


func _admin_cmd(cmd: String) -> void:
    _dialog.close()
    Net.say(cmd)
    if cmd.begins_with("/logs"):
        _hud.show_toast("Журнал — в чате")


## Окно с полем ввода: введённый текст подставляется в команду вместо %s.
func _admin_input(title: String, hint: String, fmt: String) -> void:
    _open_dialog(title, "", [["Отправить", func() -> void:
            var t := _dialog.input_text()
            if t == "":
                return
            _admin_cmd(fmt % t)],
        ["Отмена", _dialog.close]], hint)


## Телефон → «Игроки»: кто сейчас в городе, где (расстояние), из какой фракции; метка на карте.
func _open_players() -> void:
    if not Net.online:
        _open_dialog("Игроки", "Список игроков есть только в онлайне.", [["Закрыть", _dialog.close]])
        return
    var list := []
    for id in _remote:
        var r: Dictionary = _remote[id]
        var pos: Vector3 = r.get("tpos", Vector3.ZERO)
        list.append([_focus().distance_to(pos), String(r["name"]), String(r.get("fid", "")), pos])
    list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
    var text := "В городе: %d (с тобой — %d)\n\n" % [list.size(), list.size() + 1]
    var buttons := []
    for e: Array in list:
        var fid := String(e[2])
        var ftitle := String(FactionData.get_faction(fid).get("title", "")) if fid != "" and fid != "?" else ""
        var where := "%d м" % int(e[0]) if e[0] < 1000.0 else "%.1f км" % (e[0] / 1000.0)
        text += "• %s%s — %s\n" % [e[1], (" (%s)" % ftitle) if ftitle != "" else "", where]
        if buttons.size() < 5:
            buttons.append(["Метка: %s" % e[1], _faction_gps.bind(e[3], String(e[1]))])
    if list.is_empty():
        text += "Пока никого. Позови друзей!"
    text += "\nЛичное сообщение: /pm ник текст"
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Игроки онлайн", text, buttons)


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
    Sfx.play("car_door")
    # поездка — с затемнением экрана, как на электричке; время в пути — по расстоянию
    var secs := clampf(_focus().distance_to(p) / 400.0, 1.0, 3.0)
    _travel(p, "Такси «Волга» везёт тебя: %s\n%s" % [place, HudScript.format_money(price)], secs, "")
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
    _refresh_bag()


## Сумка 5×5 (окно по концепту): вещи стопками.
func _refresh_bag() -> void:
    if _bag == null:
        return
    var list := []
    for item: String in inventory:
        var info := _item_info(item)
        var what := ""
        if int(info[0]) > 0:
            what += "+%d сытости  " % int(info[0])
        if int(info[1]) > 0:
            what += "+%d здоровья" % int(info[1])
        if item.begins_with("Канистра"):
            what = "+10 л бензина в бак своей машины"
        list.append({"name": item, "count": int(inventory[item]), "icon": _item_icon(item), "about": what.strip_edges()})
    _bag.open_bag(list, "%d/%d" % [_bag_count(), BAG_SIZE])


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
        text += "\n\nТвой бизнес. Доход: %s в минуту, в кассе: %s" % [HudScript.format_money(int(bz["income"])), HudScript.format_money(till)]
        buttons.append(["Забрать выручку (%s)" % HudScript.format_money(till), _biz_collect.bind(i)])
        buttons.append(["Продать за %s" % HudScript.format_money(int(bz["price"]) / 2), _biz_sell.bind(i)])
    elif Net.authed and _biz_taken.has(i):
        text += "\n\nВладелец бизнеса: %s" % String(_biz_taken[i])
    else:
        text += "\n\nБизнес продаётся: %s, доход ~%s в минуту" % [HudScript.format_money(int(bz["price"])), HudScript.format_money(int(bz["income"]))]
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
    if Net.authed:
        Net.send_msg({"t": "biz", "i": i, "buy": true, "price": int(bz["price"])})
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
    _earned("biz", till)
    _bank_log(till, "Выручка: %s" % _biz[i]["title"])
    Sfx.play("cash")
    _hud.show_toast("Выручка +%s на карту" % HudScript.format_money(till))
    _save_game()
    _open_kiosk(i)


func _biz_sell(i: int) -> void:
    var bz: Dictionary = _biz[i]
    var pay := int(bz["price"]) / 2 + int(biz_owned.get(str(i), 0))
    biz_owned.erase(str(i))
    if Net.authed:
        Net.send_msg({"t": "refund", "amount": pay})
        Net.send_msg({"t": "biz", "i": i, "buy": false})
    bank += pay
    _bank_log(pay, "Продажа бизнеса")
    Sfx.play("cash")
    _dialog.close()
    _hud.show_toast("Бизнес продан: +%s" % HudScript.format_money(pay))
    _save_game()


## Выручка капает каждую минуту (минус 10% налога), касса вмещает 24 минуты дохода.
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
                + "и нажми «Купить бизнес». Доход капает в кассу каждую минуту.") % HudScript.format_money(LICENSE_PRICE),
                [["Закрыть", _dialog.close]])
        return
    var text := ""
    var buttons := []
    for key: String in biz_owned:
        var i := int(key)
        var bz: Dictionary = _biz[i]
        text += "%s — в кассе %s (доход %s/мин)\n" % [bz["title"], HudScript.format_money(int(biz_owned[key])),
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
                if Net.authed:
                    Net.send_msg({"t": "turf", "key": key, "gid": faction})
                _capt = {}
                _capt_cd = 300.0
                bank += 1500
                _earned("reward", 1500)
                _bank_log(1500, "Захват района")
                faction_exp += 1
                stats["turf"] = int(stats["turf"]) + 1
                Sfx.play("levelup")
                _hud.show_toast("Район наш! +1 500 ₽ из общака, +1 стаж")
                _sms_add(_faction_name(), "Район взят под контроль. Каждая получка — больше на 150 ₽ за район.")
                _refresh_turf()
                _save_game()
    # другие банды тоже не спят: раз в 5 минут кто-то что-то отжимает
    _ai_turf_t += delta
    if _ai_turf_t >= 300.0 and not Net.authed:   # онлайн районы делят живые игроки
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
        buttons.append(["%s — %s" % ["Убрать «ёлочку»" if car.freshener else "«Ёлочка» на зеркало", HudScript.format_money(150)], _sto_toggle.bind("freshener", 150)])
        buttons.append(["%s — %s" % ["Вернуть глушитель" if car.loud else "Прямоток (громкий выхлоп)", HudScript.format_money(3000)], _sto_toggle.bind("loud", 3000)])
        buttons.append(["%s — %s" % ["Поднять обратно" if car.lowered else "Занижение", HudScript.format_money(2500)], _sto_toggle.bind("lowered", 2500)])
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


func _sto_toggle(prop: String, price: int) -> void:
    if _driving == null or not _pay(price, "СТО: тюнинг"):
        return
    _driving.set(prop, not bool(_driving.get(prop)))
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
    if _weather_t <= 0.0 and not Net.authed:   # онлайн погоду задаёт сервер
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
    # утренний туман: с 5 до 9 часов, гуще всего в половине седьмого
    var h := minutes / 60.0
    var morning := clampf(1.0 - absf(h - 6.5) / 2.5, 0.0, 1.0)
    return fogs[clampi(int(_menu.settings["view"]), 0, 2)] * (1.0 + 1.8 * morning)


func _set_film(on: bool) -> void:
    if on and _film_fx == null and ResourceLoader.exists("res://shaders/film.gdshader"):
        var layer := CanvasLayer.new()
        layer.layer = -1   # над 3D, под интерфейсом
        add_child(layer)
        _film_fx = ColorRect.new()
        _film_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
        _film_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sm := ShaderMaterial.new()
        sm.shader = load("res://shaders/film.gdshader")
        _film_fx.material = sm
        layer.add_child(_film_fx)
    if _film_fx:
        _film_fx.visible = on


## Паспорт гражданина: раскрытая красная книжка с данными игрока.
func _open_passport() -> void:
    var p = preload("res://scripts/passport.gd").new()
    var lic: Array = []
    for k: String in ["A", "B", "C"]:
        if bool(licenses.get(k, false)) or (k == "B" and has_license):
            lic.append(k)
    var fname := ""
    if faction != "":
        var fd: Dictionary = FactionData.get_faction(faction)
        fname = String(fd.get("name", faction))
    var num := absi(hash(passport_name)) % 1000000
    p.data = {"name": passport_name, "female": player_female, "city": "Казань", "lic": lic, "med": med_card, "gun": gun_license,
            "faction": fname, "family": family_name, "number": "%s-КЗ %06d" % [["I", "II", "III", "IV"][num % 4], num]}
    var layer := CanvasLayer.new()
    layer.layer = 30   # поверх интерфейса
    add_child(layer)
    layer.add_child(p)


## Если игра долго идёт рывками — сами снижаем разрешение 3D (до двух раз), чтобы было плавно.
func _fps_guard(delta: float) -> void:
    if not _started or get_tree().paused:
        return
    var fps := Engine.get_frames_per_second()
    var target := 26.0 if Engine.max_fps == 30 else 40.0
    if fps > 0.0 and fps < target:
        _fps_low_t += delta
    else:
        _fps_low_t = maxf(0.0, _fps_low_t - delta * 0.5)
    if _fps_low_t > 12.0 and _auto_scale > 0.7:
        _fps_low_t = 0.0
        _auto_scale = maxf(0.7, _auto_scale - 0.15)
        _apply_settings()
        _hud.show_toast("Игра тормозит — снизил чёткость картинки для плавности (Настройки → Качество)")


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
    _earned("reward", reward)
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


# ---------------------------------------------------------------- приезд в город (первый вход)

func _arrival_intro() -> void:
    if _player == null or _player._camera == null:
        _show_welcome()
        return
    _touch.blocked = true
    _hud.visible = false      # в «кино» интерфейс не мешает
    _touch.visible = false
    var cam := Camera3D.new()
    cam.fov = 58.0
    cam.far = 900.0
    add_child(cam)
    cam.make_current()
    var p: Vector3 = _player.global_position
    var end_pos: Vector3 = _player._camera.global_position
    var start := p + Vector3(-70.0, 45.0, 55.0)
    if _kazan_train:   # начинаем над поездом
        start = (_kazan_train as Node3D).global_position + Vector3(-40.0, 35.0, 40.0)
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    for top: bool in [true, false]:   # «кино»: чёрные полосы сверху и снизу
        var bar := ColorRect.new()
        bar.color = Color.BLACK
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.anchor_right = 1.0
        if top:
            bar.anchor_bottom = 0.11
        else:
            bar.anchor_top = 0.89
            bar.anchor_bottom = 1.0
        layer.add_child(bar)
    var cap := Label.new()
    cap.text = "КАЗАНЬ. ВОКЗАЛ.\nНовая жизнь начинается здесь."
    cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cap.anchor_right = 1.0
    cap.anchor_top = 0.72
    cap.anchor_bottom = 0.88
    cap.add_theme_font_size_override("font_size", 38)
    cap.add_theme_color_override("font_color", Color(0.96, 0.91, 0.79))
    cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    cap.add_theme_constant_override("outline_size", 8)
    cap.modulate.a = 0.0
    layer.add_child(cap)
    Sfx.play("train_horn", -6.0)
    get_tree().create_timer(1.6).timeout.connect(Sfx.play.bind("station", -4.0))
    var look_at_p := p + Vector3(0, 1.4, 0)
    var fly := func(t: float) -> void:
        var e := t * t * (3.0 - 2.0 * t)
        var mid := start.lerp(end_pos, 0.5) + Vector3(0, 12.0, 0)
        cam.global_position = start.lerp(mid, e).lerp(mid.lerp(end_pos, e), e)
        if cam.global_position.distance_to(look_at_p) > 0.5:
            cam.look_at(look_at_p)
    var tw := create_tween()
    tw.tween_method(fly, 0.0, 1.0, 6.0)
    var tw2 := create_tween()
    tw2.tween_property(cap, "modulate:a", 1.0, 1.2)
    tw2.tween_interval(3.0)
    tw2.tween_property(cap, "modulate:a", 0.0, 1.0)
    tw.finished.connect(func() -> void:
        _player._camera.make_current()
        cam.queue_free()
        layer.queue_free()
        _hud.visible = true
        _touch.visible = true
        _touch.blocked = false
        _show_welcome())


# ---------------------------------------------------------------- окно «Добро пожаловать»

func _show_welcome() -> void:
    if _welcome != null:
        return
    _welcome = WelcomeScript.new()
    _hud.get_parent().add_child(_welcome)
    _touch.blocked = true
    _welcome.start_pressed.connect(_on_welcome.bind(true))
    _welcome.skip_pressed.connect(_on_welcome.bind(false))


const RULES_TEXT := """1. Отыгрывай роль: ты житель города, а не игрок. Без оскорблений, мата в общий чат и политики.
2. Не убивай и не бей без причины (DM), не дави людей машиной (DB).
3. Никаких читов, багов и сторонних программ. Нашёл баг — /report.
4. Милиция, больница и другие фракции работают по уставу. ОПГ — без беспредела в спавне и у мэрии.
5. Не мешай другим работать, не сливай чужие пароли и аккаунты.
6. Слово администратора — последнее. Вопросы и жалобы — /report текст.
Нарушения: предупреждение, мут, кик, бан. Три предупреждения — бан на 3 дня."""


# ---------------------------------------------------------------- события города (с сервера)
# Сервер объявляет находку в какой-то точке; кто первым подойдёт — тот и получит награду (решает сервер).

var _event := {}
var _event_marker: Node3D
var _event_claim_t := 0.0


func _on_city_event(m: Dictionary) -> void:
    var pos := Vector3(float(m.get("x", 0)), float(m.get("y", 0)), float(m.get("z", 0)))
    _event = {"id": int(m.get("id", 0)), "pos": pos, "title": String(m.get("title", "Находка")),
            "until": Time.get_ticks_msec() / 1000.0 + float(m.get("left", 600))}
    if _event_marker == null:
        _event_marker = MarkerScript.new()
        add_child(_event_marker)
    _event_marker.show_at(pos, String(_event["title"]).to_upper(), Color(1.0, 0.8, 0.15))
    _event_marker.visible = true
    var d := _focus().distance_to(pos)
    _hud.chat("СОБЫТИЕ: %s Жёлтая метка на карте." % String(m.get("text", "")), "warn")
    _hud.show_toast("Событие: %s — %s" % [_event["title"], _dist_text(d)], "money")
    Sfx.play("notify")
    if _gps_target == null:
        _set_gps(pos, String(_event["title"]), false)


func _on_city_event_end(m: Dictionary) -> void:
    if _event.is_empty() or int(m.get("id", -1)) != int(_event["id"]):
        return
    if _gps_target != null and _gps_name == String(_event["title"]):
        _clear_gps()
    _event = {}
    if _event_marker:
        _event_marker.visible = false
    var win := String(m.get("win", ""))
    if win == "":
        _hud.chat("Событие «%s» закончилось — никто не успел." % String(m.get("title", "")), "info")
    elif win != Net.nick:
        _hud.chat("%s первым нашёл: «%s»." % [win, String(m.get("title", ""))], "info")


func _event_tick(delta: float) -> void:
    if _event.is_empty():
        return
    if Time.get_ticks_msec() / 1000.0 > float(_event["until"]) + 30.0:   # сервер молчит — убрать метку
        _on_city_event_end({"id": _event["id"], "win": "", "title": _event["title"]})
        return
    _event_claim_t -= delta
    var p: Vector3 = _event["pos"]
    var f := _focus()
    if _event_claim_t <= 0.0 and Vector2(f.x - p.x, f.z - p.z).length() < 4.5:
        _event_claim_t = 2.0
        Net.send_msg({"t": "event_claim", "id": _event["id"]})


# ---------------------------------------------------------------- подсказки новичку
# Каждая показывается один раз в жизни персонажа, когда впервые случается нужная ситуация.

var _hint_t := 5.0
var _hint_last := -100.0


func _hint(id: String, text: String) -> bool:
    if hints_seen.has(id):
        return false
    var now := Time.get_ticks_msec() / 1000.0
    if now - _hint_last < 25.0:   # не засыпать подсказками: не чаще раза в 25 секунд
        return false
    _hint_last = now
    hints_seen[id] = true
    _hud.show_toast("Подсказка: " + text, "news")
    Sfx.play("notify", -8.0)
    return true


func _check_hints() -> void:
    if not _started or _player == null or _dialog.visible or _welcome != null or jail_left > 0.0:
        return
    if level <= 1 and passport_name == "" and quest_active and _hint("passport", "задание Петера показано на карте жёлтой меткой. Иди к мэрии за паспортом."):
        return
    if hunger < 45.0 and _hint("hunger", "сытость падает. Купи еду в ларьке «Пирожки» или в магазине и съешь её из сумки (телефон → Сумка)."):
        return
    if health < 40.0 and _hint("health", "мало здоровья. Поешь или вылечись в больнице — она отмечена в навигаторе."):
        return
    if _driving != null:
        if _hint("drive", "джойстик слева — руль, справа ГАЗ и ТОРМОЗ (держи тормоз — поедешь назад). Фары ночью включаются сами, вручную — кнопкой у спидометра."):
            return
        if _driving.fuel < 12.0 and _hint("fuel", "бензин кончается. Заправка — в навигаторе, раздел «АЗС»."):
            return
    if _night_k > 0.6 and _hint("night", "наступила ночь — время в игре московское, как в жизни. Фонари горят, но в переулках темно."):
        return
    if wanted > 0 and _hint("wanted", "ты в розыске. Милиция может задержать — тогда посидишь в КПЗ. Розыск со временем спадает."):
        return
    if cash >= 5000 and _hint("bank", "крупные суммы держи на карте: банкомат или телефон → Банк."):
        return
    if Net.online:
        if _hint("online", "ты в онлайне. Чат: обычный текст — рядом, /g — всем, /pm ник — личное. Телефон → «Игроки» — кто в городе."):
            return
        if _hint("rp", "это RP-сервер: говори от лица персонажа. /me — действие, /do — описание, /b — OOC (не от персонажа), /help — все команды. Над игроками — их ID для команд."):
            return
        if _net_target >= 0 and _hint("player_btn", "рядом игрок — кнопка «ИГРОК»: передать деньги, попросить паспорт, предложить услугу."):
            return
    if level >= 2 and _hint("level", "новый уровень! Чем выше уровень, тем больше работ, машин и фракций доступно."):
        return


## Правила сервера — один раз, при первом входе в онлайн.
func _maybe_rules() -> void:
    if rules_ok or not Net.online or _welcome != null or _dialog.visible:
        return
    _touch.blocked = true
    _open_dialog("Правила сервера", RULES_TEXT, [["Принимаю", func() -> void:
            rules_ok = true
            _dialog.close()
            _touch.blocked = false
            _save_game()
            _hint("report", "Вопрос или жалоба — напиши /report текст, администрация ответит в ЛС.")],
        ["Выйти в меню", func() -> void:
            _dialog.close()
            _touch.blocked = false
            _open_menu()]])


func _on_welcome(start: bool) -> void:
    welcome_seen = true
    if _welcome:
        _welcome.queue_free()
        _welcome = null
    _touch.blocked = false
    _maybe_rules.call_deferred()
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
    if ITEM_ICONS.has(item):
        return String(ITEM_ICONS[item])
    var low := item.to_lower()
    for pair: Array in [["пирож", "sandwich"], ["ватруш", "sandwich"], ["эклер", "sandwich"], ["беляш", "sandwich"],
            ["чебурек", "sandwich"], ["пряник", "sandwich"], ["чай", "coffee"], ["кофе", "coffee"], ["квас", "bottle"],
            ["кефир", "bottle"], ["молоко", "bottle"], ["айран", "bottle"], ["лимонад", "bottle"], ["пельмен", "dumplings"],
            ["колбас", "dumplings"], ["сало", "dumplings"], ["обед", "dumplings"], ["хлеб", "bread"], ["батон", "bread"],
            ["аптеч", "firstaid"], ["вобла", "fish"], ["лещ", "fish"], ["судак", "fish"], ["сом", "fish"], ["бинт", "bandage"], ["витамин", "vitamins"], ["канистр", "canister"]]:
        if low.contains(String(pair[0])):
            return String(pair[1])
    return "bag"



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
    _touch.weapon_text = String(Weapons.info(weapon_id)["short"]) + (" %d" % ammo if _needs_ammo(weapon_id) else "")
    var menus: bool = _hud.phone_open or _win.visible or _dialog.visible or _hud.profile.is_open() or _fmenu.visible
    var want: bool = _touch.attack_held or (Input.is_key_pressed(KEY_R) and not menus)
    if want and _fire_cd <= 0.0 and not menus:
        _attack()


func _attack() -> void:
    if _injured or _cuffed_by >= 0:
        return
    if _needs_ammo(weapon_id):
        if ammo <= 0:
            _fire_cd = 0.6
            Sfx.play("error", -8.0)
            _hud.show_toast("Нет патронов — возьми в общаке (патроны везут из порта)")
            return
        ammo -= 1
    _attack_n = (_attack_n + 1) % 1000   # другие игроки по этому счётчику слышат удар или выстрел
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
    var rng_k := 1.0 + float(skills["strength"]) / 150.0 if melee else 1.0
    var cone := 35.0 + float(skills["strength"]) * 0.15 if melee else 8.0 + float(skills["shooting"]) * 0.07
    var hit_pos := _peds.hit(origin, dir, float(info["range"]) * rng_k, cone)
    if Net.online and _net_hit(origin, dir, float(info["range"]) * rng_k, cone, melee):
        if hit_pos == Vector3.INF:
            hit_pos = origin + dir
    if not melee:
        skills["shooting"] = minf(100.0, float(skills["shooting"]) + 0.15)
    var lawful: bool = (FactionData.base(faction) == "police" or faction == "kgb") and _duty.active
    if hit_pos != Vector3.INF:
        _hit_fx(hit_pos, melee)
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


## Удар или попадание: короткий всплеск пыли и брызг (одноразовые частицы, удаляются сами).
func _hit_fx(pos: Vector3, melee: bool) -> void:
    var p := CPUParticles3D.new()
    p.one_shot = true
    p.emitting = true
    p.amount = 10 if melee else 14
    p.lifetime = 0.45
    p.explosiveness = 0.95
    p.direction = Vector3.UP
    p.spread = 70.0
    p.initial_velocity_min = 1.0
    p.initial_velocity_max = 2.8
    p.gravity = Vector3(0, -6.0, 0)
    p.scale_amount_min = 0.5
    p.scale_amount_max = 1.0
    var q := QuadMesh.new()
    q.size = Vector2(0.09, 0.09)
    var m := StandardMaterial3D.new()
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(0.55, 0.08, 0.06) if not melee else Color(0.75, 0.7, 0.62)
    q.material = m
    p.mesh = q
    add_child(p)
    var lift := 1.1 if pos.y < _player.global_position.y + 0.5 else 0.0   # точка у ног прохожего — поднимаем к груди
    p.global_position = pos + Vector3(0, lift, 0)
    get_tree().create_timer(1.0).timeout.connect(p.queue_free)


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
var _night_known := false
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
    if not _night_known:     # при входе в игру не пишем «доброе утро» среди дня
        _night_known = true
        _was_night = night_now
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
                _hud.chat("До получки во фракции меньше минуты.", "faction")
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
    if kgb_disguise != "" and FactionData.base(faction) == "kgb":   # маскировка — всегда, пока не снял
        return "" if kgb_disguise == "civil" else kgb_disguise
    var on := FactionData.is_gang(faction) or _duty.active or _interior == faction
    return "%s:%d" % [faction, faction_rank] if on else ""


func _apply_look() -> void:
    if _player == null:
        return
    _player.gear_rank = faction_rank
    _last_uniform = _uniform_key()
    # «Вор в законе» любой ОПГ — свой персонаж (мужчина в пальто и кепке), у остальных — обычный
    var gang_top := FactionData.is_gang(faction) and faction_rank >= FactionData.GANG_SKIN_RANK and not player_female
    var skin := TYAP_SKIN if gang_top else ""
    if _player.set_skin(skin):
        _equip_weapon()
    _player.set_build(Clothes.build(look))
    if skin != "":
        return
    var ufac := _last_uniform.get_slice(":", 0) if _last_uniform.contains(":") else faction
    var urank := int(_last_uniform.get_slice(":", 1)) if _last_uniform.contains(":") else faction_rank
    var u := {} if _last_uniform == "" else FactionData.uniform(ufac, urank)
    # головной убор формы: фуражка, шляпа, «петушок», каска, шапочка...
    if u.is_empty():
        var own_hat: Array = Clothes.hat(look)   # своя шапка из магазина одежды
        _player.set_cap(String(own_hat[0]), own_hat[1])
    else:
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
        style.append("badge:" + FactionData.base(ufac))
    tex["jacket_style"] = ",".join(PackedStringArray(style))
    _player.set_look(cols, tex)



## Питьё или еда — по названию (для анимации: стакан или пирожок в руке).
func _is_drink(item: String) -> bool:
    var low := item.to_lower()
    for w: String in ["чай", "квас", "кефир", "лимонад", "айран", "молоко", "кофе", "газиров", "сок", "вода"]:
        if low.contains(w):
            return true
    return false


## Жесты и позы: машет, звонит, руки вверх, хлопает, отжимается, «присядка», сидит на полу...
const EMOTES := [["wave", "Помахать"], ["handsup", "Руки вверх"], ["phone", "Звонок"], ["arms", "Руки на груди"],
        ["think", "Задуматься"], ["facepalm", "Рука-лицо"], ["point", "Показать"], ["clap", "Хлопать"],
        ["shrug", "Пожать плечами"], ["watch", "На часы"], ["salute", "Отдать честь"], ["rest", "Руки за спину"],
        ["squat", "На корточки"], ["sitfloor", "Сесть на пол"], ["lie", "Лечь"], ["pushup", "Отжиматься"],
        ["dance", "Танец"], ["prisyadka", "Вприсядку"]]


func _open_emotes() -> void:
    var buttons := []
    for e: Array in EMOTES:
        buttons.append([String(e[1]), _do_emote.bind(String(e[0]))])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Жесты", "Пошевели джойстиком — и жест закончится. Другие игроки видят твои жесты.", buttons)


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
    _spawn_faction_staff()
    _spawn_street_life()
    _spawn_city_crowd()
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
        if sit:
            _bench_sitters.append(p[0])
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
            n.female = k == 2   # в каждой группировке есть девушка
            n.hair_color = [Color(0.12, 0.08, 0.06), Color(0.35, 0.25, 0.15), Color(0.2, 0.15, 0.1)][k]
            n.jacket = String(u.get("jacket", "cloth_tracksuit"))
            n.pants = String(u.get("pants", "cloth_tracksuit"))
            n.shoes = String(u.get("shoes", "cloth_sneaker"))
            n.hat = String(u.get("cap", ""))
            n.hat_col = u.get("cap_col", Color(0, 0, 0, 0))
            n.anim = "idle_talking" if k == 1 else ("idle" if n.female else "pose_squat")
            n.name_col = Color(f["color"]).lightened(0.3)
            n.position = out + fwd * 3.0 + side * (-2.2 + k * 2.2)
            var look := (side + fwd).normalized() if k == 0 else ((-side + fwd).normalized() if k == 2 else fwd)
            n.rotation.y = atan2(look.x, look.z)
            add_child(n)


## Жизнь во дворах: бабушки на лавочках, мужики беседуют, пацаны на кортах, кто-то звонит, кто-то отжимается.
## Каждая сценка — у своей лавочки; издалека люди прячутся (npc.gd), в «лёгком» режиме сценок меньше.
const STREET_SCENES := [
    [["sitting_idle", "bench", true], ["sitting_idle", "bench2", true]],                  # бабушки на лавке
    [["idle_talking", "", false], ["pose_arms", "", false]],                              # мужики спорят
    [["pose_squat", "", false], ["pose_squat", "", false], ["pose_phone", "", false]],    # пацаны на кортах
    [["sitting_idle", "bench", false], ["pose_think", "", false]],                        # шахматы во дворе
    [["anim_pushup", "", false], ["anim_clap", "", false]],                               # спорт: один отжимается, другой считает
    [["pose_phone", "", true], ["idle", "", true]],                                        # подружки
]


func _spawn_street_life() -> void:
    if _city.benches.is_empty():
        return
    var lite := bool(_menu.settings.get("lite", false))
    var count := 4 if lite else 10
    var rng := RandomNumberGenerator.new()
    rng.seed = 1984
    var used := {}
    var looks := [["cloth_corduroy", "cloth_trousers_brown"], ["cloth_nylon_blue", "cloth_jeans"], ["cloth_tracksuit", "cloth_tracksuit"],
            ["cloth_wool_gray", "cloth_wool_black"], ["cloth_quilted_navy", "cloth_jersey_gray"], ["cloth_gabardine", "cloth_wool_black"]]
    var made := 0
    var tries := 0
    while made < count and tries < 200:
        tries += 1
        var bi: int = rng.randi() % _city.benches.size()
        var bn: Array = _city.benches[bi]
        var base: Vector3 = bn[0]
        var key := "%d|%d" % [int(base.x / 40.0), int(base.z / 40.0)]
        if used.has(key) or base.x > 1500.0 or absf(base.z) > 1500.0:
            continue
        used[key] = true
        var facing: Vector3 = bn[1]
        var side := Vector3(facing.z, 0, -facing.x)
        var scene: Array = STREET_SCENES[made % STREET_SCENES.size()]
        for k in scene.size():
            var role: Array = scene[k]
            var n = NpcScript.new()
            n.npc_name = ""
            n.mark = false
            n.collide = true
            n.female = bool(role[2])
            n.beard = not n.female and rng.randf() < 0.4
            n.alt_hair = rng.randf() < 0.5
            n.hair_color = [Color(0.12, 0.08, 0.06), Color(0.35, 0.25, 0.15), Color(0.7, 0.68, 0.65)][rng.randi() % 3]
            var lk: Array = looks[rng.randi() % looks.size()]
            n.jacket = String(lk[0])
            n.pants = String(lk[1])
            n.anim = String(role[0])
            if made % STREET_SCENES.size() == 0:   # бабушки на лавке: седые, в платках
                n.hair_color = Color(0.78, 0.77, 0.74)
                n.hat = "platok"
                n.hat_col = [Color(0.62, 0.18, 0.16), Color(0.2, 0.3, 0.55), Color(0.35, 0.45, 0.25)][k % 3]
                n.build = [0.96, 1.0, 1.15, 1.1]
            var pos: Vector3
            var look_dir := facing
            match String(role[1]):
                "bench":
                    pos = base + facing * 0.29 + side * 0.45
                "bench2":
                    pos = base + facing * 0.29 - side * 0.45
                _:
                    # стоят сбоку от лавки кружком (перед лавкой бывает парапет или стена) и смотрят друг на друга
                    var gc := base + side * 2.2 + facing * 0.5
                    var ang := k * TAU / 3.0 + 0.4
                    pos = gc + Vector3(cos(ang), 0, sin(ang)) * 0.8
                    look_dir = (gc - pos).normalized()
            if n.anim == "anim_pushup":
                look_dir = side
            n.position = Vector3(pos.x, base.y, pos.z)
            n.rotation.y = atan2(look_dir.x, look_dir.z)
            add_child(n)
        made += 1


## Городская жизнь: очереди у ларьков, дети во дворах, выпивший у пивного ларька.
func _spawn_city_crowd() -> void:
    var lite := bool(_menu.settings.get("lite", false))
    var rng := RandomNumberGenerator.new()
    rng.seed = 1985
    var looks := [["cloth_corduroy", "cloth_trousers_brown"], ["cloth_wool_gray", "cloth_wool_black"], ["cloth_quilted_navy", "cloth_jersey_gray"],
            ["cloth_gabardine", "cloth_wool_black"], ["cloth_nylon_blue", "cloth_jeans"]]
    var queues := 0
    for pk: Dictionary in _city.pickups:
        if queues >= (2 if lite else 6) or not pk.has("dir"):
            continue
        var nm := String(pk["name"])
        if not nm in ["ПИРОЖКИ", "ПРОДУКТЫ", "ЧЕБУРЕКИ", "КВАС", "ПИВО", "СЕЛЬПО", "КОФЕ"]:
            continue
        queues += 1
        var dir: Vector3 = pk["dir"]
        var side := Vector3(dir.z, 0, -dir.x)
        var base: Vector3 = pk["pos"]
        var drunk_done := false
        for k in rng.randi_range(2, 4):   # очередь сбоку от окошка, чтобы игроку было куда подойти
            var n = NpcScript.new()
            n.npc_name = ""
            n.mark = false
            n.collide = false
            n.female = rng.randf() < 0.55
            n.beard = not n.female and rng.randf() < 0.3
            var lk: Array = looks[rng.randi() % looks.size()]
            n.jacket = String(lk[0])
            n.pants = String(lk[1])
            n.hair_color = [Color(0.12, 0.08, 0.06), Color(0.35, 0.25, 0.15), Color(0.75, 0.74, 0.72)][rng.randi() % 3]
            if n.female and rng.randf() < 0.4:
                n.hat = "platok"
            n.anim = ["idle", "anim_watch", "idle_talking", "pose_arms"][rng.randi() % 4]
            var pos := base + side * 1.4 + dir * (0.3 + 0.85 * k)
            n.position = Vector3(pos.x, base.y, pos.z)
            var look := (-dir - side * 0.25).normalized()
            n.rotation.y = atan2(look.x, look.z)
            add_child(n)
        if nm == "ПИВО" and not drunk_done:   # выпивший сидит у ларька
            var d = NpcScript.new()
            d.npc_name = ""
            d.mark = false
            d.collide = true
            d.beard = true
            d.jacket = "cloth_quilted_navy"
            d.pants = "cloth_jersey_gray"
            d.hat = "kepka"
            d.anim = "pose_sitfloor"
            var dp := base - side * 2.6 + dir * 0.8
            d.position = Vector3(dp.x, base.y, dp.z)
            d.rotation.y = atan2(side.x, side.z)
            add_child(d)
    # дети во дворах: играют у лавок (ниже ростом, лёгкая комплекция)
    var kids := 0
    var used := {}
    for bn: Array in _city.benches:
        if kids >= (2 if lite else 6):
            break
        var bp: Vector3 = bn[0]
        var key := "%d|%d" % [int(bp.x / 120.0), int(bp.z / 120.0)]
        if used.has(key) or rng.randf() < 0.6 or bp.x > 1500.0 or absf(bp.z) > 1500.0:
            continue
        used[key] = true
        kids += 1
        var facing: Vector3 = bn[1]
        var c := bp - facing * 3.0
        for k in 3:
            var n = NpcScript.new()
            n.npc_name = ""
            n.mark = false
            n.collide = true
            n.female = k == 1
            n.beard = false
            n.jacket = ["ts_red", "ts_blue", "cloth_nylon_blue"][k]
            n.pants = ["cloth_tracksuit", "cloth_jeans", "cloth_jeans"][k]
            n.hair_color = [Color(0.45, 0.32, 0.18), Color(0.85, 0.7, 0.4), Color(0.2, 0.14, 0.1)][k]
            n.anim = ["anim_clap", "anim_wave", "anim_prisyadka"][k]
            n.build = [0.68, 0.86, 0.85, 0.88]
            n.name_y = 1.5
            var a := k * TAU / 3.0
            var pos := c + Vector3(cos(a), 0, sin(a)) * 1.0
            n.position = Vector3(pos.x, bp.y, pos.z)
            var look := (c - pos).normalized()
            n.rotation.y = atan2(look.x, look.z)
            add_child(n)


## У зданий госорганизаций дежурят сотрудники в форме: мужчина и женщина (женская форма — outfit_f_*).
func _spawn_faction_staff() -> void:
    for f: Dictionary in FactionData.LIST:
        if String(f.get("type", "")) == "gang" or not _city.faction_sites.has(f["id"]):
            continue
        var site: Dictionary = _city.faction_sites[f["id"]]
        if not site.has("out"):
            continue
        var out: Vector3 = site["out"]
        var yaw: float = float(site.get("out_yaw", 0.0))
        var fwd := -(Basis(Vector3.UP, yaw) * Vector3(0, 0, 1))
        var side := Vector3(fwd.z, 0, -fwd.x)
        for k in 2:
            var u: Dictionary = FactionData.uniform(f["id"], [3, 1][k])
            var n = NpcScript.new()
            n.rank = [3, 1][k]
            n.npc_name = ""
            n.mark = false
            n.collide = true
            n.beard = false
            n.female = k == 1
            n.hair_color = [Color(0.15, 0.1, 0.07), Color(0.32, 0.2, 0.12)][k]
            n.jacket = String(u.get("jacket", "cloth_suit_gray"))
            n.pants = String(u.get("pants", "cloth_suit_gray"))
            n.shoes = String(u.get("shoes", "cloth_leather_black"))
            n.short_sleeves = u.get("short", false) == true
            n.hat = String(u.get("cap", ""))
            n.hat_col = u.get("cap_col", Color(0, 0, 0, 0))
            n.anim = "idle_talking" if k == 0 else "idle"
            n.position = out + fwd * 2.5 + side * (3.2 if k == 0 else 4.4)
            var look := (-side + fwd * 0.4).normalized() if k == 0 else (side + fwd * 0.4).normalized()
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



# ================================================================ мебель в квартире

const FURNITURE := [
    {"id": "servant", "name": "Сервант «Хельга»", "price": 9000, "about": "полированный, со стеклом — посуда и хрусталь на виду"},
    {"id": "radiola", "name": "Радиола «Ригонда»", "price": 6000, "about": "играет все радиостанции, пока ты дома"},
    {"id": "armchair", "name": "Кресло с пледом", "price": 3000, "about": "бабушкин плед в цветочек"},
    {"id": "desk", "name": "Письменный столик", "price": 1500, "about": "для домашних дел и писем"},
    {"id": "chair", "name": "Мягкий стул", "price": 800, "about": "к письменному столику"},
    {"id": "tumba", "name": "Тумбочка", "price": 1200, "about": "у дивана, для мелочей"},
]


## Купленная мебель видна (и твёрдая) в комнатах жилья.
func _apply_furniture() -> void:
    for kind: String in _city.home_interiors:
        var hi: Dictionary = _city.home_interiors[kind]
        if not hi.has("furn"):
            continue
        for id: String in hi["furn"]:
            var n: Node3D = hi["furn"][id]
            var on := furniture.has(id)
            n.visible = on
            var body: StaticBody3D = n.get_meta("body")
            body.collision_layer = 1 if on else 0


func _open_furniture() -> void:
    var text := "Мебельный каталог «Уют». Доставка и сборка — сразу.\n"
    var buttons := []
    for f: Dictionary in FURNITURE:
        var id := String(f["id"])
        if furniture.has(id):
            text += "\n[+] %s — уже стоит" % f["name"]
        else:
            text += "\n- %s — %s (%s)" % [f["name"], HudScript.format_money(int(f["price"])), f["about"]]
            buttons.append(["%s · %s" % [f["name"], HudScript.format_money(int(f["price"]))], _buy_furniture.bind(id)])
    if buttons.is_empty():
        text += "\n\nКвартира обставлена полностью!"
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Мебель", text, buttons)


func _buy_furniture(id: String) -> void:
    var f := {}
    for x: Dictionary in FURNITURE:
        if String(x["id"]) == id:
            f = x
    if f.is_empty() or furniture.has(id):
        return
    if not _pay(int(f["price"]), "Мебель: " + String(f["name"])):
        return
    furniture.append(id)
    _apply_furniture()
    _add_xp(5)
    Sfx.play("cash")
    _hud.show_toast("Привезли и собрали: %s" % f["name"])
    _save_game()
    _open_furniture()


func _use_radiola() -> void:
    if not furniture.has("radiola"):
        _hud.show_toast("Радиолы нет — купи «Ригонду» в каталоге «Мебель»")
        return
    Sfx.play("radio_tune", -6.0)
    _hud.show_toast(Music.home_next())


# ================================================================ трамвай

const TRAM_FARE := 5


func _tram_board(i: int) -> void:
    if _tram == null or _tram_ride != null:
        return
    var c = _tram.car_at_stop(i)
    if c == null:
        _tram_wait = i
        _hud.show_toast("Трамвай №1 придёт примерно через %d с — жди на остановке, сядешь сам" % int(_tram.eta(i)))
        return
    _tram_enter(c)


func _tram_enter(c: Dictionary) -> void:
    if not _player.can_sit("sit"):
        return
    if not _pay(TRAM_FARE, "Проезд в трамвае"):
        return
    _tram_wait = -1
    _tram.hold(c, 2.0)
    var body: Node3D = c["body"]
    var bt: Transform3D = body.global_transform
    var seat: Vector3 = bt * Vector3(0.75, 0.9, randf_range(-3.5, 3.5))
    if not _player.sit_at(seat, -bt.basis.x):
        return
    _tram_seat = bt.affine_inverse() * _player.global_transform
    _tram_ride = c
    stats["tram"] = int(stats["tram"]) + 1
    Sfx.play("coin", -4.0)
    _hud.show_toast("Проезд %d ₽. Едем! Выйти — джойстиком на остановке" % TRAM_FARE)


func _update_tram() -> void:
    if _tram_ride != null:
        var body: Node3D = _tram_ride["body"]
        if _player.seated == "sit":
            _player.global_transform = body.global_transform * _tram_seat
            return
        if float(_tram_ride["speed"]) > 1.0:
            # на ходу не выпрыгиваем — садимся обратно
            _player.sit_at(body.global_transform * _tram_seat.origin, -body.global_transform.basis.x)
            _player.global_transform = body.global_transform * _tram_seat
            _hud.show_toast("На ходу не выходят — дождись остановки")
            return
        var best: Vector3 = body.global_position
        var bd := INF
        for st: Dictionary in _tram.stops:
            var sp: Vector3 = st["sign"]
            var dd := sp.distance_to(body.global_position)
            if dd < bd:
                bd = dd
                best = sp
        _player.global_position = best + Vector3(0, 0.3, 0)
        _player.velocity = Vector3.ZERO
        _tram_ride = null
        return
    if _tram_wait >= 0:
        var st: Dictionary = _tram.stops[_tram_wait]
        var sp: Vector3 = st["sign"]
        if _player.global_position.distance_to(sp) > 16.0 or _driving != null:
            _tram_wait = -1
            return
        var c = _tram.car_at_stop(_tram_wait)
        if c != null:
            _tram_enter(c)


# ================================================================ ограбления (только ОПГ)

const ROB := {
    "kiosk": {"rank": 1, "time": 8.0, "min": 500, "max": 1200, "wanted": 1, "xp": 10, "r": 5.0, "gun": false},
    "atm": {"rank": 2, "time": 15.0, "min": 2000, "max": 4000, "wanted": 2, "xp": 20, "r": 4.0, "gun": false},
    "store": {"rank": 3, "time": 25.0, "min": 7000, "max": 14000, "wanted": 3, "xp": 40, "r": 9.0, "gun": true},
}
const ROB_COOLDOWN := 360.0    # игровых минут до следующего налёта на ту же цель


func _setup_rob_points() -> void:
    var k := 0
    for pk: Dictionary in _city.pickups:
        var nm := String(pk["name"])
        var tier := "store" if nm == "УНИВЕРСАМ" else "kiosk"
        var pos: Vector3 = pk["pos"]
        _points.append({"pos": pos + Vector3(0.0, 0, 0.0), "r": 1.6, "text": "ОГРАБИТЬ", "cb": _start_rob.bind("p%d" % k, tier, pos, nm),
                "car": false, "gang_only": true})
        k += 1
    k = 0
    for ap: Vector3 in _city.atms:
        _points.append({"pos": ap, "r": 1.2, "text": "ВСКРЫТЬ", "cb": _start_rob.bind("a%d" % k, "atm", ap, "банкомат"),
                "car": false, "gang_only": true})
        k += 1


## Часы для перезарядок (холодильник, ограбления): 1 единица = 1 реальная секунда,
## как было при «1 игровая минута = 1 секунда», — темп игры не изменился от перехода на московское время.
func _now_min() -> float:
    return Time.get_unix_time_from_system()


func _start_rob(key: String, tier: String, pos: Vector3, nm: String) -> void:
    if not FactionData.is_gang(faction) or not _rob.is_empty():
        return
    var t: Dictionary = ROB[tier]
    if _loot > 0:
        _hud.show_toast("Сначала отнеси добычу в общак")
        return
    if faction_rank < int(t["rank"]):
        Sfx.play("error")
        _hud.show_toast("Рано тебе на такое дело — нужен ранг %s" % FactionData.rank_name(int(t["rank"]), faction))
        return
    if bool(t["gun"]) and Weapons.is_melee(weapon_id):
        Sfx.play("error")
        _hud.show_toast("С кулаками кассу не возьмёшь — нужен ствол")
        return
    if _now_min() < float(_rob_cd.get(key, -1.0)):
        _hud.show_toast("Тут недавно уже побывали — сейчас пусто и милиция рядом. Позже")
        return
    _rob = {"key": key, "tier": tier, "left": float(t["time"]), "pos": pos, "name": nm.to_lower() if nm.length() > 3 else nm}
    Sfx.play("whistle" if tier != "kiosk" else "notify", -8.0)
    _hud.show_toast("Налёт начался! Продержись %d с рядом с целью" % int(t["time"]))
    if _peds:
        _peds.scare(pos, 22.0)
    if tier != "kiosk":
        _add_wanted(int(t["wanted"]), "ограбление")


func _update_rob(delta: float, focus: Vector3) -> void:
    if _rob.is_empty():
        if _loot > 0 and FactionData.is_gang(faction) and _city.faction_sites.has(faction):
            var base: Vector3 = _city.faction_sites[faction]["out"]
            if focus.distance_to(base) < 5.0 and _driving == null:
                _deliver_loot()
        return
    var t: Dictionary = ROB[String(_rob["tier"])]
    var pos: Vector3 = _rob["pos"]
    if focus.distance_to(pos) > float(t["r"]) or _driving != null or jail_left > 0.0:
        _rob = {}
        Sfx.play("error")
        _hud.show_toast("Налёт сорван: ты ушёл с места")
        return
    _rob["left"] = float(_rob["left"]) - delta
    if float(_rob["left"]) > 0.0:
        return
    var tier := String(_rob["tier"])
    _rob_cd[String(_rob["key"])] = _now_min() + ROB_COOLDOWN
    _loot = randi_range(int(t["min"]), int(t["max"]))
    _rob = {}
    Sfx.play("cash")
    if tier == "kiosk" and randf() < 0.6:
        _add_wanted(1, "ограбление ларька")
    var where := "базу"
    if _city.faction_sites.has(faction):
        _set_gps(_city.faction_sites[faction]["out"], "Общак: база " + _faction_name(), true)
    _hud.show_toast("Взяли %s! Неси в общак на %s" % [HudScript.format_money(_loot), where])
    _add_xp(int(t["xp"]))


func _deliver_loot() -> void:
    var share := _loot * 7 / 10
    cash += share
    _earned("crime", share)
    faction_exp += 1
    Sfx.play("levelup")
    _hud.show_toast("Общак принял добычу: тебе %s, братве %s. +1 стаж" % [HudScript.format_money(share),
            HudScript.format_money(_loot - share)])
    _sms_add(_faction_name(), "Красиво сработал. Твоя доля — %s." % HudScript.format_money(share))
    _loot = 0
    stats["rob"] = int(stats["rob"]) + 1
    _clear_gps()
    _save_game()


func _lose_loot(text: String) -> void:
    _rob = {}
    if _loot > 0:
        _loot = 0
        _hud.show_toast(text)



# ================================================================ состав организации (пока игра без сервера — NPC)

const ORG_FIRST := ["Vlad", "Artem", "Dima", "Kirill", "Sergey", "Andrey", "Oleg", "Igor", "Pavel", "Roma", "Maks",
        "Denis", "Ruslan", "Timur", "Marat", "Ilya", "Zhenya", "Kostya", "Anton", "Vova", "Rinat", "Ayrat"]
const ORG_LAST := ["Minskiy", "Sokolov", "Petrov", "Ivanov", "Volkov", "Kuznetsov", "Smirnov", "Popov", "Lebedev",
        "Kozlov", "Novikov", "Morozov", "Galiev", "Safin", "Khabibullin", "Zaytsev", "Orlov", "Belov", "Frolov",
        "Nikitin", "Gareev", "Valiev"]
const ORG_CAP := 50


## Лидер, рейтинг, дата создания и список состава. Состав — постоянные NPC
## (одни и те же для организации), онлайн меняется каждый игровой час.
func _org_info() -> Dictionary:
    if Net.authed and _net_roster.get("fid", "") == faction and faction != "":
        return _org_info_online()
    var sd := absi(hash(faction))
    var rng := RandomNumberGenerator.new()
    rng.seed = sd
    var top := FactionData.ranks(faction).size()
    var me_nick := passport_name if passport_name != "" else "Без_Имени"
    var count := 12 + sd % 26
    var roster: Array = []
    var used := {}
    for k in count:
        var nm := ""
        while nm == "" or used.has(nm):
            nm = "%s_%s" % [ORG_FIRST[rng.randi() % ORG_FIRST.size()], ORG_LAST[rng.randi() % ORG_LAST.size()]]
        used[nm] = true
        var rk := top if k == 0 else (top - 1 if k < 3 else 1 + rng.randi() % maxi(1, top - 2))
        roster.append({"name": nm, "rank": rk})
    # игрок-лидер занимает место NPC-лидера
    if faction_rank >= top:
        roster.remove_at(0)
    roster.append({"name": me_nick, "rank": faction_rank, "me": true})
    var hour := int(day * 24 + minutes / 60.0)
    var online := 0
    for m: Dictionary in roster:
        var on := bool(m.get("me", false)) or (absi(hash(String(m["name"]) + str(hour))) % 3 == 0)
        m["online"] = on
        if on:
            online += 1
        var rk := int(m["rank"])
        m["role"] = "Лидер" if rk >= top else ("Заместитель" if rk == top - 1 else FactionData.rank_name(rk, faction))
    roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a["rank"]) != int(b["rank"]):
            return int(a["rank"]) > int(b["rank"])
        return bool(a.get("me", false)) and not bool(b.get("me", false)))
    var leader := ""
    for m: Dictionary in roster:
        if String(m["role"]) == "Лидер":
            leader = String(m["name"])
            break
    var rating := 5000 + sd % 7000 + faction_exp * 37 + (_turf_count(faction) * 800 if FactionData.is_gang(faction) else 0)
    var created := "%02d.%02d.%d" % [1 + sd % 28, 1 + (sd / 28) % 12, 1971 + (sd / 336) % 15]
    return {"roster": roster, "members": roster.size(), "online": online, "cap": ORG_CAP, "leader": leader,
            "rating": HudScript.format_money(rating).replace(" ₽", "").replace("₽", "").strip_edges(), "created": created}



# ================================================================ часть 1: угон, качалка, навыки, достижения

const STEAL_MODELS := [["vaz2106", "ВАЗ-2106", 3500], ["vaz2108", "ВАЗ-2108 «Восьмёрку»", 4500], ["moskvich", "«Москвич-412»", 3000],
        ["vaz2101", "«Копейку»", 2500], ["uaz469", "УАЗ-469", 5000], ["volga", "«Волгу»", 7000], ["niva", "«Ниву»", 4000]]
const STEAL_COLORS := [["вишнёвую", Color(0.45, 0.06, 0.10)], ["белую", Color(0.92, 0.92, 0.90)], ["синюю", Color(0.15, 0.22, 0.45)],
        ["зелёную", Color(0.12, 0.30, 0.22)], ["чёрную", Color(0.08, 0.08, 0.09)]]


func _update_part1(delta: float, focus: Vector3) -> void:
    _steal_cd = maxf(0.0, _steal_cd - delta)
    # навык вождения — от пройденных километров
    if _driving != null and _driving != _rent_scooter:
        var v: float = (_driving as RigidBody3D).linear_velocity.length()
        stats["drive_m"] = float(stats["drive_m"]) + v * delta
        skills["driving"] = minf(100.0, float(stats["drive_m"]) / 1000.0)
    # подход на турнике
    if _train_t > 0.0:
        _train_t -= delta
        var me := _focus()
        var moved := Vector2(me.x - _train_pos.x, me.z - _train_pos.z).length()
        if moved > 1.2 or _driving != null:
            _train_t = 0.0
            _hud.show_toast("Подход сорван")
        elif _train_t <= 0.0:
            var gain := maxf(0.5, 3.0 - float(skills["strength"]) * 0.025)
            skills["strength"] = minf(100.0, float(skills["strength"]) + gain)
            stats["workouts"] = int(stats["workouts"]) + 1
            hunger = maxf(0.0, hunger - 4.0)
            Sfx.play("levelup", -8.0)
            _hud.show_toast("Сила +%.1f (теперь %d/100). Удар дальше и точнее" % [gain, int(skills["strength"])])
    # сдать угнанную машину в гараж
    if _steal_car != null and _driving == _steal_car and _city.faction_sites.has(faction):
        var mk: Vector3 = _city.faction_sites[faction]["marker"]
        if Vector2(focus.x - mk.x, focus.z - mk.z).length() < 8.0:
            _deliver_stolen()
    # достижения — раз в 2 с
    _ach_t -= delta
    if _ach_t <= 0.0:
        _ach_t = 2.0
        _check_achievements()


func _workout() -> void:
    if _train_t > 0.0:
        return
    if hunger < 15.0:
        _hud.show_toast("Голодный не накачаешься — сначала поешь")
        return
    _train_t = 6.0
    _train_pos = _focus()
    _player.play_emote("squat")
    _hud.show_toast("Качаешься: приседания и турник — не двигайся 6 секунд")


func _steal_menu(gid: String) -> void:
    if not FactionData.is_gang(faction) or gid != faction:
        _hud.show_toast("Это не ваш гараж")
        return
    if not _steal_order.is_empty():
        _open_dialog("Заказ на угон", "Заказ уже есть: %s.\nМашина отмечена на карте." % _steal_order["name"],
                [["Отменить заказ", _cancel_steal], ["Закрыть", _dialog.close]])
        return
    if _steal_cd > 0.0:
        _hud.show_toast("Барыга пока ничего не заказывал — загляни через %d с" % int(_steal_cd))
        return
    var m: Array = STEAL_MODELS[randi() % STEAL_MODELS.size()]
    var c: Array = STEAL_COLORS[randi() % STEAL_COLORS.size()]
    var pay := int(m[2]) + randi_range(0, 1000)
    _open_dialog("Барыга", "Нужна %s %s. Стоит где-то в Казани у обочины.\nПригонишь в этот гараж целой — %s.\n\nОсторожно: может сработать сигнализация, тогда приедет милиция." % [
            c[0], m[1], HudScript.format_money(pay)],
            [["Берусь", _take_steal.bind(String(m[0]), "%s %s" % [c[0], m[1]], c[1], pay)], ["Не сейчас", _dialog.close]])


func _take_steal(model: String, nm: String, col: Color, pay: int) -> void:
    _dialog.close()
    # обочина случайного проспекта Казани: в середине квартала, у бордюра
    var lines := [-301.0, -215.0, -129.0, -43.0, 43.0, 129.0, 215.0, 301.0]
    var pos := Vector3.ZERO
    var yaw := 0.0
    for attempt in 20:
        var axis_x := randf() < 0.5
        var l: float = lines[randi() % lines.size()]
        var t := float(randi_range(-3, 3)) * CityBuilder.PITCH
        var side := 1.0 if randf() < 0.5 else -1.0
        pos = Vector3(l + side * 5.8, 0.6, t) if axis_x else Vector3(t, 0.6, l + side * 5.8)
        yaw = 0.0 if axis_x else PI * 0.5
        if pos.distance_to(_focus()) > 90.0:
            break
    var v = CarScene.instantiate()
    v.model_id = model
    v.paint = col
    v.car_name = nm
    v.owned = false
    v.position = pos
    v.rotation.y = yaw
    add_child(v)
    v.touch = _touch
    _traffic.obstacles.append(v)
    _steal_car = v
    _steal_order = {"model": model, "name": nm, "pay": pay, "taken": false}
    _set_gps(pos, "Угнать: " + nm, true)
    _hud.show_toast("Машина отмечена на карте. Подойди и садись")


func _cancel_steal() -> void:
    _dialog.close()
    _clear_steal()
    _hud.show_toast("Заказ отменён")


func _clear_steal() -> void:
    if _steal_car != null:
        if _driving == _steal_car:
            _toggle_vehicle()
        _traffic.obstacles.erase(_steal_car)
        _steal_car.queue_free()
    _steal_car = null
    _steal_order = {}
    _steal_cd = 60.0


func _deliver_stolen() -> void:
    var pay := int(_steal_order["pay"])
    var dmg_k := clampf(float(_steal_car.condition) / 100.0, 0.3, 1.0)
    pay = int(pay * dmg_k)
    _toggle_vehicle()
    cash += pay
    _earned("crime", pay)
    faction_exp += 1
    stats["steal"] = int(stats["steal"]) + 1
    _add_xp(25)
    Sfx.play("levelup")
    _hud.show_toast("Барыга забрал тачку: +%s, +1 стаж" % HudScript.format_money(pay))
    _clear_gps()
    _clear_steal()
    _steal_cd = 120.0
    _save_game()


func _open_skills() -> void:
    var text := ""
    var info := [["strength", "Сила", "качайся на турниках во дворах — удар дальше и точнее"],
            ["driving", "Вождение", "растёт от километров за рулём — машина тянет сильнее (до +20%)"],
            ["shooting", "Стрельба", "растёт от выстрелов — легче попасть"]]
    for it: Array in info:
        var v := int(skills[it[0]])
        var bar := ""
        for k in 10:
            bar += "■" if k < v / 10 else "□"
        text += "%s: %d/100\n%s\n%s\n\n" % [it[1], v, bar, it[2]]
    text += "Пройдено за рулём: %.1f км" % (float(stats["drive_m"]) / 1000.0)
    _open_dialog("Навыки", text, [["Закрыть", _dialog.close]])


const ACHIEVEMENTS := [
    ["car", "Первая машина", "купить машину", 1000],
    ["home", "Новосёл", "купить жильё", 2000],
    ["faction", "В деле", "вступить во фракцию или ОПГ", 500],
    ["rank5", "Начальство", "дорасти до 5 ранга", 5000],
    ["rich", "Зажиточный", "накопить 100 000 ₽", 3000],
    ["million", "Подпольный миллионер", "накопить 1 000 000 ₽", 25000],
    ["rob", "Налётчик", "сдать добычу в общак", 1500],
    ["steal", "Угонщик", "пригнать машину под заказ", 1500],
    ["steal5", "Профессионал", "пригнать 5 машин под заказ", 6000],
    ["turf", "Взял район", "захватить квартал", 2000],
    ["strong", "Качок", "сила 50", 2500],
    ["driver", "Водила", "проехать 50 км", 2500],
    ["sniper", "Ворошиловский стрелок", "стрельба 50", 2500],
    ["tram", "Зайцем не ездим", "проехать на трамвае", 300],
    ["furniture", "Уютное гнёздышко", "купить всю мебель", 3000],
    ["quests", "Свой в городе", "пройти все задания Петера", 5000],
    ["fish", "Рыбак", "поймать 10 рыб", 1000],
    ["cinema", "Киноман", "досмотреть фильм в ДК", 500],
    ["dance", "Король танцпола", "10 раз зажечь на дискотеке", 1500],
    ["metro", "Подземка", "проехать на метро", 300],
    ["race", "Ночной гонщик", "выиграть ночную гонку", 3000],
    ["drift", "Дрифт-король", "набрать 5 000 очков в дрифте", 3000],
]


func _ach_done(id: String) -> bool:
    match id:
        "car":
            return _has_owned_car()
        "home":
            return home >= 0
        "faction":
            return faction != ""
        "rank5":
            return faction != "" and faction_rank >= 5
        "rich":
            return cash + bank >= 100000
        "million":
            return cash + bank >= 1000000
        "rob":
            return int(stats["rob"]) >= 1
        "steal":
            return int(stats["steal"]) >= 1
        "steal5":
            return int(stats["steal"]) >= 5
        "turf":
            return int(stats["turf"]) >= 1
        "strong":
            return float(skills["strength"]) >= 50.0
        "driver":
            return float(stats["drive_m"]) >= 50000.0
        "sniper":
            return float(skills["shooting"]) >= 50.0
        "tram":
            return int(stats["tram"]) >= 1
        "furniture":
            return furniture.size() >= FURNITURE.size()
        "quests":
            return quest_i >= QUESTS.size()
        "fish", "cinema", "dance", "metro", "race":
            var need := {"fish": 10, "cinema": 1, "dance": 10, "metro": 1, "race": 1}
            return int(stats.get(id, 0)) >= int(need[id])
        "drift":
            return int(stats.get("drift_best", 0)) >= 5000
    return false


func _check_achievements() -> void:
    if not _started:
        return
    for a: Array in ACHIEVEMENTS:
        var id := String(a[0])
        if achievements.has(id) or not _ach_done(id):
            continue
        achievements.append(id)
        cash += int(a[3])
        _earned("reward", int(a[3]))
        Sfx.play("levelup")
        _hud.show_toast("Достижение «%s»! +%s" % [a[1], HudScript.format_money(int(a[3]))])
        _sms_add("Достижения", "«%s» — %s. Награда %s." % [a[1], a[2], HudScript.format_money(int(a[3]))])
        _save_game()
        return   # по одному за раз


func _open_achievements() -> void:
    var text := "Открыто %d из %d\n" % [achievements.size(), ACHIEVEMENTS.size()]
    for a: Array in ACHIEVEMENTS:
        var ok := achievements.has(String(a[0]))
        text += "\n%s %s — %s (%s)" % ["[+]" if ok else "[  ]", a[1], a[2], HudScript.format_money(int(a[3]))]
    _open_dialog("Достижения", text, [["Закрыть", _dialog.close]])



# ================================================================ часть 2: такси, рыбалка, напёрстки и «очко», суд

const FISH_PRICES := {"Вобла": 80, "Лещ": 200, "Судак": 450, "Сом": 1200}
const ROD_PRICE := 500
var _fish_spots: Array[Vector3] = []


func _setup_part2_points() -> void:
    # таксопарк — у автобусного парка
    _add_point(_city.bus_depot + Vector3(9.0, 0, 0), 3.0, "ТАКСОПАРК", _open_taxi_park, false, Color(1.0, 0.85, 0.1))
    # рыбалка — на набережных у парапета
    var cand: Array[Vector3] = []
    var kz: Rect2 = CityBuilder.ISLAND_KAZAN
    var py: Rect2 = CityBuilder.ISLAND_PYAT
    for x: float in [-400.0, -250.0, -100.0, 150.0, 300.0]:
        cand.append(Vector3(x, 0, kz.end.y - 2.2))
    for x: float in [-300.0, 320.0]:
        cand.append(Vector3(x, 0, kz.position.y + 2.2))
    for x: float in [-1300.0, -1150.0, -1000.0]:
        cand.append(Vector3(x, 0, py.end.y - 2.2))
    for p: Vector3 in cand:
        if CityBuilder.on_land(p):
            _fish_spots.append(p)
            _add_point(p, 2.2, "РЫБАЧИТЬ", _fish_start.bind(p), false, Color(0.3, 0.7, 1.0))
    # рынок Пятигорска: скупка рыбы, напёрстки, «очко»
    if _city.market != Vector3.ZERO:
        var mk: Vector3 = _city.market
        _add_point(mk + Vector3(6.0, 0, 3.0), 1.8, "СКУПКА РЫБЫ", _sell_fish, false, Color(0.3, 0.7, 1.0), false)
        _add_point(mk + Vector3(-6.0, 0, 3.5), 1.8, "НАПЁРСТКИ", _thimbles_menu, false, Color(0.9, 0.3, 0.3))
        _add_point(mk + Vector3(-9.5, 0, 3.5), 1.8, "«ОЧКО»", _cards_menu, false, Color(0.9, 0.3, 0.3), false)
        for k in 2:
            var n = NpcScript.new()
            n.npc_name = "НАПЁРСТОЧНИК" if k == 0 else "КАТАЛА"
            n.jacket = "cloth_leather2" if k == 0 else "ts_black"
            n.pants = "cloth_acidwash" if k == 0 else "ts_black"
            n.hat = "kepka"
            n.anim = "idle"
            n.mark = false
            n.position = mk + Vector3(-6.0 - k * 3.5, 0, 5.0)
            n.rotation.y = PI
            add_child(n)
            var tb := StaticBody3D.new()
            tb.position = mk + Vector3(-6.0 - k * 3.5, 0, 4.2)
            var mi := MeshInstance3D.new()
            var bm := BoxMesh.new()
            bm.size = Vector3(0.9, 0.75, 0.6)
            mi.mesh = bm
            mi.position.y = 0.375
            var mm := StandardMaterial3D.new()
            mm.albedo_color = Color(0.35, 0.25, 0.15)
            mi.material_override = mm
            tb.add_child(mi)
            var cs := CollisionShape3D.new()
            var bs := BoxShape3D.new()
            bs.size = bm.size
            cs.shape = bs
            cs.position.y = 0.375
            tb.add_child(cs)
            add_child(tb)
    # колония: работа на швейке
    if _city.kpz_cell != Vector3.ZERO:
        _add_point(_city.kpz_cell + Vector3(0, 0, 0.8), 1.6, "РАБОТАТЬ", _jail_work, false, Color.WHITE, false)


func _update_part2(delta: float) -> void:
    _court_work_cd = maxf(0.0, _court_work_cd - delta)
    if _fish_t > 0.0:
        _fish_t -= delta
        var me := _focus()
        if Vector2(me.x - _fish_pos.x, me.z - _fish_pos.z).length() > 1.5 or _driving != null:
            _fish_t = 0.0
            _hud.show_toast("Ушёл — рыба сорвалась")
        elif _fish_t <= 0.0:
            _fish_catch()


# --- такси на «Волге»

func _open_taxi_park() -> void:
    if _job.active and _job.kind == "taxi" and _work_vehicle != null:
        _open_dialog("Таксопарк", "Смена идёт. Сдать «Волгу» и закончить?", [["Сдать машину", _taxi_park_end], ["Закрыть", _dialog.close]])
        return
    _open_dialog("Таксопарк", "Бери жёлтую «Волгу» и вози пассажиров по вызовам.\nДовёз аккуратно, без ДТП — пассажир оставит чаевые (+30%).\nНужны права категории B.",
            [["Взять «Волгу» и начать смену", _taxi_park_start], ["Закрыть", _dialog.close]])


func _taxi_park_start() -> void:
    _dialog.close()
    if not _check_docs(true):
        return
    _work.stop()
    var at := Transform3D(Basis(), _city.bus_depot + Vector3(14.0, 0.7, 0))
    _on_work_vehicle_needed("taxi_volga", at)
    _taxi_cond = 100.0
    _job.start("taxi", _focus())


func _taxi_park_end() -> void:
    _dialog.close()
    _job.stop()
    _on_work_vehicle_done()
    _hud.show_toast("Смена в таксопарке закончена")


# --- рыбалка

func _fish_start(p: Vector3) -> void:
    if _fish_t > 0.0:
        return
    if not has_rod:
        _open_dialog("Рыбалка", "Нужна удочка. Купить бамбуковую удочку с мормышкой?", [["Купить — %s" % HudScript.format_money(ROD_PRICE), _buy_rod.bind(p)], ["Закрыть", _dialog.close]])
        return
    if _bag_count() >= BAG_SIZE:
        _hud.show_toast("Сумка полная — некуда класть улов")
        return
    _fish_t = randf_range(7.0, 12.0)
    _fish_pos = _focus()
    _player.play_emote("squat")
    Sfx.play("click")
    _hud.show_toast("Закинул удочку… ждём клёва, не уходи")


func _buy_rod(p: Vector3) -> void:
    if not _pay(ROD_PRICE, "Удочка"):
        return
    has_rod = true
    _dialog.close()
    Sfx.play("cash")
    _fish_start(p)


func _fish_catch() -> void:
    var r := randf()
    var fish := ""
    if r < 0.2:
        _hud.show_toast("Не клюёт… Попробуй ещё раз")
        return
    elif r < 0.62:
        fish = "Вобла"
    elif r < 0.84:
        fish = "Лещ"
    elif r < 0.96:
        fish = "Судак"
    else:
        fish = "Сом"
    if _give_item(fish):
        Sfx.play("coin")
        stats["fish"] = int(stats.get("fish", 0)) + 1
        _hud.show_toast("Поймал: %s! Продай на рынке Пятигорска (%s) или съешь" % [fish, HudScript.format_money(int(FISH_PRICES[fish]))])


func _sell_fish() -> void:
    var total := 0
    for f: String in FISH_PRICES:
        var n := int(inventory.get(f, 0))
        if n > 0:
            total += n * int(FISH_PRICES[f])
            inventory.erase(f)
    if total == 0:
        _hud.show_toast("Рыбы нет. Ловят на набережных — ищи синие метки «РЫБАЧИТЬ»")
        return
    cash += total
    _earned("fish", total)
    Sfx.play("cash")
    _hud.show_toast("Скупщик взял весь улов: +%s" % HudScript.format_money(total))
    _save_game()


# --- напёрстки

func _thimbles_menu() -> void:
    _open_dialog("Напёрстки", "— Кручу-верчу, обмануть хочу! Угадаешь, где шарик, — плачу вдвое.\n\nСтавка?",
            [["100 ₽", _thimbles_bet.bind(100)], ["500 ₽", _thimbles_bet.bind(500)], ["2 000 ₽", _thimbles_bet.bind(2000)], ["Уйти", _dialog.close]])


func _thimbles_bet(bet: int) -> void:
    if cash < bet:
        _hud.show_toast("Наличных не хватает — снимай в банкомате")
        return
    cash -= bet
    Sfx.play("click")
    _open_dialog("Напёрстки", "Напёрстки замелькали… Где шарик?",
            [["Левый", _thimbles_pick.bind(bet)], ["Средний", _thimbles_pick.bind(bet)], ["Правый", _thimbles_pick.bind(bet)]])


func _thimbles_pick(bet: int) -> void:
    if randf() < 0.3:
        cash += bet * 2
        _earned("casino", bet * 2)
        Sfx.play("cash")
        _open_dialog("Напёрстки", "Шарик тут! Выиграл %s.\n— Везучий! Ещё разок?" % HudScript.format_money(bet * 2),
                [["Ещё", _thimbles_menu], ["Хватит", _dialog.close]])
    else:
        Sfx.play("error")
        _open_dialog("Напёрстки", "Пусто. — Эх, не повезло! Шарик был под соседним.",
                [["Отыграться", _thimbles_menu], ["Уйти", _dialog.close]])
    _save_game()


# --- «очко» (двадцать одно, колода 36 карт)

var _cards := {}


func _cards_menu() -> void:
    _open_dialog("«Очко»", "Играем в двадцать одно. Валет — 2, дама — 3, король — 4, туз — 11. Два туза — «золотое очко».\nПеребрал больше 21 — проиграл.\n\nСтавка?",
            [["200 ₽", _cards_start.bind(200)], ["1 000 ₽", _cards_start.bind(1000)], ["5 000 ₽", _cards_start.bind(5000)], ["Уйти", _dialog.close]])


func _card_draw() -> Array:
    var ranks := [["6", 6], ["7", 7], ["8", 8], ["9", 9], ["10", 10], ["В", 2], ["Д", 3], ["К", 4], ["Т", 11]]
    var r: Array = ranks[randi() % ranks.size()]
    return [String(r[0]), int(r[1])]


func _hand_sum(hand: Array) -> int:
    var s := 0
    for c: Array in hand:
        s += int(c[1])
    return s


func _hand_text(hand: Array) -> String:
    var t := ""
    for c: Array in hand:
        t += String(c[0]) + "  "
    return t + "= %d" % _hand_sum(hand)


func _cards_start(bet: int) -> void:
    if cash < bet:
        _hud.show_toast("Наличных не хватает — снимай в банкомате")
        return
    cash -= bet
    _cards = {"bet": bet, "me": [_card_draw(), _card_draw()], "dealer": [_card_draw()]}
    _cards_show()


func _cards_show() -> void:
    var me: Array = _cards["me"]
    var s := _hand_sum(me)
    if me.size() == 2 and s == 22:   # два туза
        _cards_finish(true, "Золотое очко!")
        return
    if s > 21:
        _cards_finish(false, "Перебор")
        return
    _open_dialog("«Очко»", "У катáлы: %s\nУ тебя: %s" % [_hand_text(_cards["dealer"]), _hand_text(me)],
            [["Ещё карту", _cards_hit], ["Хватит", _cards_stand]])


func _cards_hit() -> void:
    (_cards["me"] as Array).append(_card_draw())
    Sfx.play("click")
    _cards_show()


func _cards_stand() -> void:
    var dealer: Array = _cards["dealer"]
    while _hand_sum(dealer) < 17:
        dealer.append(_card_draw())
    var me := _hand_sum(_cards["me"])
    var d := _hand_sum(dealer)
    if d > 21 or me > d:
        _cards_finish(true, "У катáлы %d" % d)
    elif me == d:
        cash += int(_cards["bet"])
        _earned("casino", int(_cards["bet"]))
        _open_dialog("«Очко»", "Ничья (%d на %d) — ставка возвращена." % [me, d], [["Ещё партию", _cards_menu], ["Уйти", _dialog.close]])
    else:
        _cards_finish(false, "У катáлы %d" % d)


func _cards_finish(win: bool, why: String) -> void:
    var bet := int(_cards["bet"])
    var text := "%s\nУ тебя: %s\n\n" % [why, _hand_text(_cards["me"])]
    if win:
        cash += bet * 2
        _earned("casino", bet * 2)
        Sfx.play("cash")
        text += "Выиграл %s!" % HudScript.format_money(bet * 2)
    else:
        Sfx.play("error")
        text += "Проиграл %s." % HudScript.format_money(bet)
    _open_dialog("«Очко»", text, [["Ещё партию", _cards_menu], ["Уйти", _dialog.close]])
    _save_game()


# --- суд и колония

func _hire_lawyer(price: int) -> void:
    if not _pay(price, "Адвокат"):
        return
    jail_left *= 0.5
    _dialog.close()
    Sfx.play("cash")
    _hud.show_toast("Адвокат добился смягчения: срок %d с" % int(jail_left))


func _jail_work() -> void:
    if jail_left <= 0.0:
        _hud.show_toast("Ты на свободе")
        return
    if _court_work_cd > 0.0:
        return
    _court_work_cd = 3.0
    jail_left = maxf(1.0, jail_left - 12.0)
    _player.play_emote("squat")
    Sfx.play("click")
    _hud.show_toast("Отработал смену на швейке: −12 с срока")



# ================================================================ часть 3: ДК, метро, праздники, гонки и дрифт

const CINEMA_PRICE := 25
const DISCO_PRICE := 50
const METRO_FARE := 5
## Фильмы в кинозале ДК (свои сюжеты): название и кадры-титры.
const FILMS := [
    ["Тайна Волжского моста", ["Казань, 1984 год.", "Ночью на мосту пропадает грузовик с арбузами.",
            "Лейтенант Сафин берётся за дело.", "След ведёт на рынок Пятигорска…", "Погоня по серпантину!",
            "Арбузы найдены. Справедливость восторжествовала.", "КОНЕЦ"]],
    ["Весна в Бусаево", ["Село Бусаево. Посевная.", "Тракторист Гена влюблён в почтальона Олю.",
            "Но Оля мечтает о городе…", "Гена пишет письма в стихах.", "Свадьба на всё село!", "КОНЕЦ"]],
    ["Отряд «Лучик»", ["Пионерский лагерь «Лучик».", "Вожатый пропал перед самым смотром строя и песни.",
            "Пятеро ребят идут его искать.", "Он застрял на дереве, спасая котёнка.", "Отряд берёт первое место!", "КОНЕЦ"]],
    ["Москва — Пятигорск, транзитом", ["Скорый поезд, купе №7.", "Попутчики: профессор, повар и спортсмен.",
            "Из чемодана профессора исчезает рукопись.", "Подозревают всех…", "Рукопись была в кастрюле повара!", "КОНЕЦ"]],
]
const HOLIDAYS := [
    ["Новый год", "01-01"], ["День Советской Армии", "02-23"], ["Международный женский день", "03-08"],
    ["Праздник Весны и Труда", "05-01"], ["День Победы", "05-09"], ["День Великого Октября", "11-07"],
]
## Ночная гонка: кольцо по внешним проспектам Казани.
const RACE_START := Vector3(-235.0, 0, -298.0)
const RACE_CP := [Vector3(0, 0, -301), Vector3(301, 0, -301), Vector3(301, 0, 0), Vector3(301, 0, 301),
        Vector3(0, 0, 301), Vector3(-301, 0, 301), Vector3(-301, 0, 0), Vector3(-301, 0, -301), Vector3(-150, 0, -301)]
const DRIFT_START := Vector3(330.0, 0, 298.0)
const DRIFT_TIME := 60.0

var _dk_room := ""          # "" / "cinema" / "disco"
var _film := -1
var _film_frame := 0
var _film_t := 0.0
var _disco_t := 0.0
var _disco_beat := 0.0
var _dance_acc := 0.0
var _holiday := ""
var _hol_day := -1
var _fw_t := 0.0
var _race := {}
var _race_marker: MarkerScript
var _drift := {}


func _setup_part3_points() -> void:
    var dk: Dictionary = _city.dk
    if dk.has("door"):
        _add_point(dk["door"], 2.6, "ДОМ КУЛЬТУРЫ", _open_dk, false, Color(1.0, 0.4, 0.7))
        _add_point(dk["cinema_exit"], 1.6, "ВЫЙТИ", _dk_leave, false, Color.WHITE, false)
        _add_point(dk["disco_exit"], 1.6, "ВЫЙТИ", _dk_leave, false, Color.WHITE, false)
        _add_point(dk["dance"], 3.5, "ТАНЦЕВАТЬ", _dk_dance, false, Color(1.0, 0.4, 0.7), false)
        _add_point(dk["bar"], 1.6, "БАР", _dk_bar, false, Color(1.0, 0.8, 0.2), false)
        var dj = NpcScript.new()
        dj.npc_name = "ДИДЖЕЙ"
        dj.jacket = "ts_red"
        dj.pants = "ts_black"
        dj.anim = "anim_dance"
        dj.mark = false
        dj.position = dk["dj"] + Vector3(0, 0, -1.4)
        add_child(dj)
        var spots := [Vector3(-3.5, 0, -3.0), Vector3(3.2, 0, -2.5), Vector3(-2.0, 0, 2.5), Vector3(3.8, 0, 2.0),
                Vector3(0.5, 0, -5.5), Vector3(-4.5, 0, 0.5)]
        var looks := [["ts_black", "cloth_acidwash"], ["cloth_alyaska", "ts_black"], ["ts_green", "cloth_acidwash"],
                ["cloth_leather2", "ts_black"], ["suit_gray", "ts_black"], ["ts_red", "cloth_acidwash"]]
        for k in spots.size():
            var n = NpcScript.new()
            n.npc_name = ""
            n.jacket = String(looks[k][0])
            n.pants = String(looks[k][1])
            n.anim = "anim_dance"
            n.mark = false
            n.position = dk["disco_center"] + spots[k]
            n.rotation.y = randf() * TAU
            add_child(n)
    for i in _city.metro.size():
        var st: Dictionary = _city.metro[i]
        _add_point(st["pos"], 2.0, "МЕТРО", _metro_menu.bind(i), false, Color(0.95, 0.15, 0.15))
    _add_point(RACE_START, 6.0, "НОЧНЫЕ ГОНКИ", _race_menu, true, Color(1.0, 0.35, 0.1))
    _add_point(DRIFT_START, 6.0, "ДРИФТ", _drift_menu, true, Color(1.0, 0.35, 0.1))


func _update_part3(delta: float) -> void:
    _update_dk(delta)
    _update_holiday(delta)
    _update_race(delta)
    _update_drift(delta)


func _part3_job_text() -> String:
    if not _race.is_empty():
        var i := int(_race["cp"])
        return "НОЧНАЯ ГОНКА: КП %d/%d · %.1f с · соперник %.1f с" % [i + 1, RACE_CP.size(), float(_race["t"]), float(_race["target"])]
    if not _drift.is_empty():
        return "ДРИФТ: %d очков ×%.1f · осталось %d с" % [int(_drift["score"]), 1.0 + minf(float(_drift["combo"]), 5.0) * 0.2,
                int(ceil(float(_drift["left"])))]
    if _dk_room == "cinema":
        if _film >= 0:
            return "Сеанс: «%s» — сядь в зале и смотри" % FILMS[_film][0]
        return "Кинозал ДК"
    if _dk_room == "disco":
        return "Дискотека: встань в центр зала — «ТАНЦЕВАТЬ»"
    return ""


func _warp(pos: Vector3, face: Vector3) -> void:
    if _player.seated == "sit":
        _player.set_seated("")
    _player.global_position = pos + Vector3(0, 0.3, 0)
    _player.velocity = Vector3.ZERO
    _player.set_camera_yaw(atan2(-face.x, -face.z))


# --- Дом культуры

func _open_dk() -> void:
    var hh := int(minutes) / 60
    var disco_open := hh >= 19 or hh < 3
    var film_i := (day * 24 + hh) % FILMS.size()
    _open_dialog("Дом культуры", "Кинозал: сейчас идёт «%s».\nДискотека: %s" % [FILMS[film_i][0], "открыта, играет музыка 80-х!" if disco_open else "закрыта, приходи после 19:00"],
            [["Билет в кино — %s" % HudScript.format_money(CINEMA_PRICE), _dk_cinema.bind(film_i)],
            ["На дискотеку — %s" % HudScript.format_money(DISCO_PRICE), _dk_disco],
            ["Закрыть", _dialog.close]])


func _dk_cinema(film_i: int) -> void:
    if not _pay(CINEMA_PRICE, "Билет в кино"):
        return
    _dialog.close()
    Sfx.play("door")
    _dk_room = "cinema"
    _film = film_i
    _film_frame = -1
    _film_t = 3.0
    _warp(_city.dk["cinema_spawn"], Vector3(0, 0, -1))
    var lab: Label3D = _city.dk["screen"]
    lab.text = "«%s»" % FILMS[film_i][0]
    (_city.dk["hall_light"] as OmniLight3D).light_energy = 0.15
    _hud.show_toast("Свет гаснет… Садись на любой ряд — фильм начинается")


func _dk_disco() -> void:
    var hh := int(minutes) / 60
    if not (hh >= 19 or hh < 3):
        _hud.show_toast("Дискотека открывается в 19:00")
        return
    if not _pay(DISCO_PRICE, "Вход на дискотеку"):
        return
    _dialog.close()
    Sfx.play("door")
    _dk_room = "disco"
    _dance_acc = 0.0
    _warp(_city.dk["disco_spawn"], Vector3(0, 0, -1))
    Music.play_place("club")
    _hud.show_toast("Дискотека «80»! Встань в центр зала и жми «ТАНЦЕВАТЬ»")


func _dk_leave() -> void:
    _dk_exit_state()
    Sfx.play("door")
    _warp(_city.dk["out"], Vector3(0, 0, 1))


func _dk_exit_state() -> void:
    if _dk_room == "disco":
        Music.stop_place()
    if _dk_room == "cinema":
        (_city.dk["screen"] as Label3D).text = ""
        (_city.dk["hall_light"] as OmniLight3D).light_energy = 1.2
    _dk_room = ""
    _film = -1


func _dk_dance() -> void:
    if _dk_room != "disco":
        return
    if _player.play_emote("dance"):
        _hud.show_toast("Танцуешь! Не двигайся с места, чтобы не сбиться с ритма")


func _dk_bar() -> void:
    var items := [["Лимонад «Буратино»", 60], ["Лимонад «Тархун»", 60], ["Чай в подстаканнике", 40]]
    var buttons := []
    for it: Array in items:
        buttons.append(["%s — %s" % [it[0], HudScript.format_money(int(it[1]))], _dk_buy.bind(String(it[0]), int(it[1]))])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Бар", "— Что будешь?", buttons)


func _dk_buy(item: String, price: int) -> void:
    if _bag_count() >= BAG_SIZE:
        _hud.show_toast("Сумка полная")
        return
    if not _pay(price, item):
        return
    _give_item(item)
    _dialog.close()
    Sfx.play("coin")


func _update_dk(delta: float) -> void:
    if _dk_room == "":
        return
    var dk: Dictionary = _city.dk
    var center: Vector3 = dk["cinema_center"] if _dk_room == "cinema" else dk["disco_center"]
    var me: Vector3 = _player.global_position
    if Vector2(me.x - center.x, me.z - center.z).length() > 20.0 or _driving != null:
        _dk_exit_state()   # ушёл другим путём (арест, смерть, телепорт)
        return
    if _dk_room == "cinema":
        if _film < 0:
            return
        _film_t -= delta
        var sm: StandardMaterial3D = dk["screen_mat"]
        sm.emission_energy_multiplier = 0.55 + 0.08 * sin(Time.get_ticks_msec() * 0.03)
        if _film_t > 0.0:
            return
        var frames: Array = FILMS[_film][1]
        _film_frame += 1
        if _film_frame >= frames.size():
            var watched: bool = _player.seated == "sit"
            var name_f := String(FILMS[_film][0])
            _dk_exit_state()
            _dk_room = "cinema"
            (dk["screen"] as Label3D).text = "«%s»\nСпасибо за внимание!" % name_f
            if watched:
                health = minf(100.0, health + 30.0)
                stats["cinema"] = int(stats.get("cinema", 0)) + 1
                Sfx.play("levelup")
                _hud.show_toast("Хорошее кино! Отдохнул душой: +30 здоровья")
                _save_game()
            else:
                _hud.show_toast("Фильм закончился. В следующий раз садись в зале — так приятнее")
            return
        (dk["screen"] as Label3D).text = String(frames[_film_frame])
        _film_t = 4.5
        return
    # дискотека: свет и пол в такт
    _disco_t += delta
    _disco_beat -= delta
    (dk["ball"] as Node3D).rotation.y += delta * 1.2
    var lights: Array = dk["lights"]
    for k in lights.size():
        var sl: SpotLight3D = lights[k]
        sl.rotation = Vector3(-0.9 + 0.35 * sin(_disco_t * 1.3 + k), 0.6 * sin(_disco_t * 0.9 + k * 1.7), 0)
    if _disco_beat <= 0.0:
        _disco_beat = 0.47
        var pal := [Color(1, 0.15, 0.4), Color(0.2, 0.5, 1), Color(0.2, 1, 0.4), Color(1, 0.8, 0.1), Color(0.7, 0.2, 1), Color(0.1, 0.1, 0.12)]
        for tm: StandardMaterial3D in dk["tiles"]:
            var c: Color = pal[randi() % pal.size()]
            tm.albedo_color = c
            tm.emission = c
    if _player.emote == "dance":
        _dance_acc += delta
        if _dance_acc >= 12.0:
            _dance_acc = 0.0
            stats["dance"] = int(stats.get("dance", 0)) + 1
            hunger = maxf(0.0, hunger - 3.0)
            Sfx.play("coin")
            _hud.show_toast("Зажёг на танцполе! (%d) Девчонки оглядываются" % int(stats["dance"]))


# --- метро

func _metro_menu(i: int) -> void:
    var buttons := []
    for j in _city.metro.size():
        if j != i:
            buttons.append(["«%s»" % _city.metro[j]["name"], _metro_ride.bind(i, j)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Метро — станция «%s»" % _city.metro[i]["name"], "Проезд — %s (жетон). Куда едем?" % HudScript.format_money(METRO_FARE), buttons)


func _metro_ride(from: int, to: int) -> void:
    if _traveling or not _pay(METRO_FARE, "Жетон метро"):
        return
    _dialog.close()
    stats["metro"] = int(stats.get("metro", 0)) + 1
    Sfx.play("station")
    var st: Dictionary = _city.metro[to]
    var out: Vector3 = st["out"]
    var pos: Vector3 = st["pos"]
    var face := out - pos
    _player.set_camera_yaw(atan2(-face.x, -face.z))
    await _travel(out + Vector3(0, 0.3, 0), "Осторожно, двери закрываются!\nСледующая станция — «%s»" % st["name"], 2.5, "")
    _save_game()


# --- праздники и салют

func _holiday_for_today() -> String:
    var d := Time.get_date_dict_from_system()
    var md := "%02d-%02d" % [int(d["month"]), int(d["day"])]
    if md == "12-31":
        return "Новый год"
    for h: Array in HOLIDAYS:
        if String(h[1]) == md:
            return String(h[0])
    if day % 5 == 0:
        return String(HOLIDAYS[(day / 5) % HOLIDAYS.size()][0])
    return ""


func _update_holiday(delta: float) -> void:
    if not _started:
        return
    if day != _hol_day:
        _hol_day = day
        _holiday = _holiday_for_today()
        var month := int(Time.get_date_dict_from_system()["month"])
        if _city.festive_root:
            _city.festive_root.visible = _holiday != ""
        if _city.tree_root:
            _city.tree_root.visible = _holiday == "Новый год" or month == 12 or month == 1
        if _holiday != "":
            _hud.chat("Сегодня праздник — %s! Площади украшены, работа оплачивается +50%%, в 21:00 — салют в Казани и Пятигорске." % _holiday, "info")
            if faction != "":
                bank += 1000
                _earned("reward", 1000)
                _hud.chat("Праздничная премия от организации: +%s на счёт" % HudScript.format_money(1000), "info")
    var m := int(minutes)
    if _holiday != "" and m >= 21 * 60 and m < 21 * 60 + 45:
        _fw_t -= delta
        if _fw_t <= 0.0:
            _fw_t = randf_range(0.35, 0.9)
            var spots: Array = _city.fireworks_spots
            if not spots.is_empty():
                var near: Vector3 = spots[0]
                for sp: Vector3 in spots:
                    if sp.distance_to(_focus()) < near.distance_to(_focus()):
                        near = sp
                if near.distance_to(_focus()) < 600.0:
                    _launch_firework(near + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)))


func _launch_firework(at: Vector3) -> void:
    var cols := [Color(1, 0.2, 0.2), Color(1, 0.85, 0.2), Color(0.3, 0.6, 1), Color(0.3, 1, 0.4), Color(1, 0.4, 1), Color(1, 1, 1)]
    var col: Color = cols[randi() % cols.size()]
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = col
    glow.emission_enabled = true
    glow.emission = col
    glow.emission_energy_multiplier = 4.0
    var rocket := MeshInstance3D.new()
    var rm := SphereMesh.new()
    rm.radius = 0.3
    rm.height = 0.6
    rm.radial_segments = 6
    rm.rings = 3
    rocket.mesh = rm
    rocket.material_override = glow
    add_child(rocket)
    rocket.global_position = at + Vector3(0, 1.0, 0)
    Sfx.play_at("firework", at)
    var top := at + Vector3(randf_range(-6, 6), randf_range(38.0, 55.0), randf_range(-6, 6))
    var tw := create_tween()
    tw.tween_property(rocket, "global_position", top, 0.95).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_callback(func() -> void:
        rocket.visible = false
        var p := CPUParticles3D.new()
        p.one_shot = true
        p.explosiveness = 1.0
        p.amount = 140
        p.lifetime = 2.2
        p.direction = Vector3.UP
        p.spread = 180.0
        p.initial_velocity_min = 14.0
        p.initial_velocity_max = 20.0
        p.gravity = Vector3(0, -5.0, 0)
        p.damping_min = 2.0
        p.damping_max = 3.0
        var sp := SphereMesh.new()
        sp.radius = 0.38
        sp.height = 0.76
        sp.radial_segments = 4
        sp.rings = 2
        sp.material = glow
        p.mesh = sp
        var curve := Curve.new()
        curve.add_point(Vector2(0, 1))
        curve.add_point(Vector2(1, 0))
        p.scale_amount_curve = curve
        add_child(p)
        p.global_position = top
        p.emitting = true
        var fl := OmniLight3D.new()
        fl.light_color = col
        fl.omni_range = 70.0
        fl.light_energy = 3.0
        add_child(fl)
        fl.global_position = top
        var t2 := create_tween()
        t2.tween_property(fl, "light_energy", 0.0, 0.8)
        t2.tween_interval(1.6)
        t2.tween_callback(func() -> void:
            p.queue_free()
            fl.queue_free()
            rocket.queue_free()))


# --- ночные гонки

func _race_menu() -> void:
    if not _race.is_empty() or not _drift.is_empty():
        return
    if _night_k < 0.5:
        _open_dialog("Ночные гонки", "— Днём тут гаишники. Приезжай ночью, когда стемнеет.", [["Понял", _dialog.close]])
        return
    _open_dialog("Ночные гонки", "Кольцо по внешним проспектам Казани: %d контрольных точек.\nОбгонишь соперника по времени — заберёшь ставку вдвое.\nНа больших ставках соперники быстрее." % RACE_CP.size(),
            [["Ставка 500 ₽ — «Москвич»", _race_start.bind(500, 15.0)],
            ["Ставка 2 000 ₽ — «Жигули»", _race_start.bind(2000, 18.0)],
            ["Ставка 10 000 ₽ — «Волга» с форсированным мотором", _race_start.bind(10000, 21.0)],
            ["Не сейчас", _dialog.close]])


func _race_length() -> float:
    var L := 0.0
    var prev := RACE_START
    for cp: Vector3 in RACE_CP:
        L += prev.distance_to(cp)
        prev = cp
    return L


func _race_start(bet: int, rival_speed: float) -> void:
    if _driving == null:
        return
    if not _pay(bet, "Ставка на гонку"):
        return
    _dialog.close()
    _race = {"bet": bet, "cp": 0, "t": 0.0, "target": snappedf(_race_length() / rival_speed, 0.1), "car": _driving}
    if _race_marker == null:
        _race_marker = MarkerScript.new()
        add_child(_race_marker)
    _race_show_cp()
    Sfx.play("beep")
    _hud.show_toast("СТАРТ! Гони по меткам — время пошло")


func _race_show_cp() -> void:
    var i := int(_race["cp"])
    _race_marker.show_at(RACE_CP[i], "КП %d/%d" % [i + 1, RACE_CP.size()], Color(1.0, 0.35, 0.1))
    _set_gps(RACE_CP[i], "Гонка: КП %d" % (i + 1), false)


func _update_race(delta: float) -> void:
    if _race.is_empty():
        return
    if _driving == null or _driving != _race["car"]:
        _race_end(false, "Вышел из машины — гонка проиграна")
        return
    _race["t"] = float(_race["t"]) + delta
    if float(_race["t"]) > float(_race["target"]) * 1.8:
        _race_end(false, "Соперник давно на финише")
        return
    var i := int(_race["cp"])
    var cp: Vector3 = RACE_CP[i]
    var me: Vector3 = _driving.global_position
    if Vector2(me.x - cp.x, me.z - cp.z).length() < 13.0:
        Sfx.play("beep")
        i += 1
        _race["cp"] = i
        if i >= RACE_CP.size():
            var win := float(_race["t"]) < float(_race["target"])
            _race_end(win, "Финиш: %.1f с, соперник %.1f с" % [float(_race["t"]), float(_race["target"])])
            return
        _race_show_cp()


func _race_end(win: bool, why: String) -> void:
    var bet := int(_race["bet"])
    _race = {}
    if _race_marker:
        _race_marker.visible = false
    _clear_gps()
    if win:
        cash += bet * 2
        _earned("race", bet * 2)
        stats["race"] = int(stats.get("race", 0)) + 1
        skills["driving"] = minf(100.0, float(skills["driving"]) + 2.0)
        Sfx.play("levelup")
        _open_dialog("Ночные гонки", "%s\n\nПобеда! Забираешь %s. Вождение +2." % [why, HudScript.format_money(bet * 2)], [["Отлично", _dialog.close]])
    else:
        Sfx.play("error")
        _open_dialog("Ночные гонки", "%s\n\nСтавка %s ушла сопернику." % [why, HudScript.format_money(bet)], [["Эх", _dialog.close]])
    _save_game()


# --- дрифт

func _drift_menu() -> void:
    if not _race.is_empty() or not _drift.is_empty():
        return
    var best := int(stats.get("drift_best", 0))
    _open_dialog("Дрифт", "60 секунд: проходи повороты боком — чем круче угол и выше скорость, тем больше очков.\nДлинная связка без остановки — множитель до ×2.\nНаграда — 1 ₽ за каждые 5 очков.\n\nТвой рекорд: %d" % best,
            [["Поехали!", _drift_start], ["Не сейчас", _dialog.close]])


func _drift_start() -> void:
    _dialog.close()
    if _driving == null:
        return
    _drift = {"score": 0.0, "combo": 0.0, "idle": 0.0, "left": DRIFT_TIME, "car": _driving}
    Sfx.play("beep")
    _hud.show_toast("Дрифт! Разгонись и заходи в повороты боком (ручник помогает)")


func _update_drift(delta: float) -> void:
    if _drift.is_empty():
        return
    if _driving == null or _driving != _drift["car"]:
        _drift_end()
        return
    _drift["left"] = float(_drift["left"]) - delta
    var v: Vector3 = (_driving as RigidBody3D).linear_velocity
    var hv := Vector3(v.x, 0, v.z)
    var spd := hv.length()
    var fwd: Vector3 = _driving.global_transform.basis.z
    fwd.y = 0
    var ang := 0.0
    if spd > 1.0 and fwd.length() > 0.01:
        ang = rad_to_deg(hv.normalized().angle_to(fwd.normalized()))
        if ang > 90.0:
            ang = 180.0 - ang   # задним ходом не считается дрифтом
            if hv.dot(fwd) < 0.0:
                ang = 0.0
    if spd > 8.0 and ang > 12.0 and ang < 80.0:
        _drift["combo"] = float(_drift["combo"]) + delta
        _drift["idle"] = 0.0
        var mul := 1.0 + minf(float(_drift["combo"]), 5.0) * 0.2
        _drift["score"] = float(_drift["score"]) + (ang - 10.0) * spd * delta * 0.5 * mul
    else:
        _drift["idle"] = float(_drift["idle"]) + delta
        if float(_drift["idle"]) > 0.7:
            _drift["combo"] = 0.0
    if float(_drift["left"]) <= 0.0:
        _drift_end()


func _drift_end() -> void:
    var score := int(_drift.get("score", 0.0))
    _drift = {}
    var prize := mini(score / 5, 15000)
    cash += prize
    _earned("race", prize)
    var best := int(stats.get("drift_best", 0))
    var rec := ""
    if score > best:
        stats["drift_best"] = score
        rec = "\nНовый рекорд!"
    if score > 300:
        skills["driving"] = minf(100.0, float(skills["driving"]) + 1.0)
    Sfx.play("cash" if prize > 0 else "error")
    _open_dialog("Дрифт", "Очки: %d%s\nНаграда: %s" % [score, rec, HudScript.format_money(prize)], [["Ещё раз", _drift_menu], ["Хватит", _dialog.close]])
    _save_game()



# ================================================================ онлайн: другие игроки и чат

## id -> {"name", "npc", "car", "car_key", "tpos", "tyaw", "txf", "seen"}
var _remote := {}


## Аккаунт онлайн-сервера: сохранение из облака кладём в свой файл и играем из него.
func _use_account(nick: String, save_text: String) -> void:
    _save_path = "user://acc_%s.cfg" % nick.to_lower().md5_text().substr(0, 12)
    if save_text != "":
        var cfg := ConfigFile.new()
        if cfg.parse(save_text) == OK:
            cfg.save(_save_path)
    elif FileAccess.file_exists(_save_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))   # новый аккаунт — с нуля


var _diag_frames := 0
var _diag_t := 0.0
var _diag_start := 0.0


func _net_start() -> void:
    Crash.mark("онлайн: старт")
    _diag_start = Time.get_ticks_msec() / 1000.0
    Net.server_msg.connect(_on_server_msg)
    _apply_profile(Net.profile)
    _net_point = {"pos": Vector3(0, -1000, 0), "r": 2.2, "text": "ИГРОК", "cb": _open_player_menu, "car": false}
    _points.append(_net_point)
    Net.player_joined.connect(_on_net_joined)
    Net.player_left.connect(_on_net_left)
    Net.states_received.connect(_on_net_states)
    Net.chat_received.connect(_on_net_chat)
    Net.lost.connect(_on_net_lost)
    Net.reconnected.connect(_on_net_reconnected)
    Net.reconnect_failed.connect(func(msg: String) -> void:
        _hud.chat("Не удалось вернуться на сервер (%s) — играешь офлайн, прогресс сохранится на телефоне." % msg, "warn"))
    Crash.mark("онлайн: профиль применён, hello")
    Net.hello(Net.nick, {"look": look, "sex": "f" if player_female else "m"})
    _hud.chat("Онлайн: %s. Чат — кнопка с микрофоном, «/g текст» — написать всем." % Net.host_text, "info")


func _on_chat_button() -> void:
    if not Net.online:
        _hud.toggle_chat_history()
        return
    _open_dialog("Чат", "Тебя услышат игроки рядом (60 м). Начни с «/g », чтобы написать всем на сервере.",
            [["Отправить", _send_chat], ["История", func() -> void:
                _dialog.close()
                _hud.toggle_chat_history()], ["Закрыть", _dialog.close]], "Сообщение...")


func _send_chat() -> void:
    var t := _dialog.input_text()
    _dialog.close()
    if t != "":
        Net.say(t)


func _on_net_chat(pname: String, text: String, global: bool) -> void:
    if pname == "":
        _hud.chat(text, "info")
    elif global:
        _hud.chat("[всем] %s: %s" % [pname, text], "shout")
    else:
        _hud.chat("%s: %s" % [pname, text], "say")


func _on_net_lost() -> void:
    for id: int in _remote.keys():
        _on_net_left(id)
    if Net.kick_msg != "":
        _hud.chat("Отключён: %s" % Net.kick_msg, "warn")
    if _ride_id >= 0:
        _leave_ride()
    for id: int in _pcars.keys():
        _clear_pcars(id)
    if Net.reconnecting:
        _hud.chat("Связь с сервером оборвалась — переподключаюсь...", "warn")
    else:
        _hud.chat("Связь с сервером потеряна — прогресс сохранится локально, перезайди в игру.", "warn")
    Sfx.play("error")


func _on_net_reconnected() -> void:
    _pcars_sent = ""
    _apply_profile(Net.profile)
    _save_game()
    Net.hello(Net.nick, {"look": look, "sex": "f" if player_female else "m"})
    _hud.chat("Связь восстановлена.", "info")
    Sfx.play("notify")


## Внешность одной строкой для других игроков: номера вещей по слотам, форма фракции (если надета), пол.
func _look_code() -> String:
    var parts := []
    for slot: Dictionary in Clothes.SLOTS:
        parts.append(str(int(look.get(slot["id"], 0))))
    return "%s;%s;%s" % [",".join(parts), _last_uniform if _last_uniform != "?" else "", "f" if player_female else "m"]


## Одежда другого игрока по строке внешности: [пиджак, штаны, ботинки, шапка, цвет шапки, женщина?].
func _look_from_code(code: String) -> Array:
    var p := code.split(";")
    var lk := {}
    var nums := p[0].split(",") if p.size() > 0 else PackedStringArray()
    var k := 0
    for slot: Dictionary in Clothes.SLOTS:
        if k < nums.size():
            lk[slot["id"]] = int(nums[k])
        k += 1
    var tex := Clothes.textures(lk)
    var h: Array = Clothes.hat(lk)
    var out := [String(tex.get("jacket", "")), String(tex.get("pants", "")), String(tex.get("shoes", "")), String(h[0]), h[1],
            p.size() > 2 and p[2] == "f", Clothes.build(lk), Clothes.colors(lk).get("skin", Color(0.87, 0.68, 0.55))]
    var uk := p[1] if p.size() > 1 else ""
    if uk.contains(":"):   # форма фракции на смене
        var u: Dictionary = FactionData.uniform(uk.get_slice(":", 0), int(uk.get_slice(":", 1)))
        out[0] = String(u.get("jacket", out[0]))
        out[1] = String(u.get("pants", out[1]))
        out[2] = String(u.get("shoes", out[2]))
        out[3] = String(u.get("cap", ""))
        out[4] = u.get("cap_col", Color(0, 0, 0, 0))
    return out


## Переодеть другого игрока: модель создаётся заново с новой одеждой (бывает редко — магазин, смена, форма).
func _remote_redress(r: Dictionary, code: String) -> void:
    r["look"] = code
    var lk := _look_from_code(code)
    var old: Node3D = r["npc"]
    if is_instance_valid(old) and old.jacket == String(lk[0]) and old.pants == String(lk[1]) and old.shoes == String(lk[2]) \
            and old.hat == String(lk[3]) and old.female == bool(lk[5]) and old.build == lk[6] and old.skin_col == lk[7]:
        return   # одет так же (обычно — первый пакет после входа): модель не пересоздаём
    var n = NpcScript.new()
    n.npc_name = "%s [%d]" % [r["name"], int(r.get("id", 0))]
    n.female = bool(lk[5])
    n.build = lk[6]
    n.skin_col = lk[7]
    n.remote = true
    n.collide = false
    n.mark = false
    n.beard = false
    n.anim = "idle"
    if String(lk[0]) != "":
        n.jacket = String(lk[0])
    if String(lk[1]) != "":
        n.pants = String(lk[1])
    if String(lk[2]) != "":
        n.shoes = String(lk[2])
    n.hat = String(lk[3])
    n.hat_col = lk[4]
    n.name_col = Color(0.75, 0.9, 1.0)
    n.visible = old.visible if is_instance_valid(old) else false
    add_child(n)
    if is_instance_valid(old):
        n.global_position = old.global_position
        n.rotation = old.rotation
        old.queue_free()
    r["npc"] = n
    r["fid"] = "?"          # подпись с фракцией обновится со следующим пакетом
    r["weapon"] = "?"       # оружие в руки — заново


## Оружие в руках другого игрока: бита или ствол на кисти правой руки.
func _remote_weapon(r: Dictionary, wid: String) -> void:
    r["weapon"] = wid
    var n: Node3D = r["npc"]
    if not is_instance_valid(n):
        return
    var old = n.get_meta("weapon_node") if n.has_meta("weapon_node") else null
    if old != null and is_instance_valid(old):
        (old as Node).queue_free()
    if n.has_meta("weapon_node"):
        n.remove_meta("weapon_node")
    if wid == "":
        return
    var sks := n.find_children("*", "Skeleton3D", true, false)
    if sks.is_empty() or (sks[0] as Skeleton3D).find_bone("hand_r") < 0:
        return
    var att := BoneAttachment3D.new()
    att.bone_name = "hand_r"
    sks[0].add_child(att)
    if wid == "bat":
        att.add_child(PlayerScript.make_bat())
    else:
        var path := Weapons.model_path(wid)
        if path == "" or not ResourceLoader.exists(path):
            att.queue_free()
            return
        var g: Node3D = (load(path) as PackedScene).instantiate()
        g.transform = PlayerScript.GUN_XF
        att.add_child(g)
    n.set_meta("weapon_node", att)


## Другой игрок ударил или выстрелил: звук у него, а при выстреле — вспышка у ствола.
func _remote_attack(r: Dictionary) -> void:
    var n: Node3D = r["npc"]
    if not is_instance_valid(n) or not n.visible:
        return
    var wid := String(r.get("weapon", ""))
    var p := n.global_position + Vector3(0, 1.3, 0)
    if wid == "" or wid == "bat" or Weapons.is_melee(wid):
        Sfx.play_at("swing", p, -6.0, randf_range(0.9, 1.15))
        return
    Sfx.play_at("shot_heavy" if wid in ["ak", "obrez"] else "shot", p, 0.0, randf_range(0.95, 1.05))
    var fl := OmniLight3D.new()
    fl.light_color = Color(1.0, 0.8, 0.45)
    fl.light_energy = 3.0
    fl.omni_range = 4.0
    add_child(fl)
    fl.global_position = p + n.global_transform.basis.z * 0.6
    get_tree().create_timer(0.07).timeout.connect(fl.queue_free)


## Реплика рядом стоящего игрока — облачком над головой на 6 секунд (как в RP-проектах).
func _chat_bubble(x: String, me: bool) -> void:
    for id in _remote:
        var r: Dictionary = _remote[id]
        var nm := String(r["name"])
        var text := ""
        if not me and x.begins_with(nm + ": "):
            text = x.substr(nm.length() + 2)
        elif me and x.begins_with("* " + nm + " "):
            text = "* " + x.substr(nm.length() + 3)
        if text == "":
            continue
        var holder: Node3D = r["car"] if r["car"] != null and is_instance_valid(r["car"]) else r["npc"]
        if not is_instance_valid(holder):
            return
        var old = holder.get_meta("bubble") if holder.has_meta("bubble") else null
        if old != null and is_instance_valid(old):
            (old as Node).queue_free()
        var l := Label3D.new()
        l.text = text if text.length() <= 60 else text.substr(0, 57) + "…"
        l.font_size = 44
        l.pixel_size = 0.005
        l.outline_size = 10
        l.modulate = Color(1, 1, 1) if not me else Color(0.95, 0.75, 1.0)
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        l.no_depth_test = true
        l.width = 520.0
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.position = Vector3(0, 2.75, 0)
        l.visibility_range_end = 40.0
        holder.add_child(l)
        holder.set_meta("bubble", l)
        get_tree().create_timer(6.0).timeout.connect(l.queue_free)   # если пузырь уже сменился — связь снимется сама
        return


func _on_net_joined(id: int, pname: String, info: Dictionary) -> void:
    if _remote.has(id):
        return
    var lk: Dictionary = info.get("look", {}) if info.get("look", {}) is Dictionary else {}
    var tex := Clothes.textures(lk)
    Crash.mark("онлайн: игрок %s" % pname)
    var n = NpcScript.new()
    n.npc_name = "%s [%d]" % [pname, id]
    n.female = String(info.get("sex", "")) == "f"
    n.remote = true
    n.collide = false
    n.mark = false
    n.beard = false
    n.anim = "idle"
    n.jacket = String(tex.get("jacket", n.jacket))
    n.pants = String(tex.get("pants", n.pants))
    n.shoes = String(tex.get("shoes", n.shoes))
    var h: Array = Clothes.hat(lk)
    n.hat = String(h[0])
    n.hat_col = h[1]
    n.build = Clothes.build(lk)
    n.skin_col = Clothes.colors(lk).get("skin", Color(0.87, 0.68, 0.55))
    n.name_col = Color(0.75, 0.9, 1.0)
    n.visible = false
    add_child(n)
    _remote[id] = {"id": id, "name": pname, "npc": n, "car": null, "car_key": "", "tpos": Vector3.ZERO, "tyaw": 0.0,
            "txf": Transform3D(), "seen": false}
    _hud.chat("%s зашёл в игру" % pname, "time")


func _on_net_left(id: int) -> void:
    if not _remote.has(id):
        return
    var r: Dictionary = _remote[id]
    if is_instance_valid(r["npc"]):
        (r["npc"] as Node).queue_free()
    if r["car"] != null and is_instance_valid(r["car"]):
        (r["car"] as Node).queue_free()
    _hud.chat("%s вышел из игры" % r["name"], "time")
    _remote.erase(id)
    _clear_pcars(id)


func _on_net_states(list: Array) -> void:
    for e: Array in list:
        var id := int(e[0])
        if not _remote.has(id):
            continue
        var st: Array = e[1]
        var r: Dictionary = _remote[id]
        var pnow := Time.get_ticks_msec() / 1000.0
        var pdt := pnow - float(r.get("ptt", 0.0))
        # скорость пешком по двум пакетам: между пакетами игрок идёт дальше, а не стоит и не «прыгает»
        if pdt > 0.03 and pdt < 1.0 and r.has("tpos"):
            var pv: Vector3 = ((st[0] as Vector3) - (r["tpos"] as Vector3)) / pdt
            r["pvel"] = pv if pv.length() < 12.0 else Vector3.ZERO
        else:
            r["pvel"] = Vector3.ZERO
        r["ptt"] = pnow
        r["tpos"] = st[0]
        # у игрока модель внутри _visual развёрнута на 180° (смотрит в -Z), у NPC — нет (смотрит в +Z)
        r["tyaw"] = float(st[1]) + PI
        r["anim"] = String(st[2])
        r["aspeed"] = float(st[3])
        r["hp"] = int(st[7]) if st.size() > 7 else 100
        var w := int(st[6]) if st.size() > 6 else 0
        var fid := String(st[8]) if st.size() > 8 else ""
        if w != int(r.get("wanted", -1)) or fid != String(r.get("fid", "?")):
            r["wanted"] = w
            r["fid"] = fid
            var col := Color(0.75, 0.9, 1.0)
            var tag := ""
            if fid != "":
                col = (FactionData.get_faction(fid).get("color", col) as Color).lightened(0.35)
                tag = "\n" + String(FactionData.get_faction(fid).get("title", ""))
            (r["npc"] as Node).set_label("%s [%d]" % [r["name"], id] + ("  " + "★".repeat(w) if w > 0 else "") + tag, col)
        var ride := int(st[9]) if st.size() > 9 else 0
        if ride != int(r.get("ride", 0)):
            if ride == Net.my_id:
                _hud.chat("%s сел к тебе в машину" % r["name"], "time")
            elif int(r.get("ride", 0)) == Net.my_id:
                _hud.chat("%s вышел из машины" % r["name"], "time")
            r["ride"] = ride
        # внешность, оружие, удары
        var lcode := String(st[10]) if st.size() > 10 else ""
        if lcode != "" and lcode != String(r.get("look", "")):
            _remote_redress(r, lcode)
        var wid := String(st[11]) if st.size() > 11 else ""
        if wid != String(r.get("weapon", "")):
            _remote_weapon(r, wid)
        var an := int(st[12]) if st.size() > 12 else 0
        if r.has("atk") and an != int(r["atk"]):
            _remote_attack(r)
        r["atk"] = an
        var car: Array = st[4]
        var key := "" if car.is_empty() else "%s|%s|%s|%s" % [car[0], car[1], car[2], car[4] if car.size() > 4 else ""]
        if key != r["car_key"]:
            _remote_set_car(r, car, key)
        if r["car"] != null and is_instance_valid(r["car"]):
            var fl := int(st[13]) if st.size() > 13 else 0
            if fl != int(r.get("flags", -1)):
                if fl & 4 != 0 and int(r.get("flags", 0)) & 4 == 0:
                    Sfx.play_at("horn", (r["car"] as Node3D).global_position, -2.0, 1.0)
                r["flags"] = fl
                r["car"].set_remote_flags(fl & 1 != 0, fl & 2 != 0)
        if not car.is_empty():
            var now := Time.get_ticks_msec() / 1000.0
            var nxf: Transform3D = st[5]
            var dt := now - float(r.get("tt", 0.0))
            if dt > 0.03 and dt < 1.0:   # скорость по двум последним пакетам — для предсказания
                r["vel"] = (nxf.origin - (r["txf"] as Transform3D).origin) / dt
            else:
                r["vel"] = Vector3.ZERO
            r["tt"] = now
            r["txf"] = nxf
        if not r["seen"]:   # первый раз — сразу на место, без «прилёта» через весь город
            Crash.mark("игрок %s: место, анимация %s, машина %s" % [r["name"], r["anim"], str(car)])
            r["seen"] = true
            (r["npc"] as Node3D).global_position = st[0]
            if r["car"] != null:
                (r["car"] as Node3D).global_transform = st[5]


func _remote_set_car(r: Dictionary, car: Array, key: String) -> void:
    if r["car"] != null and is_instance_valid(r["car"]):
        (r["car"] as Node).queue_free()
    r["car"] = null
    r["car_key"] = key
    var n: Node3D = r["npc"]
    if car.is_empty():
        n.visible = true
        return
    r["car"] = _make_remote_car(car, String(r["name"]))
    r["flags"] = -1
    if car.size() > 4:
        r["car"].apply_tuning_code(String(car[4]))
    var seat: Array = r["car"].driver_seat()
    if seat.size() == 2:   # другой игрок за рулём — виден водитель
        preload("res://scripts/driver_mesh.gd").seat_in(r["car"], seat[0], float(seat[1]), "passerby")
    n.visible = false


## Копия чужой машины: без физики (её двигает сервер), с подписью над крышей.
func _make_remote_car(car: Array, label: String, label_col := Color(0.75, 0.9, 1.0)) -> Node3D:
    Crash.mark("онлайн: машина %s %s" % [str(car[0]), str(car[1])])
    var c = CarScene.instantiate()
    c.kind = String(car[0])
    c.model_id = String(car[1])
    c.paint = Color.html(String(car[2]))
    c.car_name = String(car[3]) if car.size() > 3 else ""
    c.freeze = true
    c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
    add_child(c)
    var lab := Label3D.new()
    lab.text = label
    lab.font_size = 64
    lab.pixel_size = 0.005
    lab.outline_size = 12
    lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lab.modulate = label_col
    lab.position = Vector3(0, 2.3, 0)
    c.add_child(lab)
    return c


# ---------------------------------------------------------------- онлайн: припаркованные машины игроков
var _pcars := {}          # id игрока -> {"name", "l": [[kind, model, paint, name, x, y, z, yaw]...], "nodes": [...]}
var _pcars_sent := ""
var _pcars_t := 0.0


func _my_parked_cars() -> Array:
    var out := []
    for car in _cars:
        if car == null or not is_instance_valid(car) or not car.owned or not car.visible or car == _driving:
            continue
        var p: Vector3 = car.global_position
        var f: Vector3 = car.global_transform.basis.z
        out.append([String(car.kind), String(car.model_id), (car.paint as Color).to_html(false), String(car.car_name),
                snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), snappedf(atan2(f.x, f.z), 0.05)])
        if out.size() >= 6:
            break
    return out


func _update_pcars(delta: float) -> void:
    _pcars_t += delta
    if _pcars_t < 1.0:
        return
    _pcars_t = 0.0
    var mine := _my_parked_cars()
    var js := JSON.stringify(mine)
    if js != _pcars_sent:
        _pcars_sent = js
        Net.send_msg({"t": "pcars", "l": mine})
    # чужие стоящие машины — только рядом (на телефоне не держим весь город)
    var me: Vector3 = _player.global_position
    for id: int in _pcars:
        var e: Dictionary = _pcars[id]
        var l: Array = e["l"]
        var nodes: Array = e["nodes"]
        for i in l.size():
            var a: Array = l[i]
            var pos := Vector3(float(a[4]), float(a[5]), float(a[6]))
            var d := pos.distance_to(me)
            if nodes[i] == null and d < 220.0:
                var c := _make_remote_car(a, "Машина: %s" % e["name"], Color(0.85, 0.85, 0.85))
                c.global_transform = Transform3D(Basis(Vector3.UP, float(a[7])), pos)
                nodes[i] = c
            elif nodes[i] != null and d > 260.0:
                (nodes[i] as Node).queue_free()
                nodes[i] = null


func _set_pcars(id: int, l: Variant) -> void:
    _clear_pcars(id)
    if not l is Array or (l as Array).is_empty():
        return
    var ok := []
    for a: Variant in l:
        if a is Array and (a as Array).size() >= 8:
            ok.append(a)
    var nm := String(_remote[id]["name"]) if _remote.has(id) else "игрок"
    var nodes := []
    nodes.resize(ok.size())
    _pcars[id] = {"name": nm, "l": ok, "nodes": nodes}
    _pcars_t = 1.0


func _clear_pcars(id: int) -> void:
    if not _pcars.has(id):
        return
    for c: Variant in _pcars[id]["nodes"]:
        if c != null and is_instance_valid(c):
            (c as Node).queue_free()
    _pcars.erase(id)


# ---------------------------------------------------------------- онлайн: пассажир в машине другого игрока
var _ride_id := -1


func _remote_car_near() -> int:
    if _player == null or jail_left > 0.0 or _player.seated != "":
        return -1
    var best := -1
    var bd := 3.6
    for id: int in _remote:
        var c = _remote[id]["car"]
        if c == null or not is_instance_valid(c):
            continue
        var d: float = (c as Node3D).global_position.distance_to(_player.global_position)
        if d < bd:
            bd = d
            best = id
    return best


func _board_ride(id: int) -> void:
    var c = _remote[id]["car"]
    _ride_id = id
    _player.set_active(false)
    c.watch(true)
    Sfx.play("car_door", -6.0, randf_range(0.95, 1.05))
    _hud.show_toast("Ты пассажир у %s. «ВЫЙТИ» — выйти из машины" % _remote[id]["name"])


func _leave_ride() -> void:
    var id := _ride_id
    _ride_id = -1
    var pos: Vector3 = _player.global_position
    if _remote.has(id) and _remote[id]["car"] != null and is_instance_valid(_remote[id]["car"]):
        var c = _remote[id]["car"]
        c.watch(false)
        pos = c.get_exit_position()
    _player.global_position = pos
    _player.set_active(true)
    Sfx.play("car_door", -6.0, randf_range(0.95, 1.05))


func _update_online(delta: float) -> void:
    if not Net.online or _player == null:
        return
    # моё состояние
    var car := []
    var xf := Transform3D()
    if _driving != null:
        car = [String(_driving.kind), String(_driving.model_id), (_driving.paint as Color).to_html(false), String(_driving.car_name),
                _driving.tuning_code()]
        xf = _driving.global_transform
    var an := ""
    var asp := 1.0
    if _player._anim:
        an = String(_player._anim.current_animation)
        asp = _player._anim.speed_scale
    var yaw: float = _player._visual.global_rotation.y if _player._visual else 0.0
    var my_pos: Vector3 = _player.global_position
    if _ride_id >= 0:
        if not _remote.has(_ride_id) or _remote[_ride_id]["car"] == null or not is_instance_valid(_remote[_ride_id]["car"]):
            _leave_ride()
        else:
            my_pos = (_remote[_ride_id]["car"] as Node3D).global_position
            _player.global_position = my_pos + Vector3.UP * 0.3
    var flags := 0
    _horn_t = maxf(0.0, _horn_t - delta)
    if _driving != null:
        flags = (1 if _driving._headlight.visible else 0) | (2 if _driving.siren_on else 0) | (4 if _horn_t > 0.0 else 0)
    Net.send_state(delta, [my_pos, yaw, an, asp, car, xf, wanted, int(health), maxi(_ride_id, 0),
            _look_code(), weapon_id if weapon_id != "fist" else "", _attack_n, flags])
    if Net.authed:
        _net_sync(delta)
        _update_pcars(delta)
    # другие игроки — плавно к последним данным
    var k := 1.0 - exp(-10.0 * delta)
    for id: int in _remote:
        var r: Dictionary = _remote[id]
        if not r["seen"]:
            continue
        var n: Node3D = r["npc"]
        if int(r.get("ride", 0)) > 0:   # едет пассажиром — его не видно, он в машине
            n.visible = false
            continue
        if r["car"] != null and is_instance_valid(r["car"]):
            var c: Node3D = r["car"]
            var txf: Transform3D = r["txf"]
            var ahead := clampf(Time.get_ticks_msec() / 1000.0 - float(r.get("tt", 0.0)), 0.0, 0.3)
            txf.origin += (r.get("vel", Vector3.ZERO) as Vector3) * ahead   # предсказание до следующего пакета
            if c.global_position.distance_to(txf.origin) > 25.0:
                c.global_transform = txf
            else:
                c.global_transform = c.global_transform.interpolate_with(txf, k)
            n.global_position = c.global_position
            continue
        if not n.visible:
            Crash.mark("игрок %s: показан" % r["name"])
            _diag_frames = 4
            n.visible = true
        var tp: Vector3 = r["tpos"]
        var pahead := clampf(Time.get_ticks_msec() / 1000.0 - float(r.get("ptt", 0.0)), 0.0, 0.25)
        tp += (r.get("pvel", Vector3.ZERO) as Vector3) * pahead
        if n.global_position.distance_to(tp) > 30.0:
            n.global_position = tp
        else:
            n.global_position = n.global_position.lerp(tp, k)
        n.rotation.y = lerp_angle(n.rotation.y, float(r["tyaw"]), k)
        if r.has("anim"):
            if String(r["anim"]) != String(r.get("anim_logged", "")):
                r["anim_logged"] = String(r["anim"])
                Crash.mark("игрок %s: анимация %s" % [r["name"], r["anim"]])
            n.play_anim(String(r["anim"]), float(r["aspeed"]))
    if _diag_frames > 0:   # первые кадры после появления игрока — где именно падает
        _diag_frames -= 1
        Crash.mark("кадр после показа игрока, осталось %d" % _diag_frames)
    _diag_t += delta
    if _diag_t > 2.0 and Time.get_ticks_msec() / 1000.0 - _diag_start < 40.0:
        _diag_t = 0.0
        Crash.mark("память %d МБ, видео %d МБ, FPS %d, игроков %d" % [
                int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
                int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
                Engine.get_frames_per_second(), _remote.size()])



# ================================================================ онлайн: сервер — главный

var _money_ver := 0
var _sent_cash := -1
var _sent_bank := -1
var _sent_fid := "?"
var _sent_rank := -1
var _sync_t := 0.0
var _net_admin := 0
var _net_leader := false
var _homes_taken := {}
var _biz_taken := {}             # номер бизнеса -> ник владельца (чужие)
var _net_roster := {}
var _net_point := {}
var _net_target := -1


func _apply_profile(prof: Dictionary) -> void:
    family_name = String(prof.get("family", ""))
    if prof.is_empty():
        return
    _money_ver = int(prof.get("ver", 0))
    if prof.get("cash") != null:
        cash = int(prof["cash"])
        bank = int(prof.get("bank", 0))
    _sent_cash = cash
    _sent_bank = bank
    _net_admin = int(prof.get("admin", 0))
    _net_leader = prof.get("leader", false) == true
    var fid := String(prof.get("faction", ""))
    var rk := int(prof.get("rank", 0))
    if fid != faction or (fid != "" and _clamp_rank(fid, rk) != faction_rank):
        _apply_faction(fid, rk)
    _sent_fid = faction
    _sent_rank = faction_rank
    var sx := String(prof.get("sex", ""))
    if sx != "":
        _set_female(sx == "f")
    var h := int(prof.get("home", -1))
    if h != home and h < _city.homes.size():
        _set_home(h)
    _hud.set_app_visible("admin", _net_admin > 0)
    if _net_admin > 0:
        _hud.chat("У тебя админка %d уровня. Телефон → «Админ» или /help admin." % _net_admin, "warn")


## Пол персонажа: модель игрока и одежда заново.
func _set_female(on: bool) -> void:
    if on == player_female and _player != null and _player.female == on:
        return
    player_female = on
    if _player:
        _player.set_female(on)
        _equip_weapon()
        _apply_look()


func _clamp_rank(fid: String, rk: int) -> int:
    return clampi(rk, 1, FactionData.ranks(fid).size()) if fid != "" else 0


func _apply_faction(fid: String, rk: int) -> void:
    if fid == "":
        if faction != "":
            _duty.stop()
            _hud.minimap.turf = []
            _fmenu.close_menu()
            _despawn_faction_car()
            _set_faction("", 0)
    elif fid != faction:
        _set_faction(fid, _clamp_rank(fid, rk))
    else:
        faction_rank = _clamp_rank(fid, rk)
    _apply_look()
    _hud.profile.set_faction_visible(faction != "")


func _net_sync(delta: float) -> void:
    _sync_t += delta
    if _sync_t < 1.5:
        return
    _sync_t = 0.0
    if cash != _sent_cash or bank != _sent_bank:
        _sent_cash = cash
        _sent_bank = bank
        Net.send_msg({"t": "money", "cash": cash, "bank": bank, "ver": _money_ver, "src": _earn_pending})
        _earn_pending = {}
    if faction != _sent_fid or faction_rank != _sent_rank:
        _sent_fid = faction
        _sent_rank = faction_rank
        Net.send_msg({"t": "faction", "fid": faction, "rank": faction_rank})
    # кто из игроков рядом — для кнопки «ИГРОК»
    _net_target = -1
    var best := 2.6
    if _driving == null:
        for id: int in _remote:
            var r: Dictionary = _remote[id]
            if r["car"] != null or not r["seen"] or int(r.get("ride", 0)) > 0:
                continue
            var d := (r["npc"] as Node3D).global_position.distance_to(_player.global_position)
            if d < best:
                best = d
                _net_target = id
    if not _net_point.is_empty():
        _net_point["pos"] = (_remote[_net_target]["npc"] as Node3D).global_position if _net_target >= 0 else Vector3(0, -1000, 0)
        _net_point["text"] = String(_remote[_net_target]["name"]).to_upper() if _net_target >= 0 else "ИГРОК"


func _on_server_msg(m: Dictionary) -> void:
    match String(m.get("t", "")):
        "chat":
            var n := String(m.get("n", ""))
            var x := String(m.get("x", ""))
            var k := String(m.get("k", "say"))
            var kind := {"say": "say", "shout": "shout", "faction": "faction", "pm": "sms", "admin": "warn",
                    "me": "news", "info": "info"}.get(k, "info") as String
            var line := x if n == "" else "%s: %s" % [n, x]
            if k == "shout":
                line = "[всем] " + line
            elif k == "faction" and n != "":
                line = "[рация] " + line
            for part: String in line.split("\n"):
                _hud.chat(part, kind)
            if k == "pm" or k == "admin":
                Sfx.play("notify")
            if (k == "say" or k == "me") and n == "":
                _chat_bubble(x, k == "me")
        "money_set":
            cash = int(m.get("cash", cash))
            bank = int(m.get("bank", bank))
            _money_ver = int(m.get("ver", _money_ver))
            _sent_cash = cash
            _sent_bank = bank
            var msg := String(m.get("msg", ""))
            if msg != "":
                _hud.show_toast(msg, "money")
                Sfx.play("cash")
            _save_game()
        "faction_set":
            _net_leader = m.get("leader", false) == true
            _apply_faction(String(m.get("fid", "")), int(m.get("rank", 0)))
            _sent_fid = faction
            _sent_rank = faction_rank
            var fmsg := String(m.get("msg", ""))
            if fmsg != "":
                _hud.show_toast(fmsg)
                _hud.chat(fmsg, "faction")
            _save_game()
        "prof":
            var pr: Dictionary = m.get("prof", {})
            family_name = String(pr.get("family", family_name))
            var lvl := int(pr.get("admin", _net_admin))
            if lvl != _net_admin:
                _net_admin = lvl
                _hud.set_app_visible("admin", _net_admin > 0)
                _hud.chat("Уровень админки: %d" % _net_admin, "warn")
        "act":
            _on_net_act(m)
        "adm":
            _show_admin_panel(m)
        "lookup":
            _show_lookup(m.get("list", []))
        "call":
            _on_police_call(m)
        "call_taken":
            var by := String(m.get("by", ""))
            if String(m.get("from", "")) == Net.nick:
                _hud.show_toast("Вызов принял наряд: %s. Едут к тебе" % by, "money")
            else:
                _hud.chat("Рация: вызов от %s принял %s" % [m.get("from", ""), by], "faction")
        "event":
            _on_city_event(m)
        "event_end":
            _on_city_event_end(m)
        "ask":
            var aid := int(m.get("id", 0))
            _open_dialog("Предложение", String(m.get("text", "")),
                    [["Да", func() -> void:
                        _dialog.close()
                        Net.send_msg({"t": "answer", "id": aid, "ok": true})],
                    ["Нет", func() -> void:
                        _dialog.close()
                        Net.send_msg({"t": "answer", "id": aid, "ok": false})]])
            Sfx.play("notify")
        "turf":
            var mp: Dictionary = m.get("map", {})
            for key: String in mp:
                if turf.has(key):
                    turf[key] = String(mp[key])
            _refresh_turf()
        "homes":
            _homes_taken = {}
            for i: Variant in m.get("taken", []):
                _homes_taken[int(i)] = true
        "homes_upd":
            if m.get("taken", false) == true:
                _homes_taken[int(m.get("i", -1))] = true
            else:
                _homes_taken.erase(int(m.get("i", -1)))
        "pcars":
            _set_pcars(int(m.get("id", 0)), m.get("l", []))
        "bizs":
            _biz_taken = {}
            var mp: Dictionary = m.get("map", {}) if m.get("map", {}) is Dictionary else {}
            for k: String in mp:
                _biz_taken[int(k)] = String(mp[k])
            for k: String in biz_owned.keys():   # свои бизнесы из сохранения — оформить на сервере
                Net.send_msg({"t": "biz", "i": int(k), "buy": true, "claim": true})
        "biz_upd":
            if String(m.get("n", "")) != "":
                _biz_taken[int(m.get("i", -1))] = String(m["n"])
            else:
                _biz_taken.erase(int(m.get("i", -1)))
        "biz_res":
            var bi := int(m.get("i", -1))
            if m.get("ok", true) != true and biz_owned.has(str(bi)) and bi < _biz.size():
                biz_owned.erase(str(bi))
                if m.get("claim", false) == true:   # из старого сохранения: бизнес уже чужой
                    _hud.show_toast(String(m.get("msg", "Бизнес занят")))
                else:
                    bank += int(_biz[bi]["price"])
                    _bank_log(int(_biz[bi]["price"]), "Возврат: бизнес занят")
                    _hud.show_toast(String(m.get("msg", "Бизнес занят")) + " — деньги вернули на карту")
                _save_game()
        "home_res":
            if m.get("ok", true) != true and home == int(m.get("i", -2)):
                var price := int(_city.homes[home]["price"])
                _set_home(-1)
                bank += price
                _hud.show_toast(String(m.get("msg", "Жильё занято")) + " — деньги вернули на карту")
                _homes_taken[int(m.get("i", -1))] = true
        "sms":
            _sms_add(String(m.get("from", "")), String(m.get("x", "")))
            Sfx.play("notify")
        "trade_done":
            var it := String(m.get("item", ""))
            if m.get("sold", false) == true:
                inventory[it] = int(inventory.get(it, 0)) - 1
                if int(inventory[it]) <= 0:
                    inventory.erase(it)
                _hud.show_toast("«%s» — у игрока %s" % [it, m.get("who", "")], "money")
            else:
                inventory[it] = int(inventory.get(it, 0)) + 1
                _hud.show_toast("«%s» теперь в твоей сумке" % it, "money")
            _save_game()
        "port":
            port_owner = String(m.get("owner", ""))
            port_ammo = int(m.get("ammo", 0))
            port_cap = m["cap"] if m.get("cap") is Dictionary else {}
            gang_stock = int(m.get("stock", gang_stock))
            if _dialog.visible and _dialog_title() == "Порт":
                _open_port()
        "port_box":
            _port_box = m.get("on", false) == true
            if _port_box:
                Sfx.play("click")
                _hud.show_toast("Ящик патронов в руках — неси в общак своей ОПГ")
                if _city.faction_sites.has(faction):
                    _set_gps(_city.faction_sites[faction]["marker"], "Общак: сдать патроны", true)
        "ammo":
            ammo += int(m.get("n", 0))
            Sfx.play("click")
            _hud.show_toast("Патроны: +%d (всего %d)" % [int(m.get("n", 0)), ammo])
            _save_game()
        "bank_st":
            loan_due = int(m.get("loan", 0))
            loan_until = int(int(m.get("until", 0)) / 1000)
            dep_sum = int(m.get("dep", 0))
            dep_gain = int(m.get("dep_gain", 0))
            if _dialog.visible and _dialog_title() == "Банк":
                _open_bank_services()
        "lotto":
            lotto = m
            if _dialog.visible and _dialog_title() == "Спортлото":
                _open_lotto()
        "world":   # время у всех и так одно (московское), с сервера берём только погоду
            city_tax = int(m.get("tax", city_tax))
            var w := String(m.get("weather", weather))
            if w != weather and WEATHER_NAMES.has(w):
                weather = w
                _hud.show_toast("Погода: %s" % WEATHER_NAMES[weather], "weather")
                _update_daylight()
        "roster":
            _net_roster = m
            if _fmenu and _fmenu.visible:
                _fmenu.set_data(_fmenu_data())
        "tp":
            if _driving:
                _toggle_vehicle()
            _player.global_position = Vector3(float(m.get("x", 0)), float(m.get("y", 1)), float(m.get("z", 0)))
            _player.velocity = Vector3.ZERO
            _hud.show_toast("Телепорт от администратора")


func _on_net_act(m: Dictionary) -> void:
    var who := String(m.get("name", ""))
    match String(m.get("kind", "")):
        "hit":
            if _injured:
                return
            Sfx.play("hit")
            _hurt(float(m.get("dmg", 5)), "%s %s тебя!" % [who, "ударил" if m.get("melee", true) == true else "подстрелил"])
        "cuff":
            if _driving != null or _ride_id >= 0:
                _toggle_vehicle()
            _cuffed_by = int(m.get("from", -1))
            _player.frozen = true
            _hud.show_toast("%s надел на тебя наручники" % who, "warn")
            Sfx.play("lock")
        "uncuff":
            _cuffed_by = -1
            _escort_by = -1
            _player.frozen = _injured
            _player.emote = ""
            _hud.show_toast("%s снял наручники" % who)
        "follow":
            _escort_by = int(m.get("from", -1))
            _hud.show_toast("%s ведёт тебя за собой" % who, "warn")
        "unfollow":
            _escort_by = -1
        "search":
            Net.send_msg({"t": "search_res", "to": int(m.get("from", -1)), "items": _search_items()})
            _hud.show_toast("%s обыскивает тебя" % who, "warn")
        "su":
            _add_wanted(int(m.get("stars", 1)), String(m.get("why", "по ориентировке")))
            _hud.show_toast("%s объявил тебя в розыск: %s" % [who, m.get("why", "")], "warn")
        "revive":
            _end_injured()
            health = 40.0
            Sfx.play("heal")
            _dialog.close()
            _hud.show_toast("Врач %s оказал тебе помощь. Здоровье 40 — долечись в больнице" % who, "money")
        "jail":
            _court_jail(float(m.get("sec", 60)), String(m.get("why", "")))
        "free":
            if jail_left > 0.0:
                jail_left = 0.01
                _hud.show_toast("%s: ты освобождён" % who, "money")
        "medcard":
            med_card = true
            _hud.show_toast("Медкарта получена: годен", "money")
            _save_game()
        "gunlic":
            gun_license = true
            _hud.show_toast("Лицензия на оружие получена", "money")
            _save_game()
        "arrest":
            _hud.chat("Тебя задержал сотрудник %s" % who, "warn")
            _arrest()
        "heal":
            _end_injured()
            health = 100.0
            Sfx.play("heal")
            _hud.show_toast("%s вылечил тебя" % who)
        "admin_heal":
            health = 100.0
            hunger = 100.0
            Sfx.play("heal")
            _hud.show_toast("Администратор %s восстановил тебе здоровье" % who)
        "freeze":
            if _driving != null or _ride_id >= 0:
                _toggle_vehicle()     # выйти из машины
            _player.frozen = true
            _hud.show_toast("Администратор %s заморозил тебя. Жди, с тобой свяжутся." % who, "warn")
            Sfx.play("notify")
        "unfreeze":
            _player.frozen = false
            _hud.show_toast("Ты разморожен")


## Попали ли мы ударом/выстрелом в другого игрока. true — попали (сервер передаст урон).
func _net_hit(origin: Vector3, dir: Vector3, reach: float, cone: float, melee: bool) -> bool:
    var best := -1
    var best_d := reach
    for id: int in _remote:
        var r: Dictionary = _remote[id]
        if r["car"] != null or not r["seen"]:
            continue
        var to: Vector3 = (r["npc"] as Node3D).global_position + Vector3(0, 1.1, 0) - origin
        var d := to.length()
        if d > best_d or d < 0.1:
            continue
        if rad_to_deg(dir.angle_to(to)) > cone * 0.5 + 6.0:
            continue
        best = id
        best_d = d
    if best < 0:
        return false
    var dmg := 6 + int(float(skills["strength"]) / 10.0) if melee else 18 + int(float(skills["shooting"]) / 8.0)
    Net.send_msg({"t": "act", "to": best, "kind": "hit", "dmg": dmg, "melee": melee})
    return true


func _open_player_menu() -> void:
    if _net_target < 0 or not _remote.has(_net_target):
        return
    var id := _net_target
    var r: Dictionary = _remote[id]
    var fid := String(r.get("fid", ""))
    var w := int(r.get("wanted", 0))
    var text := "Организация: %s" % (FactionData.get_faction(fid).get("name", "нет") if fid != "" else "нет")
    if w > 0:
        text += "\nВ розыске: %s" % "★".repeat(w)
    var buttons := [["Передать деньги", _give_money_dialog.bind(id)],
            ["Попросить паспорт", _net_act.bind(id, "passport")]]
    buttons.append_array(_rp_player_buttons(id, r))
    if (FactionData.base(faction) == "police" or faction == "kgb") and w > 0:
        buttons.insert(0, ["Задержать", _net_act.bind(id, "arrest")])
    if FactionData.base(faction) == "hospital":
        buttons.append(["Предложить лечение (300 ₽)", _net_act.bind(id, "heal")])
    if faction != "" and fid == "" and (_net_leader or _net_admin >= 3):
        buttons.append(["Пригласить в организацию", _net_act.bind(id, "invite")])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog(String(r["name"]), text, buttons)


func _net_act(id: int, kind: String) -> void:
    _dialog.close()
    Net.send_msg({"t": "act", "to": id, "kind": kind})


func _give_money_dialog(id: int) -> void:
    _open_dialog("Передать деньги", "Сколько наличных передать игроку %s?" % _remote[id]["name"],
            [["Передать", func() -> void:
                var amount := int(_dialog.input_text())
                _dialog.close()
                if amount <= 0 or amount > cash:
                    _hud.show_toast("Неверная сумма или не хватает наличных")
                    return
                _sync_t = 99.0
                _net_sync(0.0)   # сначала сервер узнаёт наши деньги, потом — перевод
                Net.send_msg({"t": "give", "to": id, "amount": amount})],
            ["Отмена", _dialog.close]], "Сумма, ₽")


func _org_info_online() -> Dictionary:
    var top := FactionData.ranks(faction).size()
    var roster: Array = []
    var online_n := 0
    for e: Variant in _net_roster.get("list", []):
        var d: Dictionary = e
        var rk := clampi(int(d.get("rank", 1)), 1, top)
        var lead: bool = d.get("leader", false) == true
        var on: bool = d.get("online", false) == true
        if on:
            online_n += 1
        roster.append({"name": String(d.get("nick", "")), "rank": rk, "online": on, "me": String(d.get("nick", "")) == Net.nick,
                "role": "Лидер" if lead else FactionData.rank_name(rk, faction)})
    var sd := absi(hash(faction))
    return {"roster": roster, "members": roster.size(), "online": online_n, "cap": ORG_CAP,
            "leader": String(_net_roster.get("leader", "")) if String(_net_roster.get("leader", "")) != "" else "нет (назначает администрация)",
            "rating": HudScript.format_money(5000 + roster.size() * 250 + (_turf_count(faction) * 800 if FactionData.is_gang(faction) else 0)).replace(" ₽", "").replace("₽", "").strip_edges(),
            "created": "%02d.%02d.%d" % [1 + sd % 28, 1 + (sd / 28) % 12, 1971 + (sd / 336) % 15]}


# ================================================================ порт: склад патронов ОПГ

func _needs_ammo(wid: String) -> bool:
    return FactionData.is_gang(faction) and wid in ["nagant", "obrez", "ak"]


func _gang_title(gid: String) -> String:
    return String(FactionData.get_faction(gid).get("name", gid)) if gid != "" else "никто"


func _open_port() -> void:
    var gang := FactionData.is_gang(faction)
    var text := "Склад № 3. Сюда теплоходы привозят патроны.\nДержит склад: %s\nПатронов на складе: %d (теплоход подвозит понемногу)" % [_gang_title(port_owner), port_ammo]
    if not port_cap.is_empty():
        text += "\n\n⚠ ИДЁТ ШТУРМ: %s, осталось %d с" % [_gang_title(String(port_cap.get("gid", ""))), int(port_cap.get("left", 0))]
    var buttons := []
    if gang:
        if port_owner == faction:
            text += "\n\nСклад ваш. Бери ящик (50 патронов) и неси в общак на базу."
            if not _port_box:
                buttons.append(["Взять ящик патронов", _port_load])
        elif port_cap.is_empty():
            text += "\n\nЗахват: держитесь у склада 90 секунд. Если защитников больше — время стоит."
            buttons.append(["Захватить склад", _port_capture])
    elif FactionData.base(faction) == "police" or faction == "kgb":
        text += "\n\nЗа складом следят ОПГ. Штурм — повод выехать нарядом."
    else:
        text += "\n\nПосторонним тут лучше не задерживаться."
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Порт", text, buttons)


func _port_capture() -> void:
    _dialog.close()
    if Net.authed:
        Net.send_msg({"t": "port", "a": "cap"})
        return
    port_cap = {"gid": faction, "left": 90}
    _add_wanted(1, "захват склада")
    Sfx.play("notify")
    _hud.show_toast("ШТУРМ СКЛАДА! Держись у склада 90 секунд")


func _port_load() -> void:
    _dialog.close()
    if Net.authed:
        Net.send_msg({"t": "port", "a": "load"})
        return
    if port_ammo < 50:
        _hud.show_toast("На складе пусто — ждите теплоход")
        return
    port_ammo -= 50
    _on_net_msg_local({"t": "port_box", "on": true})


## Офлайн: те же сообщения, что прислал бы сервер.
func _on_net_msg_local(m: Dictionary) -> void:
    match String(m["t"]):
        "port_box":
            _port_box = m.get("on", false) == true
            if _port_box:
                Sfx.play("click")
                _hud.show_toast("Ящик патронов в руках — неси в общак своей ОПГ")
                if _city.faction_sites.has(faction):
                    _set_gps(_city.faction_sites[faction]["marker"], "Общак: сдать патроны", true)


func _port_deliver() -> void:
    _dialog.close()
    if not _port_box:
        return
    _port_box = false
    if Net.authed:
        Net.send_msg({"t": "port", "a": "deliver"})
    else:
        gang_stock += 50
    faction_exp += 1
    Sfx.play("coin")
    _hud.show_toast("Ящик в общаке: +50 патронов для своих")
    _save_game()


func _port_take() -> void:
    _dialog.close()
    if Net.authed:
        Net.send_msg({"t": "port", "a": "take", "n": 30})
        return
    if gang_stock <= 0:
        _hud.show_toast("В общаке нет патронов — везите из порта")
        return
    var got := mini(30, gang_stock)
    gang_stock -= got
    ammo += got
    _hud.show_toast("Патроны: +%d (всего %d)" % [got, ammo])
    _save_game()


func _update_port(delta: float) -> void:
    if not _started:
        return
    if _port_box and (_injured or jail_left > 0.0 or not FactionData.is_gang(faction)):
        _port_box = false
        if Net.authed:
            Net.send_msg({"t": "port", "a": "drop"})
        _hud.show_toast("Ящик патронов потерян")
    _port_toast_t -= delta
    if not port_cap.is_empty() and String(port_cap.get("gid", "")) == faction and _port_toast_t <= 0.0:
        _port_toast_t = 10.0
        _hud.show_toast("Штурм склада: осталось %d с — не уходите из порта" % int(port_cap.get("left", 0)))
    if Net.authed:
        return
    # офлайн: теплоход, штурм, другие банды
    _port_t += delta
    if _port_t >= 60.0:
        _port_t = 0.0
        port_ammo = mini(400, port_ammo + 5)
    if not port_cap.is_empty():
        if _player.global_position.distance_to(_city.port_store) > 45.0:
            port_cap = {}
            Sfx.play("error")
            _hud.show_toast("Штурм сорван: ты ушёл из порта")
            return
        port_cap["left"] = float(port_cap["left"]) - delta
        if float(port_cap["left"]) <= 0.0:
            port_owner = faction
            port_cap = {}
            Sfx.play("levelup")
            _hud.show_toast("Склад в порту теперь ваш! Возите патроны в общак")
            _save_game()


# ================================================================ ГАИ: учёт, техосмотр, штрафстоянка

const PLATE_ABC := "АВЕКМНОРСТУХ"


func _gai_plate() -> String:
    var l := func() -> String: return PLATE_ABC[randi() % PLATE_ABC.length()]
    return "%s%03d%s%s 16" % [l.call(), randi_range(1, 999), l.call(), l.call()]


func _open_gai() -> void:
    var car = _driving
    if car == null or not car.owned or car == _work_vehicle or car == _faction_car or car == _rent_scooter:
        _open_dialog("ГАИ", "Регистрационно-экзаменационное отделение ГАИ.\nПриезжай на своей машине: учёт и техосмотр.", [["Закрыть", _dialog.close]])
        return
    var to_left: int = GAI_TO_DAYS - (day - int(car.inspect_day))
    var to_text := "без срока" if car.inspect_day >= 100000 else ("до дня %d" % (int(car.inspect_day) + GAI_TO_DAYS) if to_left >= 0 else "ПРОСРОЧЕН")
    var text := "%s\nНомер: %s\nНа учёте: %s\nТехосмотр: %s\n\nБез номеров ДПС штрафует, а машину могут эвакуировать на штрафстоянку в порту." % [
            car.car_name, car.plate_text if car.plate_text != "" else "нет", "да" if car.registered else "НЕТ", to_text]
    var buttons := []
    if not car.registered:
        buttons.append(["Поставить на учёт — %s" % HudScript.format_money(GAI_REG_PRICE), _gai_register])
    if car.inspect_day < 100000 and to_left < GAI_TO_DAYS - 2:
        buttons.append(["Техосмотр — %s" % HudScript.format_money(GAI_TO_PRICE), _gai_inspect])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("ГАИ", text, buttons)


func _gai_register() -> void:
    var car = _driving
    if car == null or not _pay(GAI_REG_PRICE, "ГАИ: учёт"):
        return
    car.registered = true
    if car.plate_text == "":
        car.plate_text = _gai_plate()
    car.inspect_day = day
    car.apply_tuning()
    Sfx.play("cash")
    _hud.show_toast("Машина на учёте. Номер: %s. Техосмотр на %d дней" % [car.plate_text, GAI_TO_DAYS])
    _save_game()
    _open_gai()


func _gai_inspect() -> void:
    var car = _driving
    if car == null:
        return
    if car.condition < 60.0:
        Sfx.play("error")
        _hud.show_toast("Техосмотр не пройден: машина побита (%d%%). Сначала на СТО" % int(car.condition))
        return
    if not _pay(GAI_TO_PRICE, "ГАИ: техосмотр"):
        return
    car.inspect_day = day
    Sfx.play("cash")
    _hud.show_toast("Техосмотр пройден на %d дней" % GAI_TO_DAYS)
    _save_game()
    _open_gai()


## Машины без номеров, брошенные в городе, иногда увозит эвакуатор.
func _update_evac(delta: float) -> void:
    if not _started:
        return
    _evac_t += delta
    if _evac_t < 60.0:
        return
    _evac_t = 0.0
    var k := 0
    for car in _cars:
        if not car.owned or car.registered or car.impounded or car == _driving or not car.visible:
            continue
        if car.global_position.distance_to(_player.global_position) < 60.0 or randf() > 0.05:
            continue
        car.impounded = true
        car.reset_to(Transform3D(Basis(), _city.impound_lot + Vector3(-5.0 + k * 3.2, 0.5, 0.0)))
        k += 1
        Sfx.play("notify")
        _sms_add("ГАИ", "Ваша машина без номеров (%s) эвакуирована на штрафстоянку в порту. Забрать — %s." % [car.car_name,
                HudScript.format_money(IMPOUND_PRICE)])
        _save_game()


func _open_impound() -> void:
    var buttons := []
    for car in _cars:
        if car.owned and car.impounded:
            buttons.append(["Забрать %s — %s" % [car.car_name, HudScript.format_money(IMPOUND_PRICE)], _impound_take.bind(car)])
    buttons.append(["Закрыть", _dialog.close])
    _open_dialog("Штрафстоянка", "Сюда эвакуируют машины без номеров.\n%s" % ("Твоих машин тут нет." if buttons.size() == 1 else
            "Заплати и забирай. И поставь машину на учёт в ГАИ у УВД!"), buttons)


func _impound_take(car) -> void:
    if not _pay(IMPOUND_PRICE, "Штрафстоянка"):
        return
    car.impounded = false
    Sfx.play("cash")
    _hud.show_toast("%s свободна — стоит на штрафстоянке" % car.car_name)
    _save_game()
    _open_impound()


# ================================================================ банк: кредит, вклад, выручка бизнесов

func _now_unix() -> int:
    return int(Time.get_unix_time_from_system())


func _open_bank_services() -> void:
    var gain := dep_gain if Net.authed else _dep_gain_local()
    var text := "Кредит: до %s, +10 %%, на 3 дня. Просрочка — банк спишет сам и добавит 10 %%.\nВклад: +1 %% в час (не больше +30 %%).\n\n" % HudScript.format_money(LOAN_MAX)
    if loan_due > 0:
        var left := maxi(0, loan_until - _now_unix())
        text += "Твой кредит: вернуть %s, осталось %d ч %d мин\n" % [HudScript.format_money(loan_due), left / 3600, (left % 3600) / 60]
    if dep_sum > 0:
        text += "Вклад: %s (+%s)\n" % [HudScript.format_money(dep_sum), HudScript.format_money(gain)]
    var till := 0
    for k: String in biz_owned:
        till += int(biz_owned[k])
    if not biz_owned.is_empty():
        text += "Выручка в кассах бизнесов: %s\n" % HudScript.format_money(till)
    var buttons := []
    if loan_due <= 0:
        buttons.append(["Кредит 10 000 ₽", _bank_op.bind("loan", 10000)])
        buttons.append(["Кредит 50 000 ₽", _bank_op.bind("loan", 50000)])
    else:
        buttons.append(["Погасить кредит", _bank_op.bind("repay", 0)])
    buttons.append(["На вклад 10 000 ₽", _bank_op.bind("dep", 10000)])
    if bank >= 1000:
        buttons.append(["На вклад всё с карты", _bank_op.bind("dep", bank)])
    if dep_sum > 0:
        buttons.append(["Закрыть вклад", _bank_op.bind("wd", 0)])
    if till > 0:
        buttons.append(["Выручку бизнесов — на карту", _bank_biz_collect])
    buttons.append(["Назад", _open_atm])
    _open_dialog("Банк", text, buttons)


func _dep_gain_local() -> int:
    if dep_sum <= 0:
        return 0
    return int(dep_sum * minf(0.30, 0.01 * float(_now_unix() - dep_t) / 3600.0))


func _bank_op(op: String, sum: int) -> void:
    if Net.authed:
        _flush_money_now()
        Net.send_msg({"t": "bank", "a": op, "sum": sum})
        return
    match op:
        "loan":
            if loan_due > 0:
                return
            bank += sum
            loan_due = int(ceil(sum * 1.1))
            loan_until = _now_unix() + 3 * 86400
            _bank_log(sum, "Кредит")
            _hud.show_toast("Кредит %s на карту. Вернуть %s за 3 дня" % [HudScript.format_money(sum), HudScript.format_money(loan_due)], "money")
        "repay":
            var pay := mini(loan_due, cash + bank)
            if pay <= 0 or not _pay(pay, "Погашение кредита"):
                return
            loan_due -= pay
            _hud.show_toast("Кредит погашен" if loan_due <= 0 else "Осталось вернуть %s" % HudScript.format_money(loan_due), "money")
        "dep":
            if sum < 1000 or sum > bank:
                _hud.show_toast("На карте не хватает")
                return
            dep_sum += _dep_gain_local() + sum
            dep_t = _now_unix()
            bank -= sum
            _bank_log(-sum, "Вклад")
            _hud.show_toast("На вкладе %s" % HudScript.format_money(dep_sum), "money")
        "wd":
            var total := dep_sum + _dep_gain_local()
            bank += total
            dep_sum = 0
            _bank_log(total, "Вклад закрыт")
            _hud.show_toast("Вклад закрыт: %s на карту" % HudScript.format_money(total), "money")
    Sfx.play("cash")
    _save_game()
    _open_bank_services()


## Онлайн: перед операцией в банке — отправить серверу свежие деньги.
func _flush_money_now() -> void:
    if cash != _sent_cash or bank != _sent_bank:
        _sent_cash = cash
        _sent_bank = bank
        Net.send_msg({"t": "money", "cash": cash, "bank": bank, "ver": _money_ver, "src": _earn_pending})
        _earn_pending = {}


func _bank_biz_collect() -> void:
    var total := 0
    for k: String in biz_owned.keys():
        total += int(biz_owned[k])
        biz_owned[k] = 0
    if total <= 0:
        return
    bank += total
    _earned("biz", total)
    _bank_log(total, "Выручка бизнесов")
    Sfx.play("cash")
    _hud.show_toast("Выручка +%s на карту" % HudScript.format_money(total), "money")
    _save_game()
    _open_bank_services()


## Офлайн: просрочка кредита.
func _check_loan_local() -> void:
    if Net.authed or loan_due <= 0 or _now_unix() < loan_until:
        return
    var pay := mini(loan_due, cash + bank)
    if pay > 0:
        _pay(pay, "Просроченный кредит")
    loan_due -= pay
    if loan_due > 0:
        loan_due = int(ceil(loan_due * 1.1))
        loan_until = _now_unix() + 86400
        _sms_add("Банк", "Просрочка кредита! Долг %s (+10 %%), срок — сутки." % HudScript.format_money(loan_due))
    else:
        _sms_add("Банк", "Просроченный кредит списан с карты.")
    _save_game()


# ================================================================ лотерея «Спортлото 3 из 20»

func _lotto_next_local() -> int:
    var s := 1800
    return int(ceil(float(_now_unix() + 1) / s)) * s - _now_unix()


func _open_lotto() -> void:
    if Net.authed and lotto.is_empty():
        Net.send_msg({"t": "lotto", "a": "state"})
    var next := int(lotto.get("next", _lotto_next_local())) if Net.authed else _lotto_next_local()
    var pool := int(lotto.get("pool", 10000))
    var mine: Array = lotto.get("my", []) if Net.authed else lotto_mine
    var text := "«Спортлото 3 из 20». Билет %s.\nУгадай 3 числа: 3 — джекпот (%s), 2 — 1 000 ₽, 1 — 200 ₽.\nРозыгрыш через %d:%02d — нужно быть в игре.\n" % [
            HudScript.format_money(LOTTO_PRICE), HudScript.format_money(pool), next / 60, next % 60]
    if not mine.is_empty():
        var ts := []
        for t in mine:
            ts.append("-".join((t as Array).map(func(x) -> String: return str(x))))
        text += "\nТвои билеты: %s" % ", ".join(ts)
    var last = lotto.get("last", null)
    if last is Dictionary:
        text += "\nПрошлый тираж: %s" % ", ".join((last["nums"] as Array).map(func(x) -> String: return str(int(x))))
    _open_dialog("Спортлото", text, [["Билет: случайные числа", _lotto_buy.bind([])],
            ["Билет: свои числа", func() -> void:
                var t := _dialog.input_text()
                var nums: Array = []
                for p in t.replace(",", " ").split(" ", false):
                    nums.append(int(p))
                _lotto_buy(nums)],
            ["Закрыть", _dialog.close]], "три числа 1–20 через пробел")


func _lotto_buy(nums: Array) -> void:
    if nums.is_empty():
        var pool := range(1, 21)
        pool.shuffle()
        nums = pool.slice(0, 3)
    var uniq := {}
    for n in nums:
        if int(n) >= 1 and int(n) <= 20:
            uniq[int(n)] = true
    if uniq.size() != 3:
        Sfx.play("error")
        _hud.show_toast("Нужно 3 разных числа от 1 до 20")
        return
    var list: Array = uniq.keys()
    list.sort()
    if Net.authed:
        _flush_money_now()
        Net.send_msg({"t": "lotto", "a": "buy", "nums": list})
        Sfx.play("click")
        return
    if lotto_mine.size() >= 5:
        _hud.show_toast("Не больше 5 билетов на тираж")
        return
    if not _pay(LOTTO_PRICE, "Спортлото"):
        return
    lotto_mine.append(list)
    Sfx.play("click")
    _hud.show_toast("Билет %s куплен" % "-".join(list.map(func(x) -> String: return str(x))))
    _open_lotto()


var _lotto_draw_at := 0

## Офлайн-тираж: в :00 и :30.
func _lotto_local_tick() -> void:
    if Net.authed:
        return
    var at := _now_unix() + _lotto_next_local()
    if _lotto_draw_at == 0:
        _lotto_draw_at = at
        return
    if _now_unix() < _lotto_draw_at:
        return
    _lotto_draw_at = at
    if lotto_mine.is_empty():
        return
    var pool := range(1, 21)
    pool.shuffle()
    var win: Array = pool.slice(0, 3)
    win.sort()
    var prize := 0
    for t in lotto_mine:
        var hit := 0
        for x in t:
            if x in win:
                hit += 1
        prize += [0, 200, 1000, 10000][hit]
    lotto_mine.clear()
    lotto = {"last": {"nums": win}}
    if prize > 0:
        bank += prize
        _earned("casino", prize)
        _bank_log(prize, "Спортлото")
    _sms_add("Спортлото", "Тираж: %s. %s" % [", ".join(win.map(func(x) -> String: return str(x))),
            "Выигрыш %s на карту!" % HudScript.format_money(prize) if prize > 0 else "В этот раз без выигрыша."])
