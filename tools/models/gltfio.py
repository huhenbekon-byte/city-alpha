"""Минимальное чтение glTF/GLB: узлы, мировые матрицы, аксессоры (numpy)."""
import json, struct, os
import numpy as np

COMP = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
NUM = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class Gltf:
    def __init__(self, path):
        self.dir = os.path.dirname(path)
        if path.endswith('.glb'):
            d = open(path, 'rb').read()
            off = 12
            self.json = None
            self.bins = {}
            while off < len(d):
                ln, typ = struct.unpack_from('<II', d, off)
                chunk = d[off + 8:off + 8 + ln]
                if typ == 0x4E4F534A:
                    self.json = json.loads(chunk)
                else:
                    self.bins[0] = chunk
                off += 8 + ln
        else:
            self.json = json.load(open(path))
            self.bins = {}
        self.g = self.json
        self._world = None

    def buf(self, i):
        if i not in self.bins:
            self.bins[i] = open(os.path.join(self.dir, self.g['buffers'][i]['uri']), 'rb').read()
        return self.bins[i]

    def acc(self, i):
        a = self.g['accessors'][i]
        bv = self.g['bufferViews'][a['bufferView']]
        data = self.buf(bv['buffer'])
        dt = np.dtype(COMP[a['componentType']])
        n = NUM[a['type']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = bv.get('byteStride', dt.itemsize * n)
        cnt = a['count']
        if stride == dt.itemsize * n:
            arr = np.frombuffer(data, dtype=dt, count=cnt * n, offset=off).reshape(cnt, n)
        else:
            arr = np.stack([np.frombuffer(data, dtype=dt, count=n, offset=off + k * stride) for k in range(cnt)])
        arr = arr.astype(np.float64)
        if a.get('normalized') and dt != np.float32:
            arr = arr / np.iinfo(dt).max
        return arr

    @staticmethod
    def local(n):
        if 'matrix' in n:
            return np.array(n['matrix'], dtype=float).reshape(4, 4).T
        t = n.get('translation', [0, 0, 0]); r = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
        return trs(t, r, s)

    def world(self):
        if self._world is None:
            W = [None] * len(self.g['nodes'])
            parent = {}
            for i, n in enumerate(self.g['nodes']):
                for c in n.get('children', []):
                    parent[c] = i

            def get(i):
                if W[i] is None:
                    L = self.local(self.g['nodes'][i])
                    W[i] = get(parent[i]) @ L if i in parent else L
                return W[i]
            for i in range(len(W)):
                get(i)
            self._world = W
            self.parent = parent
        return self._world


def quat_to_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_to_quat(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2; w = 0.25 * s
        x = (m[2, 1] - m[1, 2]) / s; y = (m[0, 2] - m[2, 0]) / s; z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2; w = (m[2, 1] - m[1, 2]) / s
        x = 0.25 * s; y = (m[0, 1] + m[1, 0]) / s; z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2; w = (m[0, 2] - m[2, 0]) / s
        x = (m[0, 1] + m[1, 0]) / s; y = 0.25 * s; z = (m[1, 2] + m[2, 1]) / s
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2; w = (m[1, 0] - m[0, 1]) / s
        x = (m[0, 2] + m[2, 0]) / s; y = (m[1, 2] + m[2, 1]) / s; z = 0.25 * s
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)


def trs(t, r, s):
    M = np.eye(4)
    M[:3, :3] = quat_to_mat(r) * np.array(s)[None, :]
    M[:3, 3] = t
    return M
