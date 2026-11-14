extends Control
## Интерфейс поверх игры (по концепту): круглая карта слева вверху, под ней
## кошелёк с наличными и плашка с короной и ником; часы, задание, уведомления,
## телефон и меню игрока (статистика, банковский счёт).

signal job_selected(kind: String)
signal job_stopped
signal summon_car
signal phone_closed
signal menu_requested
signal app_pressed(id: String)

## Приложения телефона: [id, подпись, иконка, цвет плитки].
const APPS := [
    ["work", "Работа", "briefcase", Color(0.85, 0.55, 0.1)],
    ["bank", "Банк", "bank", Color(0.15, 0.55, 0.3)],
    ["gps", "Навигатор", "nav", Color(0.2, 0.45, 0.85)],
    ["bag", "Сумка", "bag", Color(0.55, 0.35, 0.2)],
    ["sms", "СМС", "chat", Color(0.3, 0.7, 0.35)],
    ["taxi", "Такси", "car", Color(0.95, 0.75, 0.1)],
    ["car", "Моя машина", "key", Color(0.35, 0.38, 0.45)],
    ["biz", "Бизнес", "money", Color(0.6, 0.45, 0.1)],
    ["emote", "Жесты", "people", Color(0.55, 0.3, 0.6)],
    ["skills", "Навыки", "star", Color(0.2, 0.55, 0.6)],
    ["achieve", "Достижения", "trophy", Color(0.75, 0.55, 0.1)],
    ["menu", "Меню", "gear", Color(0.3, 0.3, 0.33)],
]
const MinimapScript := preload("res://scripts/minimap.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Icons := preload("res://scripts/icons.gd")
const ROW_Y := 278.0   # строка «кошелёк + ник» под картой

var minimap: MinimapScript
var profile: ProfileScript
var _cash := 0
var _nick := ""
var _health := 100
var _hunger := 100
var _wanted := 0
var _weather_icon := ""
var _sms_badge := 0
var phone_open := false

var _clock: Label
var _job: Label
var _toast: Label
var _toast_time := 0.0
var _phone: Panel
var _phone_money: Label
var _phone_job: Label
var _app_btns := {}
var _job_active := false

# ---- чат-лента оповещений (как в RP-серверах): погода, зарплата, розыск, работа...
const CHAT_LINES := 7          # сколько строк видно на экране
const CHAT_LIFE := 14.0        # через сколько секунд строка гаснет
const CHAT_COLORS := {
    "info": Color(0.95, 0.95, 0.95), "money": Color(0.45, 0.95, 0.5), "weather": Color(0.55, 0.8, 1.0),
    "warn": Color(1.0, 0.45, 0.35), "faction": Color(0.4, 0.65, 1.0), "job": Color(1.0, 0.85, 0.3),
    "sms": Color(1.0, 0.6, 0.85), "news": Color(0.85, 0.75, 1.0), "time": Color(0.75, 0.75, 0.8),
    "say": Color(1.0, 1.0, 1.0), "shout": Color(1.0, 0.75, 0.4),
}
var chat_time_text := ""       # «[12:30]» перед строкой — задаёт main.gd
var _chat_box: VBoxContainer
var _chat_rows: Array = []     # [Label, осталось секунд]
var _chat_history: Array[String] = []
var _chat_panel: Panel
var _chat_text: RichTextLabel


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    _clock = _make_label(self, 18, Color(1, 1, 1, 0.9))
    _clock.position = Vector2(54, ROW_Y + 56)
    _job = _make_label(self, 19, Color(1.0, 0.85, 0.3))
    _job.position = Vector2(24, ROW_Y + 82)

    _toast = _make_label(self, 32, Color(1, 1, 1))
    _toast.anchor_left = 0.0
    _toast.anchor_right = 1.0
    _toast.offset_left = 0.0
    _toast.offset_right = 0.0
    _toast.offset_top = 215.0
    _toast.offset_bottom = 265.0
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.modulate.a = 0.0

    minimap = MinimapScript.new()
    add_child(minimap)
    minimap.position = Vector2(12, 10)
    minimap.size = Vector2(236, 236)

    _build_chat()
    _build_phone()
    profile = ProfileScript.new()
    add_child(profile)


func _process(delta: float) -> void:
    for row: Array in _chat_rows:
        row[1] = float(row[1]) - delta
        var lbl: Label = row[0]
        lbl.modulate.a = clampf(float(row[1]) / 1.5, 0.0, 1.0) if not _chat_panel.visible else 0.0
    if _toast_time > 0.0:
        _toast_time -= delta
        _toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)


