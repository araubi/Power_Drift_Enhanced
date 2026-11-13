"""Guion de ChipForge (el subconjunto que escribe a_scc.py) -> estados por fotograma de 50 Hz:
PSG (registros 0-10) y SCC (periodos y volúmenes de los 5 canales) + las 4 ondas.
Macros: vol 'ataque | bucle / suelta' (sin '|' se queda en el último valor), arp fijo, mode y noise.
Volumen de salida = (columna * macro + 7) // 15, como ChipForge (FORMAT §6.6)."""
import json, math

def parse_vol(s):
    s = s.strip()
    rel = []
    if '/' in s: s, r = s.split('/'); rel = [int(x) for x in r.split()]
    if '|' in s: a, l = s.split('|'); a = [int(x) for x in a.split()]; l = [int(x) for x in l.split()]
    else: a = [int(x) for x in s.split()]; l = []
    return a, l, rel
def seq(s): return [int(x) for x in str(s).split()] if s is not None else []

class Ins:
    def __init__(self, d):
        m = d.get('macros', {})
        self.vol = parse_vol(m.get('vol', '15'))
        arp = m.get('arp'); self.arp = seq(arp['seq']) if arp else []
        self.mode = seq(m.get('mode', '1')); self.noise = seq(m.get('noise'))
        self.wave = d.get('scc', {}).get('wave')
    def v(self, t, rel):
        a, l, r = self.vol
        if rel is not None:
            if not r: return 0
            return r[min(rel, len(r) - 1)]
        if t < len(a): return a[t]
        if l: return l[(t - len(a)) % len(l)]
        return a[-1] if a else 0
def at(lst, t, d):
    return lst[min(t, len(lst) - 1)] if lst else d

NOTAS = {'C-': 0, 'C#': 1, 'D-': 2, 'D#': 3, 'E-': 4, 'F-': 5, 'F#': 6, 'G-': 7, 'G#': 8, 'A-': 9, 'A#': 10, 'B-': 11}
def midi(n): return NOTAS[n[:2]] + 12 * (int(n[2:]) + 1)

def aplana(d):
    """-> lista de filas por canal [(tok...)] y fila del bucle"""
    sub = d['subsongs'][0]; R = sub['rows']; ch = sub['channels']; nch = len(ch)
    filas = [[] for _ in range(nch)]; inicio = []; lazo = None
    for k, fila in enumerate(sub['order']):
        ev = []; largo = R; salto = None
        for c in range(nch):
            pat = ch[c]['patterns'][fila[c]]
            if isinstance(pat, dict): pat = pat['rows']
            e = {}
            for x in pat:
                r, t = x.split(':', 1); r = int(r); tk = t.split()
                e[r] = tk
                for q in tk[3:]:
                    if q[:2] in ('0D', '0B'): largo = min(largo, r + 1); salto = q
            ev.append(e)
        inicio.append(len(filas[0]))
        for r in range(largo):
            for c in range(nch): filas[c].append(ev[c].get(r))
        if salto and salto[:2] == '0B': lazo = int(salto[2:], 16)
    return filas, (inicio[lazo] if lazo is not None else 0)

def render(path):
    d = json.load(open(path)); ins = [Ins(x) for x in d['instruments']]
    filas, lazo = aplana(d); n = len(filas[0]); nch = len(filas)
    st = [dict(ins=None, col=15, m=None, t=0, rel=None) for _ in range(nch)]
    out = []
    for f in range(n):
        for c in range(nch):
            tk = filas[c][f]; s = st[c]
            if not tk: continue
            if tk[0] == 'REL':
                if s['rel'] is None and s['m'] is not None: s['rel'] = 0
            elif tk[0] != '---':
                s['m'] = midi(tk[0]); s['t'] = 0; s['rel'] = None
                if len(tk) > 1 and tk[1] != '..': s['ins'] = int(tk[1], 16)
            if len(tk) > 2 and tk[2] != '..': s['col'] = int(tk[2], 16)
        psg = [0] * 11; mix = 0x3F; ruido = None; scc_p = [0] * 5; scc_v = [0] * 5
        for c in range(nch):
            s = st[c]
            if s['m'] is None or s['ins'] is None:
                continue
            I = ins[s['ins']]; t = s['t']
            mv = I.v(t, s['rel'])
            vol = (s['col'] * mv + 7) // 15
            m = at(I.arp, t, s['m']) if I.arp else s['m']
            fr = 440.0 * 2 ** ((m - 69) / 12)
            if c < 3:
                per = max(1, min(4095, int(round(111860.78 / fr))))
                psg[2 * c] = per & 255; psg[2 * c + 1] = per >> 8
                md = at(I.mode, t, 1)
                if vol and md & 1: mix &= ~(1 << c)
                if vol and md & 2:
                    mix &= ~(8 << c); ruido = at(I.noise, t, 0)
                psg[8 + c] = vol if md else 0
            else:
                per = max(0, min(4095, int(round(111860.78 / fr)) - 1))
                scc_p[c - 3] = per; scc_v[c - 3] = vol
            s['t'] += 1
            if s['rel'] is not None: s['rel'] += 1
        psg[6] = ruido if ruido is not None else (out[-1][0][6] if out else 0)
        psg[7] = mix
        out.append((psg, scc_p, scc_v))
    waves = [w['data'] for w in d['waves']]
    # onda de cada canal SCC 1-4 (el 5 comparte la del 4)
    ondas = []
    for c in range(3, 7):
        k = next((st_i for st_i in range(len(ins)) if False), None)
    usadas = [None] * 4
    for c in range(3, 7):
        for f in range(n):
            tk = filas[c][f]
            if tk and len(tk) > 1 and tk[0] not in ('REL', '---') and tk[1] != '..':
                usadas[c - 3] = ins[int(tk[1], 16)].wave; break
    ondas = [waves[w] if w is not None else [0] * 32 for w in usadas]
    return out, lazo, ondas

if __name__ == '__main__':
    import sys
    fr, lazo, ondas = render(sys.argv[1])
    print(len(fr), lazo, [o[:4] for o in ondas])
    for x in fr[lazo:lazo + 5]: print(x)
