import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from conv import Model, build, ROT

OUT = sys.argv[1]
only = sys.argv[2:]


def car(name, src, rot, scale, wheels_by_node=None, wheels_region=None, roles=(), budget=None, wheel_ratio=None,
        drop=None, texmax=1024, markers=True):
    if only and name not in only:
        return
    M = Model(src)
    if drop:
        M.drop(drop)
    R = ROT[rot]
    M.transform(R, scale=scale)
    if wheels_by_node:
        M.split_by_node(wheels_by_node)
    else:
        for c in M.ch:
            c['part'] = 'Body'
    if wheels_region:
        cen, r, hw = wheels_region
        wc = {k: (np.array(v) @ R.T) * scale for k, v in cen.items()}
        M.split_by_region(wc, r * scale, hw * scale)
    # земля по низу колёс, середина базы в z=0, ось симметрии x=0
    W = [c for c in M.ch if c['part'].startswith('Wheel') and len(c['I'])]
    WP = np.concatenate([c['P'][np.unique(c['I'])] for c in W])
    fz = [c for c in W if c['part'].startswith('Wheel_F')]
    rz = [c for c in W if c['part'].startswith('Wheel_R')]
    zf = np.mean(np.concatenate([c['P'][np.unique(c['I'])][:, 2] for c in fz]))
    zr = np.mean(np.concatenate([c['P'][np.unique(c['I'])][:, 2] for c in rz]))
    mn, mx = M.bbox()
    M.shift(np.array([-(mn[0] + mx[0]) / 2, -WP[:, 1].min(), -(zf + zr) / 2]))
    print(name, 'wheelbase', round(zf - zr, 3), 'size', (M.bbox()[1] - M.bbox()[0]).round(2))
    build(M, OUT, name, roles=list(roles), budget=budget, wheel_budget=wheel_ratio, texmax=texmax, markers=markers)


GLASS = [(r'glass|steklo|стекл', 'Glass')]

car('vaz2101', 'src/vaz2101.glb', 'x+', 2.424 / 281.0,
    wheels_by_node={'Wheel_FL': r'Object_10$', 'Wheel_FR': r'Object_12$', 'Wheel_RL': r'Object_14$', 'Wheel_RR': r'Object_16$'},
    roles=GLASS)
car('vaz2108', 'src/vaz2108.glb', 'z-', 2.46 / 240.38,
    wheels_by_node={'Wheel_FL': r'(^|/)wheel_', 'Wheel_FR': r'wheel3_', 'Wheel_RL': r'wheel1_', 'Wheel_RR': r'wheel2_'})
car('moskvich', 'src/moskvich.glb', 'z+', 2.40 / 1.45,
    wheels_region=({'Wheel_FL': (0.405, -0.27, 0.84), 'Wheel_FR': (-0.405, -0.27, 0.84),
                    'Wheel_RL': (0.405, -0.27, -0.61), 'Wheel_RR': (-0.405, -0.27, -0.61)}, 0.14, 0.09),
    roles=[(r'mat_2', 'Glass')])
car('uaz469', 'src/uaz469.glb', 'z+', 2.38 / 254.28,
    wheels_by_node={'Wheel_FL': r'(^|/)wheel_UAZ', 'Wheel_FR': r'wheel\.003', 'Wheel_RL': r'wheel\.001', 'Wheel_RR': r'wheel\.002'},
    roles=GLASS, budget=9000, wheel_ratio=0.35)
car('uaz452n', 'src/uaz452.glb', 'z+', 2.30 / 1.09,
    wheels_region=({'Wheel_FL': (0.44, -0.305, 0.535), 'Wheel_FR': (-0.44, -0.305, 0.535),
                    'Wheel_RL': (0.44, -0.305, -0.555), 'Wheel_RR': (-0.44, -0.305, -0.555)}, 0.178, 0.13),
    roles=GLASS)
car('gaz53', 'src/gaz.glb', 'x+', 3.70 / 342.8,
    wheels_by_node={'Wheel_FL': r'(^|/)FL_', 'Wheel_FR': r'(^|/)FR_', 'Wheel_RL': r'(^|/)RL_', 'Wheel_RR': r'(^|/)RR_'},
    roles=GLASS)
car('zil130', 'src/zil130.glb', 'x+', 3.80 / 82.43,
    wheels_by_node={'Wheel_FL': r'nh_3', 'Wheel_FR': r'nh_4', 'Wheel_RL': r'nh_1', 'Wheel_RR': r'nh_2'},
    roles=[(r'23_-_Default', 'Glass')], budget=16000, wheel_ratio=0.025)
car('laz695', 'src/laz.glb', 'z+', 4.19 / 425.0,
    wheels_region=({'Wheel_FL': (104, 55, 255), 'Wheel_FR': (-104, 55, 255),
                    'Wheel_RL': (104, 55, -170), 'Wheel_RR': (-104, 55, -170)}, 56, 26),
    roles=GLASS, budget=16000, wheel_ratio=0.15)


def moto(name, src, rot, scale, budget, cell=0.012):
    if only and name not in only:
        return
    M = Model(src)
    # мелочь (болты, шайбы) — не нужна на телефоне
    keep = []
    for c in M.ch:
        P = c['P'][np.unique(c['I'])]
        if np.linalg.norm(P.max(0) - P.min(0)) * scale > 0.035:
            keep.append(c)
    print(name, 'chunks', len(M.ch), '->', len(keep))
    M.ch = keep
    M.transform(ROT[rot], scale=scale)
    for c in M.ch:
        c['part'] = 'Body'
    import carbuild_dec as CB
    bymat = {}
    for c in M.ch:
        bymat.setdefault(c['mat'], []).append(c['P'][c['I']])
    M.ch = []
    for mi, ts in bymat.items():
        T = np.concatenate(ts)
        T2, _ = CB.decimate(T, None, cell)
        if len(T2):
            M.ch.append({'node': 'Body', 'path': 'Body', 'mat': mi, 'P': T2.reshape(-1, 3), 'UV': None,
                         'I': np.arange(len(T2) * 3).reshape(-1, 3), 'part': 'Body'})
    mn, mx = M.bbox()
    M.shift(np.array([-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2]))
    print(name, 'size', (M.bbox()[1] - M.bbox()[0]).round(2))
    build(M, OUT, name, roles=[(r'blue_paint', 'Paint'), (r'^glass', 'Glass'), (r'red\.001', 'Tail')],
          budget=budget, markers=False)


moto('izh', 'src/izh.glb', 'x+', 2.1 / 282.25, 16000, cell=0.028)
