extends Control
## Меню игрока (кнопка с 4 квадратами): «Статистика» и «Банковский счёт».
## Окна рисуются кодом по концепту: тёмные плашки, золотые акценты, иконки.
## Данные даёт main.gd через set_data().

signal opened
signal closed
signal navigator_requested

const Icons := preload("res://scripts/icons.gd")
const BG := Color(0.06, 0.06, 0.07, 0.97)
const CARD := Color(0.11, 0.11, 0.12)
const CARD_BORDER := Color(0.20, 0.20, 0.22)
const GREY := Color(0.62, 0.63, 0.67)

var data := {}

var _popup: VBoxContainer
var _stats: Control
var _bank: Control
var _font: Font


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _font = ThemeDB.fallback_font

    _popup = VBoxContainer.new()
    _popup.add_theme_constant_override("separation", 8)
    _popup.position = Vector2(232, 88)
    _popup.visible = false
    add_child(_popup)
    _pill_button(_popup, "Статистика", open_stats)
    _pill_button(_popup, "Банковский счёт", open_bank)
    _pill_button(_popup, "Навигатор", _on_navigator)

    _stats = _make_window(Vector2(780, 520))
    _stats.draw.connect(_draw_stats.bind(_stats))
    _bank = _make_window(Vector2(780, 540))
    _bank.draw.connect(_draw_bank.bind(_bank))


func set_data(d: Dictionary) -> void:
    data = d
    if _stats.visible:
        _stats.queue_redraw()
    if _bank.visible:
        _bank.queue_redraw()


func is_open() -> bool:
    return _popup.visible or _stats.visible or _bank.visible


func toggle_popup() -> void:
    if is_open():
        close_all()
        return
    _popup.visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP  # тап мимо меню — закрыть
    opened.emit()


func open_stats() -> void:
    _popup.visible = false
    _bank.visible = false
    _stats.visible = true
    _stats.queue_redraw()


func open_bank() -> void:
    _popup.visible = false
    _stats.visible = false
    _bank.visible = true
    _bank.queue_redraw()


func _on_navigator() -> void:
    close_all()
    navigator_requested.emit()


func close_all() -> void:
    var was := is_open()
    _popup.visible = false
    _stats.visible = false
    _bank.visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if was:
        closed.emit()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        close_all()
        accept_event()


# ---------------------------------------------------------------- статистика

