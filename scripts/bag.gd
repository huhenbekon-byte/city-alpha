extends Control
## Сумка по концепту игрока: тёмная шапка с жёлтым рюкзаком и надписью «СУМКА», жёлтый
## скос справа, отдельная квадратная кнопка ×, под ней сетка 5×5 ячеек. Вещи лежат стопками
## (иконка и «×3»). Тап по ячейке — выбрать; внизу название, польза и кнопки
## «Использовать» / «Выбросить».

signal use_requested(item: String)
signal drop_requested(item: String)
signal closed

const Icons := preload("res://scripts/icons.gd")
const COLS := 5
const ROWS := 5
const SLOT := Vector2(128, 92)
const GAP := 12.0
const HEAD_H := 84.0
const INFO_H := 78.0
const PANEL_DARK := Color(0.10, 0.10, 0.11)
const SLOT_COL := Color(0.15, 0.15, 0.17)
const SLOT_BORDER := Color(0.27, 0.27, 0.30)
const GOLD := Color(1.0, 0.76, 0.12)

var items: Array = []      # [{"name", "count", "icon", "about"}]
var cap_text := ""
var selected := -1

var _win: Control
var _font: Font
var _bold: Font
var _use_b: Button
var _drop_b: Button
var _size := Vector2.ZERO


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    _font = ThemeDB.fallback_font
    _bold = load("res://fonts/menu_bold.ttf") if ResourceLoader.exists("res://fonts/menu_bold.ttf") else _font
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.5)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    var grid_w := COLS * SLOT.x + (COLS + 1) * GAP
    var grid_h := ROWS * SLOT.y + (ROWS + 1) * GAP
    _size = Vector2(grid_w, HEAD_H + 12 + grid_h + INFO_H)
    _win = Control.new()
    _win.size = _size
    _win.mouse_filter = Control.MOUSE_FILTER_STOP
    _win.draw.connect(_draw_win)
    _win.gui_input.connect(_win_input)
    add_child(_win)
    var x := Button.new()
    x.flat = true
    x.focus_mode = Control.FOCUS_NONE
    x.position = Vector2(_size.x - HEAD_H, 0)
    x.size = Vector2(HEAD_H, HEAD_H)
    x.draw.connect(_draw_close.bind(x))
    x.pressed.connect(close_bag)
    _win.add_child(x)
    _use_b = _button("Использовать", GOLD, Color(0.08, 0.08, 0.08))
    _drop_b = _button("Выбросить", Color(0.18, 0.18, 0.2), Color.WHITE)
    _use_b.pressed.connect(func() -> void:
        if selected >= 0 and selected < items.size():
            use_requested.emit(String(items[selected]["name"])))
    _drop_b.pressed.connect(func() -> void:
        if selected >= 0 and selected < items.size():
            drop_requested.emit(String(items[selected]["name"])))
    resized.connect(_layout)


func _button(text: String, bg: Color, fg: Color) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 21)
    for st: String in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg if st != "pressed" else bg.lightened(0.15)
        if st == "disabled":
            sb.bg_color = Color(0.16, 0.16, 0.17)
        sb.set_corner_radius_all(14)
        b.add_theme_stylebox_override(st, sb)
    for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
        b.add_theme_color_override(k, fg)
    b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.52))
    b.pressed.connect(func() -> void: Sfx.play("click"))
    _win.add_child(b)
    return b


func open_bag(list: Array, cap: String) -> void:
    items = list
    cap_text = cap
    if selected >= items.size():
        selected = items.size() - 1
    visible = true
    _layout()
    _update_buttons()
    _win.queue_redraw()


func close_bag() -> void:
    if not visible:
        return
    Sfx.play("click")
    visible = false
    closed.emit()


func _layout() -> void:
    var vp := size
    var k := minf(1.0, minf((vp.x - 20.0) / _size.x, (vp.y - 20.0) / _size.y))
    _win.scale = Vector2(k, k)
    _win.position = (vp - _size * k) * 0.5
    var by := _size.y - INFO_H + 14
    _use_b.position = Vector2(_size.x - 2 * 190 - 24, by)
    _use_b.size = Vector2(190, 52)
    _drop_b.position = Vector2(_size.x - 190 - 12, by)
    _drop_b.size = Vector2(178, 52)


func _update_buttons() -> void:
    var ok := selected >= 0 and selected < items.size()
    _use_b.disabled = not ok
    _drop_b.disabled = not ok


func _slot_rect(i: int) -> Rect2:
    var cx := i % COLS
    var cy := i / COLS
    return Rect2(Vector2(GAP + cx * (SLOT.x + GAP), HEAD_H + 12 + GAP + cy * (SLOT.y + GAP)), SLOT)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:   # тап мимо окна — закрыть
        close_bag()
        accept_event()


