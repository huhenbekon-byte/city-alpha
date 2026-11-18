extends RefCounted
## Общий стиль интерфейса «СССР РП»: тёмный фон, красные плашки, золотая окантовка, кремовый текст.
## theme() — тема для всего окна игры (кнопки, поля ввода, прокрутка, всплывающие подсказки);
## Emblem — нарисованная звезда с серпом и молотом для заголовков.

const RED := Color(0.62, 0.09, 0.07)
const RED_DARK := Color(0.36, 0.05, 0.04)
const RED_LIGHT := Color(0.82, 0.16, 0.11)
const GOLD := Color(0.93, 0.74, 0.31)
const GOLD_DIM := Color(0.62, 0.48, 0.2)
const CREAM := Color(0.96, 0.91, 0.79)
const INK := Color(0.08, 0.06, 0.05)
const PANEL := Color(0.1, 0.075, 0.065, 0.94)
const FONT_PATH := "res://fonts/menu_bold.ttf"

static var _theme: Theme


static func font() -> Font:
    return load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font


## Плашка: заливка, окантовка, скругление.
static func box(bg: Color, border: Color, bw := 2, radius := 10, pad := 12.0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(radius)
    s.content_margin_left = pad
    s.content_margin_right = pad
    s.content_margin_top = pad * 0.5
    s.content_margin_bottom = pad * 0.5
    s.anti_aliasing = true
    return s


## Кнопка в стиле меню: красная с золотой окантовкой (main) или тёмная с золотой (обычная).
static func style_button(b: Button, main := false, font_size := 24) -> void:
    var bg := RED if main else Color(0.13, 0.1, 0.09, 0.95)
    b.add_theme_stylebox_override("normal", box(bg, GOLD_DIM, 2, 10, 18.0))
    b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), GOLD, 2, 10, 18.0))
    b.add_theme_stylebox_override("pressed", box(RED_LIGHT if main else RED_DARK, GOLD, 3, 10, 18.0))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_stylebox_override("disabled", box(Color(0.12, 0.11, 0.1, 0.7), Color(0.3, 0.27, 0.22), 2, 10, 18.0))
    b.add_theme_font_override("font", font())
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", CREAM)
    b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
    b.add_theme_color_override("font_pressed_color", GOLD)
    b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))


static func theme() -> Theme:
    if _theme:
        return _theme
    var t := Theme.new()
    t.default_font = font()
    t.default_font_size = 22
    t.set_stylebox("normal", "Button", box(Color(0.13, 0.1, 0.09, 0.95), GOLD_DIM, 2, 10, 14.0))
    t.set_stylebox("hover", "Button", box(Color(0.2, 0.14, 0.12, 0.95), GOLD, 2, 10, 14.0))
    t.set_stylebox("pressed", "Button", box(RED_DARK, GOLD, 2, 10, 14.0))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_stylebox("disabled", "Button", box(Color(0.12, 0.11, 0.1, 0.7), Color(0.3, 0.27, 0.22), 2, 10, 14.0))
    t.set_color("font_color", "Button", CREAM)
    t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
    t.set_color("font_pressed_color", "Button", GOLD)
    t.set_color("font_color", "Label", CREAM)
    t.set_stylebox("normal", "LineEdit", box(Color(0.06, 0.05, 0.045, 0.95), GOLD_DIM, 2, 8, 12.0))
    t.set_stylebox("focus", "LineEdit", box(Color(0.08, 0.06, 0.05, 0.95), GOLD, 2, 8, 12.0))
    t.set_color("font_color", "LineEdit", CREAM)
    t.set_color("font_placeholder_color", "LineEdit", Color(0.75, 0.7, 0.6, 0.55))
    t.set_color("caret_color", "LineEdit", GOLD)
    t.set_stylebox("panel", "PanelContainer", box(PANEL, GOLD_DIM, 2, 14, 16.0))
    t.set_stylebox("panel", "Panel", box(PANEL, GOLD_DIM, 2, 14, 16.0))
    t.set_stylebox("panel", "TooltipPanel", box(PANEL, GOLD, 1, 6, 8.0))
    var grab := box(GOLD_DIM, GOLD_DIM, 0, 4, 0.0)
    t.set_stylebox("grabber", "VScrollBar", grab)
    t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, GOLD, 0, 4, 0.0))
    t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, GOLD, 0, 4, 0.0))
    t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 4, 0.0))
    _theme = t
    return t


## Красная звезда с золотой каймой и серпом и молотом — эмблема для заголовков меню.
class Emblem extends Control:
    var radius := 34.0

    func _init(r := 34.0) -> void:
        radius = r
        custom_minimum_size = Vector2(r * 2.2, r * 2.2)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var c := size * 0.5
        var gold := Color(0.93, 0.74, 0.31)
        draw_circle(c, radius * 1.05, Color(0.36, 0.05, 0.04))
        draw_arc(c, radius * 1.05, 0.0, TAU, 48, gold, 3.0, true)
        var pts := PackedVector2Array()
        for i in 10:
            var a := -PI * 0.5 + i * PI / 5.0
            var rr := radius * (0.86 if i % 2 == 0 else 0.36)
            pts.append(c + Vector2(cos(a), sin(a)) * rr)
        draw_colored_polygon(pts, Color(0.82, 0.16, 0.11))
        pts.append(pts[0])
        draw_polyline(pts, gold, 2.0, true)
        # серп и молот
        var s := radius * 0.3
        draw_arc(c + Vector2(-s * 0.05, s * 0.05), s * 0.75, PI * 0.1, PI * 1.35, 16, gold, s * 0.22, true)
        draw_line(c + Vector2(-s * 0.55, s * 0.6), c + Vector2(s * 0.45, -s * 0.4), gold, s * 0.22, true)
        draw_line(c + Vector2(s * 0.2, -s * 0.65), c + Vector2(s * 0.7, -s * 0.15), gold, s * 0.3, true)
