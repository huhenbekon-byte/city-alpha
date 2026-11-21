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
    mat.set_shader_parameter("shape_on", 1.0 if nw else 0.0)


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
    mat.set_shader_parameter("shape_on", 1.0 if human() else 0.0)
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

## Покрой по образу или ткани куртки: [толщина куртки, толщина брюк (м), низ куртки (доля роста, 0 — по поясу),
## насколько сгладить ягодицы]. Китель и пиджак закрывают ягодицы, халат — до колен, боёвка пожарного толстая.
const FIT := {
    "militia": [0.006, 0.0075, 0.465, 0.9], "kgb": [0.006, 0.0075, 0.465, 0.9], "doctor": [0.0065, 0.006, 0.3, 0.85],
    "fire": [0.013, 0.014, 0.45, 0.95], "leader": [0.007, 0.007, 0.49, 0.85], "bomber": [0.008, 0.007, 0.5, 0.8],
    "tracksuit": [0.006, 0.008, 0.0, 0.85], "passerby": [0.005, 0.006, 0.0, 0.75],
    "ambulance": [0.007, 0.007, 0.49, 0.85], "opg": [0.006, 0.008, 0.0, 0.85], "avtoritet": [0.007, 0.007, 0.47, 0.85],
    "uni_mayor": [0.006, 0.0075, 0.465, 0.9], "uni_kitel": [0.006, 0.0075, 0.465, 0.9], "cloth_suit_gray": [0.0055, 0.007, 0.47, 0.85],
    "cloth_suit_navy": [0.0055, 0.007, 0.47, 0.85], "cloth_coat_dark": [0.008, 0.0065, 0.3, 0.85],
    "cloth_gabardine": [0.007, 0.0065, 0.3, 0.85], "cloth_dublenka": [0.011, 0.0065, 0.44, 0.8],
    "cloth_alyaska": [0.011, 0.0065, 0.47, 0.75], "cloth_quilted_navy": [0.009, 0.006, 0.48, 0.7],
    "cloth_leather_black": [0.0065, 0.0065, 0.49, 0.7], "cloth_leather_brown": [0.0065, 0.0065, 0.49, 0.7],
}
const FIT_DEFAULT := [0.004, 0.0055, 0.0, 0.75]


static func set_fit(mat: ShaderMaterial, key: String, jacket: String) -> void:
    var f: Array = FIT.get(key, FIT.get(jacket, FIT_DEFAULT))
    mat.set_shader_parameter("inflate_top", float(f[0]))
    mat.set_shader_parameter("inflate_bottom", float(f[1]))
    mat.set_shader_parameter("hem", float(f[2]))
    mat.set_shader_parameter("butt_flat", float(f[3]))


## Подгонка фигуры под форму организации: [грудь, живот, таз и ягодицы, ноги, руки] (толщина, 1 — как у модели).
## Базовая модель «качок», поэтому всем чуть стройнее; пожарным в боёвке — меньше всего.
const SLIM := {
    "militia": [0.95, 0.92, 0.86, 0.86, 0.84], "kgb": [0.95, 0.92, 0.86, 0.86, 0.84],
    "doctor": [0.93, 0.92, 0.88, 0.86, 0.84], "ambulance": [0.95, 0.93, 0.87, 0.86, 0.85],
    "fire": [1.0, 0.96, 0.9, 0.9, 0.9], "opg": [0.92, 0.9, 0.85, 0.84, 0.82], "tracksuit": [0.92, 0.9, 0.85, 0.84, 0.82],
    "avtoritet": [0.97, 0.98, 0.88, 0.87, 0.86], "leader": [0.97, 0.98, 0.88, 0.87, 0.86],
    "bomber": [0.97, 0.94, 0.87, 0.86, 0.86], "passerby": [0.93, 0.92, 0.87, 0.86, 0.84],
}
const SLIM_DEFAULT := [0.93, 0.92, 0.87, 0.86, 0.84]
const SLIM_F_DEFAULT := [0.96, 0.94, 0.93, 0.9, 0.86]


static func slim_for(jacket: String, pants: String, female := false) -> Array:
    var k := String((TOP_F if female else TOP).get(jacket, ""))
    if jacket.begins_with("uni_opg"):
        k = "opg"
    if k == "":
        k = String((BOTTOM_F if female else BOTTOM).get(pants, ""))
    var sl: Array = SLIM.get(k, SLIM_F_DEFAULT if female else SLIM_DEFAULT)
    if female:   # у женщин таз и бёдра не сужаем так сильно
        sl = [sl[0], sl[1], lerpf(float(sl[2]), 1.0, 0.5), lerpf(float(sl[3]), 1.0, 0.3), sl[4]]
    return sl


