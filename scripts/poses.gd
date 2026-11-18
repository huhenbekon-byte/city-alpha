extends RefCounted
## Анимации из кода (у модели мало своих): позы и короткие движения.
## Поза задаётся направлениями костей в мире (персонаж смотрит в +Z, +X — его левая сторона,
## исходная поза — T-поза). Из направлений считаются повороты костей, из поз — ключи анимации.
##   Pose_Squat  — на корточках, как пацаны у подъезда       Pose_Salute — отдать честь
##   Pose_Rest   — руки за спину (постовой)                    Pose_Guard  — боевая стойка, кулаки у лица
##   Anim_Land   — приземление после прыжка (присел и встал)   Anim_Kick   — удар ногой
##   Anim_Eat    — откусить два раза (рука ко рту)             Anim_Drink  — выпить, запрокинув голову
## Ещё: fix_lean() выпрямляет спину в ходьбе и беге (в исходных анимациях сильный наклон вперёд).

const ARMS_DOWN := {
    "upperarm_l": Vector3(0.12, -1, 0.02), "lowerarm_l": Vector3(0.06, -1, 0.12), "hand_l": Vector3(0.0, -1, 0.15),
    "upperarm_r": Vector3(-0.12, -1, 0.02), "lowerarm_r": Vector3(-0.06, -1, 0.12), "hand_r": Vector3(0.0, -1, 0.15),
}
const SQUAT := {
    "pelvis_pos": Vector3(0, 0.47, -0.16),
    "spine_01": Vector3(0, 0.85, 0.5), "spine_02": Vector3(0, 0.9, 0.42), "spine_03": Vector3(0, 0.95, 0.3),
    "neck_01": Vector3(0, 1, 0.05),
    "thigh_l": Vector3(0.28, 0.05, 0.96), "calf_l": Vector3(0.05, -0.92, -0.4), "foot_l": Vector3(0.0, -0.45, 0.9),
    "thigh_r": Vector3(-0.28, 0.05, 0.96), "calf_r": Vector3(-0.05, -0.92, -0.4), "foot_r": Vector3(0.0, -0.45, 0.9),
    "upperarm_l": Vector3(0.3, -0.8, 0.5), "lowerarm_l": Vector3(0.0, -0.45, 0.9), "hand_l": Vector3(0.0, -0.7, 0.7),
    "upperarm_r": Vector3(-0.3, -0.8, 0.5), "lowerarm_r": Vector3(0.0, -0.45, 0.9), "hand_r": Vector3(0.0, -0.7, 0.7),
}
const SALUTE := {
    "upperarm_r": Vector3(-0.84, 0.24, 0.48), "lowerarm_r": Vector3(0.94, 0.31, 0.09), "hand_r": Vector3(0.7, 0.2, 0.7),
    "upperarm_l": Vector3(0.12, -1, 0.0), "lowerarm_l": Vector3(0.05, -1, 0.05), "hand_l": Vector3(0.0, -1, 0.1),
}
const REST := {
    "upperarm_l": Vector3(0.2, -0.9, -0.35), "lowerarm_l": Vector3(-0.55, -0.35, -0.75), "hand_l": Vector3(-0.9, 0.0, -0.3),
    "upperarm_r": Vector3(-0.2, -0.9, -0.35), "lowerarm_r": Vector3(0.55, -0.35, -0.75), "hand_r": Vector3(0.9, 0.0, -0.3),
}
## боевая стойка: колени чуть согнуты, кулаки у подбородка, левый — впереди
const GUARD := {
    "pelvis_pos": Vector3(0, 0.9, -0.05),
    "spine_03": Vector3(0, 0.97, 0.15), "neck_01": Vector3(0, 1, 0.08),
    "thigh_l": Vector3(0.12, -0.96, 0.2), "calf_l": Vector3(0.02, -0.97, -0.15), "foot_l": Vector3(0.0, -0.5, 0.86),
    "thigh_r": Vector3(-0.14, -0.96, -0.12), "calf_r": Vector3(-0.02, -0.96, -0.2), "foot_r": Vector3(0.0, -0.5, 0.86),
    "upperarm_l": Vector3(0.3, -0.55, 0.78), "lowerarm_l": Vector3(-0.35, 0.72, 0.6), "hand_l": Vector3(-0.2, 0.6, 0.75),
    "upperarm_r": Vector3(-0.42, -0.72, 0.4), "lowerarm_r": Vector3(0.4, 0.82, 0.4), "hand_r": Vector3(0.25, 0.7, 0.65),
}
const LAND := {
    "pelvis_pos": Vector3(0, 0.74, -0.08),
    "spine_01": Vector3(0, 0.94, 0.3), "spine_03": Vector3(0, 0.97, 0.22),
    "thigh_l": Vector3(0.14, -0.72, 0.68), "calf_l": Vector3(0.02, -0.9, -0.45), "foot_l": Vector3(0.0, -0.45, 0.9),
    "thigh_r": Vector3(-0.14, -0.72, 0.68), "calf_r": Vector3(-0.02, -0.9, -0.45), "foot_r": Vector3(0.0, -0.45, 0.9),
    "upperarm_l": Vector3(0.75, -0.6, 0.25), "lowerarm_l": Vector3(0.55, -0.6, 0.55),
    "upperarm_r": Vector3(-0.75, -0.6, 0.25), "lowerarm_r": Vector3(-0.55, -0.6, 0.55),
}
## удар правой ногой: стойка → «замах» коленом → нога выпрямлена вперёд → обратно
const KICK_CHAMBER := {
    "pelvis_pos": Vector3(0, 0.93, -0.08),
    "spine_02": Vector3(0, 0.98, -0.12), "spine_03": Vector3(0, 0.97, -0.2),
    "thigh_l": Vector3(0.12, -0.98, 0.05), "calf_l": Vector3(0.02, -0.97, -0.12),
    "thigh_r": Vector3(-0.08, 0.15, 0.98), "calf_r": Vector3(0.0, -0.9, 0.35), "foot_r": Vector3(0.0, -0.3, 0.95),
    "upperarm_l": Vector3(0.45, -0.5, 0.7), "lowerarm_l": Vector3(-0.3, 0.75, 0.55),
    "upperarm_r": Vector3(-0.7, -0.6, -0.3), "lowerarm_r": Vector3(-0.4, -0.8, 0.4),
}
const KICK_OUT := {
    "pelvis_pos": Vector3(0, 0.92, -0.12),
    "spine_02": Vector3(0, 0.95, -0.28), "spine_03": Vector3(0, 0.93, -0.35),
    "thigh_l": Vector3(0.12, -0.98, 0.05), "calf_l": Vector3(0.02, -0.97, -0.12),
    "thigh_r": Vector3(-0.05, 0.4, 0.92), "calf_r": Vector3(0.0, 0.35, 0.94), "foot_r": Vector3(0.0, 0.5, 0.86),
    "upperarm_l": Vector3(0.45, -0.5, 0.7), "lowerarm_l": Vector3(-0.3, 0.75, 0.55),
    "upperarm_r": Vector3(-0.8, -0.55, -0.2), "lowerarm_r": Vector3(-0.5, -0.8, 0.3),
}
## еда и питьё: правая рука ко рту (рука — от плеча (-0.21, 1.46) к губам (0, 1.58, 0.1))
const HAND_MOUTH := {
    "upperarm_l": Vector3(0.12, -1, 0.02), "lowerarm_l": Vector3(0.06, -1, 0.12), "hand_l": Vector3(0.0, -1, 0.15),
    "upperarm_r": Vector3(-0.12, -0.62, 0.78), "lowerarm_r": Vector3(0.6, 0.76, -0.24), "hand_r": Vector3(0.45, 0.55, 0.7),
    "neck_01": Vector3(0, 1, 0.12),
}
const HAND_CHEW := {
    "upperarm_l": Vector3(0.12, -1, 0.02), "lowerarm_l": Vector3(0.06, -1, 0.12), "hand_l": Vector3(0.0, -1, 0.15),
    "upperarm_r": Vector3(-0.2, -0.85, 0.48), "lowerarm_r": Vector3(0.3, 0.25, 0.92), "hand_r": Vector3(0.2, 0.2, 0.95),
    "neck_01": Vector3(0, 1, 0.0),
}
const HAND_DRINK := {
    "upperarm_l": Vector3(0.12, -1, 0.02), "lowerarm_l": Vector3(0.06, -1, 0.12), "hand_l": Vector3(0.0, -1, 0.15),
    "upperarm_r": Vector3(-0.15, -0.45, 0.88), "lowerarm_r": Vector3(0.55, 0.83, -0.1), "hand_r": Vector3(0.4, 0.9, -0.2),
    "neck_01": Vector3(0, 0.94, -0.33), "spine_03": Vector3(0, 0.98, -0.18),
}

