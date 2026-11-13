extends Node
## Звуки игры. Глобальный объект Sfx (autoload): Sfx.play("coin"), Sfx.play_at("horn", pos).
## Все звуки лежат в sounds/*.wav — они синтезированы заранее скриптом tools/audio/gen_sfx.py
## (мягкие, без писка: верх срезан фильтрами).
##
## Шины звука (создаются здесь же):
##   SFX     — эффекты; в помещении включается эхо (реверберация комнаты/подъезда)
##   Ambient — фон улицы; в помещении глушится фильтром, как через стену
##   Music   — музыка и радио
## Фон: гул города, днём голуби/воробьи/вороны, ночью сверчки и далёкий лай собак.

const SOUNDS := [
    "click", "notify", "error", "coin", "cash", "levelup", "phone", "radio_tune",
    "step", "step2", "step3", "hit", "swing", "eat", "drink", "heal", "faint", "heartbeat",
    "shot", "shot_heavy", "horn", "train_horn", "station", "whistle", "car_door", "lock", "engine_start", "scooter_start",
    "door", "pigeon", "sparrow", "crow", "dog", "crickets", "rumble", "rain", "thunder", "siren",
]
const LOOPS := ["crickets", "rumble", "rain", "siren"]

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next3d := 0
var _rumble: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _bird_timer := 5.0
var _dog_timer := 20.0
var _rng := RandomNumberGenerator.new()
var night := 0.0   # 0 — день, 1 — ночь (задаёт main.gd)
var ambient_on := false
var indoor := false          # игрок в помещении (задаёт main.gd)
var _indoor_k := 0.0
var _reverb: AudioEffectReverb
var _muffle: AudioEffectLowPassFilter


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # клики в меню звучат и на паузе
    _rng.randomize()
    _setup_buses()
    for n: String in SOUNDS:
        var path := "res://sounds/%s.wav" % n
        if ResourceLoader.exists(path):
            var s: AudioStream = load(path)
            if n in LOOPS and s is AudioStreamWAV:
                var w := s as AudioStreamWAV
                w.loop_mode = AudioStreamWAV.LOOP_FORWARD
                w.loop_begin = 0
                w.loop_end = int(w.get_length() * w.mix_rate)
            _sounds[n] = s
    for i in 8:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _players.append(p)
    for i in 6:
        var p3 := AudioStreamPlayer3D.new()
        p3.unit_size = 12.0
        p3.max_distance = 140.0
        p3.bus = "SFX"
        p3.process_mode = Node.PROCESS_MODE_PAUSABLE
        add_child(p3)
        _players3d.append(p3)

    _rumble = _bg("rumble", -20.0)
    _crickets = _bg("crickets", -80.0)
    _amb = AudioStreamPlayer.new()
    _amb.bus = "Ambient"
    _amb.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(_amb)


func _bg(sound: String, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = _sounds.get(sound, null)
    p.volume_db = db
    p.bus = "Ambient"
    p.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(p)
    return p


func _setup_buses() -> void:
    for b: String in ["SFX", "Ambient", "Music"]:
        if AudioServer.get_bus_index(b) == -1:
            AudioServer.add_bus()
            var i := AudioServer.bus_count - 1
            AudioServer.set_bus_name(i, b)
            AudioServer.set_bus_send(i, "Master")
    _reverb = AudioEffectReverb.new()
    _reverb.room_size = 0.45
    _reverb.damping = 0.6
    _reverb.wet = 0.0
    _reverb.dry = 1.0
    _reverb.hipass = 0.15
    AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), _reverb)
    _muffle = AudioEffectLowPassFilter.new()
    _muffle.cutoff_hz = 16000.0
    AudioServer.add_bus_effect(AudioServer.get_bus_index("Ambient"), _muffle)
    # мягкий лимитер на общем выходе — громкие звуки не хрипят на телефоне
    var lim := AudioEffectLimiter.new()
    lim.ceiling_db = -0.5
    lim.threshold_db = -3.0
    AudioServer.add_bus_effect(0, lim)


## Включить фоновые звуки города (после старта игры).
func start_ambient() -> void:
    if ambient_on:
        return
    ambient_on = true
    _rumble.play()
    _crickets.play()


func _process(delta: float) -> void:
    # помещение: эхо комнаты на эффектах и улица «за стеной»
    _indoor_k = move_toward(_indoor_k, 1.0 if indoor else 0.0, delta * 2.5)
    _reverb.wet = 0.22 * _indoor_k
    _muffle.cutoff_hz = lerpf(16000.0, 650.0, _indoor_k)
    if not ambient_on or get_tree().paused:
        return
    var night_k := clampf(night * 1.4 - 0.4, 0.0, 1.0)
    _crickets.volume_db = linear_to_db(maxf(0.0005, night_k * 0.16))
    _rumble.volume_db = lerpf(-20.0, -25.0, night_k)
    _bird_timer -= delta
    if _bird_timer <= 0.0:
        _bird_timer = _rng.randf_range(5.0, 12.0)
        if night < 0.3:
            var r := _rng.randf()
            if r < 0.45:
                _ambient("pigeon", _rng.randf_range(-20.0, -14.0), _rng.randf_range(0.92, 1.08))
            elif r < 0.75:
                _ambient("sparrow", _rng.randf_range(-26.0, -20.0), _rng.randf_range(0.9, 1.05))
            else:
                _ambient("crow", _rng.randf_range(-22.0, -16.0), _rng.randf_range(0.9, 1.05))
    _dog_timer -= delta
    if _dog_timer <= 0.0:
        _dog_timer = _rng.randf_range(18.0, 45.0)
        if night > 0.5 or _rng.randf() < 0.25:
            _ambient("dog", _rng.randf_range(-22.0, -15.0), _rng.randf_range(0.88, 1.1))


func _ambient(sound: String, db: float, pitch: float) -> void:
    if not _sounds.has(sound):
        return
    _amb.stream = _sounds[sound]
    _amb.volume_db = db
    _amb.pitch_scale = pitch
    _amb.play()


## Звук по имени (для своих плееров, например сирены в машине). null — нет такого.
func get_sound(sound: String) -> AudioStream:
    return _sounds.get(sound, null)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
    if not _sounds.has(sound):
        return
    var p := _players[_next]
    _next = (_next + 1) % _players.size()
    p.stream = _sounds[sound]
    p.volume_db = volume_db
    p.pitch_scale = pitch
    p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
    if not _sounds.has(sound):
        return
    var p := _players3d[_next3d]
    _next3d = (_next3d + 1) % _players3d.size()
    p.stream = _sounds[sound]
    p.global_position = pos
    p.volume_db = volume_db
    p.pitch_scale = pitch
    p.play()
