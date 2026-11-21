extends Control
## Стартовый экран: главное меню («ИГРАТЬ» и настройки) → выбор сервера → загрузка.
## Город строится только после выбора сервера, потом сразу начинается игра.

signal server_chosen(index: int)

const MenuScript := preload("res://scripts/menu.gd")
const Ui := preload("res://scripts/ussr_ui.gd")
## Советы на экране загрузки — меняются каждые 4 секунды.
const TIPS := [
    "Совет: паспорт выдают в мэрии, права — в автошколе на площади.",
    "Совет: сытость падает медленно — поесть можно в ларьке «ЕДА» или дома.",
    "Совет: в игре московское время — ночью на улицах темно и горят фонари.",
    "Совет: вступить в организацию — в отделе кадров её здания.",
    "Совет: в ДК крутят кино, а вечером — дискотека.",
    "Совет: на слабом планшете включи «Слабое устройство» в настройках.",
    "Совет: свою машину можно купить на Общем рынке.",
    "Совет: зарплата во фракции приходит каждые 3 минуты.",
]
const MAIN_BG := "res://textures/menu_main.jpg"
const PLAY_TEX := "res://textures/menu_play.png"
const GEAR_TEX := "res://textures/menu_gear.png"
const SERVERS_BG := "res://textures/servers_bg.jpg"
const FONT_PATH := "res://fonts/menu_bold.ttf"
## Где на картинке меню нарисована кнопка «ИГРАТЬ» (в пикселях картинки).
const PLAY_RECT := Rect2(540, 375, 600, 200)
const GOLD := Color(0.95, 0.74, 0.33)

## Сервера на экране выбора.
## host — адрес онлайн-сервера ("адрес:порт"); пусто — одиночная игра без сети.
const SERVERS := [
    {"name": "1 СЕРВЕР", "info": "Онлайн · Казань · Пятигорск · Бусаево", "host": "city-alpha.onrender.com"},
]
var chosen_host := ""      # куда подключаться (читает main.gd после server_chosen)
var _addr: LineEdit
var _font: Font = null
var _page_main: Control
var _page_servers: Control
var _page_loading: Control
var _main_bg: TextureRect
var _play: TextureRect
var _play_hit: Button
var _settings: MenuScript
var _load_bar: ProgressBar
var _load_text: Label
var _time := 0.0
var _hover := false
var _tip: Label
var _tip_i := 0
var _tip_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if ResourceLoader.exists(FONT_PATH):
        _font = load(FONT_PATH)
    _build_main()
    _build_servers()
    _build_loading()
    _settings = MenuScript.new()
    _settings.visible = false
    add_child(_settings)
    _settings.settings_closed.connect(func() -> void: _page_main.visible = true)
    _settings.settings_changed.connect(func() -> void: Music.volume = _settings.music_volume())
    resized.connect(_layout)
    _show("main")
    _layout.call_deferred()


func _process(delta: float) -> void:
    _time += delta
    if _tip and _page_loading.visible:
        _tip_t += delta
        if _tip_t >= 4.0:
            _tip_t = 0.0
            _tip_i = (_tip_i + 1) % TIPS.size()
            _tip.text = TIPS[_tip_i]
    if _play and _page_main.visible:
        # кнопка «дышит», под пальцем — чуть больше и ярче
        var k := 1.0 + 0.018 * sin(_time * 3.0) + (0.03 if _hover else 0.0)
        _play.scale = Vector2(k, k)
        var glow := 1.0 + 0.08 * (0.5 + 0.5 * sin(_time * 3.0)) + (0.15 if _hover else 0.0)
        _play.modulate = Color(glow, glow, glow)


func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel") and _page_servers.visible:
        _show("main")
        get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and _page_servers and _page_servers.visible:
        _show("main")


func _show(page: String) -> void:
    _page_main.visible = page == "main"
    _page_servers.visible = page == "servers"
    _page_loading.visible = page == "loading"


# ---------------------------------------------------------------- главное меню