## танец на дискотеке: покачивание, руки вверх-вниз попеременно
const DANCE_A := {
    "pelvis_pos": Vector3(0.03, 0.9, 0.0),
    "spine_03": Vector3(-0.12, 0.99, 0.05), "neck_01": Vector3(0.1, 1, 0.05),
    "thigh_l": Vector3(0.14, -0.97, 0.18), "calf_l": Vector3(0.03, -0.97, -0.12),
    "thigh_r": Vector3(-0.12, -0.99, 0.0), "calf_r": Vector3(-0.02, -1, 0.0),
    "upperarm_l": Vector3(0.55, 0.75, 0.3), "lowerarm_l": Vector3(0.1, 0.95, 0.25), "hand_l": Vector3(0.0, 1, 0.1),
    "upperarm_r": Vector3(-0.5, -0.6, 0.6), "lowerarm_r": Vector3(0.3, 0.4, 0.85), "hand_r": Vector3(0.2, 0.3, 0.9),
}
const DANCE_B := {
    "pelvis_pos": Vector3(-0.03, 0.9, 0.0),
    "spine_03": Vector3(0.12, 0.99, 0.05), "neck_01": Vector3(-0.1, 1, 0.05),
    "thigh_l": Vector3(0.12, -0.99, 0.0), "calf_l": Vector3(0.02, -1, 0.0),
    "thigh_r": Vector3(-0.14, -0.97, 0.18), "calf_r": Vector3(-0.03, -0.97, -0.12),
    "upperarm_l": Vector3(0.5, -0.6, 0.6), "lowerarm_l": Vector3(-0.3, 0.4, 0.85), "hand_l": Vector3(-0.2, 0.3, 0.9),
    "upperarm_r": Vector3(-0.55, 0.75, 0.3), "lowerarm_r": Vector3(-0.1, 0.95, 0.25), "hand_r": Vector3(0.0, 1, 0.1),
}
const DANCE_LOW := {
    "pelvis_pos": Vector3(0, 0.84, -0.03),
    "spine_03": Vector3(0, 0.98, 0.15),
    "thigh_l": Vector3(0.16, -0.9, 0.38), "calf_l": Vector3(0.03, -0.95, -0.3),
    "thigh_r": Vector3(-0.16, -0.9, 0.38), "calf_r": Vector3(-0.03, -0.95, -0.3),
    "upperarm_l": Vector3(0.7, -0.5, 0.5), "lowerarm_l": Vector3(-0.2, 0.6, 0.8),
    "upperarm_r": Vector3(-0.7, -0.5, 0.5), "lowerarm_r": Vector3(0.2, 0.6, 0.8),
}


