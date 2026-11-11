extends Panel
## Магазин одежды: листаешь варианты стрелками, персонаж сразу примеряет.
## «Купить» — платишь за всё новое и надеваешь. «Закрыть» — снимаешь примерку.

signal preview_changed(look: Dictionary)
signal buy_pressed(look: Dictionary, cost: int)
signal closed

const Clothes := preload("res://scripts/clothes.gd")

var owned := {}   # slot id -> Array номеров купленных вещей
var _look := {}   # что сейчас примеряем
var _rows := {}   # slot id -> Label с названием
var _total: Label
var _buy_btn: Button


func _ready() -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.11, 0.95)
    sb.set_corner_radius_all(24)
    sb.border_color = Color(0.35, 0.35, 0.40)
    sb.set_border_width_all(4)
    add_theme_stylebox_override("panel", sb)
    anchor_left = 0.0
    anchor_right = 0.0
    anchor_top = 0.5
    anchor_bottom = 0.5
    offset_left = 20.0
    offset_right = 560.0
    offset_top = -300.0
    offset_bottom = 300.0
    visible = false

    var box := VBoxContainer.new()
    add_child(box)
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
    box.add_theme_constant_override("separation", 8)
    var title := _label(box, "Магазин одежды", 28)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    for slot: Dictionary in Clothes.SLOTS:
        var id: String = slot["id"]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        box.add_child(row)
        _small_button(row, "<", _step.bind(id, -1))
        var lbl := _label(row, "", 19)
        lbl.custom_minimum_size = Vector2(360, 54)
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _rows[id] = lbl
        _small_button(row, ">", _step.bind(id, 1))

    _total = _label(box, "", 22)
    _total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    box.add_child(buttons)
    _buy_btn = _big_button(buttons, "Купить", _on_buy)
    _big_button(buttons, "Закрыть", _on_close)


func open(current_look: Dictionary, owned_items: Dictionary) -> void:
    _look = current_look.duplicate()
    owned = owned_items
    visible = true
    _refresh()


func _step(id: String, delta: int) -> void:
    Sfx.play("click")
    var n := _items(id).size()
    _look[id] = posmod(int(_look[id]) + delta, n)
    _refresh()
    preview_changed.emit(_look)


func _refresh() -> void:
    var total := cost()
    for slot: Dictionary in Clothes.SLOTS:
        var id: String = slot["id"]
        var i := int(_look[id])
        var item: Array = _items(id)[i]
        var price: int = item[2]
        var state := "есть" if _is_owned(id, i) else ("бесплатно" if price == 0 else "%d ₽" % price)
        var lbl: Label = _rows[id]
        lbl.text = "%s: %s · %s" % [slot["name"], item[0], state]
    _total.text = "К оплате: %d ₽" % total if total > 0 else "Всё уже есть"
    _buy_btn.text = "Купить" if total > 0 else "Надеть"


func cost() -> int:
    var total := 0
    for slot: Dictionary in Clothes.SLOTS:
        var id: String = slot["id"]
        var i := int(_look[id])
        if not _is_owned(id, i):
            var item: Array = _items(id)[i]
            total += int(item[2])
    return total


func _is_owned(id: String, i: int) -> bool:
    var list: Array = owned.get(id, [0])
    return i in list


func _items(id: String) -> Array:
    for slot: Dictionary in Clothes.SLOTS:
        if slot["id"] == id:
            return slot["items"]
    return []


func _on_buy() -> void:
    buy_pressed.emit(_look.duplicate(), cost())


func _on_close() -> void:
    Sfx.play("click")
    visible = false
    closed.emit()


func _label(parent: Control, text: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = text
    var ls := LabelSettings.new()
    ls.font_size = font_size
    ls.outline_size = 4
    ls.outline_color = Color(0, 0, 0, 0.6)
    l.label_settings = ls
    parent.add_child(l)
    return l


func _small_button(parent: Control, text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(58, 54)
    b.add_theme_font_size_override("font_size", 30)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    parent.add_child(b)
    return b


func _big_button(parent: Control, text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(240, 60)
    b.add_theme_font_size_override("font_size", 24)
    b.focus_mode = Control.FOCUS_NONE
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.pressed.connect(cb)
    parent.add_child(b)
    return b