func _build_main() -> void:
    _page_main = Control.new()
    add_child(_page_main)
    _page_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.02, 0.04)
    _page_main.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _main_bg = TextureRect.new()
    if ResourceLoader.exists(MAIN_BG):
        _main_bg.texture = load(MAIN_BG)
    _main_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _main_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _main_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _page_main.add_child(_main_bg)
    _main_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Кнопка «ИГРАТЬ» — та же, что на картинке, сверху: её можно анимировать.
    _play = TextureRect.new()
    if ResourceLoader.exists(PLAY_TEX):
        _play.texture = load(PLAY_TEX)
    _play.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _play.stretch_mode = TextureRect.STRETCH_SCALE
    _play.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _page_main.add_child(_play)
    _play_hit = _flat_button(_page_main)
    _play_hit.pressed.connect(_on_play)
    _play_hit.mouse_entered.connect(func() -> void: _hover = true)
    _play_hit.mouse_exited.connect(func() -> void: _hover = false)
    _play_hit.button_down.connect(func() -> void: _hover = true)
    _play_hit.button_up.connect(func() -> void: _hover = false)

    # Шестерёнка — всегда в правом верхнем углу экрана
    var gear := TextureButton.new()
    if ResourceLoader.exists(GEAR_TEX):
        gear.texture_normal = load(GEAR_TEX)
    gear.ignore_texture_size = true
    gear.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    gear.focus_mode = Control.FOCUS_NONE
    _page_main.add_child(gear)
    gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    gear.offset_left = -130
    gear.offset_right = -30
    gear.offset_top = 30
    gear.offset_bottom = 130
    gear.pressed.connect(_on_settings)

    # логотип: эмблема и название, под ним — где идёт действие
    var logo := HBoxContainer.new()
    logo.add_theme_constant_override("separation", 16)
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _page_main.add_child(logo)
    logo.position = Vector2(36, 26)
    logo.add_child(Ui.Emblem.new(40.0))
    var lcol := VBoxContainer.new()
    lcol.add_theme_constant_override("separation", -6)
    logo.add_child(lcol)
    var big := _text(lcol, "СССР РП", 64, Ui.GOLD)
    big.label_settings.outline_size = 10
    big.label_settings.outline_color = Color(0.25, 0.03, 0.02, 0.9)
    big.label_settings.shadow_size = 6
    big.label_settings.shadow_color = Color(0, 0, 0, 0.6)
    _text(lcol, "КАЗАНЬ · ПЯТИГОРСК · БУСАЕВО · 1987", 18, Ui.CREAM)

    var ver := _text(_page_main, "СССР РП · альфа-версия", 18, Color(1, 1, 1, 0.55))
    ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    ver.offset_left = 24
    ver.offset_top = -44
    ver.offset_bottom = -16
    ver.offset_right = 600


## Кнопка «ИГРАТЬ» стоит ровно там, где она нарисована на фоне (фон растянут «с обрезкой»).
func _layout() -> void:
    if _main_bg == null or _main_bg.texture == null:
        return
    var tex_size := _main_bg.texture.get_size()
    var view := size
    var sc := maxf(view.x / tex_size.x, view.y / tex_size.y)
    var off := (view - tex_size * sc) * 0.5
    var r := Rect2(off + PLAY_RECT.position * sc, PLAY_RECT.size * sc)
    _play.position = r.position
    _play.size = r.size
    _play.pivot_offset = r.size * 0.5
    # кликабельная часть — сама плашка, без свечения
    _play_hit.position = r.position + r.size * Vector2(0.06, 0.12)
    _play_hit.size = r.size * Vector2(0.88, 0.76)


func _on_play() -> void:
    Sfx.play("click")
    _show("servers")


func _on_settings() -> void:
    Sfx.play("click")
    _page_main.visible = false
    _settings.open_settings_only()


# ---------------------------------------------------------------- выбор сервера (горизонтальный)