# ---------------------------------------------------------------- жесты, позы и действия (новые)
const LEFT_DOWN := {"upperarm_l": Vector3(0.12, -1, 0.02), "lowerarm_l": Vector3(0.06, -1, 0.12), "hand_l": Vector3(0.0, -1, 0.15)}
const RIGHT_DOWN := {"upperarm_r": Vector3(-0.12, -1, 0.02), "lowerarm_r": Vector3(-0.06, -1, 0.12), "hand_r": Vector3(0.0, -1, 0.15)}
## помахать рукой
const WAVE_A := {"upperarm_r": Vector3(-0.72, 0.62, 0.3), "lowerarm_r": Vector3(-0.4, 0.9, 0.15), "hand_r": Vector3(-0.35, 0.93, 0.1)}
const WAVE_B := {"upperarm_r": Vector3(-0.72, 0.62, 0.3), "lowerarm_r": Vector3(0.25, 0.95, 0.15), "hand_r": Vector3(0.3, 0.94, 0.1)}
## руки вверх (сдаюсь)
const HANDS_UP := {
    "upperarm_l": Vector3(0.62, 0.78, 0.05), "lowerarm_l": Vector3(0.12, 1, 0.0), "hand_l": Vector3(0.05, 1, 0.0),
    "upperarm_r": Vector3(-0.62, 0.78, 0.05), "lowerarm_r": Vector3(-0.12, 1, 0.0), "hand_r": Vector3(-0.05, 1, 0.0),
    "neck_01": Vector3(0, 1, -0.05),
}
## говорит по телефону (трубка у правого уха)
const PHONE := {
    "upperarm_r": Vector3(-0.32, -0.7, 0.62), "lowerarm_r": Vector3(0.38, 0.88, -0.28), "hand_r": Vector3(0.25, 0.95, -0.2),
    "neck_01": Vector3(-0.14, 1, 0.04),
}
## руки скрещены на груди
const ARMS_CROSSED := {
    "upperarm_l": Vector3(0.25, -0.82, 0.5), "lowerarm_l": Vector3(-0.95, 0.12, 0.3), "hand_l": Vector3(-0.9, 0.25, 0.1),
    "upperarm_r": Vector3(-0.25, -0.82, 0.5), "lowerarm_r": Vector3(0.95, 0.18, 0.24), "hand_r": Vector3(0.9, 0.3, 0.05),
}
## задумался: рука у подбородка, другая под локтем
const THINK := {
    "upperarm_l": Vector3(0.25, -0.82, 0.5), "lowerarm_l": Vector3(-0.95, 0.12, 0.3), "hand_l": Vector3(-0.9, 0.25, 0.1),
    "upperarm_r": Vector3(-0.15, -0.65, 0.75), "lowerarm_r": Vector3(0.5, 0.82, -0.1), "hand_r": Vector3(0.4, 0.6, 0.7),
    "neck_01": Vector3(0.05, 1, 0.12),
}
## рука-лицо
const FACEPALM := {
    "upperarm_r": Vector3(-0.1, -0.5, 0.86), "lowerarm_r": Vector3(0.5, 0.82, -0.25), "hand_r": Vector3(0.3, 0.55, -0.75),
    "neck_01": Vector3(0, 0.9, 0.42), "spine_03": Vector3(0, 0.98, 0.15),
}
## показать рукой вперёд
const POINT := {"upperarm_r": Vector3(-0.2, 0.18, 0.96), "lowerarm_r": Vector3(-0.12, 0.16, 0.98), "hand_r": Vector3(-0.1, 0.12, 1.0)}
## хлопать в ладоши
const CLAP_A := {
    "upperarm_l": Vector3(0.35, -0.6, 0.72), "lowerarm_l": Vector3(-0.55, 0.32, 0.78), "hand_l": Vector3(-0.6, 0.3, 0.75),
    "upperarm_r": Vector3(-0.35, -0.6, 0.72), "lowerarm_r": Vector3(0.55, 0.32, 0.78), "hand_r": Vector3(0.6, 0.3, 0.75),
}
const CLAP_B := {
    "upperarm_l": Vector3(0.4, -0.6, 0.7), "lowerarm_l": Vector3(-0.1, 0.32, 0.95), "hand_l": Vector3(-0.1, 0.3, 0.95),
    "upperarm_r": Vector3(-0.4, -0.6, 0.7), "lowerarm_r": Vector3(0.1, 0.32, 0.95), "hand_r": Vector3(0.1, 0.3, 0.95),
}
## пожать плечами
const SHRUG := {
    "upperarm_l": Vector3(0.38, -0.9, 0.12), "lowerarm_l": Vector3(0.85, 0.15, 0.5), "hand_l": Vector3(0.8, 0.3, 0.5),
    "upperarm_r": Vector3(-0.38, -0.9, 0.12), "lowerarm_r": Vector3(-0.85, 0.15, 0.5), "hand_r": Vector3(-0.8, 0.3, 0.5),
    "neck_01": Vector3(0.12, 1, 0.05),
}
## посмотреть на часы (левая рука)
const WATCH := {
    "upperarm_l": Vector3(0.3, -0.55, 0.78), "lowerarm_l": Vector3(-0.82, 0.42, 0.38), "hand_l": Vector3(-0.85, 0.35, 0.4),
    "neck_01": Vector3(0.12, 0.9, 0.4),
}
## на стуле: бёдра вперёд, голени вниз, руки на коленях (таз на высоте 0.52 — обычный стул)
static func seated(h: float, arms: Dictionary) -> Dictionary:
    var p := {
        "pelvis_pos": Vector3(0, h, 0.0),
        "spine_01": Vector3(0, 1, 0.03), "spine_02": Vector3(0, 1, 0.03), "spine_03": Vector3(0, 1, 0.05),
        "thigh_l": Vector3(0.12, -0.06, 1), "calf_l": Vector3(0.04, -1, 0.06), "foot_l": Vector3(0.0, -0.35, 0.94),
        "thigh_r": Vector3(-0.12, -0.06, 1), "calf_r": Vector3(-0.04, -1, 0.06), "foot_r": Vector3(0.0, -0.35, 0.94),
        "upperarm_l": Vector3(0.14, -0.85, 0.5), "lowerarm_l": Vector3(-0.08, -0.3, 0.95), "hand_l": Vector3(0.0, -0.4, 0.9),
        "upperarm_r": Vector3(-0.14, -0.85, 0.5), "lowerarm_r": Vector3(0.08, -0.3, 0.95), "hand_r": Vector3(0.0, -0.4, 0.9),
    }
    p.merge(arms, true)
    return p
