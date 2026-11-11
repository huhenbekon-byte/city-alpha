extends Control
## Сенсорное управление (мультитач).
## Пешком:   джойстик слева, кнопка прыжка справа.
## В машине: джойстик слева — руль, справа педали ГАЗ и ТОРМОЗ.
## Кнопка действия («Сесть» / «Выйти») появляется над правыми кнопками.
## Свайп по свободной части экрана крутит камеру.

signal look_drag(relative: Vector2)
signal interact_pressed

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
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)


func _buttons() -> Array:
    var w := size.x
    var h := size.y
    var list := []
    if mode == Mode.FOOT:
        list.append({"id": "jump", "pos": Vector2(w - 150, h - 160), "r": 66.0, "text": ""})
    else:
        list.append({"id": "gas", "pos": Vector2(w - 140, h - 175), "r": 72.0, "text": "ГАЗ"})
        list.append({"id": "brake", "pos": Vector2(w - 315, h - 120), "r": 58.0, "text": "ТОРМОЗ"})
    if interact_text != "":
        list.append({"id": "interact", "pos": Vector2(w - 145, h - 355), "r": 54.0, "text": interact_text})
    return list


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _on_touch(event as InputEventScreenTouch)
    elif event is InputEventScreenDrag:
        _on_drag(event as InputEventScreenDrag)


func _on_touch(e: InputEventScreenTouch) -> void:
    if e.pressed:
        if pads_enabled:
            for b: Dictionary in _buttons():
                var pos: Vector2 = b["pos"]
                var r: float = b["r"]
                var id: String = b["id"]
                if not _held.has(id) and e.position.distance_to(pos) < r * 1.2:
                    _held[id] = e.index
                    _set_button(id, true)
                    queue_redraw()
                    return
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


func _release_all() -> void:
    if _held.has("jump"):
        Input.action_release("jump")
    _held.clear()
    gas = false
    brake = false


func _draw() -> void:
    if not pads_enabled:
        return
    var base := _joy_center if _joy_index != -1 else Vector2(210.0, size.y - 200.0)
    var knob := _joy_knob if _joy_index != -1 else base
    # Тёмная подложка + белая обводка: видно и на светлом асфальте, и на небе.
    draw_circle(base, JOY_RADIUS, Color(0, 0, 0, 0.28))
    draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
    draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.75))
    draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 2.0, true)

    var font := ThemeDB.fallback_font
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
        draw_circle(pos, r, fill)
        draw_arc(pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 4.0, true)
        if id == "jump":
            draw_colored_polygon(PackedVector2Array([
                pos + Vector2(0, -24), pos + Vector2(22, 12), pos + Vector2(-22, 12)
            ]), Color(1, 1, 1, 0.95))
        else:
            var fs := 24
            draw_string(font, pos + Vector2(-r, fs * 0.35), text,
                    HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.95))
