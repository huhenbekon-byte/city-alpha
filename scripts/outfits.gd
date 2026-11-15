extends RefCounted
## Готовая форма персонажей: рисунок одежды, запечённый в развёртку тела (tools/outfits/bake_outfits.py)
## из раскладок «вид спереди/сзади». Включается по названию ткани куртки/штанов, которое уже выбрано
## в игре (форма фракции, магазин одежды, прохожие) — игровые данные не меняются.
## Только для мужской модели (у женской своя развёртка).

const DIR := "res://models/character/"
## реалистичная мужская модель (tools/models/human_build.py); нет файла — старая модель Quaternius
const HUMAN := "res://models/character/human.gltf"
const OLD_MALE := "res://models/character/character.gltf"
## реалистичная женская модель (та же основа, human_build.py female); нет файла — старая female.gltf
const HUMAN_F := "res://models/character/human_f.gltf"
const OLD_FEMALE := "res://models/character/female.gltf"
## текстуры тела: старая модель → новая
const HUMAN_TEX := {"body_light.png": "human_skin.png", "body_mask.png": "human_mask.png",
    "sleeve_mask.png": "human_sleeve.png", "print_ussr.png": "human_print_ussr.png",
    "body_lampas.png": "human_lampas.png", "body_tape.png": "human_tape.png", "body_vest.png": "human_vest.png"}


static func human() -> bool:
    return ResourceLoader.exists(HUMAN)


static func male_model() -> String:
    return HUMAN if human() else OLD_MALE


static func human_f() -> bool:
    return ResourceLoader.exists(HUMAN_F)


static func female_model() -> String:
    return HUMAN_F if human_f() else OLD_FEMALE


## Женщина: кожа/лицо, маска одежды и рукавов новой модели (или старые текстуры, если её нет).
static func setup_female(mat: ShaderMaterial, hair := Color(0.3, 0.18, 0.1)) -> void:
    var nw := human_f()
    mat.set_shader_parameter("body_tex", _tex(DIR + ("human_f_skin.png" if nw else "female_light.png")))
    mat.set_shader_parameter("mask_tex", _tex(DIR + ("human_f_mask.png" if nw else "female_mask.png")))
    mat.set_shader_parameter("sleeve_tex", _tex(DIR + ("human_f_sleeve.png" if nw else "female_sleeve.png")))
    mat.set_shader_parameter("cloth_aspect", Vector2(2.0, 1.0) if nw else Vector2.ONE)
    mat.set_shader_parameter("hair_col", Vector3(hair.r, hair.g, hair.b))
    mat.set_shader_parameter("hair_on", 1.0 if nw else 0.0)


## Путь текстуры тела мужской модели (имя файла старой модели → файл текущей модели).
static func body_path(file: String) -> String:
    if human():
        if HUMAN_TEX.has(file):
            return DIR + String(HUMAN_TEX[file])
        if file.begins_with("body_badge_"):
            return DIR + file.replace("body_", "human_")
    return DIR + file


## Базовая настройка шейдера тела мужчины (кожа, маска одежды, рукава, пропорции развёртки).
static func setup_male(mat: ShaderMaterial, hair := Color(0.18, 0.13, 0.09), use_hair := true) -> void:
    mat.set_shader_parameter("body_tex", _tex(body_path("body_light.png")))
    mat.set_shader_parameter("mask_tex", _tex(body_path("body_mask.png")))
    mat.set_shader_parameter("sleeve_tex", _tex(body_path("sleeve_mask.png")))
    mat.set_shader_parameter("cloth_aspect", Vector2(2.0, 1.0) if human() else Vector2.ONE)
    set_hair(mat, hair, use_hair)


## Посадка головного убора на кость Head (у реалистичной головы она ниже макушки и голова уже).
static func place_hat(h: Node3D, female := false) -> void:
    if female and human_f():
        h.position = Vector3(0, 0.128, 0.015)
        h.scale = Vector3(0.75, 0.77, 0.8)
    elif female:
        h.position = Vector3(0, 0.16, 0.008)
    elif human():
        h.position = Vector3(0, 0.15, 0.012)
        h.scale = Vector3(0.8, 0.82, 0.84)
    else:
        h.position = Vector3(0, 0.16, 0.008)
    if h.has_meta("snug") and (human_f() if female else human()):
        # вязаная шапка облегает голову: уже и ниже, отворот на лбу
        h.position.y -= 0.03
        h.position.z += 0.004
        h.scale *= Vector3(0.72, 0.8, 0.74)


static func set_hair(mat: ShaderMaterial, hair: Color, on := true) -> void:
    mat.set_shader_parameter("hair_col", Vector3(hair.r, hair.g, hair.b))
    mat.set_shader_parameter("hair_on", 1.0 if on and human() else 0.0)