func _build_servers() -> void:
    _page_servers = Control.new()
    add_child(_page_servers)
    _page_servers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.03, 0.08)
    _page_servers.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var pic := TextureRect.new()
    if ResourceLoader.exists(SERVERS_BG):
        pic.texture = load(SERVERS_BG)
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _page_servers.add_child(pic)
    pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Заголовок с линиями по бокам
    var head := HBoxContainer.new()
    head.alignment = BoxContainer.ALIGNMENT_CENTER
    head.add_theme_constant_override("separation", 40)
    _page_servers.add_child(head)
    head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    head.offset_top = 40
    head.offset_bottom = 120
    head.add_child(_line())
    head.add_child(_text(null, "ВЫБОР СЕРВЕРА", 60, Color.WHITE))
    head.add_child(_line())

    # Карточки серверов — в ряд по горизонтали
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 36)
    _page_servers.add_child(row)
    row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    row.offset_left = -700
    row.offset_right = 700
    row.offset_top = -110
    row.offset_bottom = 70
    for i in SERVERS.size():
        var sv: Dictionary = SERVERS[i]
        var card := VBoxContainer.new()
        card.add_theme_constant_override("separation", 12)
        row.add_child(card)
        var b := Button.new()
        b.text = String(sv["name"])
        b.custom_minimum_size = Vector2(520, 110)
        b.focus_mode = Control.FOCUS_NONE
        if _font:
            b.add_theme_font_override("font", _font)
        b.add_theme_font_size_override("font_size", 44)
        b.add_theme_color_override("font_color", Color.WHITE)
        b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7))
        b.add_theme_color_override("font_pressed_color", GOLD)
        b.add_theme_stylebox_override("normal", _pill(Color(0.04, 0.05, 0.08, 0.88), GOLD * Color(1, 1, 1, 0.55), 55))
        b.add_theme_stylebox_override("hover", _pill(Color(0.08, 0.08, 0.10, 0.92), GOLD, 55))
        b.add_theme_stylebox_override("pressed", _pill(Color(0.14, 0.11, 0.06, 0.95), GOLD, 55))
        b.pressed.connect(_on_server.bind(i))
        card.add_child(b)
        var info := _text(null, String(sv["info"]), 24, Color(1, 1, 1, 0.65))
        info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        card.add_child(info)

    # свой сервер: адрес (например, от playit.gg) и кнопка «Подключиться»
    var own := HBoxContainer.new()
    own.alignment = BoxContainer.ALIGNMENT_CENTER
    own.add_theme_constant_override("separation", 16)
    _page_servers.add_child(own)
    own.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    own.offset_left = -560
    own.offset_right = 560
    own.offset_top = -190
    own.offset_bottom = -110
    _addr = LineEdit.new()
    _addr.placeholder_text = "Свой сервер: адрес:порт"
    _addr.custom_minimum_size = Vector2(620, 70)
    _addr.add_theme_font_size_override("font_size", 28)
    _addr.text = _saved_host()
    own.add_child(_addr)
    var go := Button.new()
    go.text = "ПОДКЛЮЧИТЬСЯ"
    go.custom_minimum_size = Vector2(320, 70)
    go.focus_mode = Control.FOCUS_NONE
    if _font:
        go.add_theme_font_override("font", _font)
    go.add_theme_font_size_override("font_size", 28)
    go.add_theme_stylebox_override("normal", _pill(Color(0.04, 0.05, 0.08, 0.88), GOLD * Color(1, 1, 1, 0.55), 35))
    go.add_theme_stylebox_override("hover", _pill(Color(0.08, 0.08, 0.10, 0.92), GOLD, 35))
    go.add_theme_stylebox_override("pressed", _pill(Color(0.14, 0.11, 0.06, 0.95), GOLD, 35))
    go.pressed.connect(_on_own_server)
    own.add_child(go)

    _build_back()


func _saved_host() -> String:
    var cfg := ConfigFile.new()
    if cfg.load("user://settings.cfg") == OK:
        return String(cfg.get_value("net", "host", ""))
    return ""


func _on_own_server() -> void:
    var h := _addr.text.strip_edges()
    if h == "":
        Sfx.play("error")
        _addr.placeholder_text = "Впиши адрес сервера, например abc.playit.gg:12345"
        return
    var cfg := ConfigFile.new()
    cfg.load("user://settings.cfg")
    cfg.set_value("net", "host", h)
    cfg.save("user://settings.cfg")
    Sfx.play("click")
    chosen_host = h
    _show("loading")
    server_chosen.emit(-1)


