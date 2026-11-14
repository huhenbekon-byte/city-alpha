import sys, os, re, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from conv import Model, build, ROT

OUT = sys.argv[1]
only = sys.argv[2:]


def prop(name, src, rot='z+', scale=1.0, keep=None, drop=None, budget=None, texmax=1024, height=None, center=True,
         roles=(), dec_cell=None):
    """Модель стоит на y=0, центр по XZ в нуле (center=True), перед — +Z."""
    if only and name not in only:
        return
    M = Model(src)
    if keep:
        M.ch = [c for c in M.ch if re.search(keep, c['path'], re.I)]
    if drop:
        M.drop(drop)
    M.transform(ROT[rot], scale=scale)
    if height:
        mn, mx = M.bbox()
        k = height / (mx[1] - mn[1])
        for c in M.ch:
            c['P'] = c['P'] * k
    for c in M.ch:
        c['part'] = 'Body'
    if dec_cell:
        import carbuild_dec as CB
        new = []
        for c in M.ch:
            T = c['P'][c['I']]
            UV = c['UV'][c['I']] if c['UV'] is not None else None
            T2, UV2 = CB.decimate(T, UV, dec_cell)
            if len(T2):
                new.append({'node': c['node'], 'path': c['path'], 'mat': c['mat'], 'P': T2.reshape(-1, 3),
                            'UV': UV2.reshape(-1, 2) if UV2 is not None else None, 'I': np.arange(len(T2) * 3).reshape(-1, 3), 'part': 'Body'})
        M.ch = new
    mn, mx = M.bbox()
    M.shift(np.array([-(mn[0] + mx[0]) / 2 if center else 0, -mn[1], -(mn[2] + mx[2]) / 2 if center else 0]))
    mn, mx = M.bbox()
    print(name, 'size', (mx - mn).round(2))
    build(M, OUT, name, roles=list(roles), budget=budget, markers=False, texmax=texmax)


prop('bus_stop', 'src/busstop.glb', 'x+', 0.0146, texmax=512)
prop('soda', 'src/soda1.glb', 'z+', 1.0, texmax=512)
prop('soda2', 'src/soda2.glb', 'z+', 1.7 / 10.39, texmax=512)
prop('trash', 'src/trash.glb', 'z+', 1.0, texmax=512, budget=2500)
prop('pivnaya', 'src/pivnaya.glb', 'z+', 1.0, texmax=1024)
prop('kiosk_rail', 'src/kiosk_rail.glb', 'z+', 1.0, texmax=1024)
prop('playground', 'src/playground.glb', 'z+', 1.0, texmax=1024)
prop('garages', 'src/garages.glb', 'z+', 1.0, texmax=1024, budget=6000)
prop('el_pole', 'src/lights.glb', 'z+', 1.0, keep=r'pillar_02', texmax=512)
prop('khrush5', 'src/khrush5.glb', 'z+', 1.0, texmax=1024)
prop('stalinka', 'src/stalinka.glb', 'z+', 1.0, keep=r'Object013', texmax=1024)
