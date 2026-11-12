extends Control
## Главное меню / пауза и настройки. Работает, пока игра на паузе.
## Настройки хранятся в user://settings.cfg.

signal play_pressed
signal reset_pressed
signal quit_pressed
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое"]
const VIEW_NAMES := ["Близко", "Средне", "Далеко"]
const VOLUME_STEPS := [0.0, 0.25, 0.5, 0.75, 1.0]

var settings := {"quality": 1, "shadows": true, "view": 1, "fps": true, "volume": 3, "music": 2}
var started := false

var _bg_image: TextureRect
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _subtitle: Label
var _play_btn: Button
var _reset_btn: Button
var _reset_armed := false
var _quality_btn: Button
var _shadows_btn: Button
var _view_btn: Button
var _fps_btn: Button
var _volume_btn: Button
var _music_btn: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    load_settings()

    # Фон главного меню (картинка) — только до старта; на паузе видно саму игру.
    _bg_image = TextureRect.new()
    if ResourceLoader.exists("res://textures/menu_bg.jpg"):
        _bg_image.texture = load("res://textures/menu_bg.jpg")
    _bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_bg_image)
    _bg_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var bg := ColorRect.new()
    bg.color = Color(0.03, 0.04, 0.07, 0.55)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    center.add_child(col)

    var title := _label(col, "CITY ALPHA", 64, Color(1, 1, 1))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle = _label(col, "", 20, Color(0.75, 0.8, 0.9))
    _subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    _main_box = VBoxContainer.new()
    _main_box.add_theme_constant_override("separation", 12)
    col.add_child(_main_box)
    _play_btn = _button(_main_box, "Играть", _on_play)
    _button(_main_box, "Настройки", _show_settings)
    _reset_btn = _button(_main_box, "Сбросить прогресс", _on_reset)
    _button(_main_box, "Выйти из игры", _on_quit)

    _settings_box = VBoxContainer.new()
    _settings_box.add_theme_constant_override("separation", 10)
    _settings_box.visible = false
    col.add_child(_settings_box)
    _quality_btn = _button(_settings_box, "", _cycle.bind("quality"))
    _shadows_btn = _button(_settings_box, "", _cycle.bind("shadows"))
    _view_btn = _button(_settings_box, "", _cycle.bind("view"))
    _fps_btn = _button(_settings_box, "", _cycle.bind("fps"))
    _volume_btn = _button(_settings_box, "", _cycle.bind("volume"))
    _music_btn = _button(_settings_box, "", _cycle.bind("music"))
    _button(_settings_box, "Назад", _show_main)
    _refresh()


func show_menu(is_started: bool, version: String) -> void:
    started = is_started
    visible = true
    _bg_image.visible = not started
    _subtitle.text = ("Пауза" if started else "альфа-версия") + "  ·  " + version
    _play_btn.text = "Продолжить" if started else "Играть"
    _reset_armed = false
    _reset_btn.text = "Сбросить прогресс"
    _show_main()


func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        if _settings_box.visible:
            _show_main()
        elif started:
            play_pressed.emit()
        get_viewport().set_input_as_handled()


func _on_play() -> void:
    play_pressed.emit()


func _on_quit() -> void:
    quit_pressed.emit()


func _on_reset() -> void:
    if not _reset_armed:
        _reset_armed = true
        _reset_btn.text = "Точно? Нажми ещё раз"
        return
    _reset_armed = false
    _reset_btn.text = "Сбросить прогресс"
    reset_pressed.emit()


func _show_settings() -> void:
    _main_box.visible = false
    _settings_box.visible = true


func _show_main() -> void:
    _settings_box.visible = false
    _main_box.visible = true


func _cycle(key: String) -> void:
    match key:
        "quality":
            settings["quality"] = (int(settings["quality"]) + 1) % 3
        "view":
            settings["view"] = (int(settings["view"]) + 1) % 3
        "volume", "music":
            settings[key] = (int(settings[key]) + 1) % VOLUME_STEPS.size()
        "shadows", "fps":
            settings[key] = not bool(settings[key])
    _refresh()
    save_settings()
    settings_changed.emit()


func _refresh() -> void:
    _quality_btn.text = "Качество: %s" % QUALITY_NAMES[int(settings["quality"])]
    _shadows_btn.text = "Тени: %s" % ("вкл" if settings["shadows"] else "выкл")
    _view_btn.text = "Дальность: %s" % VIEW_NAMES[int(settings["view"])]
    _fps_btn.text = "Показывать FPS: %s" % ("да" if settings["fps"] else "нет")
    var vol: float = VOLUME_STEPS[int(settings["volume"])]
    _volume_btn.text = "Звук: %d%%" % int(vol * 100.0)
    _music_btn.text = "Музыка и радио: %d%%" % int(music_volume() * 100.0)


func music_volume() -> float:
    return VOLUME_STEPS[clampi(int(settings.get("music", 2)), 0, VOLUME_STEPS.size() - 1)]


func volume() -> float:
    return VOLUME_STEPS[int(settings["volume"])]


func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return
    for key: String in settings.keys():
        settings[key] = cfg.get_value("settings", key, settings[key])


func save_settings() -> void:
    var cfg := ConfigFile.new()
    for key: String in settings.keys():
        cfg.set_value("settings", key, settings[key])
    cfg.save(SETTINGS_PATH)


func _button(parent: Control, text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.pressed.connect(_click)
    b.text = text
    b.custom_minimum_size = Vector2(440, 64)
    b.add_theme_font_size_override("font_size", 26)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    parent.add_child(b)
    return b


func _label(parent: Control, text: String, font_size: int, col: Color) -> Label:
    var l := Label.new()
    l.text = text
    var ls := LabelSettings.new()
    ls.font_size = font_size
    ls.font_color = col
    ls.outline_size = 8
    ls.outline_color = Color(0, 0, 0, 0.6)
    l.label_settings = ls
    parent.add_child(l)
    return l


func _click() -> void:
    Sfx.play("click")