const CARDS_ARMS := {
    "upperarm_l": Vector3(0.22, -0.78, 0.58), "lowerarm_l": Vector3(-0.38, 0.3, 0.87), "hand_l": Vector3(-0.3, 0.4, 0.86),
    "upperarm_r": Vector3(-0.22, -0.78, 0.58), "lowerarm_r": Vector3(0.38, 0.3, 0.87), "hand_r": Vector3(0.3, 0.4, 0.86),
    "neck_01": Vector3(0, 0.95, 0.3),
}
const CARDS_THROW := {
    "upperarm_r": Vector3(-0.25, -0.5, 0.83), "lowerarm_r": Vector3(0.1, -0.05, 1), "hand_r": Vector3(0.0, -0.2, 0.98),
}
const TYPE_A := {
    "upperarm_l": Vector3(0.16, -0.8, 0.58), "lowerarm_l": Vector3(-0.12, -0.08, 1), "hand_l": Vector3(0.0, -0.35, 0.94),
    "upperarm_r": Vector3(-0.16, -0.8, 0.58), "lowerarm_r": Vector3(0.12, -0.02, 1), "hand_r": Vector3(0.0, -0.15, 0.99),
    "neck_01": Vector3(0, 0.98, 0.18),
}
const TYPE_B := {
    "upperarm_l": Vector3(0.16, -0.8, 0.58), "lowerarm_l": Vector3(-0.12, -0.02, 1), "hand_l": Vector3(0.0, -0.15, 0.99),
    "upperarm_r": Vector3(-0.16, -0.8, 0.58), "lowerarm_r": Vector3(0.12, -0.08, 1), "hand_r": Vector3(0.0, -0.35, 0.94),
    "neck_01": Vector3(0, 0.98, 0.18),
}
## лёжа на спине (голова к -Z); h — высота таза (0.12 — на полу, 0.75 — на койке)
static func lying(h: float) -> Dictionary:
    return {
        "pelvis_pos": Vector3(0, h, 0.0),
        "pelvis": Vector3(0, 0.02, -1),
        "spine_01": Vector3(0, 0.02, -1), "spine_02": Vector3(0, 0.0, -1), "spine_03": Vector3(0, 0.0, -1),
        "neck_01": Vector3(0, 0.15, -1),
        "thigh_l": Vector3(0.1, 0.0, 1), "calf_l": Vector3(0.03, 0.0, 1), "foot_l": Vector3(0.05, 1, 0.2),
        "thigh_r": Vector3(-0.1, 0.0, 1), "calf_r": Vector3(-0.03, 0.0, 1), "foot_r": Vector3(-0.05, 1, 0.2),
        "upperarm_l": Vector3(0.3, 0.0, 0.95), "lowerarm_l": Vector3(0.12, 0.0, 1), "hand_l": Vector3(0.05, -0.1, 1),
        "upperarm_r": Vector3(-0.3, 0.0, 0.95), "lowerarm_r": Vector3(-0.12, 0.0, 1), "hand_r": Vector3(-0.05, -0.1, 1),
    }
## жим лёжа на скамье (штанга над грудью)
static func bench(up: bool) -> Dictionary:
    var p := lying(0.55)
    p["thigh_l"] = Vector3(0.3, -0.45, 0.85)
    p["calf_l"] = Vector3(0.05, -1, 0.05)
    p["foot_l"] = Vector3(0.0, -0.3, 0.95)
    p["thigh_r"] = Vector3(-0.3, -0.45, 0.85)
    p["calf_r"] = Vector3(-0.05, -1, 0.05)
    p["foot_r"] = Vector3(0.0, -0.3, 0.95)
    if up:
        p.merge({"upperarm_l": Vector3(0.3, 0.95, -0.05), "lowerarm_l": Vector3(0.05, 1, 0.0), "hand_l": Vector3(0.0, 1, 0.0),
                "upperarm_r": Vector3(-0.3, 0.95, -0.05), "lowerarm_r": Vector3(-0.05, 1, 0.0), "hand_r": Vector3(0.0, 1, 0.0)}, true)
    else:
        p.merge({"upperarm_l": Vector3(0.95, 0.1, 0.0), "lowerarm_l": Vector3(0.0, 1, 0.0), "hand_l": Vector3(0.0, 1, 0.0),
                "upperarm_r": Vector3(-0.95, 0.1, 0.0), "lowerarm_r": Vector3(0.0, 1, 0.0), "hand_r": Vector3(0.0, 1, 0.0)}, true)
    return p
## отжимания: тело планкой, голова вперёд (+Z)
static func pushup(up: bool) -> Dictionary:
    var h := 0.4 if up else 0.24
    var p := {
        "pelvis_pos": Vector3(0, h, -0.1),
        "pelvis": Vector3(0, 0.2 if up else 0.08, 1),
        "spine_01": Vector3(0, 0.22 if up else 0.08, 1), "spine_02": Vector3(0, 0.22 if up else 0.08, 1), "spine_03": Vector3(0, 0.22 if up else 0.08, 1),
        "neck_01": Vector3(0, 0.35, 1),
        "thigh_l": Vector3(0.08, -0.22 if up else -0.1, -1), "calf_l": Vector3(0.04, -0.22 if up else -0.1, -1), "foot_l": Vector3(0.0, -1, -0.25),
        "thigh_r": Vector3(-0.08, -0.22 if up else -0.1, -1), "calf_r": Vector3(-0.04, -0.22 if up else -0.1, -1), "foot_r": Vector3(0.0, -1, -0.25),
    }
    if up:
        p.merge({"upperarm_l": Vector3(0.2, -1, 0.0), "lowerarm_l": Vector3(0.05, -1, 0.0), "hand_l": Vector3(0.0, -0.1, 1),
                "upperarm_r": Vector3(-0.2, -1, 0.0), "lowerarm_r": Vector3(-0.05, -1, 0.0), "hand_r": Vector3(0.0, -0.1, 1)}, true)
    else:
        p.merge({"upperarm_l": Vector3(0.7, -0.35, -0.6), "lowerarm_l": Vector3(0.0, -1, 0.1), "hand_l": Vector3(0.0, -0.1, 1),
                "upperarm_r": Vector3(-0.7, -0.35, -0.6), "lowerarm_r": Vector3(0.0, -1, 0.1), "hand_r": Vector3(0.0, -0.1, 1)}, true)
    return p
