extends Panel
## Универсальное окно: заголовок, текст, (по желанию) поле ввода и кнопки.
## open("Банкомат", "Текст", [["Снять 1000", callable], ["Закрыть", callable]])
## Кнопка сама окно не закрывает — это решает её обработчик (close() или новый open()).

signal closed

const Ui := preload("res://scripts/ussr_ui.gd")

var _title: Label
var _text: Label
var _input: LineEdit
var _buttons: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
    # тёмная карточка с золотой рамкой и красной полосой сверху — общий стиль «СССР РП»
    var sb := Ui.box(Color(0.1, 0.075, 0.065, 0.985), Ui.GOLD_DIM, 3, 18, 0.0)
    sb.border_width_top = 10
    sb.border_color = Ui.GOLD_DIM
    add_theme_stylebox_override("panel", sb)
    var band := ColorRect.new()
    band.color = Ui.RED
    band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(band)
    band.anchor_right = 1.0
    band.offset_left = 18.0
    band.offset_right = -18.0
    band.offset_top = 3.0
    band.offset_bottom = 9.0
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

    _title = _label(box, 28, Ui.GOLD)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _text = _label(box, 20, Ui.CREAM)
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

    # кнопки — в прокрутке: если их много (жесты, панель админа), список листается пальцем
    _scroll = ScrollContainer.new()
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(_scroll)
    _buttons = VBoxContainer.new()
    _buttons.add_theme_constant_override("separation", 8)
    _buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.add_child(_buttons)


## buttons: [[текст, Callable], ...]. input_hint != "" — показать поле ввода.
func open(title: String, text: String, buttons: Array, input_hint := "") -> void:
    _title.text = title
    _text.text = text
    _input.visible = input_hint != ""
    _input.placeholder_text = input_hint
    _input.text = ""
    for c in _buttons.get_children():
        c.queue_free()
    var first := true
    var two_cols := buttons.size() > 7   # много кнопок (панель админа) — в два столбца
    var row: HBoxContainer = null
    for i in buttons.size():
        var item: Array = buttons[i]
        var b := Button.new()
        b.text = item[0]
        b.custom_minimum_size = Vector2(0, 50 if two_cols else 58)
        b.clip_text = two_cols
        Ui.style_button(b, first and buttons.size() > 1 and not String(item[0]).begins_with("Закрыть"), 19 if two_cols else 22)
        first = false
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_click)
        b.pressed.connect(item[1])
        var last := i == buttons.size() - 1
        if two_cols and not last:
            if row == null or row.get_child_count() >= 2:
                row = HBoxContainer.new()
                row.add_theme_constant_override("separation", 8)
                _buttons.add_child(row)
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(b)
        else:
            _buttons.add_child(b)
    var rows := (buttons.size() - 1 + 1) / 2 + 1 if two_cols else buttons.size()
    var bh := 50.0 if two_cols else 58.0
    var need := rows * bh + maxf(0.0, rows - 1) * 8.0
    var room := 470.0 - (60.0 if input_hint != "" else 0.0) - minf(200.0, text.length() * 0.45)
    _scroll.custom_minimum_size = Vector2(0, minf(need, maxf(200.0, room)))
    _scroll.scroll_vertical = 0
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
    ls.font = Ui.font()
    ls.font_size = font_size
    ls.font_color = col
    ls.outline_size = 4
    ls.outline_color = Color(0, 0, 0, 0.6)
    l.label_settings = ls
    parent.add_child(l)
    return l