func set_money(cash: int, bank: int) -> void:
    if cash != _cash:
        _cash = cash
        queue_redraw()
    _phone_money.text = "Наличные: %s\nНа карте: %s" % [format_money(cash), format_money(bank)]


## Полоски здоровья и сытости под деньгами.
func set_vitals(health: float, hunger: float) -> void:
    var h := int(ceil(health))
    var f := int(ceil(hunger))
    if h != _health or f != _hunger or h < 25 or _wanted > 0:
        _health = h
        _hunger = f
        queue_redraw()
        minimap.health = clampf(health / 100.0, 0.0, 1.0)


## Значок погоды у часов: "sun", "cloud", "rain", "snow".
func set_weather(icon: String) -> void:
    if icon != _weather_icon:
        _weather_icon = icon
        queue_redraw()


## Звёзды розыска (0..5).
func set_wanted(stars: int) -> void:
    if stars != _wanted:
        _wanted = stars
        queue_redraw()


## Сколько непрочитанных СМС (кружок на приложении).
func set_sms_badge(n: int) -> void:
    if n != _sms_badge:
        _sms_badge = n
        if _app_btns.has("sms"):
            (_app_btns["sms"] as Button).queue_redraw()


func _vital_bar(pos: Vector2, k: float, col: Color, icon: String) -> void:
    var blink := icon == "heart" and k < 0.25 and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.4
    Icons.panel(self, Rect2(pos + Vector2(28, -8), Vector2(124, 16)), Color(0.05, 0.05, 0.06, 0.85), 8, 2, Color(0, 0, 0, 0.9))
    Icons.panel(self, Rect2(pos + Vector2(30, -6), Vector2(120 * clampf(k, 0.0, 1.0), 12)), col.lightened(0.3) if blink else col, 6)
    if icon == "heart":
        Icons.draw(self, "heart", pos + Vector2(10, 0), 26, Color(1.0, 0.35, 0.35), Color.BLACK)
    else:
        # куриная ножка
        draw_circle(pos + Vector2(13, -3), 8.0, Color.BLACK)
        draw_line(pos + Vector2(10, 1), pos + Vector2(3, 9), Color.BLACK, 6.0, true)
        draw_circle(pos + Vector2(13, -3), 6.0, Color(1.0, 0.65, 0.25))
        draw_line(pos + Vector2(10, 1), pos + Vector2(3, 9), Color(0.95, 0.92, 0.85), 3.0, true)


func set_nick(nick: String) -> void:
    if nick != _nick:
        _nick = nick
        queue_redraw()