## Назад — круглая кнопка слева внизу
func _build_back() -> void:
    var back := Button.new()
    back.text = "‹"
    back.focus_mode = Control.FOCUS_NONE
    if _font:
        back.add_theme_font_override("font", _font)
    back.add_theme_font_size_override("font_size", 64)
    back.add_theme_stylebox_override("normal", _pill(Color(0.04, 0.05, 0.08, 0.88), Color(1, 1, 1, 0.25), 55))
    back.add_theme_stylebox_override("hover", _pill(Color(0.08, 0.08, 0.1, 0.9), GOLD, 55))
    back.add_theme_stylebox_override("pressed", _pill(Color(0.14, 0.11, 0.06, 0.95), GOLD, 55))
    _page_servers.add_child(back)
    back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    back.offset_left = 50
    back.offset_right = 160
    back.offset_top = -150
    back.offset_bottom = -40
    back.pressed.connect(_on_back)


func _on_back() -> void:
    Sfx.play("click")
    _show("main")


func _on_server(i: int) -> void:
    Sfx.play("click")
    chosen_host = String(SERVERS[i].get("host", "")) if i >= 0 and i < SERVERS.size() else ""
    _show("loading")
    server_chosen.emit(i)


func _build_loading() -> void:
    _page_loading = Control.new()
    add_child(_page_loading)
    _page_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.02, 0.03)
    _page_loading.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var pic := TextureRect.new()
    var path := "res://textures/loading.jpg" if ResourceLoader.exists("res://textures/loading.jpg") else MAIN_BG
    if ResourceLoader.exists(path):
        pic.texture = load(path)
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _page_loading.add_child(pic)
    pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.35)
    _page_loading.add_child(shade)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _load_text = _text(_page_loading, "Подключение к серверу...", 34, Color.WHITE)
    _load_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _load_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _load_text.offset_left = -500
    _load_text.offset_right = 500
    _load_text.offset_top = -150
    _load_text.offset_bottom = -100

    _tip = _text(_page_loading, TIPS[0], 22, Ui.CREAM)
    _tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _tip.offset_left = -560
    _tip.offset_right = 560
    _tip.offset_top = -60
    _tip.offset_bottom = -26
    var logo := HBoxContainer.new()
    logo.add_theme_constant_override("separation", 12)
    _page_loading.add_child(logo)
    logo.position = Vector2(30, 24)
    logo.add_child(Ui.Emblem.new(30.0))
    _text(logo, "СССР РП", 46, Ui.GOLD)

    _load_bar = ProgressBar.new()
    _load_bar.show_percentage = false
    _load_bar.max_value = 100.0
    var under := StyleBoxFlat.new()
    under.bg_color = Color(0, 0, 0, 0.55)
    under.set_corner_radius_all(8)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Ui.RED_LIGHT
    fill.border_color = GOLD
    fill.set_border_width_all(2)
    fill.set_corner_radius_all(8)
    _load_bar.add_theme_stylebox_override("background", under)
    _load_bar.add_theme_stylebox_override("fill", fill)
    _page_loading.add_child(_load_bar)
    _load_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _load_bar.offset_left = -420
    _load_bar.offset_right = 420
    _load_bar.offset_top = -86
    _load_bar.offset_bottom = -70


## Кнопка «Играть офлайн» на время подключения к серверу.
var _offline_btn: Button


func show_offline_button(on: bool) -> void:
    if on and _offline_btn == null:
        _offline_btn = Button.new()
        _offline_btn.text = "Играть офлайн"
        _offline_btn.focus_mode = Control.FOCUS_NONE
        _offline_btn.add_theme_font_size_override("font_size", 26)
        for st: String in ["normal", "hover", "pressed"]:
            _offline_btn.add_theme_stylebox_override(st, _pill(Color(0.04, 0.05, 0.08, 0.85), Color(1, 1, 1, 0.3), 30))
        _page_loading.add_child(_offline_btn)
        _offline_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
        _offline_btn.offset_left = -170
        _offline_btn.offset_right = 170
        _offline_btn.offset_top = -240
        _offline_btn.offset_bottom = -180
        _offline_btn.pressed.connect(func() -> void:
            Sfx.play("click")
            Net.cancel_join = true)
    if _offline_btn:
        _offline_btn.visible = on


