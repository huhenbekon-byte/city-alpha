extends Node3D
## Прохожие: гуляют по тротуарам вокруг кварталов, машут ногами и руками,
## останавливаются перед игроком. Если сбить машиной — падают и через
## несколько секунд «уходят» в другой квартал. Далёкие не рисуются.

const CityBuilder := preload("res://scripts/city_builder.gd")
const BodyMesh := preload("res://scripts/body_mesh.gd")

const COUNT := 36
const WALK := 34.0          # середина тротуара от центра квартала
const SPEED := 1.4
const SHIRTS := [
    Color(0.80, 0.20, 0.20), Color(0.20, 0.50, 0.80), Color(0.90, 0.70, 0.20),
    Color(0.30, 0.60, 0.30), Color(0.55, 0.30, 0.60), Color(0.92, 0.92, 0.92),
    Color(0.15, 0.15, 0.17), Color(0.85, 0.45, 0.20),
]
const PANTS := [Color(0.18, 0.22, 0.32), Color(0.12, 0.12, 0.13), Color(0.40, 0.35, 0.30)]

## 3D-прохожие: та же модель, что у игрока (мужчина) и женская. Одежда — ткани по маске.
const CHAR_DIR := "res://models/character/"
const MALE_TOPS := [["cloth_bolonya_green", ""], ["cloth_wool_gray", ""], ["cloth_gabardine", ""],
        ["cloth_quilted_navy", ""], ["cloth_check_blue", "short"], ["cloth_nylon_blue", ""], ["cloth_corduroy", ""],
        ["cloth_cotton_white", "short"], ["cloth_leather_black", ""], ["cloth_leather_brown", ""], ["cloth_red_cotton", "short"]]
const MALE_PANTS := ["cloth_wool_black", "cloth_jersey_gray", "cloth_acidwash", "cloth_trousers_brown", "cloth_denim_blue", "cloth_gabardine"]
const MALE_SHOES := ["cloth_leather_black", "cloth_leather_brown", "cloth_canvas_white", "cloth_rubber_black"]
const FEMALE_TOPS := [["cloth_chintz", "dress"], ["cloth_chintz", "dress,short"], ["cloth_cardigan", ""], ["cloth_bolonya_green", ""],
        ["cloth_gabardine", ""], ["cloth_cotton_white", "short"], ["cloth_check_blue", "short"], ["cloth_red_cotton", "short"]]
const FEMALE_PANTS := ["cloth_wool_black", "cloth_acidwash", "cloth_trousers_brown", "cloth_denim_blue"]
const FEMALE_SHOES := ["cloth_leather_black", "cloth_canvas_white", "cloth_rubber_black", "cloth_leather_brown"]
const HAIR_COLORS := [Color(0.10, 0.07, 0.05), Color(0.30, 0.20, 0.12), Color(0.55, 0.42, 0.25), Color(0.80, 0.68, 0.42),
        Color(0.55, 0.25, 0.10), Color(0.60, 0.60, 0.60), Color(0.05, 0.05, 0.05)]
const SKIN_TINTS := [Vector3(1.0, 1.0, 1.0), Vector3(1.08, 1.12, 1.15), Vector3(0.85, 0.78, 0.70), Vector3(0.70, 0.60, 0.50)]

var _scenes := {}        # "male"/"female" -> PackedScene
var _tex := {}
var _shader: Shader = null

signal knocked(pos: Vector3)   # сбили машиной (для розыска)

var player: Node3D = null    # пешеход останавливается перед ним
var cars: Array = []         # машины игрока — ими можно сбить
var focus := Vector3.ZERO

var _peds: Array = []
var _rng := RandomNumberGenerator.new()
var _skin: StandardMaterial3D
var _body_meshes := {}
var _leg_meshes := {}


func setup() -> void:
    _rng.randomize()
    if ResourceLoader.exists("res://shaders/character.gdshader"):
        _shader = load("res://shaders/character.gdshader")
        for k: String in ["male", "female"]:
            var path := CHAR_DIR + ("character.gltf" if k == "male" else "female.gltf")
            if ResourceLoader.exists(path):
                var sc = load(path)
                if sc is PackedScene:
                    _scenes[k] = sc
    _skin = StandardMaterial3D.new()
    _skin.albedo_color = Color(0.87, 0.68, 0.55)
    for i in COUNT:
        var p := _make_ped()
        _place_random(p)
        _peds.append(p)