## Строка под картой: кошелёк + наличные, плашка с короной и ником.
func _draw() -> void:
    var font := ThemeDB.fallback_font
    var y := ROW_Y
    Icons.draw(self, "wallet", Vector2(44, y), 40, Color.WHITE, Color.BLACK)
    var money := _fmt(_cash) + " ₽"
    draw_string_outline(font, Vector2(78, y + 13), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 12, Color.BLACK)
    draw_string(font, Vector2(78, y + 13), money, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
    var bx := 78.0 + font.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 16.0
    var nick := _nick.to_upper() if _nick != "" else "БЕЗ ПАСПОРТА"
    var nw := font.get_string_size(nick, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
    Icons.panel(self, Rect2(bx, y - 23, nw + 78, 46), Color(0.07, 0.07, 0.08, 0.92), 14, 2, Color(0.25, 0.25, 0.27))
    Icons.draw(self, "crown", Vector2(bx + 30, y + 1), 30, Icons.GOLD)
    draw_string(font, Vector2(bx + 56, y + 9), nick, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
    _vital_bar(Vector2(24, y + 36), _health / 100.0, Color(0.85, 0.15, 0.15), "heart")
    _vital_bar(Vector2(184, y + 36), _hunger / 100.0, Color(0.95, 0.6, 0.1), "food")
    if _weather_icon != "":
        Icons.draw(self, _weather_icon, Vector2(36, y + 67), 26, Color.WHITE, Color.BLACK)
    if _wanted > 0:
        var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
        for k in 5:
            var on := k < _wanted
            var col := (Color(1.0, 0.25, 0.2) if blink else Color(0.35, 0.55, 1.0)) if on else Color(1, 1, 1, 0.25)
            Icons.draw(self, "star", Vector2(360 + k * 28, y + 36), 24, col, Color.BLACK if on else Color(0, 0, 0, 0))


static func _fmt(v: int) -> String:
    var s := str(absi(v))
    var out := ""
    while s.length() > 3:
        out = " " + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return ("-" if v < 0 else "") + s + out


func set_clock(text: String) -> void:
    _clock.text = text


func set_job(text: String) -> void:
    _job.text = text


func show_toast(text: String, kind := "info") -> void:
    _toast.text = text
    _toast_time = 3.5
    _toast.modulate.a = 1.0
    chat(text, kind)


## Строка в чат: kind задаёт цвет ("money", "weather", "warn", "faction", "job", "sms", "news", "time").
func chat(text: String, kind := "info") -> void:
    var line := ("%s " % chat_time_text if chat_time_text != "" else "") + text
    var col: Color = CHAT_COLORS.get(kind, CHAT_COLORS["info"])
    _chat_history.append("[color=#%s]%s[/color]" % [col.to_html(false), line.replace("[", "(").replace("]", ")")])
    if _chat_history.size() > 60:
        _chat_history.remove_at(0)
    var lbl := _make_label(_chat_box, 19, col)
    lbl.text = line
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.custom_minimum_size = Vector2(_chat_box.size.x, 0)
    _chat_rows.append([lbl, CHAT_LIFE])
    while _chat_rows.size() > CHAT_LINES:
        var old: Label = _chat_rows[0][0]
        old.queue_free()
        _chat_rows.remove_at(0)
    if _chat_panel.visible:
        _refresh_chat_history()


func _build_chat() -> void:
    _chat_box = VBoxContainer.new()
    _chat_box.position = Vector2(330, 8)
    _chat_box.size = Vector2(620, 200)
    _chat_box.add_theme_constant_override("separation", 0)
    _chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_chat_box)
    # касание по ленте открывает историю
    var tap := Button.new()
    tap.flat = true
    tap.focus_mode = Control.FOCUS_NONE
    tap.position = Vector2(330, 0)
    tap.size = Vector2(620, 170)
    tap.modulate.a = 0.0
    tap.pressed.connect(_toggle_chat_history)
    add_child(tap)
    _chat_panel = Panel.new()
    _chat_panel.position = Vector2(330, 8)
    _chat_panel.size = Vector2(640, 330)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.05, 0.07, 0.82)
    sb.set_corner_radius_all(14)
    sb.border_color = Color(1, 1, 1, 0.25)
    sb.set_border_width_all(2)
    _chat_panel.add_theme_stylebox_override("panel", sb)
    _chat_panel.visible = false
    add_child(_chat_panel)
    var title := _make_label(_chat_panel, 18, Color(1, 1, 1, 0.6))
    title.text = "ЧАТ · коснись, чтобы закрыть"
    title.position = Vector2(16, 6)
    _chat_text = RichTextLabel.new()
    _chat_text.bbcode_enabled = true
    _chat_text.scroll_following = true
    _chat_text.position = Vector2(14, 34)
    _chat_text.size = Vector2(612, 286)
    _chat_text.add_theme_font_size_override("normal_font_size", 19)
    _chat_text.mouse_filter = Control.MOUSE_FILTER_PASS
    _chat_panel.add_child(_chat_text)
    var close := Button.new()
    close.flat = true
    close.focus_mode = Control.FOCUS_NONE
    close.modulate.a = 0.0
    close.position = Vector2(0, 0)
    close.size = Vector2(640, 34)
    close.pressed.connect(_toggle_chat_history)
    _chat_panel.add_child(close)


## Кнопка с микрофоном: открыть / закрыть историю чата.
func toggle_chat_history() -> void:
    _toggle_chat_history()


func _toggle_chat_history() -> void:
    _chat_panel.visible = not _chat_panel.visible
    if _chat_panel.visible:
        _refresh_chat_history()


func _refresh_chat_history() -> void:
    _chat_text.text = "\n".join(PackedStringArray(_chat_history))


static func format_money(value: int) -> String:
    var s := str(absi(value))
    var out := ""
    while s.length() > 3:
        out = " " + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return ("-" if value < 0 else "") + s + out + " ₽"


# ---------------------------------------------------------------- телефон

func open_phone(job_active: bool, job_text: String) -> void:
    phone_open = true
    _phone.visible = true
    update_phone(job_active, job_text)


func close_phone() -> void:
    if not phone_open:
        return
    phone_open = false
    _phone.visible = false
    phone_closed.emit()


func update_phone(job_active: bool, job_text: String) -> void:
    _job_active = job_active
    _phone_job.text = job_text


func _build_phone() -> void:
    _phone = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.11, 0.97)
    sb.set_corner_radius_all(30)
    sb.border_color = Color(0.35, 0.35, 0.40)
    sb.set_border_width_all(5)
    _phone.add_theme_stylebox_override("panel", sb)
    _phone.visible = false
    add_child(_phone)
    if ResourceLoader.exists("res://textures/phone_wallpaper.jpg"):
        var wp := TextureRect.new()
        wp.texture = load("res://textures/phone_wallpaper.jpg")
        wp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        wp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        wp.modulate = Color(1, 1, 1, 0.85)
        wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _phone.add_child(wp)
        wp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
    _phone.anchor_left = 0.5
    _phone.anchor_right = 0.5
    _phone.anchor_top = 0.5
    _phone.anchor_bottom = 0.5
    _phone.offset_left = -232.0
    _phone.offset_right = 232.0
    _phone.offset_top = -350.0
    _phone.offset_bottom = 350.0

    var box := VBoxContainer.new()
    _phone.add_child(box)
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 26)
    box.add_theme_constant_override("separation", 10)

    var title := _make_label(box, 30, Color(1, 1, 1))
    title.text = "Телефон"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _phone_money = _make_label(box, 26, Color(0.65, 1.0, 0.65))
    _phone_job = _make_label(box, 18, Color(0.85, 0.85, 0.9))
    _phone_job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _phone_job.custom_minimum_size = Vector2(320, 90)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 10)
    box.add_child(grid)
    for app: Array in APPS:
        var b := Button.new()
        b.custom_minimum_size = Vector2(96, 96)
        b.focus_mode = Control.FOCUS_NONE
        b.flat = true
        b.draw.connect(_draw_app.bind(b, app))
        b.pressed.connect(_click)
        b.pressed.connect(_on_app.bind(String(app[0])))
        grid.add_child(b)
        _app_btns[String(app[0])] = b
    var close := _make_button(box, "Закрыть")
    close.pressed.connect(close_phone)


