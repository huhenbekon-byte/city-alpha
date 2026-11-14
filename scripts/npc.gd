extends Node3D
## Неигровой персонаж города: Петер у вокзала, тётя Галя в кассе, таксист, пассажиры с чемоданами.
## Настройки задаются до add_child. Издалека (> 70 м) прячется и не анимируется — бережём FPS.

const CHAR_PATH := "res://models/character/character.gltf"
const FEMALE_PATH := "res://models/character/female.gltf"
const CHAR_DIR := "res://models/character/"

var npc_name := "ПЕТЕР"        # пусто — без подписи
var female := false
var jacket := "cloth_corduroy"
var pants := "cloth_trousers_brown"
var shoes := "cloth_leather_black"
var short_sleeves := false
var hair_color := Color(0.62, 0.6, 0.58)
var beard := true
var alt_hair := false
var anim := "idle_talking"     # начало имени анимации: idle_talking, idle, sitting_idle
var collide := true
var mark := true               # жёлтый «!» над головой
var suitcase := false          # чемодан рядом
var name_y := 2.12
var hat := ""                  # головной убор (см. hats.gd): "petushok", "militia"...
var hat_col := Color(0, 0, 0, 0)
var name_col := Color(1.0, 0.95, 0.8)
var remote := false            # другой игрок по сети: анимации задаёт main.gd через play_anim()
const Hats := preload("res://scripts/hats.gd")
const Poses := preload("res://scripts/poses.gd")

var _mark: Label3D
var _ap: AnimationPlayer
var _model: Node3D
var _time := 0.0
var _far_t := 0.0


func _ready() -> void:
    if collide:
        var body := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.3
        cap.height = 1.8
        cs.shape = cap
        cs.position.y = 0.9
        body.add_child(cs)
        add_child(body)

    var path := FEMALE_PATH if female and ResourceLoader.exists(FEMALE_PATH) else CHAR_PATH
    if ResourceLoader.exists(path):
        var ps = load(path)
        if ps is PackedScene:
            var m := (ps as PackedScene).instantiate() as Node3D
            add_child(m)
            _model = m
            _dress(m)
            var players := m.find_children("*", "AnimationPlayer", true, false)
            if not players.is_empty():
                _ap = players[0] as AnimationPlayer
                if (anim.begins_with("pose_") or anim.begins_with("anim_") or remote) and not female:
                    var sks := m.find_children("*", "Skeleton3D", true, false)
                    if not sks.is_empty():
                        Poses.install(_ap, sks[0] as Skeleton3D)
                var a := _find_anim(anim)
                if a == "":
                    a = _find_anim("idle")
                if a != "":
                    if anim.begins_with("death"):   # лежит: проиграть до конца и замереть
                        _ap.get_animation(a).loop_mode = Animation.LOOP_NONE
                        _ap.play(a)
                        _ap.seek(_ap.get_animation(a).length - 0.01, true)
                    else:
                        _ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
                        _ap.play(a)
                        _ap.seek(randf() * 2.0, true)
            if hat != "":
                for sk: Node in m.find_children("*", "Skeleton3D", true, false):
                    if (sk as Skeleton3D).find_bone("Head") >= 0:
                        var att := BoneAttachment3D.new()
                        att.bone_name = "Head"
                        sk.add_child(att)
                        var h := Hats.build(hat, hat_col)
                        h.position = Vector3(0, 0.16, 0.008)
                        att.add_child(h)
                        break
    if suitcase:
        var sc := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.5, 0.36, 0.18)
        sc.mesh = bm
        var sm := StandardMaterial3D.new()
        sm.albedo_color = [Color(0.45, 0.28, 0.16), Color(0.2, 0.25, 0.4), Color(0.35, 0.33, 0.3)][randi() % 3]
        sm.roughness = 0.6
        sc.material_override = sm
        sc.position = Vector3(0.38, 0.2, 0.05)
        add_child(sc)

    var name_l := Label3D.new()
    name_l.text = npc_name
    name_l.visible = npc_name != ""
    name_l.font_size = 64
    name_l.pixel_size = 0.005
    name_l.outline_size = 12
    name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_l.no_depth_test = false
    name_l.modulate = name_col
    name_l.position = Vector3(0, name_y, 0)
    add_child(name_l)
    _mark = Label3D.new()
    _mark.text = "!"
    _mark.font_size = 150
    _mark.pixel_size = 0.005
    _mark.outline_size = 18
    _mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _mark.modulate = Color(1.0, 0.82, 0.1)
    _mark.position = Vector3(0, name_y + 0.43, 0)
    _mark.visible = mark
    add_child(_mark)


