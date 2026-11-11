extends Node3D
## Метка цели: светящийся столб, кольцо на земле и подпись с расстоянием,
## видная сквозь дома. Используется работами и экзаменом в автошколе.

var _mat: StandardMaterial3D
var _label: Label3D
var _title := ""


func _ready() -> void:
    visible = false
    _mat = StandardMaterial3D.new()
    _mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mat.cull_mode = BaseMaterial3D.CULL_DISABLED

    var beam_mesh := CylinderMesh.new()
    beam_mesh.top_radius = 0.9
    beam_mesh.bottom_radius = 0.9
    beam_mesh.height = 30.0
    beam_mesh.radial_segments = 16
    beam_mesh.rings = 1
    beam_mesh.cap_top = false
    beam_mesh.cap_bottom = false
    var beam := MeshInstance3D.new()
    beam.mesh = beam_mesh
    beam.material_override = _mat
    beam.position.y = 15.0
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(beam)

    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 2.2
    ring_mesh.bottom_radius = 2.2
    ring_mesh.height = 0.04
    ring_mesh.radial_segments = 24
    var ring := MeshInstance3D.new()
    ring.mesh = ring_mesh
    ring.material_override = _mat
    ring.position.y = 0.13
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)

    _label = Label3D.new()
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.no_depth_test = true
    _label.fixed_size = true
    _label.pixel_size = 0.0018
    _label.font_size = 40
    _label.outline_size = 10
    _label.position.y = 3.5
    add_child(_label)


func show_at(pos: Vector3, title: String, col: Color) -> void:
    position = Vector3(pos.x, 0.0, pos.z)
    _title = title
    _mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
    _label.modulate = Color(col.r, col.g, col.b, 1.0)
    _label.text = title
    visible = true


func update_distance(from: Vector3) -> void:
    if visible:
        _label.text = "%s\n%d м" % [_title, int(Vector2(from.x - position.x, from.z - position.z).length())]
