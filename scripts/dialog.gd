extends Panel
## Универсальное окно: заголовок, текст, (по желанию) поле ввода и кнопки.
## open("Банкомат", "Текст", [["Снять 1000", callable], ["Закрыть", callable]])
## Кнопка сама окно не закрывает — это решает её обработчик (close() или новый open()).

signal closed

var _title: Label
var _text: Label
var _input: LineEdit
var _buttons: VBoxContainer


func _ready() -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.11, 0.96)
    sb.set_corner_radius_all(24)
    sb.border_color = Color(0.35, 0.35, 0.40)
    sb.set_border_width_all(4)
    add_theme_stylebox_override("panel", sb)
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 0.5
    anchor_bottom = 0.5
    offset_left = -260.0
    offset_right = 260.0
    offset_top = -330.0
    offset_bottom = 330.0
    visible = false

    var box := VBoxContainer.new()
    add_child(box)
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 22)
    box.add_theme_constant_override("separation", 10)

    _title = _label(box, 28, Color(1, 1, 1))
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _text = _label(box, 20, Color(0.85, 0.87, 0.92))
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _text.custom_minimum_size = Vector2(470, 0)

    _input = LineEdit.new()
    _input.custom_minimum_size = Vector2(0, 58)
    _input.add_theme_font_size_override("font_size", 24)
    _input.visible = false
    box.add_child(_input)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(spacer)

    _buttons = VBoxContainer.new()
    _buttons.add_theme_constant_override("separation", 8)
    box.add_child(_buttons)


## buttons: [[текст, Callable], ...]. input_hint != "" — показать поле ввода.
func open(title: String, text: String, buttons: Array, input_hint := "") -> void:
    _title.text = title
    _text.text = text
    _input.visible = input_hint != ""
    _input.placeholder_text = input_hint
    _input.text = ""
    for c in _buttons.get_children():
        c.queue_free()
    for item: Array in buttons:
        var b := Button.new()
        b.text = item[0]
        b.custom_minimum_size = Vector2(0, 58)
        b.add_theme_font_size_override("font_size", 22)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_click)
        b.pressed.connect(item[1])
        _buttons.add_child(b)
    visible = true


func input_text() -> String:
    return _input.text.strip_edges()


func close() -> void:
    if not visible:
        return
    visible = false
    _input.release_focus()
    closed.emit()


func _click() -> void:
    Sfx.play("click")


func _label(parent: Control, font_size: int, col: Color) -> Label:
    var l := Label.new()
    var ls := LabelSettings.new()
    ls.font_size = font_size
    ls.font_color = col
    ls.outline_size = 4
    ls.outline_color = Color(0, 0, 0, 0.6)
    l.label_settings = ls
    parent.add_child(l)
    return l
