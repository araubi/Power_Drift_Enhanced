"""ChipForge neutro (nivel escrituras, PSG completo) -> estados por cuadro para codifica6.
Estado: (psg[0..10], scc_p[5], scc_v[5] (0 si la tecla está suelta), ondas[4] (tuplas de 32))."""
import json
def estados(path):
    j = json.load(open(path)); e = j['subcanciones'][0]['escrituras']
    assert e['hz'] == 50, e['hz']
    ch = {c['tipo']: c for c in e['chips']}
    psg = [0] * 16; psg[7] = 0x3F; scc = [0] * 256
    for r, v in ch['psg']['inicio']: psg[r] = v
    for r, v in ch['scc']['inicio']: scc[r] = v
    def foto():
        on = scc[0x8F]
        sp = [scc[0x80 + 2*k] | (scc[0x81 + 2*k] & 15) << 8 for k in range(5)]
        sv = [(scc[0x8A + k] & 15) if on >> k & 1 else 0 for k in range(5)]
        on_ = [tuple((x if x < 128 else x - 256) for x in scc[32*s:32*s+32]) for s in range(4)]
        return (psg[:11], sp, sv, on_)
    def seccion(nombre):
        secs = {c['tipo']: c[nombre] for c in e['chips']}
        if secs['psg'] is None: return []
        n = secs['psg']['fotogramas']; assert secs['scc']['fotogramas'] == n
        por = {}
        for t, s in secs.items():
            f = 0
            for esp, pares in s['grupos']:
                f += esp; por.setdefault(f, []).append((t, pares))
        out = []
        for f in range(n):
            for t, pares in por.get(f, []):
                for r, v in pares:
                    if t == 'psg': psg[r] = v
                    else: scc[r] = v
            out.append(foto())
        return out
    intro = seccion('intro'); bucle = seccion('bucle')
    return intro + bucle, (len(intro) if bucle else None), e
if __name__ == '__main__':
    import sys
    for p in sys.argv[1:]:
        fr, lazo, e = estados(p)
        ondas = set(); sub = [0]*4; dist = [set() for _ in range(4)]
        for i in range(1, len(fr)):
            for s in range(4):
                if fr[i][3][s] != fr[i-1][3][s]: sub[s] += 1; dist[s].add(fr[i][3][s])
        print(p.split('/')[-1], len(fr), 'cuadros, bucle', lazo, 'fin', e['fin'], 'subidas', sub, 'distintas', [len(d) for d in dist])