func _process(delta: float) -> void:
    _time += delta
    _look_at_player(delta)
    if _mark.visible:
        _mark.position.y = name_y + 0.43 + sin(_time * 3.0) * 0.06
    _far_t -= delta
    if _far_t <= 0.0:
        _far_t = 0.5
        var cam := get_viewport().get_camera_3d()
        var near := cam == null or cam.global_position.distance_to(global_position) < 70.0
        if _model and _model.visible != near:
            _model.visible = near
            if _ap:
                if near:
                    _ap.play()
                else:
                    _ap.pause()


## Стоящий человек поворачивается к игроку, когда тот подходит близко (сидящие и лежащие — нет).
func _look_at_player(delta: float) -> void:
    if _model == null or not _model.visible or remote:
        return
    for still: String in ["sit", "death", "pose", "walk"]:
        if anim.begins_with(still):
            return
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    var target := 0.0
    var tp := cam.global_position
    var players := get_tree().get_nodes_in_group("player")
    if not players.is_empty():
        tp = (players[0] as Node3D).global_position
    var rel := global_transform.affine_inverse() * tp
    rel.y = 0.0
    if rel.length() < 6.0 and rel.length() > 0.3:
        target = clampf(atan2(rel.x, rel.z), -1.9, 1.9)
    _model.rotation.y = lerp_angle(_model.rotation.y, target, 1.0 - exp(-3.0 * delta))


## Показать «!» над головой (есть новое задание / ещё не знакомы).
func set_has_quest(on: bool) -> void:
    if _mark:
        _mark.visible = on


func _find_anim(base: String) -> String:
    if _ap == null:
        return ""
    for an in _ap.get_animation_list():
        if String(an).to_lower().begins_with(base):
            return String(an)
    return ""


## Одежда по настройкам (ткани из textures/cloth_*.png), причёска и борода.
func _dress(m: Node) -> void:
    if not ResourceLoader.exists("res://shaders/character.gdshader"):
        return
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/character.gdshader")
    mat.set_shader_parameter("body_tex", _tex(CHAR_DIR + ("female_light.png" if female else "body_light.png")))
    mat.set_shader_parameter("mask_tex", _tex(CHAR_DIR + ("female_mask.png" if female else "body_mask.png")))
    mat.set_shader_parameter("sleeve_tex", _tex(CHAR_DIR + ("female_sleeve.png" if female else "sleeve_mask.png")))
    mat.set_shader_parameter("jacket_tex", _tex("res://textures/%s.png" % jacket))
    mat.set_shader_parameter("pants_tex", _tex("res://textures/%s.png" % pants))
    mat.set_shader_parameter("shoes_tex", _tex("res://textures/%s.png" % shoes))
    for slot: String in ["jacket", "pants", "shoes"]:
        mat.set_shader_parameter(slot + "_col", Vector3(1, 1, 1))
    mat.set_shader_parameter("long_sleeves", 0.0 if short_sleeves else 1.0)
    mat.set_shader_parameter("print_on", 0.0)
    mat.set_shader_parameter("skin_tint", Vector3(1.0, 0.97, 0.95))
    var hair := StandardMaterial3D.new()
    hair.albedo_color = hair_color
    var ht := _tex(CHAR_DIR + ("hair2_gray.png" if female else "hair_gray.png"))
    if ht:
        hair.albedo_texture = ht
    hair.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    hair.alpha_scissor_threshold = 0.4
    hair.cull_mode = BaseMaterial3D.CULL_DISABLED
    for n: Node in m.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        var nm := String(mi.name).to_lower()
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if nm.contains("hairalt"):
            mi.visible = (nm.contains("beard") and beard) or (not nm.contains("beard") and alt_hair)
            mi.material_override = hair
        elif nm.contains("hair"):
            mi.visible = not alt_hair
            mi.material_override = hair
        elif nm.contains("eyebrow"):
            mi.material_override = hair
        elif nm.contains("superhero") or nm.contains("body"):
            mi.material_override = mat


func _tex(path: String) -> Texture2D:
    return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Сетевой игрок: включить анимацию по точному имени (как у локального игрока).
func play_anim(anim_name: String, speed: float) -> void:
    if _ap == null or anim_name == "" or not _ap.has_animation(anim_name):
        return
    if _ap.current_animation != anim_name:
        var a := _ap.get_animation(anim_name)
        if a and a.loop_mode == Animation.LOOP_NONE and not anim_name.begins_with("Anim_") and not anim_name.begins_with("Pose_"):
            a.loop_mode = Animation.LOOP_LINEAR
        _ap.play(anim_name, 0.2)
    _ap.speed_scale = clampf(speed, 0.0, 3.0)
