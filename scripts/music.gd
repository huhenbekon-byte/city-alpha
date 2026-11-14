extends Node
## Музыка: темы главного меню, радио в машине (11 станций) и саундтрек погони.
## Глобальный Music. Радио «живое»: включаешь станцию — играет с того места, где она сейчас в эфире.
## Новые треки сочинены и синтезированы скриптом tools/audio/gen_music.py.

const STATIONS := [
    {"name": "Маяк — вечерний эфир", "file": "radio_mayak"},
    {"name": "Эстрада 80-х", "file": "radio_estrada"},
    {"name": "Дворовая гитара", "file": "radio_dvor"},
    {"name": "Юность — рок-клуб", "file": "radio_rock"},
    {"name": "Дискотека 80-х", "file": "radio_disco"},
    {"name": "Духовой оркестр в парке", "file": "radio_march"},
    {"name": "Ресторан «Кавказ»", "file": "radio_kavkaz"},
    {"name": "Ретро Волна", "file": "radio_retro"},
    {"name": "Ночной драйв FM", "file": "radio_synthwave"},
    {"name": "Район FM", "file": "radio_phonk"},
    {"name": "Лоу-фай 101", "file": "radio_lofi"},
]
const MENU_THEMES := ["menu2", "menu"]

var volume := 0.6          # 0..1, из настроек
var station := 0           # текущая станция, -1 — радио выключено
var _streams := {}
var _player: AudioStreamPlayer
var _mode := ""            # "menu" / "radio" / "score" / ""
var _score := ""
var _target := 0.0         # громкость, к которой плавно идём (0..1)
var _level := 0.0
var _menu_i := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # играет и на паузе (в меню)
    _player = AudioStreamPlayer.new()
    if AudioServer.get_bus_index("Music") != -1:
        _player.bus = "Music"
    add_child(_player)
    _menu_i = randi() % MENU_THEMES.size()


func _stream(file: String) -> AudioStream:
    if not _streams.has(file):
        var path := "res://music/%s.ogg" % file
        var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
        if s is AudioStreamOggVorbis:
            (s as AudioStreamOggVorbis).loop = true
        _streams[file] = s
    return _streams[file]


func _start(file: String, live: bool) -> void:
    var s := _stream(file)
    if s == null:
        _player.stop()
        return
    if _player.stream != s or not _player.playing:
        _player.stream = s
        var from := 0.0
        if live:
            from = fmod(Time.get_ticks_msec() / 1000.0, maxf(1.0, s.get_length()))
        _player.play(from)
        _level = 0.0
    _target = 1.0


## Тема меню: при каждом заходе в меню — следующая из двух.
func play_menu() -> void:
    if _mode != "menu":
        _menu_i = (_menu_i + 1) % MENU_THEMES.size()
    _mode = "menu"
    _start(String(MENU_THEMES[_menu_i]), false)


func play_radio() -> void:
    _mode = "radio"
    if station < 0:
        _target = 0.0
        return
    _start(String(STATIONS[station]["file"]), true)


## Радиола дома: следующая станция по кругу, после последней — выкл. Возвращает подсказку.
var home_station := -1


func home_next() -> String:
    home_station += 1
    if home_station >= STATIONS.size():
        home_station = -1
        stop()
        return "Радиола выключена"
    _mode = "home"
    _player.stop()
    _start(String(STATIONS[home_station]["file"]), true)
    return "Радиола: " + String(STATIONS[home_station]["name"])


func stop_home() -> void:
    if _mode == "home":
        home_station = -1
        stop()


## Музыка места (дискотека в ДК): важнее всего, пока игрок внутри.
func play_place(file: String) -> void:
    if _mode == "place" and _score == file:
        return
    _mode = "place"
    _score = file
    _player.stop()
    _start(file, true)


func stop_place() -> void:
    if _mode == "place":
        stop()


## Саундтрек ситуации (например, "score_chase" при розыске). Радио в машине и радиола важнее.
func play_score(file: String) -> void:
    if _mode == "radio" or _mode == "home" or _mode == "place" or (_mode == "score" and _score == file):
        return
    _mode = "score"
    _score = file
    _start(file, false)


func stop_score() -> void:
    if _mode == "score":
        stop()


## Плавно выключить (вышли из машины, начали игру).
func stop() -> void:
    _mode = ""
    _score = ""
    _target = 0.0


func is_radio() -> bool:
    return _mode == "radio"


func is_score() -> bool:
    return _mode == "score"


## Следующая станция (после последней — «выкл»). Возвращает название для подсказки.
func next_station() -> String:
    station += 1
    if station >= STATIONS.size():
        station = -1
    if _mode == "radio":
        _player.stop()
        play_radio()
    return "Радио выключено" if station < 0 else "Радио: " + String(STATIONS[station]["name"])


func _process(delta: float) -> void:
    _level = move_toward(_level, _target, delta * (0.6 if _target > _level else 1.2))
    if _level <= 0.001 and _target == 0.0:
        if _player.playing:
            _player.stop()
        return
    var base := 0.7
    if _mode == "radio":
        base = 0.55
    elif _mode == "score":
        base = 0.45
    elif _mode == "home":
        base = 0.5
    elif _mode == "place":
        base = 0.75
    _player.volume_db = linear_to_db(maxf(0.0001, _level * volume * base))
