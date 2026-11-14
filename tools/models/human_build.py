"""Реалистичный человек (Human Male/Female Basemesh Rigged, Niclas, CC BY 4.0) → персонаж игры.

Что делает:
  1. Берёт мужское тело и глаза из GLB (скелет Rigify, 700 костей, руки в A-позе).
  2. Переводит его в T-позу своими же весами (как у персонажа Quaternius, под которого сделаны анимации).
  3. Переносит веса на скелет Quaternius (65 костей, те же имена: pelvis, spine_01, upperarm_l, ...):
     повороты костей в покое — как у Quaternius (анимации подходят без пересчёта), длины — новой модели.
  4. Копирует анимации из character.gltf (смещение таза — под новый рост).
  5. Пишет models/character/human.gltf + human.bin.

Запуск из корня проекта:  python3 tools/models/human_build.py <путь к base.glb> [female]
(female — женская сетка того же файла → human_f.gltf, рост 1,66 м)
"""
import sys, os, re, json, struct
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from gltfio import Gltf, quat_to_mat, mat_to_quat

OUT_DIR = 'models/character'
HEIGHT = 1.78            # рост нового персонажа, м
HEIGHT_F = 1.66          # рост женщины

Q = Gltf(os.path.join(OUT_DIR, 'character.gltf'))
QW = Q.world()
QSK = Q.g['skins'][0]
QNAMES = [Q.g['nodes'][j]['name'] for j in QSK['joints']]
QPOS = {n: QW[QSK['joints'][k]][:3, 3] for k, n in enumerate(QNAMES)}
QPARENT = {}
for k, j in enumerate(QSK['joints']):
    for c in Q.g['nodes'][j].get('children', []):
        if c in QSK['joints']:
            QPARENT[QNAMES[QSK['joints'].index(c)]] = QNAMES[k]


def strip(n):
    return re.sub(r'_\d+$', '', n)


def side(n):
    return 'l' if '.L' in n else ('r' if '.R' in n else '')


FINGER = {'f_index': 'index', 'f_middle': 'middle', 'f_ring': 'ring', 'f_pinky': 'pinky', 'thumb': 'thumb'}


def map_bone(n):
    """Имя кости Rigify → кость Quaternius (или None)."""
    b = strip(n)
    s = side(b)
    core = b.replace('DEF-', '').replace('ORG-', '').replace('MCH-', '')
    spine = {'spine': 'pelvis', 'spine.001': 'spine_01', 'spine.002': 'spine_02', 'spine.003': 'spine_03',
             'spine.004': 'neck_01', 'spine.005': 'neck_01', 'spine.006': 'Head'}
    if core in spine:
        return spine[core]
    if core.startswith('pelvis'):
        return 'pelvis'
    if core.startswith('breast'):
        return 'spine_03'
    if not s:
        return 'Head' if any(k in core for k in ('brow', 'cheek', 'chin', 'ear', 'eye', 'jaw', 'lip', 'nose',
                                                  'forehead', 'temple', 'tongue', 'teeth', 'lid', 'face')) else None
    if core.startswith('shoulder'):
        return 'clavicle_' + s
    if core.startswith('upper_arm'):
        return 'upperarm_' + s
    if core.startswith('forearm'):
        return 'lowerarm_' + s
    if core.startswith('hand') or core.startswith('palm'):
        return 'hand_' + s
    for k, v in FINGER.items():
        m = re.match(k + r'\.0(\d)', core)
        if m:
            return '%s_0%s_%s' % (v, m.group(1), s)
    if core.startswith('thigh'):
        return 'thigh_' + s
    if core.startswith('shin'):
        return 'calf_' + s
    if core.startswith('foot'):
        return 'foot_' + s
    if core.startswith('toe'):
        return 'ball_' + s
    if any(k in core for k in ('brow', 'cheek', 'chin', 'ear', 'eye', 'jaw', 'lip', 'nose', 'lid', 'temple')):
        return 'Head'
    return None


