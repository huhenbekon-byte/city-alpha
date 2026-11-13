extends Control
## Окно «Добро пожаловать» при первом появлении на вокзале (по концепту игрока):
## тёмная карточка, жёлтый заголовок, текст про квестовую линию, пионер справа,
## кнопки «Начать квест» (жёлтая) и «Пропустить квест» (тёмная).

signal start_pressed
signal skip_pressed

const FONT_PATH := "res://fonts/menu_bold.ttf"
const PORTRAIT := "res://textures/hud/pioneer.png"
const YELLOW := Color(0.98, 0.74, 0.11)
const TITLE := "ДОБРО ПОЖАЛОВАТЬ\nНА USSR RP!"
const BODY := "Пройди квестовую линию и получи награды для более быстрого продвижения на сервере. При помощи квестов ты освоишь основные механики нашего сервера, поймёшь, где заработать свои первые деньги, и научишься отыгрывать свою роль.\n\nЕсли откажешься от квестовой линии, то награды не получишь, но ты в любой момент можешь начать данную линию квестов у Петера на вокзале!"

var _card: Panel
var _font: Font


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)

    _card = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.13, 0.135, 0.15)
    sb.set_corner_radius_all(22)
    sb.shadow_color = Color(0, 0, 0, 0.5)
    sb.shadow_size = 18
    _card.add_theme_stylebox_override("panel", sb)
    _card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
    add_child(_card)

    # мягкий свет в верхнем левом углу, как на концепте
    var glow := TextureRect.new()
    var g := GradientTexture2D.new()
    var gr := Gradient.new()
    gr.set_color(0, Color(1, 1, 1, 0.09))
    gr.set_color(1, Color(1, 1, 1, 0.0))
    g.gradient = gr
    g.fill = GradientTexture2D.FILL_RADIAL
    g.fill_from = Vector2(0.15, 0.1)
    g.fill_to = Vector2(0.9, 0.9)
    glow.texture = g
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _card.add_child(glow)

    if ResourceLoader.exists(PORTRAIT):
        var p := TextureRect.new()
        p.name = "Portrait"
        p.texture = load(PORTRAIT)
        p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _card.add_child(p)

    var title := Label.new()
    title.name = "Title"
    title.text = TITLE
    var ts := LabelSettings.new()
    ts.font = _font
    ts.font_size = 50
    ts.font_color = YELLOW
    ts.line_spacing = -6
    title.label_settings = ts
    _card.add_child(title)

    var body := Label.new()
    body.name = "Body"
    body.text = BODY
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var bs := LabelSettings.new()
    bs.font_size = 20
    bs.font_color = Color(0.95, 0.95, 0.95)
    bs.line_spacing = 2
    body.label_settings = bs
    _card.add_child(body)

    _card.add_child(_button("Start", "Начать квест", YELLOW, Color(0.08, 0.08, 0.08), func() -> void: start_pressed.emit()))
    _card.add_child(_button("Skip", "Пропустить квест", Color(0.15, 0.17, 0.21), Color.WHITE, func() -> void: skip_pressed.emit()))
    resized.connect(_layout)
    _layout.call_deferred()


func _button(node_name: String, text: String, bg: Color, fg: Color, cb: Callable) -> Button:
    var b := Button.new()
    b.name = node_name
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    for st: String in ["normal", "hover", "pressed"]:
        var s := StyleBoxFlat.new()
        s.bg_color = bg if st == "normal" else (bg.lightened(0.08) if st == "hover" else bg.darkened(0.12))
        s.set_corner_radius_all(14)
        if bg.v < 0.3:
            s.border_color = Color(1, 1, 1, 0.08)
            s.set_border_width_all(2)
        b.add_theme_stylebox_override(st, s)
    b.add_theme_font_override("font", _font)
    b.add_theme_font_size_override("font_size", 30)
    for c: String in ["font_color", "font_hover_color", "font_pressed_color"]:
        b.add_theme_color_override(c, fg)
    b.pressed.connect(func() -> void:
        Sfx.play("click")
        cb.call())
    return b


## Карточка 980×620, на маленьком экране ужимается.
func _layout() -> void:
    var vp := size
    var k := minf(1.0, minf((vp.x - 40.0) / 980.0, (vp.y - 30.0) / 620.0))
    var cs := Vector2(980, 620)
    _card.size = cs
    _card.scale = Vector2(k, k)
    _card.position = (vp - cs * k) * 0.5
    var p := _card.get_node_or_null("Portrait") as TextureRect
    if p:
        p.position = Vector2(cs.x - 380, 20)
        p.size = Vector2(380, cs.y - 20)
    var t := _card.get_node("Title") as Label
    t.position = Vector2(44, 40)
    t.size = Vector2(580, 130)
    var b := _card.get_node("Body") as Label
    b.position = Vector2(44, 160)
    b.size = Vector2(530, 300)
    var st := _card.get_node("Start") as Button
    st.position = Vector2(44, cs.y - 130)
    st.size = Vector2(270, 92)
    var sk := _card.get_node("Skip") as Button
    sk.position = Vector2(334, cs.y - 130)
    sk.size = Vector2(300, 92)