## ткань куртки → форма (верх: куртка и рукава)
const TOP := {
    "uni_militia": "militia", "uni_kgb": "kgb", "uni_doctor": "doctor", "uni_canvas": "fire",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_bolonya_green": "bomber", "cloth_leather_black": "leader", "cloth_corduroy": "passerby",
}
## ткань штанов → форма (низ: штаны)
const BOTTOM := {
    "uni_navy": "militia", "uni_kgb": "kgb", "uni_canvas": "fire",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_jersey_gray": "bomber", "cloth_wool_black": "leader", "cloth_trousers_brown": "passerby",
}
## женские образы (лист автора: форма, костюмы и лица — outfit_f_<образ>.png)
const TOP_F := {
    "uni_militia": "militia", "uni_kitel": "militia", "uni_shirt": "militia",
    "uni_kgb": "kgb", "uni_mayor": "kgb", "cloth_suit_gray": "kgb", "cloth_suit_navy": "kgb", "cloth_gabardine": "kgb",
    "cloth_coat_dark": "kgb",
    "uni_doctor": "doctor", "uni_scrubs": "doctor", "cloth_cotton_white": "doctor", "uni_canvas": "fire",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_leather_black": "leader", "velour": "leader", "cloth_bolonya_green": "leader", "cloth_dublenka": "leader",
    "cloth_cardigan": "passerby", "cloth_sweater": "passerby", "cloth_corduroy": "passerby", "cloth_chintz": "passerby",
}
const BOTTOM_F := {
    "uni_navy": "militia", "uni_kgb": "kgb", "cloth_suit_gray": "kgb", "cloth_suit_navy": "kgb",
    "uni_scrubs": "doctor", "uni_canvas": "fire",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_wool_black": "leader", "cloth_acidwash": "passerby", "cloth_denim_blue": "passerby", "cloth_denim": "passerby",
    "cloth_trousers_brown": "passerby", "cloth_wool_gray": "passerby",
}
## обувь из раскладки — только вместо тёмной обуви
const DARK_SHOES := ["cloth_leather_black", "cloth_rubber_black"]
## спортивные костюмы других цветов: перекраска бордового костюма (средний цвет ткани)
const TINT := {
    "ts_black": Color(0.16, 0.16, 0.18), "ts_blue": Color(0.05, 0.16, 0.50), "ts_green": Color(0.08, 0.30, 0.18),
    "ts_yellow": Color(0.88, 0.62, 0.05),
}

static var _cache := {}


static func _tex(path: String) -> Texture2D:
    if not _cache.has(path):
        _cache[path] = load(path) if ResourceLoader.exists(path) else null
    return _cache[path]


## Включить/выключить форму на материале персонажа (шейдер character.gdshader).
## jacket_col — цвет из магазина (для «спортивной» белой ткани cloth_tracksuit).
static func apply(mat: ShaderMaterial, jacket: String, pants: String, shoes: String,
        jacket_col := Color.WHITE, female := false) -> void:
    if mat == null:
        return
    var top_n := String((TOP_F if female else TOP).get(jacket, ""))
    var bot_n := String((BOTTOM_F if female else BOTTOM).get(pants, ""))
    if not (human_f() if female else human()):
        top_n = ""; bot_n = ""          # образы запечены под новую модель
    var pre := "outfit_f_" if female else "outfit_"
    var top_t := _tex(DIR + pre + "%s.png" % top_n) if top_n != "" else null
    var bot_t := _tex(DIR + pre + "%s.png" % bot_n) if bot_n != "" else null
    mat.set_shader_parameter("outfit_top_on", 1.0 if top_t else 0.0)
    mat.set_shader_parameter("outfit_bottom_on", 1.0 if bot_t else 0.0)
    mat.set_shader_parameter("outfit_shoes_on", 1.0 if bot_t and (female or shoes in DARK_SHOES) else 0.0)
    if top_t:
        mat.set_shader_parameter("outfit_top", top_t)
    if bot_t:
        mat.set_shader_parameter("outfit_bottom", bot_t)
    var tint := Color(1, 1, 1, 0)
    var key := jacket if top_n == "tracksuit" else pants
    if TINT.has(key):
        var c: Color = TINT[key]
        tint = Color(c.r, c.g, c.b, 1.0)
    elif key == "cloth_tracksuit" and not jacket_col.is_equal_approx(Color.WHITE):
        tint = Color(jacket_col.r, jacket_col.g, jacket_col.b, 1.0)
    mat.set_shader_parameter("outfit_tint", tint)
    if top_t:
        mat.set_shader_parameter("hair_on", 0.0)     # лицо и волосы — из образа