func _process(delta: float) -> void:
    for p: Dictionary in _peds:
        var root: Node3D = p["root"]
        var pos: Vector3 = p["pos"]

        if p["down"]:
            p["timer"] = float(p["timer"]) - delta
            if float(p["timer"]) <= 0.0:
                root.rotation = Vector3.ZERO
                p["down"] = false
                p["anim_state"] = ""
                _place_random(p)
            continue

        # Сбили машиной?
        for car in cars:
            if car.driven and absf(car.speed_kmh()) > 12.0 and car.global_position.distance_to(pos) < 2.0:
                p["down"] = true
                p["timer"] = 5.0
                var ap_d = p.get("anim")
                if ap_d is AnimationPlayer and (ap_d as AnimationPlayer).has_animation("Death01"):
                    (ap_d as AnimationPlayer).play("Death01", 0.1)
                else:
                    root.rotation.x = -PI * 0.5
                    root.position = pos + Vector3(0, 0.25, 0)
                Sfx.play_at("hit", pos)
                knocked.emit(pos)
                break
        if p["down"]:
            continue

        var corners: Array = p["corners"]
        var goal: Vector3 = corners[int(p["idx"])]
        var to := goal - pos
        to.y = 0.0
        var dir := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
        var stop := false
        if player and player.visible:
            var rel := player.global_position - pos
            stop = rel.dot(dir) > 0.0 and rel.dot(dir) < 1.8 and Vector2(rel.x, rel.z).length() < 1.8

        if not stop:
            var step: float = SPEED * float(p["speed_k"]) * delta
            if to.length() <= step:
                pos = goal
                p["idx"] = (int(p["idx"]) + 1) % 4
            else:
                pos += dir * step
            p["phase"] = float(p["phase"]) + step * 3.2
        p["pos"] = pos

        var near := pos.distance_to(focus) < 70.0
        root.visible = near
        var ap = p.get("anim")
        if ap is AnimationPlayer:
            var anim_p := ap as AnimationPlayer
            anim_p.active = near
            if near:
                root.position = pos
                root.rotation.y = atan2(dir.x, dir.z)
                var want := "Idle_Loop" if stop else "Walk_Loop"
                if String(p.get("anim_state", "")) != want and anim_p.has_animation(want):
                    anim_p.play(want, 0.25)
                    p["anim_state"] = want
                anim_p.speed_scale = 1.0 if stop else SPEED * float(p["speed_k"]) / 1.5
            continue
        if near:
            root.position = pos
            root.rotation.y = atan2(dir.x, dir.z)
            var swing := sin(float(p["phase"])) * (0.0 if stop else 0.55)
            var legs: Array = p["legs"]
            (legs[0] as Node3D).rotation.x = swing
            (legs[1] as Node3D).rotation.x = -swing


## Ставит пешехода на тротуар случайного квартала, подальше от камеры, если можно.
func _place_random(p: Dictionary) -> void:
    var g := CityBuilder.GRID
    var c := Vector3(_rng.randi_range(-g, g) * CityBuilder.PITCH, 0.0, _rng.randi_range(-g, g) * CityBuilder.PITCH)
    var y := CityBuilder.SIDE_H
    var corners := [c + Vector3(-WALK, y, -WALK), c + Vector3(WALK, y, -WALK),
            c + Vector3(WALK, y, WALK), c + Vector3(-WALK, y, WALK)]
    if _rng.randf() < 0.5:
        corners.reverse()
    var idx := _rng.randi() % 4
    var prev: Vector3 = corners[(idx + 3) % 4]
    var nxt: Vector3 = corners[idx]
    p["corners"] = corners
    p["idx"] = idx
    p["pos"] = prev.lerp(nxt, _rng.randf())
    p["speed_k"] = _rng.randf_range(0.8, 1.2)


func _make_ped() -> Dictionary:
    if not _scenes.is_empty():
        var d3 := _make_ped_3d()
        if not d3.is_empty():
            return d3
    var si := _rng.randi() % SHIRTS.size()
    var pi_ := _rng.randi() % PANTS.size()
    var bk := si * 10 + pi_
    if not _body_meshes.has(bk):
        _body_meshes[bk] = _build_body_mesh(SHIRTS[si], si, pi_)
    if not _leg_meshes.has(pi_):
        _leg_meshes[pi_] = _build_leg_mesh(PANTS[pi_], pi_)

    var root := Node3D.new()
    add_child(root)
    var body := MeshInstance3D.new()
    body.mesh = _body_meshes[bk]
    root.add_child(body)
    var legs := []
    for side: float in [-0.1, 0.1]:
        var hip := Node3D.new()
        hip.position = Vector3(side, 0.92, 0)
        root.add_child(hip)
        var leg := MeshInstance3D.new()
        leg.mesh = _leg_meshes[pi_]
        hip.add_child(leg)
        legs.append(hip)
    return {"root": root, "legs": legs, "pos": Vector3.ZERO, "corners": [], "idx": 0,
            "phase": _rng.randf() * TAU, "speed_k": 1.0, "down": false, "timer": 0.0}


