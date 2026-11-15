extends RefCounted
## Водитель для машин-ботов и машин других игроков: модель персонажа в позе «за рулём»,
## один раз «запечённая» в обычную сетку (без скелета и анимаций) — дёшево даже для слабых планшетов.
## Ноги ниже сиденья отрезаны (их не видно), сетка общая для всех машин.

const Outfits := preload("res://scripts/outfits.gd")
const OUTFITS := ["passerby", "leader", "bomber", "tracksuit", "kgb"]

static var _cache := {}      # образ -> [ArrayMesh, таз Vector3]


## [сетка, таз в координатах модели] для образа (outfit_<образ>.png); [] — модели нет.
static func get_mesh(host: Node, outfit: String) -> Array:
    if _cache.has(outfit):
        return _cache[outfit]
    var res := _bake(host, outfit)
    _cache[outfit] = res
    return res


## Посадить водителя в машину: seat — точка таза на сиденье (локально в машине), sc — масштаб.
## Машина смотрит вдоль +Z (как модели машин игры), водитель слева (+X).
static func seat_in(car: Node3D, seat: Vector3, sc: float, outfit: String, fade := 60.0) -> MeshInstance3D:
    var dm := get_mesh(car, outfit)
    if dm.is_empty():
        return null
    var mi := MeshInstance3D.new()
    mi.mesh = dm[0]
    var pelvis: Vector3 = dm[1]
    mi.transform = Transform3D(Basis().scaled(Vector3.ONE * sc), seat - pelvis * sc)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.visibility_range_end = fade          # издалека водителя за стеклом всё равно не видно
    car.add_child(mi)
    return mi


## Место водителя по габаритам модели машины (сетка с колёсами): таз и масштаб.
static func seat_for_mesh(mesh: Mesh, model_id := "") -> Array:
    var box := mesh.get_aabb()
    var floor_y := box.position.y + 0.32
    var roof := box.position.y + box.size.y
    var hip_z := box.position.z + box.size.z * 0.53
    if model_id.begins_with("uaz452"):   # «буханка»: кабина над передней осью
        floor_y = box.position.y + 0.62
        hip_z = box.position.z + box.size.z - 0.95
    var sc := clampf((roof - 0.14 - floor_y) / 1.42, 0.62, 1.0)
    var hip := Vector3(box.size.x * 0.21, floor_y + 0.47 * sc, hip_z)
    return [hip, sc]


static func _bake(host: Node, outfit: String) -> Array:
    if not Outfits.human():
        return []
    var ps = load(Outfits.male_model())
    if ps == null:
        return []
    var inst: Node3D = (ps as PackedScene).instantiate()
    host.add_child(inst)
    var out := []
    var aps := inst.find_children("*", "AnimationPlayer", true, false)
    var skels := inst.find_children("*", "Skeleton3D", true, false)
    var mis := inst.find_children("*", "MeshInstance3D", true, false)
    if not aps.is_empty() and not skels.is_empty() and not mis.is_empty():
        var ap: AnimationPlayer = aps[0]
        for an: String in ap.get_animation_list():
            if an.to_lower().contains("driv"):
                ap.play(an)
                ap.seek(0.2, true)
                break
        var skel: Skeleton3D = skels[0]
        var mi: MeshInstance3D = mis[0]
        for m: MeshInstance3D in mis:
            if String(m.name).to_lower().contains("body"):
                mi = m
        out = _skin_to_static(mi, skel, outfit)
    inst.queue_free()
    return out


static func _skin_to_static(mi: MeshInstance3D, skel: Skeleton3D, outfit: String) -> Array:
    var skin: Skin = mi.skin
    if mi.mesh == null or skin == null:
        return []
    var arr: Array = mi.mesh.surface_get_arrays(0)
    var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
    var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
    var UV: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
    var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
    var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
    var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
    if V.is_empty() or B.is_empty() or I.is_empty():
        return []
    var per := B.size() / V.size()
    var mats: Array[Transform3D] = []
    for i in skin.get_bind_count():
        var bi := skin.get_bind_bone(i)
        if bi < 0:
            bi = skel.find_bone(skin.get_bind_name(i))
        mats.append(skel.get_bone_global_pose(maxi(bi, 0)) * skin.get_bind_pose(i))
    var pv := PackedVector3Array()
    var pn := PackedVector3Array()
    pv.resize(V.size())
    pn.resize(V.size())
    for v in V.size():
        var p := Vector3.ZERO
        var n := Vector3.ZERO
        for k in per:
            var w := W[v * per + k]
            if w <= 0.0:
                continue
            var m := mats[B[v * per + k]]
            p += (m * V[v]) * w
            n += (m.basis * N[v]) * w
        pv[v] = p
        pn[v] = n.normalized()
    var pelvis := Vector3(0, 0.55, 0.3)
    var pb := skel.find_bone("pelvis")
    if pb >= 0:
        pelvis = skel.get_bone_global_pose(pb).origin
    # только то, что видно в окне машины: от середины бедра и выше
    var cut := pelvis.y - 0.12
    var remap := {}
    var nv := PackedVector3Array()
    var nn := PackedVector3Array()
    var nuv := PackedVector2Array()
    var ni := PackedInt32Array()
    for t in range(0, I.size(), 3):
        var a := I[t]
        var b := I[t + 1]
        var c := I[t + 2]
        if pv[a].y < cut and pv[b].y < cut and pv[c].y < cut:
            continue
        for v: int in [a, b, c]:
            if not remap.has(v):
                remap[v] = nv.size()
                nv.append(pv[v])
                nn.append(pn[v])
                nuv.append(UV[v])
            ni.append(remap[v])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = nv
    arrays[Mesh.ARRAY_NORMAL] = nn
    arrays[Mesh.ARRAY_TEX_UV] = nuv
    arrays[Mesh.ARRAY_INDEX] = ni
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mat := StandardMaterial3D.new()
    var tex_path := Outfits.DIR + "outfit_%s.png" % outfit
    if ResourceLoader.exists(tex_path):
        mat.albedo_texture = load(tex_path)
    mat.roughness = 0.9
    mesh.surface_set_material(0, mat)
    return [mesh, pelvis]
