"""Карта развёртки тела персонажа: для каждого пикселя текстуры 1024×1024 — точка на теле (x, y, z)
и нормаль. Нужна, чтобы переносить рисунки одежды (вид спереди/сзади) на развёртку без «наугад»."""
import json, struct, numpy as np

COMP = {5126: ('f', 4), 5123: ('H', 2), 5125: ('I', 4), 5121: ('B', 1)}
NUM = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def load_body(path='models/character/character.gltf', mesh_name='Sphere.005_Retopology.004'):
    g = json.load(open(path))
    base = path.rsplit('/', 1)[0]
    bins = {}

    def acc(i):
        a = g['accessors'][i]
        bv = g['bufferViews'][a['bufferView']]
        b = g['buffers'][bv['buffer']]
        if bv['buffer'] not in bins:
            bins[bv['buffer']] = open(base + '/' + b['uri'], 'rb').read()
        data = bins[bv['buffer']]
        fmt, sz = COMP[a['componentType']]
        n = NUM[a['type']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = bv.get('byteStride', sz * n)
        out = np.zeros((a['count'], n), dtype=np.float64)
        for k in range(a['count']):
            out[k] = struct.unpack_from('<' + fmt * n, data, off + k * stride)
        return out

    m = next(mm for mm in g['meshes'] if mm['name'] == mesh_name)
    p = m['primitives'][0]
    pos = acc(p['attributes']['POSITION'])
    nor = acc(p['attributes']['NORMAL'])
    uv = acc(p['attributes']['TEXCOORD_0'])
    idx = acc(p['indices']).astype(np.int64).reshape(-1, 3)
    return pos, nor, uv, idx


def rasterize(pos, nor, uv, idx, size=1024, height=None):
    """Возвращает P (h,w,3), N (h,w,3), mask (h,w). size — ширина, height — высота (по умолчанию = size)."""
    hgt = height or size
    P = np.zeros((hgt, size, 3)); N = np.zeros((hgt, size, 3)); M = np.zeros((hgt, size), bool)
    scale = np.array([size, hgt])
    for t in idx:
        u = uv[t] * scale - 0.5
        x0, y0 = np.floor(u.min(0)).astype(int); x1, y1 = np.ceil(u.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, size - 1); y1 = min(y1, hgt - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        a, b, c = u
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        w2 = 1 - w0 - w1
        ins = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not ins.any():
            continue
        W = np.stack([w0[ins], w1[ins], w2[ins]], 1)
        yy, xx = ys[ins], xs[ins]
        P[yy, xx] = W @ pos[t]
        N[yy, xx] = W @ nor[t]
        M[yy, xx] = True
    n = np.linalg.norm(N, axis=2, keepdims=True); N = N / np.maximum(n, 1e-9)
    return P, N, M