## сидит на полу, колени вверх, руки на коленях
const SIT_FLOOR := {
    "pelvis_pos": Vector3(0, 0.13, -0.15),
    "spine_01": Vector3(0, 1, -0.12), "spine_02": Vector3(0, 1, -0.05), "spine_03": Vector3(0, 1, 0.05),
    "thigh_l": Vector3(0.25, 0.55, 0.8), "calf_l": Vector3(0.05, -0.85, 0.5), "foot_l": Vector3(0.0, -0.3, 0.95),
    "thigh_r": Vector3(-0.25, 0.55, 0.8), "calf_r": Vector3(-0.05, -0.85, 0.5), "foot_r": Vector3(0.0, -0.3, 0.95),
    "upperarm_l": Vector3(0.18, -0.55, 0.82), "lowerarm_l": Vector3(-0.1, 0.25, 0.96), "hand_l": Vector3(0.0, -0.2, 0.98),
    "upperarm_r": Vector3(-0.18, -0.55, 0.82), "lowerarm_r": Vector3(0.1, 0.25, 0.96), "hand_r": Vector3(0.0, -0.2, 0.98),
}
## работа за верстаком: левая держит, правая стучит молотком
const WORK_A := {
    "spine_03": Vector3(0, 0.95, 0.3), "neck_01": Vector3(0, 0.85, 0.5),
    "upperarm_l": Vector3(0.22, -0.7, 0.68), "lowerarm_l": Vector3(-0.25, -0.3, 0.92), "hand_l": Vector3(-0.1, -0.4, 0.9),
    "upperarm_r": Vector3(-0.25, -0.45, 0.86), "lowerarm_r": Vector3(0.1, 0.65, 0.75), "hand_r": Vector3(0.0, 0.7, 0.7),
}
const WORK_B := {
    "spine_03": Vector3(0, 0.95, 0.3), "neck_01": Vector3(0, 0.85, 0.5),
    "upperarm_l": Vector3(0.22, -0.7, 0.68), "lowerarm_l": Vector3(-0.25, -0.3, 0.92), "hand_l": Vector3(-0.1, -0.4, 0.9),
    "upperarm_r": Vector3(-0.22, -0.6, 0.77), "lowerarm_r": Vector3(0.1, -0.55, 0.83), "hand_r": Vector3(0.0, -0.6, 0.8),
}
## удары по груше: из стойки — правой, левой
const JAB_R := {
    "pelvis_pos": Vector3(0, 0.9, -0.05), "spine_03": Vector3(0.08, 0.97, 0.2),
    "upperarm_l": Vector3(0.3, -0.55, 0.78), "lowerarm_l": Vector3(-0.35, 0.72, 0.6), "hand_l": Vector3(-0.2, 0.6, 0.75),
    "upperarm_r": Vector3(-0.12, 0.08, 1), "lowerarm_r": Vector3(-0.04, 0.06, 1), "hand_r": Vector3(0.0, 0.05, 1),
}
const JAB_L := {
    "pelvis_pos": Vector3(0, 0.9, -0.05), "spine_03": Vector3(-0.08, 0.97, 0.2),
    "upperarm_l": Vector3(0.12, 0.08, 1), "lowerarm_l": Vector3(0.04, 0.06, 1), "hand_l": Vector3(0.0, 0.05, 1),
    "upperarm_r": Vector3(-0.42, -0.72, 0.4), "lowerarm_r": Vector3(0.4, 0.82, 0.4), "hand_r": Vector3(0.25, 0.7, 0.65),
}
## «присядка»: руки на поясе, ноги по очереди вперёд
const SQUAT_DANCE_A := {
    "pelvis_pos": Vector3(0, 0.62, -0.1), "spine_03": Vector3(0, 1, 0.05),
    "thigh_l": Vector3(0.2, -0.45, 0.87), "calf_l": Vector3(0.05, -0.95, -0.3), "foot_l": Vector3(0.0, -0.4, 0.9),
    "thigh_r": Vector3(-0.15, -0.55, 0.8), "calf_r": Vector3(0.0, 0.1, 1), "foot_r": Vector3(0.0, 0.6, 0.8),
    "upperarm_l": Vector3(0.6, -0.75, -0.25), "lowerarm_l": Vector3(-0.6, 0.15, 0.78), "hand_l": Vector3(-0.5, -0.2, 0.8),
    "upperarm_r": Vector3(-0.6, -0.75, -0.25), "lowerarm_r": Vector3(0.6, 0.15, 0.78), "hand_r": Vector3(0.5, -0.2, 0.8),
}
const SQUAT_DANCE_B := {
    "pelvis_pos": Vector3(0, 0.62, -0.1), "spine_03": Vector3(0, 1, 0.05),
    "thigh_l": Vector3(0.15, -0.55, 0.8), "calf_l": Vector3(0.0, 0.1, 1), "foot_l": Vector3(0.0, 0.6, 0.8),
    "thigh_r": Vector3(-0.2, -0.45, 0.87), "calf_r": Vector3(-0.05, -0.95, -0.3), "foot_r": Vector3(0.0, -0.4, 0.9),
    "upperarm_l": Vector3(0.6, -0.75, -0.25), "lowerarm_l": Vector3(-0.6, 0.15, 0.78), "hand_l": Vector3(-0.5, -0.2, 0.8),
    "upperarm_r": Vector3(-0.6, -0.75, -0.25), "lowerarm_r": Vector3(0.6, 0.15, 0.78), "hand_r": Vector3(0.5, -0.2, 0.8),
}
const SQUAT_DANCE_UP := {
    "pelvis_pos": Vector3(0, 0.82, -0.05),
    "thigh_l": Vector3(0.15, -0.9, 0.4), "calf_l": Vector3(0.03, -0.95, -0.3),
    "thigh_r": Vector3(-0.15, -0.9, 0.4), "calf_r": Vector3(-0.03, -0.95, -0.3),
    "upperarm_l": Vector3(0.6, -0.75, -0.25), "lowerarm_l": Vector3(-0.6, 0.15, 0.78), "hand_l": Vector3(-0.5, -0.2, 0.8),
    "upperarm_r": Vector3(-0.6, -0.75, -0.25), "lowerarm_r": Vector3(0.6, 0.15, 0.78), "hand_r": Vector3(0.5, -0.2, 0.8),
}
## осмотреться по сторонам (для бездействия)
const LOOK_L := {"neck_01": Vector3(0.45, 0.9, 0.1), "spine_03": Vector3(0.1, 1, 0.02)}
const LOOK_R := {"neck_01": Vector3(-0.45, 0.9, 0.1), "spine_03": Vector3(-0.1, 1, 0.02)}

# ---------------------------------------------------------------- бег как у человека
# Свой цикл бега вместо мультяшного (огромные прыжки, руки в стороны): умеренный шаг, лёгкий наклон
# корпуса вперёд, руки согнуты под прямым углом и ходят вперёд-назад вдоль тела, голова ровно.
# Ключи: правая нога впереди (касание) → полёт → левая впереди → полёт. Вторая половина — зеркало первой.

