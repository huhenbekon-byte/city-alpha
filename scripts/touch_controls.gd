extends Control
## Сенсорное управление (мультитач).
## Пешком:   джойстик слева, кнопка прыжка справа.
## В машине: джойстик слева — руль, справа педали ГАЗ и ТОРМОЗ.
## Кнопка действия («Сесть» / «Выйти») появляется над правыми кнопками.
## Свайп по свободной части экрана крутит камеру.

const Icons := preload("res://scripts/icons.gd")

signal look_drag(relative: Vector2)
signal interact_pressed
signal phone_pressed
signal horn_pressed
signal hudmenu_pressed
signal radio_pressed
signal weapon_pressed

enum Mode { FOOT, CAR }

const JOY_RADIUS := 110.0
const KNOB_RADIUS := 46.0

## false на ПК: кнопки не рисуются, любой drag мышью крутит камеру.
var pads_enabled := true
var mode: Mode = Mode.FOOT:
    set(value):
        if value == mode:
            return
        mode = value
        _release_all()
        queue_redraw()
## true, пока открыт телефон: касания уходят в его кнопки, а не в джойстик.
var blocked := false:
    set(value):
        blocked = value
        _release_all()
        _joy_index = -1
        _look_index = -1
        joy_vector = Vector2.ZERO
        queue_redraw()
## Подпись на кнопке оружия («КУЛАК», «ПМ»...). Пусто — кнопок оружия нет.
var weapon_text := "":
    set(value):
        if value == weapon_text:
            return
        weapon_text = value
        queue_redraw()
## Кнопка «удар/огонь» зажата (автомат стреляет очередью).
var attack_held := false
var interact_text := "":
    set(value):
        if value == interact_text:
            return
        interact_text = value
        queue_redraw()

## Вектор джойстика, длина 0..1 (y < 0 — вперёд).
var joy_vector := Vector2.ZERO
var gas := false
var brake := false

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _look_index := -1
var _held := {}  # id кнопки -> индекс пальца


func _ready() -> void:
    # Именно *_and_offsets_*: иначе размер остаётся 0x0 и кнопки рисуются за экраном.
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)


func _buttons() -> Array:
    var w := size.x
    var h := size.y
    var list := []
    if mode == Mode.FOOT:
        list.append({"id": "jump", "pos": Vector2(w - 150, h - 160), "r": 66.0, "text": ""})
        if weapon_text != "":
            list.append({"id": "attack", "pos": Vector2(w - 320, h - 125), "r": 62.0,
                    "text": "УДАР" if weapon_text == "КУЛАК" else "ОГОНЬ"})
            list.append({"id": "weapon", "pos": Vector2(w - 330, h - 285), "r": 44.0, "text": weapon_text})
    else:
        list.append({"id": "gas", "pos": Vector2(w - 140, h - 175), "r": 72.0, "text": "ГАЗ"})
        list.append({"id": "brake", "pos": Vector2(w - 315, h - 120), "r": 58.0, "text": "ТОРМОЗ"})
        list.append({"id": "horn", "pos": Vector2(w - 305, h - 268), "r": 44.0, "text": "БИП"})
        list.append({"id": "radio", "pos": Vector2(w - 450, h - 205), "r": 40.0, "text": "РАДИО"})
    if interact_text != "":
        list.append({"id": "interact", "pos": Vector2(w - 145, h - 355), "r": 54.0, "text": interact_text})
    list.append({"id": "phone", "pos": Vector2(w - 62, 62), "r": 38.0, "text": ""})
    list.append({"id": "hudmenu", "pos": Vector2(282, 46), "r": 32.0, "text": ""})
    return list


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _on_touch(event as InputEventScreenTouch)
    elif event is InputEventScreenDrag:
        _on_drag(event as InputEventScreenDrag)


func _on_touch(e: InputEventScreenTouch) -> void:
    if e.pressed:
        if blocked:
            return
        for b: Dictionary in _buttons():
            var pos: Vector2 = b["pos"]
            var r: float = b["r"]
            var id: String = b["id"]
            if not pads_enabled and id != "phone" and id != "hudmenu":
                continue  # на ПК из кнопок только телефон
            if not _held.has(id) and e.position.distance_to(pos) < r * 1.2:
                _held[id] = e.index
                _set_button(id, true)
                queue_redraw()
                return
        if pads_enabled:
            if _joy_index == -1 and e.position.x < size.x * 0.45 and e.position.y > size.y * 0.3:
                _joy_index = e.index
                _joy_center = e.position
                _joy_knob = e.position
                joy_vector = Vector2.ZERO
                queue_redraw()
                return
        if _look_index == -1:
            _look_index = e.index
    else:
        for id: String in _held.keys():
            if _held[id] == e.index:
                _held.erase(id)
                _set_button(id, false)
        if e.index == _joy_index:
            _joy_index = -1
            joy_vector = Vector2.ZERO
        if e.index == _look_index:
            _look_index = -1
        queue_redraw()


