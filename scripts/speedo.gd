extends Control
## Спидометр внизу по центру (по концепту игрока): большая скорость «км/ч»,
## бак, состояние машины с лампой «ТОРМ.», лампы ручника, замка дверей и фар.
## Замок и фары — кнопки (их касания ловит touch_controls по button_centers()).

const FONT_PATH := "res://fonts/menu_bold.ttf"
const ICONS := ["fuel", "brake_warn", "handbrake", "lock", "lights"]
const W := 500.0
const H := 186.0
const CREAM := Color(0.93, 0.90, 0.82)
const BTN_R := 32.0

var speed := 0
var fuel_k := 1.0
var uses_fuel := true
var cond_k := 1.0
var braking := false
var hand := false
var locked := false
var lights := false
var brand := "СССР РП"

var _font: Font
var _tex := {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
    for k: String in ICONS:
        var p := "res://textures/hud/spd_%s.png" % k
        if ResourceLoader.exists(p):
            _tex[k] = load(p)
    size = Vector2(W, H)


## Где на экране рисуется прямоугольник спидометра.
static func rect_for(view: Vector2) -> Rect2:
    return Rect2(Vector2(view.x * 0.5 - W * 0.5, view.y - H - 6.0), Vector2(W, H))


## Центры кнопок «замок» и «фары» в координатах экрана.
static func button_centers(view: Vector2) -> Dictionary:
    var o := rect_for(view).position
    return {"lock": o + Vector2(340, 154), "lights": o + Vector2(448, 154)}


func set_state(kmh: float, fuel: float, has_fuel: bool, cond: float, brk: bool, hb: bool, lk: bool, li: bool) -> void:
    var s := int(absf(kmh))
    var changed := s != speed or absf(fuel - fuel_k) > 0.005 or absf(cond - cond_k) > 0.005 \
            or brk != braking or hb != hand or lk != locked or li != lights or has_fuel != uses_fuel
    speed = s
    fuel_k = fuel
    uses_fuel = has_fuel
    cond_k = cond
    braking = brk
    hand = hb
    locked = lk
    lights = li
    if changed or cond_k < 0.3:
        queue_redraw()


func _icon(k: String, center: Vector2, h: float, col: Color) -> void:
    if not _tex.has(k):
        return
    var t: Texture2D = _tex[k]
    var w := h * float(t.get_width()) / float(t.get_height())
    var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
    draw_texture_rect(t, Rect2(r.position + Vector2(2, 2), r.size), false, Color(0, 0, 0, 0.55 * col.a))
    draw_texture_rect(t, r, false, col)


func _text(pos: Vector2, s: String, fs: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
    draw_string(_font, pos + Vector2(2, 3), s, align, width, fs, Color(0, 0, 0, 0.6))
    draw_string(_font, pos, s, align, width, fs, col)


func _bar(r: Rect2, k: float, col: Color, tail: Color) -> void:
    draw_rect(r.grow(2.0), Color(0, 0, 0, 0.45))
    draw_rect(r, Color(0.12, 0.12, 0.12, 0.6))
    var kk := clampf(k, 0.0, 1.0)
    draw_rect(Rect2(r.position, Vector2(r.size.x * kk, r.size.y)), col)
    if kk > 0.02 and kk < 0.99:   # мягкий «хвост» как на концепте
        draw_rect(Rect2(r.position + Vector2(r.size.x * kk, 0), Vector2(minf(26.0, r.size.x * (1.0 - kk)), r.size.y)), tail)
    draw_rect(r, CREAM * Color(1, 1, 1, 0.8), false, 2.0)


func _draw() -> void:
    # лёгкая подложка — цифры видно и на снегу, и на асфальте
    draw_rect(Rect2(Vector2(-10, 4), Vector2(W + 20, H - 4)), Color(0, 0, 0, 0.22))
    var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.4

    # скорость
    _text(Vector2(0, 122), str(speed), 112, CREAM, 186.0, HORIZONTAL_ALIGNMENT_CENTER)
    _text(Vector2(0, 168), "К М / Ч", 30, CREAM, 186.0, HORIZONTAL_ALIGNMENT_CENTER)

    # бак
    var low := uses_fuel and fuel_k < 0.15
    _icon("fuel", Vector2(226, 34), 44, (Color(1.0, 0.35, 0.3) if blink else CREAM) if low else CREAM)
    if uses_fuel:
        _bar(Rect2(262, 26, 228, 15), fuel_k, CREAM, Color(0.75, 0.3, 0.2, 0.55))
    else:
        _text(Vector2(262, 42), "без бензина", 20, CREAM * Color(1, 1, 1, 0.7))

    # состояние машины + лампа «ТОРМ.»
    var warn := braking or hand or (cond_k < 0.3 and blink)
    _icon("brake_warn", Vector2(226, 88), 54, Color(1.0, 0.32, 0.25) if warn else CREAM * Color(1, 1, 1, 0.55))
    _bar(Rect2(262, 80, 228, 15), cond_k, Color(0.82, 0.28, 0.2), Color(0.5, 0.15, 0.1, 0.5))
    _text(Vector2(262, 126), brand, 26, CREAM, 228.0, HORIZONTAL_ALIGNMENT_CENTER)

    # нижний ряд: ручник, замок, фары
    var c := button_centers(Vector2.ZERO)   # смещение считаем от своего угла ниже
    var o := rect_for(Vector2.ZERO).position
    _icon("handbrake", Vector2(232, 154), 42, Color(1.0, 0.32, 0.25) if hand else CREAM * Color(1, 1, 1, 0.5))
    for k: String in ["lock", "lights"]:
        var p: Vector2 = c[k] - o
        var on := locked if k == "lock" else lights
        draw_circle(p, BTN_R, Color(0, 0, 0, 0.35 if not on else 0.5))
        draw_arc(p, BTN_R, 0.0, TAU, 40, CREAM * Color(1, 1, 1, 0.9 if on else 0.4), 2.5, true)
        var col := CREAM * Color(1, 1, 1, 0.55)
        if on:
            col = Color(1.0, 0.8, 0.25) if k == "lock" else Color(0.6, 0.88, 1.0)
        _icon(k, p, 38, col)