## Туловище, руки и голова — один меш (рубашка, брюки, кожа, волосы).
## Детали смотрят в -Z, а прохожий идёт в +Z — поэтому всё повёрнуто на 180°.
func _build_body_mesh(shirt: Color, si := 0, pi_ := 0) -> ArrayMesh:
    var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
    var shirt_mat := _cloth_mat(shirt, ["cloth_sweater", "cloth_leather2", "cloth_knit", "cloth_nylon"][si % 4])
    var pants_mat := _cloth_mat(PANTS[pi_], "cloth_jeans" if pi_ % 2 == 0 else "cloth_denim")
    var hair_mat := StandardMaterial3D.new()
    hair_mat.albedo_color = [Color(0.12, 0.08, 0.05), Color(0.35, 0.25, 0.15), Color(0.6, 0.5, 0.3), Color(0.2, 0.2, 0.2)][si % 4]
    var st_shirt := SurfaceTool.new()
    st_shirt.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_shirt.set_material(shirt_mat)
    st_shirt.append_from(BodyMesh.part("torso"), 0, flip * Transform3D(Basis(), Vector3(0, 1.0, 0)))
    for side: float in [-1.0, 1.0]:
        var sh := Vector3(0.26 * side, 1.45, 0)
        var tilt := Basis(Vector3.BACK, 0.08 * side)
        st_shirt.append_from(_sphere(0.085), 0, flip * Transform3D(Basis(), sh))
        st_shirt.append_from(BodyMesh.part("upper_arm"), 0, flip * Transform3D(tilt, sh))
        var el := sh + tilt * Vector3(0, -0.29, 0)
        st_shirt.append_from(BodyMesh.part("forearm"), 0, flip * Transform3D(tilt, el))
    var st_pants := SurfaceTool.new()
    st_pants.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_pants.set_material(pants_mat)
    st_pants.append_from(BodyMesh.part("pelvis"), 0, flip * Transform3D(Basis(), Vector3(0, 0.97, 0)))
    var st_skin := SurfaceTool.new()
    st_skin.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_skin.set_material(_skin)
    st_skin.append_from(_sphere(0.12), 0, flip * Transform3D(Basis(), Vector3(0, 1.68, 0)))
    var neck := CylinderMesh.new()
    neck.top_radius = 0.055
    neck.bottom_radius = 0.06
    neck.height = 0.12
    neck.radial_segments = 10
    st_skin.append_from(neck, 0, flip * Transform3D(Basis(), Vector3(0, 1.58, 0)))
    for side: float in [-1.0, 1.0]:
        var tilt := Basis(Vector3.BACK, 0.08 * side)
        var el := Vector3(0.26 * side, 1.45, 0) + tilt * Vector3(0, -0.29, 0)
        st_skin.append_from(BodyMesh.part("hand"), 0, flip * Transform3D(tilt, el))
    var st_hair := SurfaceTool.new()
    st_hair.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_hair.set_material(hair_mat)
    st_hair.append_from(BodyMesh.part("hair"), 0, flip * Transform3D(Basis(), Vector3(0, 1.705, 0.02)))
    var mesh := ArrayMesh.new()
    st_shirt.commit(mesh)
    st_pants.commit(mesh)
    st_skin.commit(mesh)
    st_hair.commit(mesh)
    return mesh


## Нога от бедра вниз: бедро, колено, голень, ботинок.
func _build_leg_mesh(col: Color, pi_ := 0) -> ArrayMesh:
    var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
    var mat := _cloth_mat(col, "cloth_jeans" if pi_ % 2 == 0 else "cloth_denim")
    var shoe := StandardMaterial3D.new()
    shoe.albedo_color = Color(0.12, 0.11, 0.1)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(mat)
    st.append_from(BodyMesh.part("thigh"), 0, flip)
    st.append_from(_sphere(0.068), 0, flip * Transform3D(Basis(), Vector3(0, -0.45, 0)))
    st.append_from(BodyMesh.part("calf"), 0, flip * Transform3D(Basis(), Vector3(0, -0.45, 0)))
    var st2 := SurfaceTool.new()
    st2.begin(Mesh.PRIMITIVE_TRIANGLES)
    st2.set_material(shoe)
    st2.append_from(BodyMesh.part("shoe"), 0, flip * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.86, 0.07)))
    var mesh := ArrayMesh.new()
    st.commit(mesh)
    st2.commit(mesh)
    return mesh


