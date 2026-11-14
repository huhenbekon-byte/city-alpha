"""Сборка машин (и статичных моделей) в glTF формата игры.

Геометрия задаётся «уголками»: для каждого материала массив треугольников (T,3,3) и uv (T,3,2) или None.
Узлы: Body, Wheel_FL/FR/RL/RR (центр колеса в начале координат узла), PlateF/PlateR, Side, Roof.
"""
import json, math, os
import numpy as np


def decimate(tris, uvs, cell):
    """Упрощение кластеризацией вершин: вершины в одной клетке сетки сливаются в среднюю точку.
    tris (T,3,3), uvs (T,3,2) или None. Вырожденные треугольники выкидываются, uv остаются свои."""
    P = tris.reshape(-1, 3)
    key = np.floor(P / cell).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    cnt = np.bincount(inv)
    cen = np.zeros((cnt.size, 3))
    for k in range(3):
        cen[:, k] = np.bincount(inv, P[:, k]) / cnt
    ids = inv.reshape(-1, 3)
    ok = (ids[:, 0] != ids[:, 1]) & (ids[:, 1] != ids[:, 2]) & (ids[:, 0] != ids[:, 2])
    ids = ids[ok]
    # одинаковые треугольники (после слияния) — оставить один
    srt = np.sort(ids, axis=1)
    _, first = np.unique(srt, axis=0, return_index=True)
    first = np.sort(first)
    keep = np.nonzero(ok)[0][first]
    out = cen[ids[first]]
    return out, (uvs[keep] if uvs is not None else None)