## Телосложение на скелете: b = [рост, плечи, живот, бёдра] (магазин), slim — подгонка под форму (slim_for).
## Масштаб кости переходит на дочерние, поэтому задаём «итоговую» толщину каждой кости и делим на родителя.
static func apply_build(model: Node3D, b: Array, base_scale: float, jacket := "", pants := "", female := false) -> void:
    if model == null or b.size() < 4:
        return
    var sl := slim_for(jacket, pants, female)
    model.scale = Vector3.ONE * base_scale * float(b[0])
    var chest := float(b[1]) * float(sl[0])
    var belly := float(b[2]) * float(sl[1])
    var hips := float(sl[2]) * lerpf(1.0, float(b[3]), 0.5)
    var legs := float(b[3]) * float(sl[3])
    var arms := float(sl[4]) * (float(b[1]) if float(b[1]) > 1.0 else 1.0)
    var calf := lerpf(1.0, legs, 0.6)
    var fore := lerpf(1.0, arms, 0.7)
    var want := {
        "pelvis": Vector3(hips, 1.0, hips), "spine_01": Vector3(lerpf(hips, belly, 0.5), 1.0, lerpf(hips, belly, 0.5)),
        "spine_02": Vector3(belly, 1.0, belly), "spine_03": Vector3(chest, 1.0, chest * 0.6 + 0.4),
        "neck_01": Vector3.ONE, "clavicle_l": Vector3.ONE, "clavicle_r": Vector3.ONE,
    }
    for side: String in ["l", "r"]:
        want["upperarm_" + side] = Vector3(arms, 1.0, arms)
        want["lowerarm_" + side] = Vector3(fore, 1.0, fore)
        want["hand_" + side] = Vector3.ONE
        want["thigh_" + side] = Vector3(legs, 1.0, legs)
        want["calf_" + side] = Vector3(calf, 1.0, calf)
        want["foot_" + side] = Vector3.ONE
    for sk: Node in model.find_children("*", "Skeleton3D", true, false):
        var s := sk as Skeleton3D
        var acc := {}   # итоговая толщина кости
        for i in s.get_bone_count():   # кости идут от корня к детям
            var n := s.get_bone_name(i)
            var p := s.get_bone_parent(i)
            var parent_c: Vector3 = acc.get(p, Vector3.ONE) if p >= 0 else Vector3.ONE
            var c: Vector3 = want.get(n, parent_c)
            acc[i] = c
            if want.has(n) or not parent_c.is_equal_approx(Vector3.ONE):
                s.set_bone_pose_scale(i, c / parent_c)


static func _bscale(s: Skeleton3D, bone: String, sc: Vector3) -> void:
    var i := s.find_bone(bone)
    if i >= 0:
        s.set_bone_pose_scale(i, sc)


## ткань куртки → форма (верх: куртка и рукава)
const TOP := {
    "uni_militia": "militia", "uni_kgb": "kgb", "uni_doctor": "doctor", "uni_canvas": "fire",
    "uni_scrubs": "ambulance", "uni_avtoritet": "avtoritet", "uni_kitel": "militia", "uni_shirt": "militia",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_bolonya_green": "bomber", "cloth_leather_black": "leader", "cloth_corduroy": "passerby",
}
## ткань штанов → форма (низ: штаны)
const BOTTOM := {
    "uni_navy": "militia", "uni_kgb": "kgb", "uni_canvas": "fire", "uni_scrubs": "ambulance", "uni_avtoritet": "avtoritet",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_jersey_gray": "bomber", "cloth_wool_black": "leader", "cloth_trousers_brown": "passerby",
}
## женские образы (лист автора: форма, костюмы и лица — outfit_f_<образ>.png)
const TOP_F := {
    "uni_militia": "militia", "uni_kitel": "militia", "uni_shirt": "militia",
    "uni_kgb": "kgb", "uni_mayor": "kgb", "cloth_suit_gray": "kgb", "cloth_suit_navy": "kgb", "cloth_gabardine": "kgb",
    "cloth_coat_dark": "kgb",
    "uni_doctor": "doctor", "uni_scrubs": "ambulance", "cloth_cotton_white": "doctor", "uni_canvas": "fire",
    "uni_avtoritet": "avtoritet",
    "cloth_tracksuit": "tracksuit", "ts_black": "tracksuit", "ts_red": "tracksuit", "ts_green": "tracksuit",
    "ts_blue": "tracksuit", "ts_yellow": "tracksuit",
    "cloth_leather_black": "leader", "velour": "leader", "cloth_bolonya_green": "leader", "cloth_dublenka": "leader",
    "cloth_cardigan": "passerby", "cloth_sweater": "passerby", "cloth_corduroy": "passerby", "cloth_chintz": "passerby",
}
const BOTTOM_F := {
    "uni_navy": "militia", "uni_kgb": "kgb", "cloth_suit_gray": "kgb", "cloth_suit_navy": "kgb",
    "uni_scrubs": "ambulance", "uni_canvas": "fire", "uni_avtoritet": "avtoritet",
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

## чёрный костюм «ОПГ» (uni_opg_<цвет>): полосы и надписи — цветом банды
const OPG_STRIPES := {"red": Color(0.85, 0.12, 0.1), "blue": Color(0.2, 0.4, 0.95), "yellow": Color(1.0, 0.78, 0.12),
    "green": Color(0.2, 0.7, 0.3)}

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
    if jacket.begins_with("uni_opg"):
        top_n = "opg"
    if pants.begins_with("uni_opg"):
        bot_n = "opg"
    if not (human_f() if female else human()):
        top_n = ""; bot_n = ""          # образы запечены под новую модель
    var pre := "outfit_f_" if female else "outfit_"
    var top_t := _tex(DIR + pre + "%s.png" % top_n) if top_n != "" else null
    var bot_t := _tex(DIR + pre + "%s.png" % bot_n) if bot_n != "" else null
    set_fit(mat, top_n if top_t else "", jacket)
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
    var mode := 0.0
    if top_n == "opg" or bot_n == "opg":
        var gc := (jacket if top_n == "opg" else pants).trim_prefix("uni_opg_")
        tint = Color(1, 1, 1, 0)
        if OPG_STRIPES.has(gc):
            var c2: Color = OPG_STRIPES[gc]
            tint = Color(c2.r, c2.g, c2.b, 1.0)
        mode = 1.0
    mat.set_shader_parameter("outfit_tint", tint)
    mat.set_shader_parameter("outfit_tint_mode", mode)
    if top_t:
        mat.set_shader_parameter("hair_on", 0.0)     # лицо и волосы — из образа