def rot_between(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    v = np.cross(a, b); c = np.dot(a, b)
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))



def uv_islands(I, n):
    par = np.arange(n)
    def f(x):
        while par[x] != x:
            par[x] = par[par[x]]; x = par[x]
        return x
    for t in I:
        r0 = f(t[0])
        for v in t[1:]:
            r = f(v)
            if r != r0: par[r] = r0
    return np.array([f(i) for i in range(n)])


def fix_overlaps(b, R=512, thr=0.12):
    from scipy.spatial import cKDTree
    UV, I, P = b['UV'], b['I'], b['P']
    isl_v = uv_islands(I, len(P)); isl = isl_v[I[:, 0]]
    q = P.copy(); q[:, 0] = np.abs(q[:, 0] - np.median(P[:, 0]))
    c3 = q[I].mean(1)
    first = -np.ones((R, R), int); hits = []
    for ti, t in enumerate(I):
        u = UV[t] * R
        x0, y0 = np.floor(u.min(0)).astype(int); x1, y1 = np.ceil(u.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, R - 1), min(y1, R - 1)
        if x1 < x0 or y1 < y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
        a, bb, c = u
        d = (bb[1] - c[1]) * (a[0] - c[0]) + (c[0] - bb[0]) * (a[1] - c[1])
        if abs(d) < 1e-9: continue
        l1 = ((bb[1] - c[1]) * (xs - c[0]) + (c[0] - bb[0]) * (ys - c[1])) / d
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        m = (l1 > 0.02) & (l2 > 0.02) & (1 - l1 - l2 > 0.02)
        if not m.any(): continue
        py, px = np.nonzero(m); py += y0; px += x0
        prev = first[py, px]
        for o in np.unique(prev[prev >= 0]):
            if isl[o] != isl[ti] and np.linalg.norm(c3[o] - c3[ti]) > thr:
                hits.append((o, ti))
        first[py, px] = np.where(prev < 0, ti, prev)
    if not hits:
        return
    size = np.bincount(isl_v, minlength=len(P))
    bad_isl = set()
    for o, t in hits:
        bad_isl.add(isl[o] if size[isl[o]] < size[isl[t]] else isl[t])
    bad_v = np.where(np.isin(isl_v, list(bad_isl)))[0]
    good_v = np.where(~np.isin(isl_v, list(bad_isl)))[0]
    _, k = cKDTree(P[good_v]).query(P[bad_v])
    UV[bad_v] = UV[good_v[k]]
    print('острова с наложенной развёрткой:', len(bad_isl), 'вершин', len(bad_v),
          'размеры', sorted(int(size[i]) for i in bad_isl))


def repack(b, aspect=2.0, pad=0.006, head_y=0.84, head_k=2.0):
    """Раскладка островов UV без наложений, одинаковая плотность (голова — head_k)."""
    UV, I, P = b['UV'], b['I'], b['P']
    isl_v = uv_islands(I, len(P)); isl_t = isl_v[I[:, 0]]
    ymin, ymax = P[:, 1].min(), P[:, 1].max()
    def area(X):
        a = X[:, 1] - X[:, 0]; c = X[:, 2] - X[:, 0]
        if X.shape[2] == 2:
            return np.abs(a[:, 0] * c[:, 1] - a[:, 1] * c[:, 0]) / 2
        return np.linalg.norm(np.cross(a, c), axis=1) / 2
    items = []
    for r in np.unique(isl_t):
        tm = isl_t == r; vs = np.unique(I[tm])
        a3 = area(P[I[tm]]).sum(); a2 = area(UV[I[tm]]).sum()
        uv = UV[vs].copy()
        if a2 < 1e-12 or a3 < 1e-12:                     # вырожденный остров — точка
            uv[:] = 0; s = 0.0
        else:
            s = np.sqrt(a3 / a2)
            if (P[vs, 1].mean() - ymin) / (ymax - ymin) > head_y:
                s *= head_k
        uv = (uv - uv.min(0)) * s
        items.append((vs, uv))
    def pack(k, C=1024):
        # «линия горизонта»: каждый остров кладём туда, где он ляжет ниже всего
        sky = np.zeros(C); dx = aspect / C; out = []
        for vs, uv in sorted(items, key=lambda it: -(it[1][:, 1].max())):
            w, h = uv.max(0) * k
            n = min(C, int(np.ceil((w + pad) / dx)) + 1)
            win = np.lib.stride_tricks.sliding_window_view(sky, n).max(1)
            x0 = int(np.argmin(win)); y = win[x0]
            out.append((vs, uv * k + [x0 * dx + pad, y + pad]))
            sky[x0:x0 + n] = y + h + pad
        return out, sky.max() + pad
    lo, hi = 0.0, 100.0
    for _ in range(50):
        k = (lo + hi) / 2
        if pack(k)[1] <= 1.0: lo = k
        else: hi = k
    out, _ = pack(lo)
    for vs, uv in out:
        UV[vs] = uv / [aspect, 1.0]
    b['UV'] = np.clip(UV, 0, 1)
    print('развёртка: островов', len(items), 'плотность', round(lo, 3))