## Зеркало позы: левое ↔ правое.
static func mirror(p: Dictionary) -> Dictionary:
    var out := {}
    for k: String in p:
        var v: Vector3 = p[k]
        var nk := k
        if k.ends_with("_l"):
            nk = k.trim_suffix("_l") + "_r"
        elif k.ends_with("_r"):
            nk = k.trim_suffix("_r") + "_l"
        out[nk] = Vector3(-v.x, v.y, v.z)
    return out


## Касание: правая нога впереди, левая сзади отталкивается; руки наоборот. k — сила (бег 1.0, спринт 1.35).
static func run_contact(k: float) -> Dictionary:
    var lean := 0.17 * k
    return {
        "pelvis_pos": Vector3(0, 0.885, 0.0),
        "spine_01": Vector3(0, 1, lean), "spine_02": Vector3(0, 1, lean), "spine_03": Vector3(0, 1, lean * 0.8),
        "neck_01": Vector3(0, 1, -0.06),
        "thigh_r": Vector3(-0.07, -0.86, 0.46 * k), "calf_r": Vector3(-0.02, -0.98, 0.16), "foot_r": Vector3(0.0, -0.3, 0.95),
        "thigh_l": Vector3(0.07, -0.93, -0.36 * k), "calf_l": Vector3(0.02, -0.55, -0.83), "foot_l": Vector3(0.0, -0.92, -0.38),
        # левая рука впереди: плечо вперёд-вниз, предплечье вверх (локоть ~90°), кисть у груди
        "upperarm_l": Vector3(0.1, -0.9, 0.36 * k), "lowerarm_l": Vector3(-0.22, 0.74, 0.63), "hand_l": Vector3(-0.2, 0.7, 0.68),
        # правая рука сзади: локоть назад, кисть у бедра
        "upperarm_r": Vector3(-0.12, -0.82, -0.55 * k), "lowerarm_r": Vector3(-0.05, -0.3, 0.95), "hand_r": Vector3(0.0, -0.35, 0.94),
    }


## Полёт / проход: опорная (правая) под телом толкает назад, левая выносится вперёд с высоким коленом.
static func run_pass(k: float) -> Dictionary:
    var lean := 0.17 * k
    return {
        "pelvis_pos": Vector3(0, 0.93, 0.0),
        "spine_01": Vector3(0, 1, lean), "spine_02": Vector3(0, 1, lean), "spine_03": Vector3(0, 1, lean * 0.8),
        "neck_01": Vector3(0, 1, -0.06),
        "thigh_r": Vector3(-0.07, -0.96, -0.24 * k), "calf_r": Vector3(-0.02, -0.82, -0.57), "foot_r": Vector3(0.0, -0.85, -0.5),
        "thigh_l": Vector3(0.07, -0.62, 0.78 * k), "calf_l": Vector3(0.02, -0.9, -0.42), "foot_l": Vector3(0.0, -0.45, 0.89),
        "upperarm_l": Vector3(0.13, -0.98, 0.1), "lowerarm_l": Vector3(-0.15, 0.5, 0.85), "hand_l": Vector3(-0.12, 0.45, 0.88),
        "upperarm_r": Vector3(-0.13, -0.98, -0.06), "lowerarm_r": Vector3(0.12, 0.4, 0.9), "hand_r": Vector3(0.1, 0.35, 0.93),
    }


static func run_cycle(sk: Skeleton3D, prefix: String, k: float, length: float) -> Animation:
    var a := run_contact(k)
    var b := run_pass(k)
    return make(sk, prefix, [[0.0, a], [length * 0.25, b], [length * 0.5, mirror(a)], [length * 0.75, mirror(b)], [length, a]], length, true)


## Ключ жеста -> имя анимации (то, что ставится в player._anim_map и что видят другие игроки).
const EXTRA := {
    "wave": "Anim_Wave", "handsup": "Pose_HandsUp", "phone": "Pose_Phone", "arms": "Pose_Arms", "think": "Pose_Think",
    "facepalm": "Pose_Facepalm", "point": "Pose_Point", "clap": "Anim_Clap", "shrug": "Anim_Shrug", "watch": "Anim_Watch",
    "sitfloor": "Pose_SitFloor", "lie": "Pose_Lie", "lie_bed": "Pose_LieBed", "pushup": "Anim_Pushup", "bench": "Anim_Bench",
    "chair": "Pose_Chair", "cards": "Anim_Cards", "typing": "Anim_Typing", "work": "Anim_Work", "boxing": "Anim_Boxing",
    "prisyadka": "Anim_Prisyadka", "look": "Anim_Look",
}


## Добавить анимации в AnimationPlayer модели.
static func install(ap: AnimationPlayer, sk: Skeleton3D) -> void:
    var prefix := _skeleton_path(ap, sk)
    if prefix == "":
        return
    var lib: AnimationLibrary = ap.get_animation_library("")
    if lib == null or lib.has_animation("Pose_Squat"):
        return
    lib.add_animation("Pose_Squat", make(sk, prefix, [[0.0, SQUAT]], 1.0, true))
    lib.add_animation("Pose_Salute", make(sk, prefix, [[0.0, SALUTE]], 1.0, true))
    lib.add_animation("Pose_Rest", make(sk, prefix, [[0.0, REST]], 1.0, true))
    lib.add_animation("Pose_Guard", make(sk, prefix, [[0.0, GUARD], [0.6, _shift(GUARD, -0.015)], [1.2, GUARD]], 1.2, true))
    lib.add_animation("Anim_Land", make(sk, prefix, [[0.0, LAND], [0.32, {}]], 0.32, false))
    lib.add_animation("Anim_Kick", make(sk, prefix, [[0.0, GUARD], [0.12, KICK_CHAMBER], [0.22, KICK_OUT], [0.34, KICK_OUT],
            [0.46, KICK_CHAMBER], [0.6, GUARD]], 0.6, false))
    lib.add_animation("Anim_Eat", make(sk, prefix, [[0.0, ARMS_DOWN], [0.35, HAND_MOUTH], [0.6, HAND_CHEW], [0.85, HAND_CHEW],
            [1.1, HAND_MOUTH], [1.35, HAND_CHEW], [1.6, HAND_CHEW], [1.9, ARMS_DOWN]], 1.9, false))
    lib.add_animation("Anim_Dance", make(sk, prefix, [[0.0, DANCE_A], [0.25, DANCE_LOW], [0.5, DANCE_B], [0.75, DANCE_LOW],
            [1.0, DANCE_A]], 1.0, true))
    lib.add_animation("Anim_Drink", make(sk, prefix, [[0.0, ARMS_DOWN], [0.4, HAND_MOUTH], [0.7, HAND_DRINK], [1.5, HAND_DRINK],
            [1.8, HAND_MOUTH], [2.1, ARMS_DOWN]], 2.1, false))
    _install_extra(lib, sk, prefix)
    lib.add_animation("Anim_Jog", run_cycle(sk, prefix, 1.0, 0.68))
    lib.add_animation("Anim_Sprint", run_cycle(sk, prefix, 1.35, 0.58))


