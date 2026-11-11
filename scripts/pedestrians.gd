extends Node3D
## Прохожие: гуляют по тротуарам вокруг кварталов, машут ногами и руками,
## останавливаются перед игроком. Если сбить машиной — падают и через
## несколько секунд «уходят» в другой квартал. Далёкие не рисуются.

const CityBuilder := preload("res://scripts/city_builder.gd")

const COUNT := 36
const WALK := 34.0          # середина тротуара от центра квартала
const SPEED := 1.4
const SHIRTS := [
    Color(0.80, 0.20, 0.20), Color(0.20, 0.50, 0.80), Color(0.90, 0.70, 0.20),
    Color(0.30, 0.60, 0.30), Color(0.55, 0.30, 0.60), Color(0.92, 0.92, 0.92),
    Color(0.15, 0.15, 0.17), Color(0.85, 0.45, 0.20),
]
const PANTS := [Color(0.18, 0.22, 0.32), Color(0.12, 0.12, 0.13), Color(0.40, 0.35, 0.30)]

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
                _place_random(p)
            continue

        # Сбили машиной?
        for car in cars:
            if car.driven and absf(car.speed_kmh()) > 12.0 and car.global_position.distance_to(pos) < 2.0:
                p["down"] = true
                p["timer"] = 5.0
                root.rotation.x = -PI * 0.5
                root.position = pos + Vector3(0, 0.25, 0)
                Sfx.play_at("hit", pos)
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

        var near := pos.distance_to(focus) < 75.0
        root.visible = near
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
    var si := _rng.randi() % SHIRTS.size()
    var pi_ := _rng.randi() % PANTS.size()
    if not _body_meshes.has(si):
        _body_meshes[si] = _build_body_mesh(SHIRTS[si])
    if not _leg_meshes.has(pi_):
        _leg_meshes[pi_] = _build_leg_mesh(PANTS[pi_])

    var root := Node3D.new()
    add_child(root)
    var body := MeshInstance3D.new()
    body.mesh = _body_meshes[si]
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


## Туловище, руки и голова — один меш с двумя материалами.
func _build_body_mesh(shirt: Color) -> ArrayMesh:
    var shirt_mat := StandardMaterial3D.new()
    shirt_mat.albedo_color = shirt
    var st_shirt := SurfaceTool.new()
    st_shirt.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_shirt.set_material(shirt_mat)
    st_shirt.append_from(_capsule(0.2, 0.62), 0, Transform3D(Basis(), Vector3(0, 1.22, 0)))
    st_shirt.append_from(_capsule(0.07, 0.6), 0, Transform3D(Basis(), Vector3(0.27, 1.14, 0)))
    st_shirt.append_from(_capsule(0.07, 0.6), 0, Transform3D(Basis(), Vector3(-0.27, 1.14, 0)))
    var st_skin := SurfaceTool.new()
    st_skin.begin(Mesh.PRIMITIVE_TRIANGLES)
    st_skin.set_material(_skin)
    var head := SphereMesh.new()
    head.radius = 0.12
    head.height = 0.24
    head.radial_segments = 12
    head.rings = 6
    st_skin.append_from(head, 0, Transform3D(Basis(), Vector3(0, 1.68, 0)))
    var mesh := ArrayMesh.new()
    st_shirt.commit(mesh)
    st_skin.commit(mesh)
    return mesh


func _build_leg_mesh(col: Color) -> ArrayMesh:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(mat)
    st.append_from(_capsule(0.08, 0.92), 0, Transform3D(Basis(), Vector3(0, -0.46, 0)))
    var mesh := ArrayMesh.new()
    st.commit(mesh)
    return mesh


func _capsule(r: float, h: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 10
    m.rings = 4
    return m
