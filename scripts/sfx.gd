extends Node
## Все звуки игры синтезируются прямо в коде — аудиофайлы не нужны.
## Глобальный объект Sfx (autoload): Sfx.play("coin"), Sfx.play_at("horn", pos).
## Фон: гул города (всегда), птицы днём, сверчки ночью.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next3d := 0
var _rumble: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _bird_timer := 5.0
var _rng := RandomNumberGenerator.new()
var night := 0.0   # 0 — день, 1 — ночь (задаёт main.gd)
var ambient_on := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # клики в меню звучат и на паузе
    _rng.seed = 7
    _sounds["step"] = _make_step()
    _sounds["horn"] = _make_horn()
    _sounds["coin"] = _make_coin()
    _sounds["click"] = _make_tone([900.0], 0.045, 0.35)
    _sounds["notify"] = _make_tone([660.0, 880.0], 0.09, 0.4)
    _sounds["error"] = _make_tone([300.0, 220.0], 0.1, 0.4)
    _sounds["bird"] = _make_bird()
    _sounds["hit"] = _make_hit()
    # Звуки из файлов (sounds/*.wav): еда, дверь, лечение, новый уровень, касса, сирена...
    for n: String in ["eat", "door", "heal", "levelup", "cash", "siren", "heartbeat", "faint", "rain", "thunder"]:
        var path := "res://sounds/%s.wav" % n
        if ResourceLoader.exists(path):
            _sounds[n] = load(path)
    for i in 6:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)
    for i in 4:
        var p3 := AudioStreamPlayer3D.new()
        p3.unit_size = 12.0
        p3.max_distance = 120.0
        p3.process_mode = Node.PROCESS_MODE_PAUSABLE
        add_child(p3)
        _players3d.append(p3)

    _rumble = AudioStreamPlayer.new()
    _rumble.stream = _make_rumble()
    _rumble.volume_db = -22.0
    _rumble.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(_rumble)
    _crickets = AudioStreamPlayer.new()
    _crickets.stream = _make_crickets()
    _crickets.volume_db = -80.0
    _crickets.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(_crickets)


## Включить фоновые звуки города (после старта игры).
func start_ambient() -> void:
    if ambient_on:
        return
    ambient_on = true
    _rumble.play()
    _crickets.play()


func _process(delta: float) -> void:
    if not ambient_on or get_tree().paused:
        return
    _crickets.volume_db = linear_to_db(maxf(0.001, clampf(night * 1.4 - 0.4, 0.0, 1.0) * 0.18))
    _bird_timer -= delta
    if _bird_timer <= 0.0:
        _bird_timer = _rng.randf_range(4.0, 11.0)
        if night < 0.3:
            play("bird", _rng.randf_range(-20.0, -12.0), _rng.randf_range(0.85, 1.25))


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


# ---------------------------------------------------------------- синтез

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in samples.size():
        data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = RATE
    w.stereo = false
    w.data = data
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = samples.size()
    return w


func _buf(seconds: float) -> PackedFloat32Array:
    var s := PackedFloat32Array()
    s.resize(int(seconds * RATE))
    return s


## Шаг: короткий приглушённый шорох.
func _make_step() -> AudioStreamWAV:
    var s := _buf(0.09)
    var lp := 0.0
    for i in s.size():
        var t := float(i) / s.size()
        lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.12
        s[i] = lp * 2.2 * pow(1.0 - t, 3.0)
    return _wav(s)


## Гудок: два квадратных тона, как у старой машины.
func _make_horn() -> AudioStreamWAV:
    var s := _buf(0.45)
    var lp := 0.0
    for i in s.size():
        var t := float(i) / RATE
        var a := 1.0 if fmod(t * 392.0, 1.0) < 0.5 else -1.0
        var b := 1.0 if fmod(t * 494.0, 1.0) < 0.5 else -1.0
        lp += ((a + b) * 0.25 - lp) * 0.3
        var env := minf(1.0, t * 60.0) * minf(1.0, (0.45 - t) * 30.0)
        s[i] = lp * env * 0.8
    return _wav(s)


## «Дзынь» — деньги пришли.
func _make_coin() -> AudioStreamWAV:
    var s := _buf(0.35)
    for i in s.size():
        var t := float(i) / RATE
        var f := 1320.0 if t < 0.07 else 1760.0
        var t2 := t if t < 0.07 else t - 0.07
        s[i] = sin(TAU * f * t) * exp(-t2 * 12.0) * 0.45
    return _wav(s)


func _make_tone(freqs: Array, note_len: float, vol: float) -> AudioStreamWAV:
    var s := _buf(note_len * freqs.size())
    var n := int(note_len * RATE)
    for i in s.size():
        var k := mini(i / n, freqs.size() - 1)
        var t := float(i - k * n) / RATE
        var f: float = freqs[k]
        s[i] = sin(TAU * f * t) * exp(-t * 25.0) * vol
    return _wav(s)


## Птица: два быстрых свиста с понижением.
func _make_bird() -> AudioStreamWAV:
    var s := _buf(0.5)
    var ph := 0.0
    for i in s.size():
        var t := float(i) / RATE
        var chirp := fmod(t, 0.22) / 0.22
        var f := 3400.0 - chirp * 1300.0
        ph += TAU * f / RATE
        var env := sin(PI * minf(chirp / 0.6, 1.0)) if chirp < 0.6 else 0.0
        s[i] = sin(ph) * env * 0.3
    return _wav(s)


## Удар: глухой стук.
func _make_hit() -> AudioStreamWAV:
    var s := _buf(0.25)
    var lp := 0.0
    for i in s.size():
        var t := float(i) / RATE
        lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.05
        s[i] = (lp * 3.0 + sin(TAU * 70.0 * t) * 0.6) * exp(-t * 18.0)
    return _wav(s)


## Гул города: «коричневый» шум, зациклен.
func _make_rumble() -> AudioStreamWAV:
    var s := _buf(4.0)
    var b := 0.0
    for i in s.size():
        b = clampf(b + _rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0) * 0.998
        s[i] = b * 0.9
    # плавная склейка конца с началом
    var fade := 2000
    for i in fade:
        var k := float(i) / fade
        s[s.size() - fade + i] = lerpf(s[s.size() - fade + i], s[i], k)
    return _wav(s, true)


## Сверчки: короткие высокие трели.
func _make_crickets() -> AudioStreamWAV:
    var s := _buf(2.0)
    for i in s.size():
        var t := float(i) / RATE
        var trill := fmod(t, 0.5)
        var on := trill < 0.18 and fmod(trill, 0.03) < 0.018
        s[i] = sin(TAU * 4400.0 * t) * (0.5 if on else 0.0)
    return _wav(s, true)