func _draw_stats(ci: Control) -> void:
    var sz := ci.size
    Icons.panel(ci, Rect2(Vector2.ZERO, sz), BG, 26, 2, Color(0.18, 0.18, 0.2))

    # Аватар в золотом кольце
    var ac := Vector2(118, 112)
    ci.draw_circle(ac, 84, Color(1.0, 0.76, 0.18, 0.18))
    ci.draw_circle(ac, 78, Icons.GOLD)
    ci.draw_circle(ac, 70, Color(0.09, 0.09, 0.1))
    Icons.draw(ci, "user", ac + Vector2(0, 8), 110, Color(0.88, 0.88, 0.9))

    # Ник
    Icons.panel(ci, Rect2(206, 36, 460, 70), Color(0.10, 0.10, 0.11), 34, 2, CARD_BORDER)
    _text(ci, Vector2(232, 88), String(data.get("name", "")).to_upper(), 42, Color.WHITE)

    # Уровень и опыт
    Icons.panel(ci, Rect2(206, 116, 480, 60), Color(0.10, 0.10, 0.11), 30, 2, CARD_BORDER)
    Icons.panel(ci, Rect2(226, 127, 66, 38), Icons.GOLD, 10)
    _text(ci, Vector2(236, 155), "LVL", 22, Color(0.1, 0.1, 0.1))
    _text(ci, Vector2(304, 160), str(data.get("level", 1)), 36, Color.WHITE)
    var lw := _font.get_string_size(str(data.get("level", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
    ci.draw_line(Vector2(320 + lw, 132), Vector2(320 + lw, 160), Icons.GOLD, 3.0)
    _text(ci, Vector2(336 + lw, 156), "%d / %d XP" % [int(data.get("xp", 0)), int(data.get("need", 100))], 24, GREY)
    # полоска опыта
    var k := clampf(float(data.get("xp", 0)) / maxf(1.0, float(data.get("need", 100))), 0.0, 1.0)
    Icons.panel(ci, Rect2(226, 168, 440, 4), Color(0.2, 0.2, 0.22), 2)
    Icons.panel(ci, Rect2(226, 168, 440 * k, 4), Icons.GOLD, 2)

    var items := [
        ["wallet", "ДЕНЬГИ", _money(int(data.get("cash", 0)))],
        ["briefcase", "РАБОТА", String(data.get("job", "Безработный"))],
        ["crown", "РЕЙТИНГ", _num(int(data.get("rating", 0)))],
        ["phone", "НОМЕР ТЕЛЕФОНА", String(data.get("phone", "—"))],
        ["house", "ПРОЖИВАНИЕ", String(data.get("home", "Нет"))],
        ["people", "ОРГАНИЗАЦИЯ", String(data.get("org", "Нет"))],
    ]
    for i in items.size():
        var it: Array = items[i]
        var x := 26.0 if i % 2 == 0 else 400.0
        var y := 200.0 + float(i / 2) * 104.0
        _info_card(ci, Rect2(x, y, 354, 90), it[0], it[1], it[2])


func _info_card(ci: Control, r: Rect2, icon: String, caption: String, value: String) -> void:
    Icons.panel(ci, r, CARD, 16, 2, CARD_BORDER)
    Icons.draw(ci, icon, r.position + Vector2(46, 45), 46, Color(0.95, 0.95, 0.95))
    _text(ci, r.position + Vector2(92, 36), caption, 18, GREY)
    _text(ci, r.position + Vector2(92, 72), value, 28, Color.WHITE, r.size.x - 104)


# ---------------------------------------------------------------- банк

func _draw_bank(ci: Control) -> void:
    var sz := ci.size
    Icons.panel(ci, Rect2(Vector2.ZERO, sz), BG, 26, 2, Color(0.18, 0.18, 0.2))
    Icons.draw(ci, "card", Vector2(56, 52), 44, Icons.GOLD)
    _text(ci, Vector2(92, 64), "БАНКОВСКИЙ СЧЁТ", 32, Color.WHITE)

    # Карта
    var cr := Rect2(26, 96, 380, 230)
    Icons.panel(ci, cr, Color(0.80, 0.60, 0.14), 22)
    Icons.panel(ci, Rect2(cr.position + Vector2(0, 130), Vector2(cr.size.x, 100)), Color(0.72, 0.52, 0.10), 22)
    Icons.panel(ci, Rect2(cr.position + Vector2(0, 120), Vector2(cr.size.x, 30)), Color(0.72, 0.52, 0.10), 0)
    _text(ci, cr.position + Vector2(24, 42), "CITY BANK", 24, Color(0.15, 0.1, 0.02))
    Icons.panel(ci, Rect2(cr.position + Vector2(24, 62), Vector2(52, 38)), Color(0.95, 0.85, 0.55), 8)
    _text(ci, cr.position + Vector2(24, 140), String(data.get("card", "")), 26, Color.WHITE)
    _text(ci, cr.position + Vector2(24, 172), String(data.get("name", "")).to_upper(), 20, Color(1, 1, 1, 0.85))
    _text(ci, cr.position + Vector2(24, 212), _money(int(data.get("bank", 0))), 32, Color.WHITE)

    # Балансы
    var bx := 426.0
    _info_card(ci, Rect2(bx, 96, 328, 90), "card", "НА КАРТЕ", _money(int(data.get("bank", 0))))
    _info_card(ci, Rect2(bx, 196, 328, 90), "wallet", "НАЛИЧНЫЕ", _money(int(data.get("cash", 0))))
    _text(ci, Vector2(bx, 312), "Снять и положить — в банкомате", 17, GREY)

    # История
    Icons.panel(ci, Rect2(26, 340, sz.x - 52, sz.y - 362), CARD, 16, 2, CARD_BORDER)
    _text(ci, Vector2(46, 374), "ИСТОРИЯ ОПЕРАЦИЙ", 18, GREY)
    var hist: Array = data.get("history", [])
    if hist.is_empty():
        _text(ci, Vector2(46, 412), "Пока пусто — поработай!", 22, Color(0.8, 0.8, 0.8))
    var n := mini(5, hist.size())
    for i in n:
        var h: Array = hist[hist.size() - 1 - i]
        var amount: int = h[0]
        var y := 410.0 + i * 30.0
        var col := Color(0.4, 0.9, 0.45) if amount >= 0 else Color(1.0, 0.4, 0.35)
        _text(ci, Vector2(46, y), ("+" if amount >= 0 else "−") + _money(absi(amount)), 22, col)
        _text(ci, Vector2(230, y), String(h[1]), 22, Color(0.88, 0.88, 0.9), sz.x - 290)


# ---------------------------------------------------------------- помощники

func _make_window(sz: Vector2) -> Control:
    var w := Control.new()
    w.visible = false
    w.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(w)
    w.anchor_left = 0.5
    w.anchor_right = 0.5
    w.anchor_top = 0.5
    w.anchor_bottom = 0.5
    w.offset_left = -sz.x * 0.5
    w.offset_right = sz.x * 0.5
    w.offset_top = -sz.y * 0.5
    w.offset_bottom = sz.y * 0.5
    var x := Button.new()
    x.text = "X"
    x.add_theme_font_size_override("font_size", 26)
    x.focus_mode = Control.FOCUS_NONE
    x.flat = true
    x.position = Vector2(sz.x - 62, 12)
    x.size = Vector2(50, 50)
    x.pressed.connect(close_all)
    w.add_child(x)
    return w


func _pill_button(parent: Control, text: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = "  " + text
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(300, 60)
    b.add_theme_font_size_override("font_size", 24)
    b.focus_mode = Control.FOCUS_NONE
    for st: String in ["normal", "hover", "pressed"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.08, 0.08, 0.09, 0.95) if st != "pressed" else Color(0.18, 0.18, 0.2, 0.95)
        sb.set_corner_radius_all(18)
        sb.set_border_width_all(2)
        sb.border_color = Icons.GOLD if st == "hover" else Color(0.25, 0.25, 0.27)
        b.add_theme_stylebox_override(st, sb)
    b.pressed.connect(func() -> void: Sfx.play("click"))
    b.pressed.connect(cb)
    parent.add_child(b)


func _text(ci: Control, pos: Vector2, text: String, font_size: int, col: Color, max_w := -1.0) -> void:
    ci.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, col,
            TextServer.JUSTIFICATION_NONE)


func _money(v: int) -> String:
    return _num(v) + " ₽"


func _num(v: int) -> String:
    var s := str(absi(v))
    var out := ""
    while s.length() > 3:
        out = " " + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return ("-" if v < 0 else "") + s + out