def main(src, female=False):
    G = Gltf(src); g = G.g; W = G.world()
    # мужчина — скин без костей груди, женщина — с ними
    si = next(i for i, s in enumerate(g['skins']) if any('breast' in g['nodes'][j]['name'] for j in s['joints']) == female)
    sk = g['skins'][si]
    jn = [g['nodes'][j]['name'] for j in sk['joints']]
    jpos = np.array([W[j][:3, 3] for j in sk['joints']])
    meshes = [n for n in g['nodes'] if 'mesh' in n and n.get('skin') == si]
    parts = []
    for n in meshes:
        pr = g['meshes'][n['mesh']]['primitives'][0]
        a = pr['attributes']
        parts.append(dict(P=G.acc(a['POSITION']), N=G.acc(a['NORMAL']), UV=G.acc(a['TEXCOORD_0']),
                          J=G.acc(a['JOINTS_0']).astype(int), Wt=G.acc(a['WEIGHTS_0']), I=G.acc(pr['indices']).astype(int).reshape(-1, 3)))
    parts.sort(key=lambda p: -len(p['P']))      # тело, затем глаза
    for part in parts:                           # развёртка лежит в плитке (-16, 16) — сдвинуть в 0..1
        t = np.floor(np.median(part['UV'], 0))
        part['UV'] = part['UV'] - t
    # исходная развёртка — автоматическая, без текстуры: острова наложены друг на друга
    # (голова на руки, кисти, стопы) и зеркальны (левая и правая половины в одних пикселях).
    # Заново раскладываем все острова без наложений в атлас 2:1 (текстура 2048×1024),
    # голове — двойная плотность пикселей (лицо со скина)
    # глазные яблоки входят в тело (своими островами атласа): на них ложатся глаза с фото,
    # иначе на месте глаз — дыры в голове
    b, e = parts[0], parts[1]
    nb = len(b['P'])
    for k in ('P', 'N', 'UV', 'J', 'Wt'):
        b[k] = np.concatenate([b[k], e[k]])
    b['I'] = np.concatenate([b['I'], e['I'] + nb])
    repack(parts[0])
    body, eyes = parts[0], parts[1]

    # опорные точки скелета новой модели (по именам Quaternius)
    def rp(name):
        for k, n in enumerate(jn):
            if strip(n) == name:
                return jpos[k]
        raise KeyError(name)
    P = {}
    P['pelvis'] = rp('DEF-spine'); P['spine_01'] = rp('DEF-spine.001'); P['spine_02'] = rp('DEF-spine.002')
    P['spine_03'] = rp('DEF-spine.003'); P['neck_01'] = rp('DEF-spine.004'); P['Head'] = rp('DEF-spine.006')
    for s, S in (('l', 'L'), ('r', 'R')):
        P['clavicle_' + s] = rp('DEF-shoulder.' + S); P['upperarm_' + s] = rp('DEF-upper_arm.' + S)
        P['lowerarm_' + s] = rp('DEF-forearm.' + S); P['hand_' + s] = rp('DEF-hand.' + S)
        for k, v in FINGER.items():
            for i in (1, 2, 3):
                P['%s_0%d_%s' % (v, i, s)] = rp('DEF-%s.0%d.%s' % (k, i, S))
            P['%s_04_leaf_%s' % (v, s)] = P['%s_03_%s' % (v, s)] + (P['%s_03_%s' % (v, s)] - P['%s_02_%s' % (v, s)]) * 0.9
        P['thigh_' + s] = rp('DEF-thigh.' + S); P['calf_' + s] = rp('DEF-shin.' + S)
        P['foot_' + s] = rp('DEF-foot.' + S); P['ball_' + s] = rp('DEF-toe.' + S)
        d = P['ball_' + s] - P['foot_' + s]; d[1] = 0
        P['ball_leaf_' + s] = P['ball_' + s] + d / max(np.linalg.norm(d), 1e-6) * 0.07
    c = P['pelvis'].copy(); P['root'] = np.array([c[0], 0.0, c[2]])

    # веса: Rigify → Quaternius (непонятные кости — к ближайшему суставу)
    qidx = {n: i for i, n in enumerate(QNAMES)}
    bone_map = []
    for k, n in enumerate(jn):
        m = map_bone(n)
        if m is None:
            d = {q: np.linalg.norm(P[q] - jpos[k]) for q in P if q != 'root'}
            m = min(d, key=d.get)
        bone_map.append(qidx[m])
    bone_map = np.array(bone_map)

    def remap(part):
        nv = len(part['P'])
        acc = np.zeros((nv, len(QNAMES)))
        for c in range(4):
            np.add.at(acc, (np.arange(nv), bone_map[part['J'][:, c]]), part['Wt'][:, c])
        top = np.argsort(-acc, 1)[:, :4]
        w = np.take_along_axis(acc, top, 1)
        w = w / np.maximum(w.sum(1, keepdims=True), 1e-9)
        return top, w
    body['QJ'], body['QW'] = remap(body)
    eyes['QJ'] = np.zeros_like(eyes['J']); eyes['QJ'][:, 0] = qidx['Head']
    eyes['QW'] = np.zeros_like(eyes['Wt']); eyes['QW'][:, 0] = 1

    # T-поза: каждую кость руки/ноги/пальца повернуть так, чтобы она смотрела как у Quaternius
    CHILD = {}
    for s in 'lr':
        CHILD.update({'clavicle_' + s: 'upperarm_' + s, 'upperarm_' + s: 'lowerarm_' + s, 'lowerarm_' + s: 'hand_' + s,
                      'hand_' + s: 'middle_01_' + s, 'thigh_' + s: 'calf_' + s, 'calf_' + s: 'foot_' + s,
                      'foot_' + s: 'ball_' + s, 'ball_' + s: 'ball_leaf_' + s})
        for v in FINGER.values():
            for i in (1, 2, 3):
                CHILD['%s_0%d_%s' % (v, i, s)] = '%s_0%d_%s' % (v, i + 1, s) if i < 3 else '%s_04_leaf_%s' % (v, s)
    order = [n for n in QNAMES]                   # имена в порядке иерархии (родитель раньше ребёнка)
    D = {}
    for n in order:
        par = QPARENT.get(n)
        Dp = D[par] if par else np.eye(4)
        head = (Dp @ np.append(P[n], 1))[:3]
        if n in CHILD and CHILD[n] in P:
            tail = (Dp @ np.append(P[CHILD[n]], 1))[:3]
            want = QPOS[CHILD[n]] - QPOS[n]
            if n.startswith('clavicle'):
                R = np.eye(3)                       # ключицу не трогаем
            else:
                R = rot_between(tail - head, want)
            T = np.eye(4); T[:3, :3] = R; T[:3, 3] = head - R @ head
            D[n] = T @ Dp
        else:
            D[n] = Dp
    newP = {n: (D[QPARENT[n]] @ np.append(P[n], 1))[:3] if n in QPARENT else P[n] for n in QNAMES}

    def pose(part):
        M = np.stack([D[QNAMES[i]] for i in range(len(QNAMES))])
        Ms = np.einsum('vk,vkij->vij', part['QW'], M[part['QJ']])
        p = np.einsum('vij,vj->vi', Ms[:, :3, :3], part['P']) + Ms[:, :3, 3]
        nn = np.einsum('vij,vj->vi', Ms[:, :3, :3], part['N'])
        return p, nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
    for part in (body, eyes):
        part['TP'], part['TN'] = pose(part)

    # масштаб и положение: ступни на нуле, центр — над началом координат
    ymin = body['TP'][:, 1].min(); ymax = body['TP'][:, 1].max()
    k = (HEIGHT_F if female else HEIGHT) / (ymax - ymin)
    off = np.array([-P['root'][0], -ymin, -P['root'][2]])
    for part in (body, eyes):
        part['TP'] = (part['TP'] + off) * k
    for n in newP:
        newP[n] = (newP[n] + off) * k
    newP['root'] = np.zeros(3)
    print('рост %.2f м, масштаб %.3f, таз %.3f (у Quaternius %.3f)' % ((HEIGHT_F if female else HEIGHT), k, newP['pelvis'][1], QPOS['pelvis'][1]))

    # скелет: повороты покоя — Quaternius, положения — новые
    qglob = {n: QW[QSK['joints'][i]][:3, :3] for i, n in enumerate(QNAMES)}
    qglob = {n: m / np.linalg.norm(m, axis=0, keepdims=True) for n, m in qglob.items()}   # без масштаба
    write(newP, qglob, body, eyes, 'human_f' if female else 'human')


