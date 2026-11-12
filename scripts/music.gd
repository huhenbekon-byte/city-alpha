extends Node
## Музыка: тема главного меню и радио в машине (6 станций). Глобальный Music.
## Радио «живое»: включаешь станцию — играет с того места, где она сейчас в эфире.

const STATIONS := [
    {"name": "Ночной драйв FM", "file": "radio_synthwave"},
    {"name": "Район FM", "file": "radio_phonk"},
    {"name": "Лоу-фай 101", "file": "radio_lofi"},
    {"name": "Ретро Волна", "file": "radio_retro"},
    {"name": "Эстрада 80-х", "file": "radio_estrada"},
    {"name": "Маяк — вечерний эфир", "file": "radio_mayak"},
]

var volume := 0.6          # 0..1, из настроек
var station := 0           # текущая станция, -1 — радио выключено
var _streams := {}
var _player: AudioStreamPlayer
var _mode := ""            # "menu" / "radio" / ""
var _target := 0.0         # громкость, к которой плавно идём (0..1)
var _level := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # играет и на паузе (в меню)
    _player = AudioStreamPlayer.new()
    add_child(_player)


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


func play_menu() -> void:
    _mode = "menu"
    _start("menu", false)


func play_radio() -> void:
    _mode = "radio"
    if station < 0:
        _target = 0.0
        return
    _start(String(STATIONS[station]["file"]), true)


## Плавно выключить (вышли из машины, начали игру).
func stop() -> void:
    _mode = ""
    _target = 0.0


func is_radio() -> bool:
    return _mode == "radio"


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
    var base := 0.55 if _mode == "radio" else 0.7
    _player.volume_db = linear_to_db(maxf(0.0001, _level * volume * base))
