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
    lib.add_animation("Anim_Drink", make(sk, prefix, [[0.0, ARMS_DOWN], [0.4, HAND_MOUTH], [0.7, HAND_DRINK], [1.5, HAND_DRINK],
            [1.8, HAND_MOUTH], [2.1, ARMS_DOWN]], 2.1, false))


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