## Вход в аккаунт онлайн-сервера (поверх экрана загрузки).
## Возвращает [true, ник, сохранение] — вошёл; [false, "", ""] — выбрал офлайн.
signal _login_done(res: Array)
var _login_panel: PanelContainer


func ask_login() -> Array:
    var cfg := ConfigFile.new()
    cfg.load("user://settings.cfg")
    _login_panel = PanelContainer.new()
    var sb := _pill(Color(0.04, 0.05, 0.08, 0.94), GOLD * Color(1, 1, 1, 0.6), 30)
    sb.content_margin_left = 40
    sb.content_margin_right = 40
    sb.content_margin_top = 30
    sb.content_margin_bottom = 30
    _login_panel.add_theme_stylebox_override("panel", sb)
    _page_loading.add_child(_login_panel)
    _login_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _login_panel.offset_left = -380
    _login_panel.offset_right = 380
    _login_panel.offset_top = -310
    _login_panel.offset_bottom = 270
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    _login_panel.add_child(box)
    var title := _text(box, "ВХОД В АККАУНТ", 40, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var nick := LineEdit.new()
    nick.placeholder_text = "RP-ник: Имя_Фамилия (Иван_Петров)"
    nick.max_length = 20
    nick.custom_minimum_size = Vector2(0, 64)
    nick.add_theme_font_size_override("font_size", 28)
    nick.text = String(cfg.get_value("net", "nick", ""))
    box.add_child(nick)
    var pw := LineEdit.new()
    pw.placeholder_text = "Пароль"
    pw.secret = true
    pw.max_length = 64
    pw.custom_minimum_size = Vector2(0, 64)
    pw.add_theme_font_size_override("font_size", 28)
    pw.text = String(cfg.get_value("net", "pass", ""))
    box.add_child(pw)
    # пол персонажа — выбирается при регистрации (для входа в старый аккаунт не нужен)
    var sex := ["m"]
    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 12)
    srow.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(srow)
    _text(srow, "Персонаж:", 24, Color(1, 1, 1, 0.75))
    var b_m := _sex_button(srow, "МУЖЧИНА")
    var b_f := _sex_button(srow, "ЖЕНЩИНА")
    var pick_sex := func(v: String) -> void:
        sex[0] = v
        _sex_style(b_m, v == "m")
        _sex_style(b_f, v == "f")
    b_m.pressed.connect(func() -> void:
        Sfx.play("click")
        pick_sex.call("m"))
    b_f.pressed.connect(func() -> void:
        Sfx.play("click")
        pick_sex.call("f"))
    pick_sex.call("m")
    var err := _text(box, "Новый игрок — придумай ник и пароль, выбери персонажа и нажми «Регистрация»", 22, Color(1, 1, 1, 0.7))
    err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_child(row)
    var b_in := _login_button(row, "ВОЙТИ", true)
    var b_reg := _login_button(row, "РЕГИСТРАЦИЯ", false)
    var b_off := Button.new()
    b_off.flat = true
    b_off.text = "Играть офлайн"
    b_off.focus_mode = Control.FOCUS_NONE
    b_off.add_theme_font_size_override("font_size", 22)
    b_off.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
    box.add_child(b_off)
    var busy := [false]
    var try_auth := func(mode: String) -> void:
        if busy[0]:
            return
        busy[0] = true
        err.label_settings.font_color = Color(1, 1, 1, 0.7)
        Sfx.play("click")
        # связь могла оборваться, пока игрок вводил ник (сервер перезапускался, сеть) — подключаемся заново
        if not Net.is_open():
            err.text = "Подключаюсь к серверу..."
            if not await Net.join(Net.host_text):
                busy[0] = false
                Sfx.play("error")
                err.text = "Сервер не отвечает. Проверь интернет и нажми ещё раз (или «Играть офлайн»)."
                err.label_settings.font_color = Color(1.0, 0.45, 0.35)
                return
        err.text = "Подождите..."
        var got := [null]
        var on_res := func(ok: bool, msg: String, nk: String, save: String) -> void:
            got[0] = [ok, msg, nk, save]
        Net.auth_result.connect(on_res)
        Net.auth(mode, nick.text.strip_edges(), pw.text, sex[0])
        var waited := 0.0
        while got[0] == null and waited < 20.0 and Net.is_open():   # ответ, обрыв связи или 20 с тишины
            await get_tree().create_timer(0.25).timeout
            waited += 0.25
        if Net.auth_result.is_connected(on_res):
            Net.auth_result.disconnect(on_res)
        busy[0] = false
        if got[0] == null:
            Sfx.play("error")
            err.text = ("Связь с сервером прервалась — нажми ещё раз" if not Net.is_open()
                    else "Сервер не ответил — нажми ещё раз через несколько секунд")
            err.label_settings.font_color = Color(1.0, 0.45, 0.35)
            return
        var r: Array = got[0]
        if bool(r[0]):
            var c2 := ConfigFile.new()
            c2.load("user://settings.cfg")
            c2.set_value("net", "nick", String(r[2]))
            c2.set_value("net", "pass", pw.text)
            c2.save("user://settings.cfg")
            _login_panel.queue_free()
            _login_done.emit([true, String(r[2]), String(r[3])])
        else:
            Sfx.play("error")
            err.text = String(r[1])
            err.label_settings.font_color = Color(1.0, 0.45, 0.35)
    b_in.pressed.connect(func() -> void: try_auth.call("login"))
    b_reg.pressed.connect(func() -> void: try_auth.call("register"))
    b_off.pressed.connect(func() -> void:
        Sfx.play("click")
        _login_panel.queue_free()
        _login_done.emit([false, "", ""]))
    var res: Array = await _login_done
    return res


