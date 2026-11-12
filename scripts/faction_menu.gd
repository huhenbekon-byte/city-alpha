extends Control
## Меню организации (кнопка «Фракция» в меню игрока и красная метка автопарка).
## Вкладки: Главная, Состав, Ранги, Автопарк, Объявления, Управление — по концепту.
## Данные даёт main.gd через open_menu(data, tab) и set_data(data).

signal closed
signal gps_requested(kind: String)      # "base" / "garage"
signal leave_requested
signal spawn_requested(index: int)
signal announce_posted(text: String)
signal duty_toggled

const Icons := preload("res://scripts/icons.gd")
const BG := Color(0.07, 0.07, 0.08, 0.97)
const CARD := Color(0.12, 0.12, 0.13)
const BORDER := Color(0.22, 0.22, 0.24)
const GREY := Color(0.62, 0.63, 0.67)
const WIN := Vector2(1060, 640)
const TABS := [["main", "Главная"], ["members", "Состав"], ["ranks", "Ранги"], ["garage", "Автопарк"],
        ["news", "Объявления"], ["manage", "Управление"]]
const CONTENT := Rect2(282, 180, 752, 380)

var data := {}
var tab := "main"

var _win: Control
var _tabs: Array[Button] = []
var _dyn: Control           # кнопки и поля текущей вкладки
var _news_edit: LineEdit = null
var _font: Font
var _emblems := {}


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    _font = ThemeDB.fallback_font

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)

    _win = Control.new()
    _win.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_win)
    _win.anchor_left = 0.5
    _win.anchor_right = 0.5
    _win.anchor_top = 0.5
    _win.anchor_bottom = 0.5
    _win.offset_left = -WIN.x * 0.5
    _win.offset_right = WIN.x * 0.5
    _win.offset_top = -WIN.y * 0.5
    _win.offset_bottom = WIN.y * 0.5
    _win.draw.connect(_draw_win)

    var x := Button.new()
    x.flat = true
    x.focus_mode = Control.FOCUS_NONE
    x.position = Vector2(WIN.x - 72, 18)
    x.size = Vector2(56, 56)
    x.draw.connect(_draw_close.bind(x))
    x.pressed.connect(close_menu)
    _win.add_child(x)

    for i in TABS.size():
        var t: Array = TABS[i]
        var b := Button.new()
        b.text = t[1]
        b.focus_mode = Control.FOCUS_NONE
        b.position = Vector2(26, 186 + i * 64)
        b.size = Vector2(232, 54)
        b.add_theme_font_size_override("font_size", 23)
        b.pressed.connect(_on_tab.bind(String(t[0])))
        _win.add_child(b)
        _tabs.append(b)

    var bw := (WIN.x - 52.0 - 32.0) / 3.0
    _bottom_button("Метка на базу", Vector2(26, 572), Vector2(bw, 52), "gold", func() -> void: gps_requested.emit("base"))
    _bottom_button("Метка на автопарк", Vector2(26 + bw + 16, 572), Vector2(bw, 52), "dark", func() -> void: gps_requested.emit("garage"))
    _bottom_button("Покинуть организацию", Vector2(26 + (bw + 16) * 2, 572), Vector2(bw, 52), "red", func() -> void: leave_requested.emit())

    _dyn = Control.new()
    _dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _win.add_child(_dyn)


func open_menu(d: Dictionary, start_tab := "main") -> void:
    data = d
    tab = start_tab
    visible = true
    _rebuild()


func set_data(d: Dictionary) -> void:
    data = d
    _win.queue_redraw()


func close_menu() -> void:
    if not visible:
        return
    Sfx.play("click")
    visible = false
    if _news_edit:
        _news_edit.release_focus()
    closed.emit()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:   # тап мимо окна — закрыть
        close_menu()
        accept_event()


func _accent() -> Color:
    return data.get("accent", Icons.GOLD)


func _on_tab(id: String) -> void:
    Sfx.play("click")
    tab = id
    _rebuild()


# ---------------------------------------------------------------- кнопки

