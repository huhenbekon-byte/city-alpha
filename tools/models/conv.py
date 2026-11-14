"""Конвертер моделей Sketchfab (GLB) в формат игры (glTF + .bin + текстуры).

Машины: +Z вперёд, земля y=0, узлы Body и Wheel_FL/FR/RL/RR (колесо в центре узла),
метки PlateF/PlateR/Side/Roof. Материалы с ролями Paint/Glass/Tail.
Пропсы и дома: один узел Body, низ y=0, центр по XZ (или как задано).
"""
import io, json, os, re, struct, subprocess, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glbflat import Glb

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(os.path.dirname(HERE), 'godot')

ROT = {  # исходные оси -> игровые: (x, y, z) берём как ...
    'z+': np.eye(3),
    'z-': np.diag([-1, 1, -1]),
    'x+': np.array([[0, 0, -1], [0, 1, 0], [1, 0, 0]]),   # перед был +X
    'x-': np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]]),   # перед был -X
}


def rot_up(R, up):
    """Если «верх» исходника — Z (Blender без поворота), сначала кладём Z в Y."""
    if up == 'z':
        U = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]])
        return R @ U
    return R


class Model:
    def __init__(self, src):
        self.G = Glb(src)
        self.mats = self.G.materials()
        self.ch = self.G.chunks()

    def transform(self, R, scale=None, length=None, center='wheels', axis_len=2):
        for c in self.ch:
            c['P'] = c['P'] @ R.T
        P = np.concatenate([c['P'] for c in self.ch])
        if length:
            scale = length / (P[:, axis_len].max() - P[:, axis_len].min())
        for c in self.ch:
            c['P'] = c['P'] * scale
        self.scale = scale

    def drop(self, pat):
        self.ch = [c for c in self.ch if not re.search(pat, c['path'], re.I)]

    def bbox(self):
        P = np.concatenate([c['P'] for c in self.ch])
        return P.min(0), P.max(0)

    def shift(self, d):
        for c in self.ch:
            c['P'] = c['P'] + d

    def split_by_node(self, pats):
        """{часть: regex имени узла} — чанки по частям, остальное Body."""
        for c in self.ch:
            c['part'] = 'Body'
            for part, pat in pats.items():
                if re.search(pat, c['path'], re.I):
                    c['part'] = part

    def split_by_region(self, wheels, r, half_w):
        """Колёса, вшитые в кузов: треугольники внутри цилиндра колеса уходят в колесо.
        wheels: {Wheel_FL: (x, y, z)} в игровых координатах."""
        new = []
        for c in self.ch:
            if c.get('part', 'Body') != 'Body':
                new.append(c); continue
            P, I = c['P'], c['I']
            T = P[I]  # (T,3,3)
            taken = np.zeros(len(I), bool)
            for part, (x, y, z) in wheels.items():
                d = np.hypot(T[:, :, 1] - y, T[:, :, 2] - z)
                inside = (d < r * 1.04).all(1) & (np.abs(T[:, :, 0] - x) < half_w).all(1) & ~taken
                if inside.any():
                    nc = dict(c); nc['I'] = I[inside]; nc['part'] = part
                    new.append(nc)
                    taken |= inside
            rest = dict(c); rest['I'] = I[~taken]; rest['part'] = 'Body'
            new.append(rest)
        self.ch = new


def tex_out(G, mats, mi, outdir, prefix, texmax, cache):
    m = mats[mi]
    if m['tex'] is None:
        return None
    key = (m['tex'], m['alpha'] != 'OPAQUE')
    if key in cache:
        return cache[key]
    raw = G.image_bytes(m['tex'])
    im = Image.open(io.BytesIO(raw))
    has_alpha = m['alpha'] != 'OPAQUE' and im.mode in ('RGBA', 'LA', 'P')
    im = im.convert('RGBA' if has_alpha else 'RGB')
    if max(im.size) > texmax:
        k = texmax / max(im.size)
        im = im.resize((max(4, int(im.width * k)), max(4, int(im.height * k))), Image.LANCZOS)
    fn = '%s_%d.%s' % (prefix, len(cache), 'png' if has_alpha else 'jpg')
    if has_alpha:
        im.save(os.path.join(outdir, fn), optimize=True)
    else:
        im.save(os.path.join(outdir, fn), quality=85, optimize=True)
    cache[key] = fn
    return fn


