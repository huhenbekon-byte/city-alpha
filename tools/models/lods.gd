extends SceneTree
## Упрощение мешоптимайзером Godot. Для каждой поверхности пишем готовые
## вершины (позиции, нормали, uv) и индексы LOD нужной доли (обход как в glTF).
func _initialize():
    var a := OS.get_cmdline_user_args()
    var src: String = a[0]
    var dst: String = a[1]
    var ratio := float(a[2])
    var wratio := float(a[3])
    var doc := GLTFDocument.new()
    var st := GLTFState.new()
    if doc.append_from_file(src, st) != OK:
        print("load error"); quit(); return
    var out := {}
    var meshes := st.get_meshes()
    for mi in meshes.size():
        var im: ImporterMesh = meshes[mi].mesh
        var nm := String(meshes[mi].resource_name) + String(im.resource_name)
        var r := wratio if nm.contains("Wheel") else ratio
        im.generate_lods(25.0, 60.0, [])
        for s in im.get_surface_count():
            var arr: Array = im.get_surface_arrays(s)
            var base: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
            var n0 := base.size() / 3
            var best := base
            for l in im.get_surface_lod_count(s):
                var idx := im.get_surface_lod_indices(s, l)
                if idx.size() / 3 >= maxf(n0 * r, 12.0):
                    best = idx
            var lst := PackedInt32Array()
            lst.resize(best.size())
            for i in range(0, best.size(), 3):
                lst[i] = best[i]
                lst[i + 1] = best[i + 2]
                lst[i + 2] = best[i + 1]
            var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
            var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
            var fv := PackedFloat32Array()
            for p in v:
                fv.append(p.x); fv.append(p.y); fv.append(p.z)
            var fn := PackedFloat32Array()
            for p in n:
                fn.append(p.x); fn.append(p.y); fn.append(p.z)
            var fu := PackedFloat32Array()
            for p in uv:
                fu.append(p.x); fu.append(p.y)
            out["%d_%d" % [mi, s]] = {"i": Array(lst), "v": Array(fv), "n": Array(fn), "uv": Array(fu)}
    var f := FileAccess.open(dst, FileAccess.WRITE)
    f.store_string(JSON.stringify(out))
    f.close()
    quit()