func _rebuild() -> void:
    var acc := _accent()
    for i in _tabs.size():
        var on: bool = TABS[i][0] == tab
        var b := _tabs[i]
        for st: String in ["normal", "hover", "pressed"]:
            var sb := StyleBoxFlat.new()
            sb.bg_color = Color(acc.r, acc.g, acc.b, 0.12) if on else Color(0.06, 0.06, 0.07)
            sb.set_corner_radius_all(27)
            sb.set_border_width_all(3 if on else 2)
            sb.border_color = acc if on else BORDER
            b.add_theme_stylebox_override(st, sb)
        b.add_theme_color_override("font_color", acc if on else Color.WHITE)
        b.add_theme_color_override("font_hover_color", acc if on else Color.WHITE)
    for c in _dyn.get_children():
        c.queue_free()
    _news_edit = null
    var c0 := CONTENT.position
    match tab:
        "main":
            var on := bool(data.get("on_duty", false))
            var b := _small_button("Закончить смену" if on else "Начать смену", Vector2(WIN.x - 26 - 230, 112), Vector2(230, 48), true)
            b.pressed.connect(func() -> void: duty_toggled.emit())
        "garage":
            var list: Array = data.get("vehicles", [])
            for i in list.size():
                var v: Dictionary = list[i]
                var cell := _vehicle_cell(i)
                var ok := int(data.get("rank", 1)) >= int(v["rank"])
                var b := _small_button("Заспавнить" if ok else "Ранг %d" % int(v["rank"]),
                        cell.position + Vector2(cell.size.x - 196, cell.size.y - 54), Vector2(180, 42), ok)
                b.pressed.connect(_emit_spawn.bind(i))
        "news":
            if int(data.get("rank", 1)) >= 5:
                _news_edit = LineEdit.new()
                _news_edit.placeholder_text = "Текст объявления для состава..."
                _news_edit.position = c0 + Vector2(0, 322)
                _news_edit.size = Vector2(CONTENT.size.x - 200, 52)
                _news_edit.add_theme_font_size_override("font_size", 20)
                _news_edit.max_length = 140
                _dyn.add_child(_news_edit)
                var b := _small_button("Опубликовать", c0 + Vector2(CONTENT.size.x - 186, 322), Vector2(186, 52), true)
                b.pressed.connect(_post_news)
    _win.queue_redraw()


func _emit_spawn(i: int) -> void:
    spawn_requested.emit(i)


func _post_news() -> void:
    if _news_edit == null:
        return
    var t := _news_edit.text.strip_edges()
    if t == "":
        return
    announce_posted.emit(t)
    _news_edit.text = ""


