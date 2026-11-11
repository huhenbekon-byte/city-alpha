extends Control
## Большое окно в стиле концепта GPS: заголовок с иконкой, поиск, крестик,
## категории слева, список справа, две кнопки снизу (тёмная и золотая).
## Им пользуются и Навигатор, и Общий рынок — содержимое задаёт main.gd.
##
## categories: [{"id", "name", "icon"}]
## rows:       [{"icon", "icon_col", "name", "value", "value_col", "pin", "enabled"}]

signal category_selected(id: String)
signal row_selected(index: int)
signal search_changed(text: String)
signal left_pressed
signal right_pressed
signal closed

const Icons := preload("res://scripts/icons.gd")
const GOLD := Color(1.0, 0.72, 0.10)
const DARK := Color(0.09, 0.09, 0.10, 0.98)
const ROW := Color(0.13, 0.13, 0.14)
const BORDER := Color(0.22, 0.22, 0.24)

var title := "GPS"
var title_icon := "pin"
var category := ""
var selected := -1

var _win: Control
var _header: Control
var _search: LineEdit
var _cat_box: VBoxContainer
var _row_box: VBoxContainer
var _row_scroll: ScrollContainer
var _left: Button
var _right: Button
var _cats: Array = []
var _rows: Array = []
var _font: Font


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    _font = ThemeDB.fallback_font

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _win = Control.new()
    add_child(_win)
    _win.anchor_left = 0.5
    _win.anchor_right = 0.5
    _win.anchor_top = 0.5
    _win.anchor_bottom = 0.5
    _win.offset_left = -540.0
    _win.offset_right = 540.0
    _win.offset_top = -340.0
    _win.offset_bottom = 340.0

    # Заголовок «GPS» и рамка поиска рисуются кодом
    _header = Control.new()
    _header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _header.size = Vector2(1000, 80)
    _header.draw.connect(_draw_header)
    _win.add_child(_header)

    _search = LineEdit.new()
    _search.position = Vector2(318, 14)
    _search.size = Vector2(600, 52)
    _search.placeholder_text = "Поиск по GPS..."
    _search.add_theme_font_size_override("font_size", 24)
    _search.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), 0))
    _search.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 0))
    _search.text_changed.connect(func(t: String) -> void: search_changed.emit(t))
    _win.add_child(_search)

    var close := Button.new()
    close.position = Vector2(1002, 6)
    close.size = Vector2(70, 70)
    close.focus_mode = Control.FOCUS_NONE
    close.add_theme_stylebox_override("normal", _box(Color(0.1, 0.1, 0.11), 35, 3, Color(0.25, 0.25, 0.27)))
    close.add_theme_stylebox_override("hover", _box(Color(0.16, 0.16, 0.17), 35, 3, GOLD))
    close.add_theme_stylebox_override("pressed", _box(Color(0.2, 0.2, 0.22), 35, 3, GOLD))
    close.draw.connect(_draw_close.bind(close))
    close.pressed.connect(close_window)
    _win.add_child(close)

    # Категории слева
    var cat_scroll := ScrollContainer.new()
    cat_scroll.position = Vector2(0, 90)
    cat_scroll.size = Vector2(286, 590)
    cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _win.add_child(cat_scroll)
    _cat_box = VBoxContainer.new()
    _cat_box.custom_minimum_size = Vector2(276, 0)
    _cat_box.add_theme_constant_override("separation", 6)
    cat_scroll.add_child(_cat_box)

    # Список справа
    var list_bg := Panel.new()
    list_bg.position = Vector2(298, 90)
    list_bg.size = Vector2(782, 500)
    list_bg.add_theme_stylebox_override("panel", _box(DARK, 18, 2, BORDER))
    list_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _win.add_child(list_bg)
    _row_scroll = ScrollContainer.new()
    _row_scroll.position = Vector2(310, 100)
    _row_scroll.size = Vector2(758, 480)
    _row_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _win.add_child(_row_scroll)
    _row_box = VBoxContainer.new()
    _row_box.custom_minimum_size = Vector2(744, 0)
    _row_box.add_theme_constant_override("separation", 6)
    _row_scroll.add_child(_row_box)

    # Кнопки снизу
    _left = _bottom_button(Vector2(298, 604), Vector2(380, 70), false)
    _left.pressed.connect(func() -> void: left_pressed.emit())
    _right = _bottom_button(Vector2(692, 604), Vector2(388, 70), true)
    _right.pressed.connect(func() -> void: right_pressed.emit())


## Открыть окно. with_search — показывать поле поиска.
func open_window(win_title: String, icon: String, cats: Array, with_search: bool, placeholder := "") -> void:
    title = win_title
    title_icon = icon
    _cats = cats
    _search.visible = with_search
    _search.text = ""
    _search.placeholder_text = placeholder
    selected = -1
    category = String(cats[0]["id"]) if not cats.is_empty() else ""
    _rebuild_categories()
    _header.queue_redraw()
    visible = true
    category_selected.emit(category)


func close_window() -> void:
    if not visible:
        return
    Sfx.play("click")
    visible = false
    _search.release_focus()
    closed.emit()


func set_rows(rows: Array, keep_selection := false) -> void:
    _rows = rows
    if not keep_selection or selected >= rows.size():
        selected = -1
    for c in _row_box.get_children():
        c.queue_free()
    for i in rows.size():
        var b := Button.new()
        b.custom_minimum_size = Vector2(0, 58)
        b.focus_mode = Control.FOCUS_NONE
        var sel := i == selected
        b.add_theme_stylebox_override("normal", _box(ROW, 16, 3 if sel else 2, GOLD if sel else BORDER))
        b.add_theme_stylebox_override("hover", _box(ROW.lightened(0.05), 16, 3 if sel else 2, GOLD if sel else BORDER))
        b.add_theme_stylebox_override("pressed", _box(ROW.lightened(0.1), 16, 3, GOLD))
        b.draw.connect(_draw_row.bind(b, rows[i]))
        b.pressed.connect(_on_row.bind(i))
        _row_box.add_child(b)