func _draw_app(b: Button, app: Array) -> void:
    var col: Color = app[3]
    var r := Rect2(Vector2((b.size.x - 64.0) * 0.5, 2), Vector2(64, 64))
    Icons.panel(b, r, col.darkened(0.25) if b.is_pressed() else col, 16)
    Icons.draw(b, String(app[2]), r.get_center(), 40, Color.WHITE)
    var font := ThemeDB.fallback_font
    var t := String(app[1])
    var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
    b.draw_string(font, Vector2((b.size.x - w) * 0.5, 88), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    if String(app[0]) == "sms" and _sms_badge > 0:
        b.draw_circle(Vector2(r.end.x, 6), 11, Color(0.9, 0.15, 0.15))
        var n := str(mini(_sms_badge, 9))
        b.draw_string(font, Vector2(r.end.x - 5, 12), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _on_app(id: String) -> void:
    if id == "menu":
        _on_menu_pressed()
        return
    app_pressed.emit(id)


func _on_menu_pressed() -> void:
    close_phone()
    menu_requested.emit()


func _on_courier_pressed() -> void:
    if _job_active:
        job_stopped.emit()
    else:
        job_selected.emit("courier")


func _on_taxi_pressed() -> void:
    job_selected.emit("taxi")


func _on_summon_pressed() -> void:
    summon_car.emit()


func _make_button(parent: Control, text: String) -> Button:
    var b := Button.new()
    b.pressed.connect(_click)
    b.text = text
    b.custom_minimum_size = Vector2(0, 62)
    b.add_theme_font_size_override("font_size", 24)
    b.focus_mode = Control.FOCUS_NONE
    parent.add_child(b)
    return b


func _make_label(parent: Control, font_size: int, col: Color) -> Label:
    var l := Label.new()
    var ls := LabelSettings.new()
    ls.font_size = font_size
    ls.font_color = col
    ls.outline_size = 6
    ls.outline_color = Color(0, 0, 0, 0.75)
    l.label_settings = ls
    parent.add_child(l)
    return l


func _click() -> void:
    Sfx.play("click")