func _cloth_mat(col: Color, tex_name: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = 0.85
    var path := "res://textures/%s.png" % tex_name
    if ResourceLoader.exists(path):
        m.albedo_texture = load(path)
        m.uv1_triplanar = true
        m.uv1_scale = Vector3.ONE * 3.5
    return m


func _sphere(r: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = r * 2.0
    m.radial_segments = 12
    m.rings = 6
    return m


func _capsule(r: float, h: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 10
    m.rings = 4
    return m



# ---------------------------------------------------------------- 3D-прохожие

func _ctex(tex_name: String) -> Texture2D:
    if _tex.has(tex_name):
        return _tex[tex_name]
    var path := tex_name if tex_name.begins_with("res://") else "res://textures/%s.png" % tex_name
    var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
    _tex[tex_name] = t
    return t


func _make_ped_3d() -> Dictionary:
    var female := _scenes.has("female") and (_rng.randf() < 0.45 or not _scenes.has("male"))
    var sc: PackedScene = _scenes["female" if female else "male"]
    var model := sc.instantiate() as Node3D
    if model == null:
        return {}
    var root := Node3D.new()
    add_child(root)
    root.add_child(model)
    var players := model.find_children("*", "AnimationPlayer", true, false)
    var ap: AnimationPlayer = players[0] if not players.is_empty() else null
    if ap:
        for an: String in ["Walk_Loop", "Idle_Loop"]:
            if ap.has_animation(an):
                ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
        if ap.has_animation("Walk_Loop"):
            ap.play("Walk_Loop")
            ap.seek(_rng.randf() * 1.0, true)

    # одежда
    var tops: Array = FEMALE_TOPS if female else MALE_TOPS
    var top: Array = tops[_rng.randi() % tops.size()]
    var style := String(top[1])
    var pants_l: Array = FEMALE_PANTS if female else MALE_PANTS
    var shoes_l: Array = FEMALE_SHOES if female else MALE_SHOES
    var pants_name: String = top[0] if style.contains("dress") else pants_l[_rng.randi() % pants_l.size()]
    var shoes_name: String = shoes_l[_rng.randi() % shoes_l.size()]
    var mat := ShaderMaterial.new()
    mat.shader = _shader
    var pre := "female_" if female else "body_"
    mat.set_shader_parameter("body_tex", _ctex(CHAR_DIR + ("female_light.png" if female else "body_light.png")))
    mat.set_shader_parameter("mask_tex", _ctex(CHAR_DIR + pre + "mask.png"))
    mat.set_shader_parameter("sleeve_tex", _ctex(CHAR_DIR + ("female_sleeve.png" if female else "sleeve_mask.png")))
    mat.set_shader_parameter("jacket_tex", _ctex(String(top[0])))
    mat.set_shader_parameter("pants_tex", _ctex(pants_name))
    mat.set_shader_parameter("shoes_tex", _ctex(shoes_name))
    var tint := _rng.randf_range(0.85, 1.05)
    for slot: String in ["jacket", "pants", "shoes"]:
        mat.set_shader_parameter(slot + "_col", Vector3(tint, tint, tint))
    mat.set_shader_parameter("long_sleeves", 0.0 if style.contains("short") else 1.0)
    mat.set_shader_parameter("print_on", 0.0)
    mat.set_shader_parameter("skin_tint", SKIN_TINTS[_rng.randi() % SKIN_TINTS.size()])

    # причёска и цвет волос
    var hair_mat := StandardMaterial3D.new()
    var hc: Color = HAIR_COLORS[_rng.randi() % HAIR_COLORS.size()]
    hair_mat.albedo_color = hc.lightened(0.15)
    var ht := _ctex(CHAR_DIR + ("hair2_gray.png" if female else "hair_gray.png"))
    if ht:
        hair_mat.albedo_texture = ht
    hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    hair_mat.alpha_scissor_threshold = 0.4
    hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    hair_mat.roughness = 0.7
    var alt := _rng.randf() < 0.4
    var beard := not female and _rng.randf() < 0.3
    for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_i := mi as MeshInstance3D
        mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var nm := String(mesh_i.name).to_lower()
        if nm.contains("hairalt"):
            mesh_i.visible = (nm.contains("beard") and beard) or (not nm.contains("beard") and alt)
            mesh_i.material_override = hair_mat
        elif nm.contains("hair"):
            mesh_i.visible = not alt
            mesh_i.material_override = hair_mat
        elif nm.contains("eyebrow"):
            mesh_i.material_override = hair_mat
        elif nm.contains("superhero") or nm.contains("body"):
            mesh_i.material_override = mat
    return {"root": root, "legs": [], "pos": Vector3.ZERO, "corners": [], "idx": 0, "anim": ap, "anim_state": "Walk_Loop",
            "phase": _rng.randf() * TAU, "speed_k": 1.0, "down": false, "timer": 0.0}