static func _install_extra(lib: AnimationLibrary, sk: Skeleton3D, prefix: String) -> void:
    var wave_a := LEFT_DOWN.merged(WAVE_A)
    var wave_b := LEFT_DOWN.merged(WAVE_B)
    lib.add_animation("Anim_Wave", make(sk, prefix, [[0.0, wave_a], [0.3, wave_b], [0.6, wave_a], [0.9, wave_b], [1.2, wave_a]], 1.2, true))
    lib.add_animation("Pose_HandsUp", make(sk, prefix, [[0.0, HANDS_UP], [0.8, _shift(HANDS_UP, 0.0)]], 0.8, true))
    lib.add_animation("Pose_Phone", make(sk, prefix, [[0.0, LEFT_DOWN.merged(PHONE)], [1.5, LEFT_DOWN.merged(PHONE).merged({"neck_01": Vector3(-0.2, 1, 0.12)}, true)],
            [3.0, LEFT_DOWN.merged(PHONE)]], 3.0, true))
    lib.add_animation("Pose_Arms", make(sk, prefix, [[0.0, ARMS_CROSSED]], 1.0, true))
    lib.add_animation("Pose_Think", make(sk, prefix, [[0.0, THINK], [2.0, THINK.merged({"neck_01": Vector3(-0.08, 1, 0.15)}, true)], [4.0, THINK]], 4.0, true))
    lib.add_animation("Pose_Facepalm", make(sk, prefix, [[0.0, LEFT_DOWN.merged(FACEPALM)]], 1.0, true))
    lib.add_animation("Pose_Point", make(sk, prefix, [[0.0, LEFT_DOWN.merged(POINT)]], 1.0, true))
    lib.add_animation("Anim_Clap", make(sk, prefix, [[0.0, CLAP_B], [0.16, CLAP_A], [0.32, CLAP_B]], 0.32, true))
    lib.add_animation("Anim_Shrug", make(sk, prefix, [[0.0, ARMS_DOWN], [0.35, SHRUG], [1.2, SHRUG], [1.6, ARMS_DOWN]], 1.6, false))
    lib.add_animation("Anim_Watch", make(sk, prefix, [[0.0, ARMS_DOWN], [0.4, RIGHT_DOWN.merged(WATCH)], [1.6, RIGHT_DOWN.merged(WATCH)], [2.0, ARMS_DOWN]], 2.0, false))
    lib.add_animation("Pose_SitFloor", make(sk, prefix, [[0.0, SIT_FLOOR]], 1.0, true))
    lib.add_animation("Pose_Lie", make(sk, prefix, [[0.0, lying(0.12)]], 1.0, true))
    lib.add_animation("Pose_LieBed", make(sk, prefix, [[0.0, lying(0.72)]], 1.0, true))
    lib.add_animation("Anim_Pushup", make(sk, prefix, [[0.0, pushup(true)], [0.6, pushup(false)], [1.2, pushup(true)]], 1.2, true))
    lib.add_animation("Anim_Bench", make(sk, prefix, [[0.0, bench(true)], [0.9, bench(false)], [1.8, bench(true)]], 1.8, true))
    lib.add_animation("Pose_Chair", make(sk, prefix, [[0.0, seated(0.52, {})], [2.5, seated(0.52, {"neck_01": Vector3(0.1, 1, 0.08)})],
            [5.0, seated(0.52, {})]], 5.0, true))
    lib.add_animation("Anim_Cards", make(sk, prefix, [[0.0, seated(0.52, CARDS_ARMS)], [1.6, seated(0.52, CARDS_ARMS)],
            [1.9, seated(0.52, CARDS_ARMS.merged(CARDS_THROW, true))], [2.3, seated(0.52, CARDS_ARMS)], [3.2, seated(0.52, CARDS_ARMS)]], 3.2, true))
    lib.add_animation("Anim_Typing", make(sk, prefix, [[0.0, seated(0.52, TYPE_A)], [0.18, seated(0.52, TYPE_B)], [0.36, seated(0.52, TYPE_A)]], 0.36, true))
    lib.add_animation("Anim_Work", make(sk, prefix, [[0.0, WORK_A], [0.25, WORK_B], [0.5, WORK_A]], 0.5, true))
    lib.add_animation("Anim_Boxing", make(sk, prefix, [[0.0, GUARD], [0.15, JAB_R], [0.35, GUARD], [0.55, JAB_L], [0.75, GUARD],
            [0.9, JAB_R], [1.05, GUARD], [1.5, GUARD]], 1.5, true))
    lib.add_animation("Anim_Prisyadka", make(sk, prefix, [[0.0, SQUAT_DANCE_A], [0.25, SQUAT_DANCE_UP], [0.5, SQUAT_DANCE_B], [0.75, SQUAT_DANCE_UP],
            [1.0, SQUAT_DANCE_A]], 1.0, true))
    lib.add_animation("Anim_Look", make(sk, prefix, [[0.0, ARMS_DOWN], [0.8, ARMS_DOWN.merged(LOOK_L)], [1.8, ARMS_DOWN.merged(LOOK_L)],
            [2.6, ARMS_DOWN.merged(LOOK_R)], [3.6, ARMS_DOWN.merged(LOOK_R)], [4.2, ARMS_DOWN]], 4.2, false))