def write(newP, qglob, body, eyes, name='human'):
    g = Q.g
    out = {'asset': {'version': '2.0', 'generator': 'city-alpha human_build.py',
                     'extras': {'author': 'Niclas (https://sketchfab.com/niclas.schoepe)', 'license': 'CC-BY-4.0',
                                'source': 'https://sketchfab.com/3d-models/human-malefemale-basemesh-rigged-96fa14a5a3f0413e98b605e3f65e447c'}},
           'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [], 'meshes': [], 'accessors': [], 'bufferViews': [],
           'buffers': [], 'skins': [], 'animations': [], 'materials': [
               {'name': 'Body', 'pbrMetallicRoughness': {'baseColorFactor': [0.8, 0.65, 0.55, 1], 'metallicFactor': 0, 'roughnessFactor': 0.7}},
               ]}
    blob = bytearray()

    def add(arr, ctype, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(blob) % 4:
            blob.append(0)
        off = len(blob); blob.extend(arr.tobytes())
        bv = {'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes}
        if target:
            bv['target'] = target
        out['bufferViews'].append(bv)
        a = {'bufferView': len(out['bufferViews']) - 1, 'componentType': ctype, 'count': len(arr), 'type': typ}
        if minmax:
            a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        out['accessors'].append(a)
        return len(out['accessors']) - 1

    # узлы: 0 Armature → root (иерархия Quaternius) ; меши
    names = QNAMES
    node_of = {}
    out['nodes'].append({'name': 'Armature', 'children': []})
    # повороты покоя локально: R_local = R_parent_glob^T R_glob ; смещение — из новых положений
    arm_rot = QW[Q.g['scenes'][0]['nodes'][0]][:3, :3]
    for n in names:
        node_of[n] = len(out['nodes'])
        out['nodes'].append({'name': n, 'children': []})
    for n in names:
        par = QPARENT.get(n)
        Rg = qglob[n]
        Rp = qglob[par] if par else np.eye(3)
        Pp = newP[par] if par else np.zeros(3)
        Rl = Rp.T @ Rg
        t = Rp.T @ (newP[n] - Pp)
        nd = out['nodes'][node_of[n]]
        nd['rotation'] = mat_to_quat(Rl).tolist()
        nd['translation'] = t.tolist()
        if par:
            out['nodes'][node_of[par]]['children'].append(node_of[n])
        else:
            out['nodes'][0]['children'].append(node_of[n])
    for nd in out['nodes']:
        if not nd['children']:
            del nd['children']
    # обратные матрицы привязки
    ibm = []
    for n in names:
        M = np.eye(4); M[:3, :3] = qglob[n]; M[:3, 3] = newP[n]
        ibm.append(np.linalg.inv(M).T.reshape(-1))
    ibm_acc = add(np.array(ibm, dtype=np.float32), 5126, 'MAT4')
    out['skins'].append({'joints': [node_of[n] for n in names], 'inverseBindMatrices': ibm_acc, 'skeleton': node_of['root']})

    for mname, part, mat in (('Body', body, 0),):          # глаза — нарисованные с фото (шарики не совпадали)
        a = {'POSITION': add(part['TP'].astype(np.float32), 5126, 'VEC3', 34962, True),
             'NORMAL': add(part['TN'].astype(np.float32), 5126, 'VEC3', 34962),
             'TEXCOORD_0': add(part['UV'].astype(np.float32), 5126, 'VEC2', 34962),
             'JOINTS_0': add(part['QJ'].astype(np.uint16), 5123, 'VEC4', 34962),
             'WEIGHTS_0': add(part['QW'].astype(np.float32), 5126, 'VEC4', 34962)}
        idx = add(part['I'].reshape(-1).astype(np.uint32), 5125, 'SCALAR', 34963)
        out['meshes'].append({'name': mname, 'primitives': [{'attributes': a, 'indices': idx, 'material': mat}]})
        out['nodes'].append({'name': mname, 'mesh': len(out['meshes']) - 1, 'skin': 0})
        out['nodes'][0]['children'].append(len(out['nodes']) - 1)

    # анимации Quaternius: повороты как есть, смещение таза — под новый рост
    ratio = newP['pelvis'][1] / QPOS['pelvis'][1]
    for an in g['animations']:
        na = {'name': an['name'], 'channels': [], 'samplers': []}
        for ch in an['channels']:
            tn = g['nodes'][ch['target']['node']]['name']
            if tn not in node_of:
                continue
            smp = an['samplers'][ch['sampler']]
            inp = Q.acc(smp['input']).astype(np.float32)
            outv = Q.acc(smp['output']).astype(np.float32)
            path = ch['target']['path']
            if path == 'translation':
                if tn == 'pelvis':
                    outv = outv * ratio
                elif tn == 'root':
                    pass
                else:
                    continue          # длины костей — свои
            if path == 'scale':
                continue
            ia = add(inp.astype(np.float32), 5126, 'SCALAR', None, True)
            outv = outv.astype(np.float32)
            oa = add(outv, 5126, {3: 'VEC3', 4: 'VEC4'}[outv.shape[1]])
            na['samplers'].append({'input': ia, 'output': oa, 'interpolation': smp.get('interpolation', 'LINEAR')})
            na['channels'].append({'sampler': len(na['samplers']) - 1, 'target': {'node': node_of[tn], 'path': path}})
        out['animations'].append(na)

    out['asset']['extras']['eyes'] = [eyes['TP'][eyes['TP'][:, 0] > 0].mean(0).tolist(), eyes['TP'][eyes['TP'][:, 0] < 0].mean(0).tolist()]
    out['buffers'].append({'uri': name + '.bin', 'byteLength': len(blob)})
    open(os.path.join(OUT_DIR, name + '.bin'), 'wb').write(bytes(blob))
    json.dump(out, open(os.path.join(OUT_DIR, name + '.gltf'), 'w'), indent=1)
    print('записано: %s.gltf (%d вершин тела, %d треугольников), %s.bin %.1f МБ' %
          (name, len(body['TP']), len(body['I']), name, len(blob) / 1e6))


if __name__ == '__main__':
    main(sys.argv[1], len(sys.argv) > 2 and sys.argv[2] == 'female')
