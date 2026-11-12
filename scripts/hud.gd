extends Control
## Интерфейс поверх игры (по концепту): круглая карта слева вверху, под ней
## кошелёк с наличными и плашка с короной и ником; часы, задание, уведомления,
## телефон и меню игрока (статистика, банковский счёт).

signal job_selected(kind: String)
signal job_stopped
signal summon_car
signal phone_closed
signal menu_requested

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
var phone_open := false

var _clock: Label
var _job: Label
var _toast: Label
var _toast_time := 0.0
var _phone: Panel
var _phone_money: Label
var _phone_job: Label
var _courier_btn: Button
var _taxi_btn: Button
var _job_active := false


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    _clock = _make_label(self, 18, Color(1, 1, 1, 0.9))
    _clock.position = Vector2(24, ROW_Y + 56)
    _job = _make_label(self, 19, Color(1.0, 0.85, 0.3))
    _job.position = Vector2(24, ROW_Y + 82)

    _toast = _make_label(self, 32, Color(1, 1, 1))
    _toast.anchor_left = 0.0
    _toast.anchor_right = 1.0
    _toast.offset_left = 0.0
    _toast.offset_right = 0.0
    _toast.offset_top = 140.0
    _toast.offset_bottom = 190.0
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.modulate.a = 0.0

    minimap = MinimapScript.new()
    add_child(minimap)
    minimap.position = Vector2(12, 10)
    minimap.size = Vector2(236, 236)

    _build_phone()
    profile = ProfileScript.new()
    add_child(profile)


func _process(delta: float) -> void:
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
    if h != _health or f != _hunger or h < 25:
        _health = h
        _hunger = f
        queue_redraw()


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


func show_toast(text: String) -> void:
    _toast.text = text
    _toast_time = 3.5
    _toast.modulate.a = 1.0


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
    _courier_btn.text = "Закончить смену" if job_active else "Работа: курьер"
    _taxi_btn.visible = not job_active
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
    _phone.anchor_left = 0.5
    _phone.anchor_right = 0.5
    _phone.anchor_top = 0.5
    _phone.anchor_bottom = 0.5
    _phone.offset_left = -190.0
    _phone.offset_right = 190.0
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

    _courier_btn = _make_button(box, "Работа: курьер")
    _courier_btn.pressed.connect(_on_courier_pressed)
    _taxi_btn = _make_button(box, "Работа: таксист")
    _taxi_btn.pressed.connect(_on_taxi_pressed)
    var summon := _make_button(box, "Подогнать машину")
    summon.pressed.connect(_on_summon_pressed)
    var menu := _make_button(box, "Меню / пауза")
    menu.pressed.connect(_on_menu_pressed)
    var close := _make_button(box, "Закрыть")
    close.pressed.connect(close_phone)


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