func _sex_button(parent: Control, text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(200, 56)
    b.focus_mode = Control.FOCUS_NONE
    if _font:
        b.add_theme_font_override("font", _font)
    b.add_theme_font_size_override("font_size", 24)
    parent.add_child(b)
    return b


func _sex_style(b: Button, on: bool) -> void:
    var bg := Color(0.95, 0.74, 0.33) if on else Color(0.10, 0.11, 0.14)
    var fg := Color(0.08, 0.08, 0.08) if on else Color(1, 1, 1, 0.8)
    for st: String in ["normal", "hover", "pressed"]:
        b.add_theme_stylebox_override(st, _pill(bg, GOLD, 26))
    for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
        b.add_theme_color_override(k, fg)


func _login_button(parent: Control, text: String, main: bool) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(300, 72)
    b.focus_mode = Control.FOCUS_NONE
    if _font:
        b.add_theme_font_override("font", _font)
    b.add_theme_font_size_override("font_size", 28)
    var bg := Color(0.95, 0.74, 0.33) if main else Color(0.10, 0.11, 0.14)
    var fg := Color(0.08, 0.08, 0.08) if main else Color.WHITE
    for st: String in ["normal", "hover", "pressed"]:
        b.add_theme_stylebox_override(st, _pill(bg.lightened(0.1 if st == "pressed" else 0.0), GOLD, 30))
    for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
        b.add_theme_color_override(k, fg)
    parent.add_child(b)
    return b


## Плавно довести полосу загрузки до value (с надписью).
func progress(value: float, text: String, seconds := 0.4) -> void:
    _load_text.text = text
    var tw := create_tween()
    tw.tween_property(_load_bar, "value", value, seconds)
    await tw.finished


# ---------------------------------------------------------------- помощники

func _flat_button(parent: Control) -> Button:
    var b := Button.new()
    b.flat = true
    b.focus_mode = Control.FOCUS_NONE
    var empty := StyleBoxEmpty.new()
    for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
        b.add_theme_stylebox_override(st, empty)
    parent.add_child(b)
    return b


func _pill(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(3)
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(border.r, border.g, border.b, 0.25)
    s.shadow_size = 10
    return s


func _line() -> ColorRect:
    var l := ColorRect.new()
    l.color = Color(1, 1, 1, 0.6)
    l.custom_minimum_size = Vector2(260, 3)
    l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    return l


func _text(parent: Control, text: String, font_size: int, col: Color) -> Label:
    var l := Label.new()
    l.text = text
    var ls := LabelSettings.new()
    if _font:
        ls.font = _font
    ls.font_size = font_size
    ls.font_color = col
    ls.outline_size = 6
    ls.outline_color = Color(0, 0, 0, 0.5)
    l.label_settings = ls
    if parent:
        parent.add_child(l)
    return l