func set_buttons(left_text: String, right_text: String, left_on := true, right_on := true) -> void:
    _left.text = left_text
    _right.text = right_text
    _left.disabled = not left_on
    _right.disabled = not right_on
    _left.visible = left_text != ""
    _right.visible = right_text != ""


func search_text() -> String:
    return _search.text.strip_edges()


# ---------------------------------------------------------------- внутреннее

func _on_row(i: int) -> void:
    Sfx.play("click")
    selected = i
    set_rows(_rows, true)
    row_selected.emit(i)


func _on_category(id: String) -> void:
    Sfx.play("click")
    category = id
    selected = -1
    _search.text = ""
    _rebuild_categories()
    category_selected.emit(id)


func _rebuild_categories() -> void:
    for c in _cat_box.get_children():
        c.queue_free()
    for cat: Dictionary in _cats:
        var id: String = cat["id"]
        var on := id == category
        var b := Button.new()
        b.custom_minimum_size = Vector2(0, 52)
        b.focus_mode = Control.FOCUS_NONE
        var bg := Color(0.24, 0.18, 0.05) if on else ROW
        b.add_theme_stylebox_override("normal", _box(bg, 16, 3 if on else 2, GOLD if on else BORDER))
        b.add_theme_stylebox_override("hover", _box(bg.lightened(0.05), 16, 3 if on else 2, GOLD if on else BORDER))
        b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.1), 16, 3, GOLD))
        b.draw.connect(_draw_cat.bind(b, cat))
        b.pressed.connect(_on_category.bind(id))
        _cat_box.add_child(b)


func _draw_close(b: Button) -> void:
    b.draw_line(Vector2(22, 22), Vector2(48, 48), Color.WHITE, 6.0, true)
    b.draw_line(Vector2(48, 22), Vector2(22, 48), Color.WHITE, 6.0, true)


func _draw_cat(b: Button, cat: Dictionary) -> void:
    Icons.draw(b, String(cat["icon"]), Vector2(34, 26), 32, Color.WHITE)
    b.draw_string(_font, Vector2(68, 35), String(cat["name"]), HORIZONTAL_ALIGNMENT_LEFT, 200, 23, Color.WHITE)


func _draw_row(b: Button, row: Dictionary) -> void:
    var enabled: bool = row.get("enabled", true)
    var text_col := Color.WHITE if enabled else Color(0.6, 0.6, 0.62)
    var icon_col: Color = row.get("icon_col", Color.WHITE)
    Icons.draw(b, String(row.get("icon", "pin")), Vector2(40, 29), 34, icon_col)
    b.draw_string(_font, Vector2(80, 38), String(row.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 470, 25, text_col)
    var value := String(row.get("value", ""))
    var right_x := b.size.x - (54.0 if row.get("pin", false) else 20.0)
    var vw := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
    b.draw_string(_font, Vector2(right_x - vw, 38), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
            row.get("value_col", Color(0.85, 0.85, 0.88)))
    if row.get("pin", false):
        Icons.draw(b, "pin", Vector2(b.size.x - 30, 29), 30, Color(0.6, 0.6, 0.64))


func _draw_header() -> void:
    var h := _header
    # Плашка с заголовком и золотым «хвостом»
    h.draw_colored_polygon(PackedVector2Array([Vector2(250, 8), Vector2(270, 8), Vector2(300, 66), Vector2(280, 72)]), GOLD)
    Icons.panel(h, Rect2(0, 0, 276, 76), Color(0.1, 0.1, 0.11), 22, 3, Color(0.2, 0.2, 0.22))
    Icons.draw(h, title_icon, Vector2(48, 38), 46, GOLD)
    h.draw_string(_font, Vector2(90, 54), title, HORIZONTAL_ALIGNMENT_LEFT, 180, 40, Color.WHITE)
    if _search.visible:
        Icons.panel(h, Rect2(298, 8, 700, 64), Color(0.07, 0.07, 0.08), 32, 3, Color(0.3, 0.3, 0.33))
        Icons.draw(h, "search", Vector2(330, 40), 30, Color(0.75, 0.75, 0.78))


func _bottom_button(pos: Vector2, sz: Vector2, gold: bool) -> Button:
    var b := Button.new()
    b.position = pos
    b.size = sz
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 25)
    var bg := GOLD if gold else Color(0.1, 0.1, 0.11)
    b.add_theme_stylebox_override("normal", _box(bg, 18, 2, BORDER))
    b.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), 18, 2, GOLD))
    b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), 18, 2, GOLD))
    b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.4), 18, 2, BORDER))
    var fc := Color(0.08, 0.08, 0.08) if gold else Color.WHITE
    b.add_theme_color_override("font_color", fc)
    b.add_theme_color_override("font_hover_color", fc)
    b.add_theme_color_override("font_pressed_color", fc)
    b.add_theme_color_override("font_disabled_color", fc * Color(1, 1, 1, 0.5))
    b.pressed.connect(func() -> void: Sfx.play("click"))
    _win.add_child(b)
    return b


func _box(col: Color, radius: int, border := 0, border_col := Color.BLACK) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = col
    sb.set_corner_radius_all(radius)
    sb.anti_aliasing = true
    if border > 0:
        sb.set_border_width_all(border)
        sb.border_color = border_col
    sb.content_margin_left = 16
    sb.content_margin_right = 16
    return sb