func _on_drag(e: InputEventScreenDrag) -> void:
    if e.index == _joy_index:
        var off := (e.position - _joy_center).limit_length(JOY_RADIUS)
        _joy_knob = _joy_center + off
        joy_vector = off / JOY_RADIUS
        queue_redraw()
    elif e.index == _look_index:
        look_drag.emit(e.relative)


func _set_button(id: String, down: bool) -> void:
    match id:
        "jump":
            if down:
                Input.action_press("jump")
            else:
                Input.action_release("jump")
        "gas":
            gas = down
        "brake":
            brake = down
        "interact":
            if down:
                interact_pressed.emit()
        "phone":
            if down:
                phone_pressed.emit()
        "horn":
            if down:
                horn_pressed.emit()
        "hudmenu":
            if down:
                hudmenu_pressed.emit()
        "radio":
            if down:
                radio_pressed.emit()
        "attack":
            attack_held = down
        "weapon":
            if down:
                weapon_pressed.emit()


func _release_all() -> void:
    if _held.has("jump"):
        Input.action_release("jump")
    _held.clear()
    attack_held = false
    gas = false
    brake = false


func _draw() -> void:
    if blocked:
        return
    var font := ThemeDB.fallback_font
    if not pads_enabled:
        _draw_phone_button(font)
        return
    var base := _joy_center if _joy_index != -1 else Vector2(210.0, size.y - 200.0)
    var knob := _joy_knob if _joy_index != -1 else base
    # Тёмная подложка + белая обводка: видно и на светлом асфальте, и на небе.
    draw_circle(base, JOY_RADIUS, Color(0, 0, 0, 0.28))
    draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
    draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.75))
    draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 2.0, true)

    for b: Dictionary in _buttons():
        var pos: Vector2 = b["pos"]
        var r: float = b["r"]
        var id: String = b["id"]
        var text: String = b["text"]
        var down := _held.has(id)
        var fill := Color(0, 0, 0, 0.5 if down else 0.3)
        if id == "gas":
            fill = Color(0.15, 0.6, 0.25, 0.8 if down else 0.55)
        elif id == "brake":
            fill = Color(0.75, 0.15, 0.12, 0.8 if down else 0.55)
        elif id == "interact":
            fill = Color(0.9, 0.6, 0.05, 0.9 if down else 0.7)
        elif id == "attack":
            fill = Color(0.7, 0.12, 0.1, 0.85 if down else 0.55)
        draw_circle(pos, r, fill)
        draw_arc(pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 4.0, true)
        if id == "phone":
            _draw_phone_icon(pos)
        elif id == "hudmenu":
            _draw_hudmenu(pos, r, down)
            continue
        elif id == "jump":
            draw_colored_polygon(PackedVector2Array([
                pos + Vector2(0, -24), pos + Vector2(22, 12), pos + Vector2(-22, 12)
            ]), Color(1, 1, 1, 0.95))
        else:
            var fs := 24 if text.length() <= 6 else 17
            draw_string(font, pos + Vector2(-r, fs * 0.35), text,
                    HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.95))


func _draw_phone_button(_font: Font) -> void:
    for b: Dictionary in _buttons():
        if b["id"] == "hudmenu":
            _draw_hudmenu(b["pos"], b["r"], _held.has("hudmenu"))
        if b["id"] == "phone":
            var pos: Vector2 = b["pos"]
            var r: float = b["r"]
            draw_circle(pos, r, Color(0, 0, 0, 0.5 if _held.has("phone") else 0.3))
            draw_arc(pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 4.0, true)
            _draw_phone_icon(pos)


func _draw_phone_icon(pos: Vector2) -> void:
    var body := Rect2(pos - Vector2(11, 18), Vector2(22, 36))
    draw_rect(body, Color(1, 1, 1, 0.95), false, 3.0)
    draw_rect(Rect2(pos - Vector2(7, 13), Vector2(14, 21)), Color(0.5, 0.8, 1.0, 0.9))
    draw_circle(pos + Vector2(0, 13), 2.2, Color(1, 1, 1, 0.95))


## Кнопка меню игрока: тёмный круг с четырьмя белыми квадратиками.
func _draw_hudmenu(pos: Vector2, r: float, down: bool) -> void:
    draw_circle(pos, r + 2.0, Color(0.6, 0.6, 0.62))
    draw_circle(pos, r, Color(0.13, 0.13, 0.14) if not down else Color(0.25, 0.25, 0.27))
    Icons.draw(self, "grid", pos, r * 1.1, Color.WHITE)
