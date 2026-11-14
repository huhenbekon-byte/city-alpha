"""Чтение GLB: все примитивы в мировых координатах сцены, с именами узлов и материалами."""
import json, struct, io
import numpy as np

CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_matrix(n):
    if 'matrix' in n:
        return np.array(n['matrix'], float).reshape(4, 4).T
    M = np.eye(4)
    R = quat_mat(n.get('rotation', [0, 0, 0, 1]))
    S = np.diag(n.get('scale', [1, 1, 1]))
    M[:3, :3] = R @ S
    M[:3, 3] = n.get('translation', [0, 0, 0])
    return M


class Glb:
    def __init__(self, path):
        f = open(path, 'rb').read()
        L = struct.unpack('<I', f[12:16])[0]
        self.g = json.loads(f[20:20 + L])
        o = 20 + L
        self.bin = b''
        if o < len(f):
            bl = struct.unpack('<I', f[o:o + 4])[0]
            self.bin = f[o + 8:o + 8 + bl]

    def acc(self, i):
        g = self.g
        a = g['accessors'][i]
        n = NC[a['type']]
        dt = np.dtype(CT[a['componentType']])
        if 'bufferView' not in a:
            return np.zeros((a['count'], n), dt)
        bv = g['bufferViews'][a['bufferView']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = bv.get('byteStride', 0)
        if stride and stride != dt.itemsize * n:
            raw = np.frombuffer(self.bin, np.uint8, stride * (a['count'] - 1) + dt.itemsize * n, off)
            out = np.zeros((a['count'], dt.itemsize * n), np.uint8)
            for k in range(a['count']):
                pass
            idx = np.arange(a['count'])[:, None] * stride + np.arange(dt.itemsize * n)[None, :]
            out = raw[idx]
            arr = np.ascontiguousarray(out).view(dt).reshape(a['count'], n)
        else:
            arr = np.frombuffer(self.bin, dt, a['count'] * n, off).reshape(a['count'], n)
        arr = arr.astype(np.float64) if dt.kind == 'f' else arr
        if a.get('normalized') and dt.kind in 'iu':
            arr = arr.astype(np.float64) / float(np.iinfo(dt).max)
        return arr

    def image_bytes(self, tex_index):
        g = self.g
        t = g['textures'][tex_index]
        src = t.get('source')
        if src is None:
            for ext in t.get('extensions', {}).values():
                src = ext.get('source')
        im = g['images'][src]
        bv = g['bufferViews'][im['bufferView']]
        o = bv.get('byteOffset', 0)
        return self.bin[o:o + bv['byteLength']]

    def materials(self):
        out = []
        for i, m in enumerate(self.g.get('materials', [])):
            pbr = m.get('pbrMetallicRoughness', {})
            d = {'name': m.get('name', 'mat%d' % i), 'color': pbr.get('baseColorFactor', [1, 1, 1, 1]),
                 'alpha': m.get('alphaMode', 'OPAQUE'), 'tex': None, 'metal': pbr.get('metallicFactor', 1.0),
                 'rough': pbr.get('roughnessFactor', 1.0), 'emit': m.get('emissiveFactor')}
            if 'baseColorTexture' in pbr:
                d['tex'] = pbr['baseColorTexture']['index']
            out.append(d)
        return out

    def chunks(self):
        """[{node, path, mat, P (N,3) мир, UV (N,2)|None, I (T,3)}]"""
        g = self.g
        out = []
        scene = g['scenes'][g.get('scene', 0)]

        def walk(ni, M, path):
            n = g['nodes'][ni]
            W = M @ node_matrix(n)
            nm = n.get('name', 'n%d' % ni)
            p2 = path + [nm]
            if 'mesh' in n:
                for pi, p in enumerate(g['meshes'][n['mesh']]['primitives']):
                    if p.get('mode', 4) != 4:
                        continue
                    P = self.acc(p['attributes']['POSITION'])
                    P = (np.c_[P, np.ones(len(P))] @ W.T)[:, :3]
                    UV = self.acc(p['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in p['attributes'] else None
                    I = self.acc(p['indices']).reshape(-1, 3).astype(np.int64) if 'indices' in p else np.arange(len(P)).reshape(-1, 3)
                    if np.linalg.det(W[:3, :3]) < 0:
                        I = I[:, [0, 2, 1]]
                    out.append({'node': nm, 'path': '/'.join(p2), 'mat': p.get('material', -1), 'P': P, 'UV': UV, 'I': I,
                                'mesh': g['meshes'][n['mesh']].get('name', '')})
            for c in n.get('children', []):
                walk(c, W, p2)

        for r in scene['nodes']:
            walk(r, np.eye(4), [])
        return out