def build(M, outdir, name, roles=None, texmax=1024, budget=None, wheel_budget=None, markers=True, root=None,
          keep_wheel_parts=('Wheel_FL', 'Wheel_FR', 'Wheel_RL', 'Wheel_RR'), smooth_none=False):
    """Пишет name.gltf/.bin. roles: [(regex имени материала, роль)]."""
    roles = roles or []
    G, mats = M.G, M.mats
    parts = {}
    for c in M.ch:
        if len(c['I']) == 0:
            continue
        parts.setdefault(c.get('part', 'Body'), []).append(c)
    nodes, meshes, mats_out, images, textures, accs, views = [], [], [], [], [], [], []
    buf = bytearray()
    cache = {}
    matidx = {}

    def add(arr, comp, typ, target):
        b = arr.tobytes(); off = len(buf); buf.extend(b)
        while len(buf) % 4:
            buf.append(0)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(b), 'target': target})
        a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(len(arr)), 'type': typ}
        if typ == 'VEC3':
            a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    def material(mi):
        if mi in matidx:
            return matidx[mi]
        m = mats[mi] if mi >= 0 else {'name': 'Default', 'color': [0.6, 0.6, 0.6, 1], 'alpha': 'OPAQUE', 'tex': None, 'metal': 0, 'rough': 0.8}
        role = None
        for pat, rl in roles:
            if re.search(pat, m['name'], re.I):
                role = rl; break
        nm = role or re.sub(r'[^A-Za-z0-9_]', '_', m['name'])[:24] or 'M%d' % mi
        if not role and nm in ('Paint', 'Glass', 'Tail'):
            nm = 'M_' + nm
        out = {'name': nm, 'doubleSided': True,
               'pbrMetallicRoughness': {'baseColorFactor': [float(x) for x in m['color']],
                                        'metallicFactor': float(min(m.get('metal', 0) or 0, 0.6)),
                                        'roughnessFactor': float(max(m.get('rough', 1) if m.get('rough') is not None else 1, 0.25))}}
        fn = tex_out(G, mats, mi, outdir, name, texmax, cache) if mi >= 0 else None
        if fn:
            if fn not in [im['uri'] for im in images]:
                images.append({'uri': fn}); textures.append({'source': len(images) - 1})
            ti = [im['uri'] for im in images].index(fn)
            out['pbrMetallicRoughness']['baseColorTexture'] = {'index': ti}
        if role == 'Glass' or m['alpha'] == 'BLEND':
            out['alphaMode'] = 'BLEND'
            c = out['pbrMetallicRoughness']['baseColorFactor']
            if role == 'Glass':
                c[3] = min(c[3], 0.5) if c[3] < 0.95 else 0.45
        elif m['alpha'] == 'MASK':
            out['alphaMode'] = 'MASK'; out['alphaCutoff'] = 0.5
        mats_out.append(out)
        matidx[mi] = len(mats_out) - 1
        return matidx[mi]

    total = 0
    info = {}
    order = ['Body'] + [p for p in parts if p != 'Body']
    for part in order:
        if part not in parts:
            continue
        cs = parts[part]
        # центр колеса
        cen = np.zeros(3)
        if part.startswith('Wheel'):
            allp = np.concatenate([c['P'][np.unique(c['I'])] for c in cs])
            mn, mx = allp.min(0), allp.max(0)
            cen = (mn + mx) / 2
            info[part] = (cen, (mx[1] - mn[1]) / 2, mx[0] - mn[0])
        bymat = {}
        for c in cs:
            bymat.setdefault(c['mat'], []).append(c)
        prims = []
        for mi, lst in bymat.items():
            Ps, UVs, Is = [], [], []
            off = 0
            for c in lst:
                used, inv = np.unique(c['I'], return_inverse=True)
                Ps.append(c['P'][used] - cen)
                UVs.append(c['UV'][used] if c['UV'] is not None else np.zeros((len(used), 2)))
                Is.append(inv.reshape(-1, 3) + off)
                off += len(used)
            P = np.concatenate(Ps).astype(np.float32)
            UV = np.concatenate(UVs).astype(np.float32)
            I = np.concatenate(Is).astype(np.uint32)
            # нормали по геометрии (сглаженные по общим вершинам)
            T = P[I]
            fn = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
            N = np.zeros_like(P)
            for k in range(3):
                np.add.at(N, I[:, k], fn)
            N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
            attrs = {'POSITION': add(np.ascontiguousarray(P), 5126, 'VEC3', 34962),
                     'NORMAL': add(np.ascontiguousarray(N.astype(np.float32)), 5126, 'VEC3', 34962)}
            if any(c['UV'] is not None for c in lst):
                attrs['TEXCOORD_0'] = add(np.ascontiguousarray(UV), 5126, 'VEC2', 34962)
            prims.append({'attributes': attrs, 'indices': add(I.reshape(-1), 5125, 'SCALAR', 34963), 'material': material(mi)})
            total += len(I)
        meshes.append({'name': part, 'primitives': prims})
        nd = {'name': part, 'mesh': len(meshes) - 1}
        if part != 'Body':
            nd['translation'] = [float(x) for x in cen]
        nodes.append(nd)
    if markers:
        mn, mx = M.bbox()
        for nm, t in (('PlateF', [0, 0.45, mx[2]]), ('PlateR', [0, 0.55, mn[2]]), ('Side', [mx[0] - 0.02, (mn[1] + mx[1]) * 0.45, 0]),
                      ('Roof', [0, mx[1], 0])):
            nodes.append({'name': nm, 'translation': [float(x) for x in t]})
    nodes.append({'name': root or name, 'children': list(range(len(nodes)))})
    g = {'asset': {'version': '2.0', 'generator': 'city-alpha conv'}, 'scene': 0,
         'scenes': [{'nodes': [len(nodes) - 1]}], 'nodes': nodes, 'meshes': meshes, 'materials': mats_out,
         'accessors': accs, 'bufferViews': views, 'buffers': [{'uri': name + '.bin', 'byteLength': len(buf)}]}
    if images:
        g['images'] = images; g['textures'] = textures
    base = os.path.join(outdir, name)
    open(base + '.bin', 'wb').write(buf)
    json.dump(g, open(base + '.gltf', 'w'))
    print(name, 'tris', total, 'bin', len(buf) // 1024, 'KB', 'wheels', {k: (v[0].round(2).tolist(), round(v[1], 3)) for k, v in info.items()})
    if budget and total > budget:
        simplify(base, budget / total, wheel_budget)
    return info


def simplify(base, ratio, wheel_ratio=None):
    """Упрощение мешоптимайзером Godot: меняются только индексы, вершины остаются."""
    tool = os.path.join(HERE, 'lods.gd')
    out = base + '.lods'
    r = subprocess.run([GODOT, '--headless', '--path', HERE, '-s', tool, '--', base + '.gltf', out, str(ratio),
                        str(wheel_ratio or ratio)], capture_output=True, text=True, timeout=1200)
    if not os.path.exists(out):
        print(r.stdout[-2000:], r.stderr[-2000:]); raise SystemExit('lods failed')
    data = json.load(open(out))
    g = json.load(open(base + '.gltf'))
    buf = bytearray(open(base + '.bin', 'rb').read())
    tot = 0
    for mi, m in enumerate(g['meshes']):
        for pi, p in enumerate(m['primitives']):
            key = '%d_%d' % (mi, pi)
            if key not in data:
                continue
            d = data[key]

            def put(arr, comp, typ, target):
                b = arr.tobytes(); off = len(buf); buf.extend(b)
                while len(buf) % 4:
                    buf.append(0)
                g['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(b), 'target': target})
                a = {'bufferView': len(g['bufferViews']) - 1, 'componentType': comp, 'count': int(len(arr)), 'type': typ}
                if typ == 'VEC3':
                    a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
                g['accessors'].append(a)
                return len(g['accessors']) - 1
            V = np.array(d['v'], np.float32).reshape(-1, 3)
            if len(V) == 0 or len(d['i']) == 0:
                continue
            attrs = {'POSITION': put(V, 5126, 'VEC3', 34962)}
            if d['n']:
                attrs['NORMAL'] = put(np.array(d['n'], np.float32).reshape(-1, 3), 5126, 'VEC3', 34962)
            if d['uv'] and 'TEXCOORD_0' in p['attributes']:
                attrs['TEXCOORD_0'] = put(np.array(d['uv'], np.float32).reshape(-1, 2), 5126, 'VEC2', 34962)
            p['attributes'] = attrs
            p['indices'] = put(np.array(d['i'], np.uint32), 5125, 'SCALAR', 34963)
            tot += len(d['i']) // 3
    g['buffers'][0]['byteLength'] = len(buf)
    open(base + '.bin', 'wb').write(buf)
    json.dump(g, open(base + '.gltf', 'w'))
    compact(base)
    os.remove(out)


def compact(base):
    g = json.load(open(base + '.gltf'))
    buf = open(base + '.bin', 'rb').read()
    CT = {5126: np.float32, 5125: np.uint32}
    NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}

    def acc(i):
        a = g['accessors'][i]; bv = g['bufferViews'][a['bufferView']]
        return np.frombuffer(buf, CT[a['componentType']], a['count'] * NC[a['type']], bv['byteOffset']).reshape(a['count'], NC[a['type']])
    nb = bytearray(); views = []; accs = []

    def add(arr, comp, typ, target):
        b = arr.tobytes(); off = len(nb); nb.extend(b)
        while len(nb) % 4:
            nb.append(0)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(b), 'target': target})
        a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(len(arr)), 'type': typ}
        if typ == 'VEC3':
            a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        accs.append(a); return len(accs) - 1
    tot = 0
    for m in g['meshes']:
        keep = []
        for p in m['primitives']:
            idx = acc(p['indices']).reshape(-1).astype(np.int64)
            if len(idx) == 0:
                continue
            used, inv = np.unique(idx, return_inverse=True)
            attrs = {}
            for k, v in p['attributes'].items():
                a = np.ascontiguousarray(acc(v)[used])
                attrs[k] = add(a, 5126, 'VEC3' if a.shape[1] == 3 else 'VEC2', 34962)
            p['attributes'] = attrs
            p['indices'] = add(inv.astype(np.uint32), 5125, 'SCALAR', 34963)
            tot += len(inv) // 3
            keep.append(p)
        m['primitives'] = keep
    g['accessors'] = accs; g['bufferViews'] = views
    g['buffers'] = [{'uri': os.path.basename(base) + '.bin', 'byteLength': len(nb)}]
    open(base + '.bin', 'wb').write(nb); json.dump(g, open(base + '.gltf', 'w'))
    print('  simplified tris', tot, 'bin', len(nb) // 1024, 'KB')