def smooth_normals(tris, angle=40.0):
    """Нормали по уголкам: сглаживание между гранями с общей точкой и углом меньше angle."""
    T = len(tris)
    fn = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    ln = np.linalg.norm(fn, axis=1, keepdims=True)
    fn = np.where(ln > 1e-12, fn / np.maximum(ln, 1e-12), np.array([0, 1.0, 0]))
    P = tris.reshape(-1, 3)
    key = np.round(P * 1e4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    face_of = np.repeat(np.arange(T), 3)
    order = np.argsort(inv, kind='stable')
    inv_s = inv[order]
    bounds = np.flatnonzero(np.diff(inv_s)) + 1
    groups = np.split(order, bounds)
    out = np.repeat(fn, 3, axis=0).copy()
    cl = math.cos(math.radians(angle))
    for g in groups:
        if len(g) < 2:
            continue
        fns = fn[face_of[g]]
        dots = fns @ fns.T
        acc = (dots > cl).astype(float) @ fns
        acc /= np.linalg.norm(acc, axis=1, keepdims=True) + 1e-12
        out[g] = acc
    return out.reshape(T, 3, 3)


class Gltf:
    def __init__(self):
        self.buf = bytearray(); self.views = []; self.accs = []; self.meshes = []; self.mats = []
        self.mat_index = {}; self.images = []; self.textures = []; self.nodes = []

    def _add(self, arr, comp, typ, target):
        b = arr.tobytes(); off = len(self.buf); self.buf.extend(b)
        while len(self.buf) % 4:
            self.buf.append(0)
        self.views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(b), 'target': target})
        a = {'bufferView': len(self.views) - 1, 'componentType': comp, 'count': len(arr), 'type': typ}
        if typ == 'VEC3':
            a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        self.accs.append(a)
        return len(self.accs) - 1

    def material(self, spec):
        n = spec['name']
        if n in self.mat_index:
            return self.mat_index[n]
        m = {'name': n, 'doubleSided': spec.get('double', True),
             'pbrMetallicRoughness': {'baseColorFactor': list(spec.get('color', [1, 1, 1, 1])),
                                      'metallicFactor': spec.get('metal', 0.0), 'roughnessFactor': spec.get('rough', 0.7)}}
        if 'tex' in spec:
            self.images.append({'uri': spec['tex']})
            tx = {'source': len(self.images) - 1}
            if spec.get('nearest'):
                tx['sampler'] = 0
            self.textures.append(tx)
            m['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(self.textures) - 1}
        if spec.get('alpha') == 'BLEND':
            m['alphaMode'] = 'BLEND'
        elif spec.get('alpha') == 'MASK':
            m['alphaMode'] = 'MASK'; m['alphaCutoff'] = 0.5
        if 'emit' in spec:
            m['emissiveFactor'] = spec['emit']
        self.mats.append(m)
        self.mat_index[n] = len(self.mats) - 1
        return self.mat_index[n]

    def mesh(self, name, parts, angle=40.0):
        """parts: list of (matspec, tris (T,3,3), uvs (T,3,2) or None)"""
        prims = []
        for spec, tris, uvs in parts:
            if tris is None or len(tris) == 0:
                continue
            nrm = smooth_normals(tris, angle)
            p = tris.reshape(-1, 3).astype(np.float32); n = nrm.reshape(-1, 3).astype(np.float32)
            cols = [p, n] + ([uvs.reshape(-1, 2).astype(np.float32)] if uvs is not None else [])
            allv = np.concatenate(cols, axis=1)
            q = np.round(allv * 2000).astype(np.int64)
            _, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
            allv = allv[first]; idx = inv.reshape(-1).astype(np.uint32)
            p = np.ascontiguousarray(allv[:, :3]); n = np.ascontiguousarray(allv[:, 3:6])
            attrs = {'POSITION': self._add(p, 5126, 'VEC3', 34962), 'NORMAL': self._add(n, 5126, 'VEC3', 34962)}
            if uvs is not None:
                attrs['TEXCOORD_0'] = self._add(np.ascontiguousarray(allv[:, 6:8]), 5126, 'VEC2', 34962)
            prims.append({'attributes': attrs, 'indices': self._add(idx, 5125, 'SCALAR', 34963),
                          'material': self.material(spec)})
        self.meshes.append({'name': name, 'primitives': prims})
        return len(self.meshes) - 1

    def node(self, name, mesh=None, t=None, rot=None):
        n = {'name': name}
        if mesh is not None:
            n['mesh'] = mesh
        if t is not None:
            n['translation'] = [float(x) for x in t]
        if rot is not None:
            n['rotation'] = rot
        self.nodes.append(n)
        return len(self.nodes) - 1

    def save(self, base, root_name):
        kids = list(range(len(self.nodes)))
        self.nodes.append({'name': root_name, 'children': kids})
        name = os.path.basename(base)
        g = {'asset': {'version': '2.0', 'generator': 'city-alpha carbuild'}, 'scene': 0,
             'scenes': [{'nodes': [len(self.nodes) - 1]}], 'nodes': self.nodes, 'meshes': self.meshes,
             'materials': self.mats, 'accessors': self.accs, 'bufferViews': self.views,
             'buffers': [{'uri': name + '.bin', 'byteLength': len(self.buf)}]}
        if self.images:
            g['images'] = self.images; g['textures'] = self.textures
            g['samplers'] = [{'magFilter': 9728, 'minFilter': 9728}]
        open(base + '.bin', 'wb').write(self.buf)
        json.dump(g, open(base + '.gltf', 'w'))
        return len(self.buf)


def wheel_tris(radius, width, rim_ratio=0.62, seg=20):
    """Колесо вдоль оси X: шина (боковины + протектор) и диск-колпак. Возвращает (tire, rim)."""
    a = np.linspace(0, 2 * math.pi, seg + 1)
    tire = []; rim = []
    hw = width / 2
    for i in range(seg):
        c0, s0, c1, s1 = math.cos(a[i]), math.sin(a[i]), math.cos(a[i + 1]), math.sin(a[i + 1])
        o0 = np.array([0, c0 * radius, s0 * radius]); o1 = np.array([0, c1 * radius, s1 * radius])
        r = radius * rim_ratio
        i0 = np.array([0, c0 * r, s0 * r]); i1 = np.array([0, c1 * r, s1 * r])
        L = np.array([-hw, 0, 0]); R = np.array([hw, 0, 0])
        # протектор
        tire += [[o0 + L, o1 + L, o1 + R], [o0 + L, o1 + R, o0 + R]]
        for side in (L, R):
            tire += [[o0 + side, i0 + side, i1 + side], [o0 + side, i1 + side, o1 + side]]
            # колпак, чуть утоплен
            d = side * 0.8
            rim += [[d, i0 + d, i1 + d]]
    return np.array(tire), np.array(rim)