## Выпрямить спину в ходьбе и беге: повороты таза и позвоночника наполовину — к позе покоя.
static func fix_lean(ap: AnimationPlayer, sk: Skeleton3D, anim_name: String, keep: float) -> void:
    if not ap.has_animation(anim_name):
        return
    var a := ap.get_animation(anim_name)
    if a.has_meta("lean_fixed"):
        return
    a.set_meta("lean_fixed", true)
    for t in a.get_track_count():
        if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
            continue
        var path := String(a.track_get_path(t))
        var bname := path.get_slice(":", 1)
        var k := 1.0
        match bname:
            "pelvis":
                k = minf(1.0, keep + 0.25)
            "spine_01", "spine_02", "spine_03":
                k = keep
            "neck_01":
                k = minf(1.0, keep + 0.2)
            _:
                continue
        var bi := sk.find_bone(bname)
        if bi < 0:
            continue
        var rest := sk.get_bone_rest(bi).basis.get_rotation_quaternion()
        # средний наклон за цикл — его и убираем; качание (отклонения от среднего) оставляем
        var n := a.track_get_key_count(t)
        if n == 0:
            continue
        var mean := Quaternion()
        var acc := Vector4.ZERO
        for i in n:
            var q: Quaternion = a.track_get_key_value(t, i)
            if Vector4(q.x, q.y, q.z, q.w).dot(Vector4(rest.x, rest.y, rest.z, rest.w)) < 0.0:
                q = -q
            acc += Vector4(q.x, q.y, q.z, q.w)
        acc = acc.normalized()
        mean = Quaternion(acc.x, acc.y, acc.z, acc.w)
        var target := rest.slerp(mean, k)          # сколько наклона оставить
        var corr := target * mean.inverse()
        for i in n:
            var q: Quaternion = a.track_get_key_value(t, i)
            a.track_set_key_value(t, i, (corr * q).normalized())


static func _shift(pose: Dictionary, dy: float) -> Dictionary:
    var out := pose.duplicate()
    if out.has("pelvis_pos"):
        out["pelvis_pos"] = (out["pelvis_pos"] as Vector3) + Vector3(0, dy, 0)
    return out


static func _skeleton_path(ap: AnimationPlayer, sk: Skeleton3D) -> String:
    var root := ap.get_node(ap.root_node)
    if root == null:
        return ""
    return String(root.get_path_to(sk))


## Анимация из ключей [[время, поза], ...]. Пустая поза {} — исходная стойка (руки как в idle — вниз).
static func make(sk: Skeleton3D, prefix: String, keys: Array, length: float, loop: bool) -> Animation:
    var anim := Animation.new()
    anim.length = length
    anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
    var bones := {}
    var with_pos := false
    for kp: Array in keys:
        var pose: Dictionary = kp[1] if not (kp[1] as Dictionary).is_empty() else ARMS_DOWN
        for b: String in pose:
            if b != "pelvis_pos":
                bones[b] = true
            else:
                with_pos = true
    var tracks := {}
    for bname: String in bones:
        if sk.find_bone(bname) < 0:
            continue
        var t := anim.add_track(Animation.TYPE_ROTATION_3D)
        anim.track_set_path(t, "%s:%s" % [prefix, bname])
        tracks[bname] = t
    var pelvis_t := -1
    var pi := sk.find_bone("pelvis")
    if with_pos and pi >= 0:
        pelvis_t = anim.add_track(Animation.TYPE_POSITION_3D)
        anim.track_set_path(pelvis_t, "%s:pelvis" % prefix)
    for kp: Array in keys:
        var time: float = kp[0]
        var pose: Dictionary = kp[1] if not (kp[1] as Dictionary).is_empty() else ARMS_DOWN
        var locals := _solve(sk, pose)
        for bname: String in tracks:
            var bi := sk.find_bone(bname)
            var q: Quaternion = locals.get(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion())
            anim.rotation_track_insert_key(tracks[bname], time, q)
        if pelvis_t >= 0:
            var parent_rest := sk.get_bone_global_rest(sk.get_bone_parent(pi))
            var pp: Vector3 = pose.get("pelvis_pos", sk.get_bone_global_rest(pi).origin)
            anim.position_track_insert_key(pelvis_t, time, parent_rest.affine_inverse() * pp)
    return anim


## Повороты костей (в системе родителя) для позы.
static func _solve(sk: Skeleton3D, pose: Dictionary) -> Dictionary:
    var glob := {}
    var out := {}
    for i in sk.get_bone_count():
        var bname := sk.get_bone_name(i)
        var parent := sk.get_bone_parent(i)
        var rest_g := sk.get_bone_global_rest(i)
        var parent_g := Basis()
        var parent_rest_g := Basis()
        if parent >= 0:
            parent_g = glob[parent] if glob.has(parent) else sk.get_bone_global_rest(parent).basis
            parent_rest_g = sk.get_bone_global_rest(parent).basis
        var g := parent_g * parent_rest_g.inverse() * rest_g.basis
        if pose.has(bname):
            var child := _first_child(sk, i)
            if child >= 0:
                var rest_dir := (sk.get_bone_global_rest(child).origin - rest_g.origin).normalized()
                var cur_dir := (parent_g * parent_rest_g.inverse() * rest_dir).normalized()
                var want: Vector3 = (pose[bname] as Vector3).normalized()
                g = _rot_between(cur_dir, want) * g
        g = g.orthonormalized()
        glob[i] = g
        var local: Basis = (parent_g.inverse() * g).orthonormalized() if parent >= 0 else g
        out[i] = local.get_rotation_quaternion()
    return out


static func _first_child(sk: Skeleton3D, i: int) -> int:
    var kids := sk.get_bone_children(i)
    if kids.is_empty():
        return -1
    # у кисти — средний палец, у таза — первый позвонок
    for k: int in kids:
        var n := sk.get_bone_name(k)
        for pre: String in ["middle_01", "spine", "calf", "lowerarm", "hand", "foot", "ball", "neck", "Head"]:
            if n.begins_with(pre):
                return k
    return kids[0]


static func _rot_between(a: Vector3, b: Vector3) -> Basis:
    var axis := a.cross(b)
    var s := axis.length()
    var c := a.dot(b)
    if s < 1e-5:
        return Basis() if c > 0.0 else Basis(Vector3.UP, PI)
    return Basis(axis / s, atan2(s, c))