func _win_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var p: Vector2 = event.position
        for i in COLS * ROWS:
            if _slot_rect(i).has_point(p):
                selected = i if i < items.size() else -1
                Sfx.play("click")
                _update_buttons()
                _win.queue_redraw()
                break
        _win.accept_event()


func _draw_win() -> void:
    var ci := _win
    # шапка
    var head := Rect2(0, 0, _size.x - HEAD_H - 12, HEAD_H)
    Icons.panel(ci, head, Color(0.12, 0.12, 0.13), 20, 3, Color(0.03, 0.03, 0.03))
    var tip := PackedVector2Array([Vector2(head.end.x - 54, 0), Vector2(head.end.x - 30, 0),
            Vector2(head.end.x + 2, head.end.y - 4), Vector2(head.end.x - 16, head.end.y - 4)])
    ci.draw_colored_polygon(tip, GOLD)
    _backpack(ci, Vector2(48, HEAD_H * 0.5))
    ci.draw_string(_bold, Vector2(96, HEAD_H * 0.5 + 16), "СУМКА", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
    var tw := _bold.get_string_size("СУМКА", HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
    ci.draw_string(_font, Vector2(110 + tw, HEAD_H * 0.5 + 12), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.6, 0.6, 0.64))
    # кнопка закрытия — отдельный квадрат
    Icons.panel(ci, Rect2(_size.x - HEAD_H, 0, HEAD_H, HEAD_H), Color(0.12, 0.12, 0.13), 20, 3, Color(0.03, 0.03, 0.03))
    # сетка
    var body := Rect2(0, HEAD_H + 12, _size.x, _size.y - HEAD_H - 12)
    Icons.panel(ci, body, PANEL_DARK, 22, 3, Color(0.03, 0.03, 0.03))
    for i in COLS * ROWS:
        var r := _slot_rect(i)
        var sel := i == selected
        Icons.panel(ci, r, SLOT_COL, 14, 3 if sel else 2, GOLD if sel else SLOT_BORDER)
        if i < items.size():
            var it: Dictionary = items[i]
            Icons.draw(ci, String(it["icon"]), r.get_center() + Vector2(0, -4), 56, Color.WHITE)
            var cnt := int(it["count"])
            if cnt > 1:
                var t := "×%d" % cnt
                var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
                Icons.panel(ci, Rect2(r.end - Vector2(w + 16, 28), Vector2(w + 10, 22)), Color(0, 0, 0, 0.6), 8)
                ci.draw_string(_font, r.end - Vector2(w + 11, 11), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
    # низ: что выбрано
    var iy := _size.y - INFO_H + 30
    if selected >= 0 and selected < items.size():
        var it: Dictionary = items[selected]
        ci.draw_string(_bold, Vector2(22, iy + 4), String(it["name"]), HORIZONTAL_ALIGNMENT_LEFT, _size.x - 440, 24, GOLD)
        ci.draw_string(_font, Vector2(22, iy + 32), String(it["about"]), HORIZONTAL_ALIGNMENT_LEFT, _size.x - 440, 19, Color(0.8, 0.8, 0.84))
    elif items.is_empty():
        ci.draw_string(_font, Vector2(22, iy + 14), "Сумка пуста — купи еду в ларьках", HORIZONTAL_ALIGNMENT_LEFT, _size.x - 440, 21, Color(0.6, 0.6, 0.64))
    else:
        ci.draw_string(_font, Vector2(22, iy + 14), "Нажми на вещь, чтобы выбрать", HORIZONTAL_ALIGNMENT_LEFT, _size.x - 440, 21, Color(0.6, 0.6, 0.64))


## Жёлтый рюкзак как на концепте: корпус, ручка, карман и лямки.
func _backpack(ci: Control, c: Vector2) -> void:
    ci.draw_arc(c + Vector2(0, -20), 9, PI, TAU, 16, GOLD, 5.0, true)
    Icons.panel(ci, Rect2(c + Vector2(-22, -20), Vector2(44, 46)), GOLD, 12)
    Icons.panel(ci, Rect2(c + Vector2(-14, 4), Vector2(28, 16)), Color(0.85, 0.6, 0.05), 5)
    ci.draw_line(c + Vector2(-14, -6), c + Vector2(14, -6), Color(0.12, 0.12, 0.13), 3.0)
    for sx: float in [-6.0, 6.0]:
        ci.draw_line(c + Vector2(sx, 6), c + Vector2(sx, 18), Color(0.12, 0.12, 0.13), 2.0)


func _draw_close(b: Button) -> void:
    var m := 26.0
    var s := b.size
    b.draw_line(Vector2(m, m), s - Vector2(m, m), Color.WHITE, 8.0, true)
    b.draw_line(Vector2(s.x - m, m), Vector2(m, s.y - m), Color.WHITE, 8.0, true)