func _bottom_button(text: String, pos: Vector2, sz: Vector2, style: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.position = pos
    b.size = sz
    b.add_theme_font_size_override("font_size", 22)
    var bg := Color(0.06, 0.06, 0.07)
    var fc := Color.WHITE
    var border := BORDER
    if style == "gold":
        bg = Icons.GOLD
        fc = Color(0.08, 0.08, 0.08)
        border = Icons.GOLD
    elif style == "red":
        bg = Color(0.35, 0.08, 0.08)
        fc = Color(1.0, 0.75, 0.72)
        border = Color(0.45, 0.12, 0.12)
    for st: String in ["normal", "hover", "pressed"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg if st != "pressed" else bg.lightened(0.15)
        sb.set_corner_radius_all(16)
        sb.set_border_width_all(2)
        sb.border_color = border
        b.add_theme_stylebox_override(st, sb)
    for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
        b.add_theme_color_override(k, fc)
    b.pressed.connect(func() -> void: Sfx.play("click"))
    b.pressed.connect(cb)
    _win.add_child(b)


func _small_button(text: String, pos: Vector2, sz: Vector2, on: bool) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.position = pos
    b.size = sz
    b.disabled = not on
    b.add_theme_font_size_override("font_size", 19)
    var acc := _accent()
    for st: String in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = acc if on else Color(0.16, 0.16, 0.17)
        if st == "pressed":
            sb.bg_color = acc.lightened(0.2)
        sb.set_corner_radius_all(12)
        b.add_theme_stylebox_override(st, sb)
    var fc := Color(0.08, 0.08, 0.08) if on else Color(0.55, 0.55, 0.58)
    for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
        b.add_theme_color_override(k, fc)
    b.pressed.connect(func() -> void: Sfx.play("click"))
    _dyn.add_child(b)
    return b


func _vehicle_cell(i: int) -> Rect2:
    var w := (CONTENT.size.x - 16.0) / 2.0
    return Rect2(CONTENT.position + Vector2((i % 2) * (w + 16.0), (i / 2) * 136.0), Vector2(w, 124))


# ---------------------------------------------------------------- рисование

func _emblem_tex(id: String) -> Texture2D:
    if not _emblems.has(id):
        var path := "res://textures/emblems/%s.png" % id
        _emblems[id] = load(path) if ResourceLoader.exists(path) else null
    return _emblems[id]


func _draw_win() -> void:
    var ci := _win
    var acc := _accent()
    Icons.panel(ci, Rect2(Vector2.ZERO, WIN), BG, 28, 2, Color(0.2, 0.2, 0.22))

    # шапка: эмблема в кольце, название, ранг и стаж
    var ec := Vector2(92, 90)
    ci.draw_circle(ec, 64, Color(acc.r, acc.g, acc.b, 0.18))
    ci.draw_circle(ec, 58, acc)
    ci.draw_circle(ec, 52, Color(0.09, 0.09, 0.1))
    var tex := _emblem_tex(String(data.get("emblem", "")))
    if tex:
        ci.draw_texture_rect(tex, Rect2(ec - Vector2(36, 36), Vector2(72, 72)), false)
    else:
        Icons.draw(ci, "shield", ec, 64, acc)
    _text(ci, Vector2(172, 104), String(data.get("title", "")), 48, Color.WHITE, 780)
    var sub := "Ранг: %s" % data.get("rank_name", "")
    if int(data.get("need", 0)) > 0:
        sub += " · Стаж %d/%d" % [mini(int(data.get("exp", 0)), int(data.get("need", 0))), int(data.get("need", 0))]
    _text(ci, Vector2(174, 142), sub, 22, GREY)

    match tab:
        "main":
            _draw_main(ci)
        "members":
            _draw_members(ci)
        "ranks":
            _draw_ranks(ci)
        "garage":
            _draw_garage(ci)
        "news":
            _draw_news(ci)
        _:
            _draw_manage(ci)


func _card(ci: Control, r: Rect2, icon: String, caption: String, value: String) -> void:
    Icons.panel(ci, r, CARD, 18, 2, BORDER)
    if icon == "clock":
        var c := r.position + Vector2(52, r.size.y * 0.5)
        ci.draw_arc(c, 21, 0, TAU, 32, Color.WHITE, 4.0, true)
        ci.draw_line(c, c + Vector2(0, -12), Color.WHITE, 4.0, true)
        ci.draw_line(c, c + Vector2(9, 5), Color.WHITE, 4.0, true)
    elif icon == "rank":
        var c := r.position + Vector2(52, r.size.y * 0.5)
        var pts := PackedVector2Array([c + Vector2(-18, -24), c + Vector2(18, -24), c + Vector2(18, 24),
                c + Vector2(0, 12), c + Vector2(-18, 24), c + Vector2(-18, -24)])
        ci.draw_polyline(pts, Color.WHITE, 4.0, true)
        _text(ci, c + Vector2(-7, 2), str(data.get("rank", 1)), 22, Color.WHITE)
    else:
        Icons.draw(ci, icon, r.position + Vector2(52, r.size.y * 0.5), 46, Color.WHITE)
    _text(ci, r.position + Vector2(100, 40), caption, 22, GREY)
    _text(ci, r.position + Vector2(100, 78), value, 32, Color.WHITE, r.size.x - 110)


func _draw_main(ci: Control) -> void:
    var c0 := CONTENT.position
    var w := (CONTENT.size.x - 16.0) / 2.0
    _card(ci, Rect2(c0, Vector2(w, 98)), "wallet", String(data.get("pay_word", "Зарплата")), String(data.get("pay", "")))
    _card(ci, Rect2(c0 + Vector2(w + 16, 0), Vector2(w, 98)), "clock", "До получки", "%d мин" % int(data.get("payday_left", 0)))
    _card(ci, Rect2(c0 + Vector2(0, 112), Vector2(w, 98)), "people", "Онлайн", "%d / %d" % [int(data.get("online", 1)), int(data.get("members", 1))])
    _card(ci, Rect2(c0 + Vector2(w + 16, 112), Vector2(w, 98)), "rank", "Ваш ранг", "%d / 6" % int(data.get("rank", 1)))

    var r := Rect2(c0 + Vector2(0, 224), Vector2(CONTENT.size.x, 156))
    Icons.panel(ci, r, CARD, 18, 2, BORDER)
    var news: Array = data.get("news", [])
    _text(ci, r.position + Vector2(20, 36), "Объявление лидера", 24, Color.WHITE)
    if news.is_empty():
        _text(ci, r.position + Vector2(20, 70), "Объявлений пока нет.", 20, Color(0.85, 0.85, 0.88))
    else:
        var last: Array = news[news.size() - 1]
        ci.draw_multiline_string(_font, r.position + Vector2(20, 68), String(last[0]), HORIZONTAL_ALIGNMENT_LEFT,
                r.size.x - 40, 20, 2, Color(0.85, 0.85, 0.88))
        _text(ci, r.position + Vector2(20, 112), "Автор: %s" % last[1], 18, GREY)
    var need := int(data.get("need", 0))
    var by := r.position.y + 132
    if need > 0:
        var done := mini(int(data.get("exp", 0)), need)
        var t := "До повышения: "
        _text(ci, Vector2(r.position.x + 20, by), t, 19, GREY)
        var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
        _text(ci, Vector2(r.position.x + 20 + tw, by), "%d из %d получек" % [done, need], 19, _accent())
        Icons.panel(ci, Rect2(r.position.x + 300, by - 10, r.size.x - 320, 10), Color(0.22, 0.22, 0.24), 5)
        Icons.panel(ci, Rect2(r.position.x + 300, by - 10, (r.size.x - 320) * float(done) / float(need), 10), _accent(), 5)
    else:
        _text(ci, Vector2(r.position.x + 20, by), "Повышение — по решению руководства", 19, GREY)


func _draw_members(ci: Control) -> void:
    var c0 := CONTENT.position
    _text(ci, c0 + Vector2(66, 20), "Ник", 19, GREY)
    _text(ci, c0 + Vector2(380, 20), "Ранг", 19, GREY)
    _text(ci, c0 + Vector2(620, 20), "Онлайн", 19, GREY)
    var r := Rect2(c0 + Vector2(0, 36), Vector2(CONTENT.size.x, 60))
    Icons.panel(ci, r, CARD, 16, 2, _accent())
    var yc := r.position.y + 30
    ci.draw_circle(Vector2(r.position.x + 34, yc), 21, Color(0.2, 0.2, 0.22))
    Icons.draw(ci, "user", Vector2(r.position.x + 34, yc + 2), 30, Color(0.85, 0.85, 0.88))
    _text(ci, Vector2(r.position.x + 66, yc + 8), String(data.get("nick", "")) + "  (ты)", 22, Color.WHITE, 300)
    _text(ci, Vector2(r.position.x + 380, yc + 8), String(data.get("rank_name", "")), 20, _accent(), 230)
    ci.draw_circle(Vector2(r.position.x + 640, yc), 7, Color(0.3, 0.9, 0.4))
    ci.draw_multiline_string(_font, c0 + Vector2(0, 140), "Сейчас в составе только ты. Другие игроки появятся здесь, "
            + "когда игра будет работать на сервере: тогда лидер сможет повышать, понижать и увольнять.",
            HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x, 19, 3, GREY)


func _draw_ranks(ci: Control) -> void:
    var c0 := CONTENT.position
    var ranks: Array = data.get("ranks", [])
    _text(ci, c0 + Vector2(58, 20), "Ранг", 19, GREY)
    _text(ci, c0 + Vector2(430, 20), "Мест", 19, GREY)
    _text(ci, c0 + Vector2(560, 20), String(data.get("pay_word", "Зарплата")), 19, GREY)
    var my := int(data.get("rank", 1))
    for i in ranks.size():
        var rk: Array = ranks[i]
        var r := Rect2(c0 + Vector2(0, 34 + i * 56), Vector2(CONTENT.size.x, 48))
        var mine := i + 1 == my
        Icons.panel(ci, r, CARD, 12, 2, _accent() if mine else BORDER)
        Icons.draw(ci, "star", Vector2(r.position.x + 28, r.position.y + 24), 24, _accent() if i + 1 <= my else Color(0.4, 0.4, 0.42))
        _text(ci, r.position + Vector2(58, 32), String(rk[0]), 21, _accent() if mine else Color.WHITE, 360)
        _text(ci, r.position + Vector2(430, 32), str(rk[1]), 21, Color.WHITE)
        _text(ci, r.position + Vector2(560, 32), String(rk[2]), 21, Color.WHITE)


func _draw_garage(ci: Control) -> void:
    var list: Array = data.get("vehicles", [])
    var my := int(data.get("rank", 1))
    for i in list.size():
        var v: Dictionary = list[i]
        var r := _vehicle_cell(i)
        var ok := my >= int(v["rank"])
        Icons.panel(ci, r, CARD, 16, 2, BORDER)
        var kind := String(v["kind"])
        var paint: Color = v["paint"]
        Icons.draw(ci, "car" if kind == "car" else kind, r.position + Vector2(50, 44), 64, paint.lightened(0.35) if ok else Color(0.45, 0.45, 0.47))
        _text(ci, r.position + Vector2(98, 34), String(v["name"]), 22, Color.WHITE if ok else GREY, r.size.x - 140)
        _text(ci, r.position + Vector2(98, 62), "Макс. скорость: %d км/ч" % int(v["speed"]), 17, GREY)
        _text(ci, r.position + Vector2(98, 86), "Требуемый ранг: %d" % int(v["rank"]), 17, GREY)
        if not ok:
            Icons.draw(ci, "lock", r.position + Vector2(r.size.x - 26, 24), 24, GREY)
    if not bool(data.get("at_garage", false)):
        _text(ci, CONTENT.position + Vector2(0, 288), "Машину выдают на стоянке: встань на красную метку автопарка у базы.", 18, GREY, CONTENT.size.x)


func _draw_news(ci: Control) -> void:
    var c0 := CONTENT.position
    var news: Array = data.get("news", [])
    if news.is_empty():
        _text(ci, c0 + Vector2(0, 30), "Объявлений пока нет.", 22, Color(0.85, 0.85, 0.88))
    var shown := mini(4, news.size())
    for k in shown:
        var n: Array = news[news.size() - 1 - k]
        var r := Rect2(c0 + Vector2(0, k * 78), Vector2(CONTENT.size.x, 70))
        Icons.panel(ci, r, CARD, 14, 2, BORDER)
        ci.draw_string(_font, r.position + Vector2(18, 30), String(n[0]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 19, Color.WHITE)
        _text(ci, r.position + Vector2(18, 56), String(n[1]), 16, GREY)
    if int(data.get("rank", 1)) < 5:
        _text(ci, c0 + Vector2(0, 350), "Писать объявления могут Заместитель (СС) и Лидер (Л/СС).", 18, GREY)


func _draw_manage(ci: Control) -> void:
    var c0 := CONTENT.position
    var leader := int(data.get("rank", 1)) >= 5
    var items := ["Пригласить игрока", "Повысить / понизить", "Уволить из организации",
            "Общак" if bool(data.get("gang", false)) else "Склад организации"]
    for i in items.size():
        var r := Rect2(c0 + Vector2(0, i * 66), Vector2(CONTENT.size.x, 56))
        Icons.panel(ci, r, CARD, 14, 2, BORDER)
        _text(ci, r.position + Vector2(56, 36), String(items[i]), 22, Color.WHITE if leader else GREY)
        Icons.draw(ci, "lock", r.position + Vector2(28, 28), 24, GREY)
        _text(ci, r.position + Vector2(CONTENT.size.x - 260, 36), "появится на сервере", 17, GREY)
    var note := "Управление доступно Заместителю (СС) и Лидеру (Л/СС)." if not leader \
            else "Управление составом заработает, когда игра будет на сервере."
    _text(ci, c0 + Vector2(0, 300), note, 19, GREY, CONTENT.size.x)


func _draw_close(b: Button) -> void:
    b.draw_line(Vector2(16, 16), Vector2(40, 40), Color.WHITE, 5.0, true)
    b.draw_line(Vector2(40, 16), Vector2(16, 40), Color.WHITE, 5.0, true)


func _text(ci: Control, pos: Vector2, text: String, font_size: int, col: Color, max_w := -1.0) -> void:
    ci.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, col)
