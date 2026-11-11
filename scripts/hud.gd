extends Control
## Интерфейс поверх игры: деньги, часы, текущее задание, мини-карта,
## всплывающие уведомления и телефон с меню.

signal job_selected(kind: String)
signal job_stopped
signal summon_car
signal phone_closed
signal menu_requested

const MinimapScript := preload("res://scripts/minimap.gd")

var minimap: MinimapScript
var phone_open := false

var _money: Label
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

    _money = _make_label(self, 34, Color(0.65, 1.0, 0.65))
    _money.position = Vector2(20, 10)
    _clock = _make_label(self, 22, Color(1, 1, 1))
    _clock.position = Vector2(22, 56)
    _job = _make_label(self, 20, Color(1.0, 0.85, 0.3))
    _job.position = Vector2(22, 88)

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
    minimap.anchor_left = 1.0
    minimap.anchor_right = 1.0
    minimap.anchor_top = 0.0
    minimap.anchor_bottom = 0.0
    minimap.offset_left = -240.0
    minimap.offset_right = -20.0
    minimap.offset_top = 16.0
    minimap.offset_bottom = 236.0

    _build_phone()


func _process(delta: float) -> void:
    if _toast_time > 0.0:
        _toast_time -= delta
        _toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)


func set_money(value: int) -> void:
    var t := format_money(value)
    _money.text = t
    _phone_money.text = "Баланс: " + t


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
    return ("-" if value < 0 else "") + s + out + " руб."


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
    if job_active:
        _phone_job.text = job_text
    else:
        _phone_job.text = "Курьер — можно пешком. Таксист — платят больше, нужна своя машина (автосалон на площади). Успел вовремя — бонус +30%."


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
