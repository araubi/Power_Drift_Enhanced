"""Power Drift (arcade) -> guion de ChipForge para PSG + SCC (.cfscript.json).
SCC 1 = bajo (muestras PCM tonales), SCC 2-5 = voces FM distintas (sin las que solo doblan a otra),
PSG A = otra voz FM si sobra, PSG B = bombo, PSG C = charles (que también hace de caja).
Una fila = un fotograma de 50 Hz (speed 1). Las ondas SCC salen de los patches del YM2151
(simulación de los 4 operadores con su algoritmo, realimentación, MUL y TL) y la del bajo de la
propia muestra PCM. Requiere los registros de MAME (/root/pd/musica/cXX.log) y la ROM de muestras."""
import sys, os, math, json, collections
sys.path.insert(0, '/root/pd/musica/herr')
import numpy as np
import arregla as AR, ticks, voces, pcm

FILAS = 64
NOM = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']
def nota(m): return NOM[m % 12] + str(m // 12 - 1)

# ---------- onda SCC desde un patch del YM2151 ----------
MODS = {0: {2: [0], 1: [2], 3: [1]}, 1: {1: [0, 2], 3: [1]}, 2: {1: [2], 3: [0, 1]}, 3: {2: [0], 3: [2, 1]},
        4: {2: [0], 3: [1]}, 5: {2: [0], 1: [0], 3: [0]}, 6: {2: [0]}, 7: {}}
OUTS = {0: [3], 1: [3], 2: [3], 3: [3], 4: [2, 3], 5: [1, 2, 3], 6: [1, 2, 3], 7: [0, 1, 2, 3]}
def onda_fm(p):
    """p = (reg20, [reg40 x4], [reg60 x4]) en orden de registro M1, M2, C1, C2 -> 32 valores -128..127"""
    r20, r40, r60 = p
    con = r20 & 7; fb = (r20 >> 3) & 7
    mul = [(x & 15) or 0.5 for x in r40]
    amp = [10 ** (-0.75 * (x & 127) / 20) for x in r60]
    N = 2048; vueltas = 3
    t = np.arange(N * vueltas) / N
    out = {k: np.zeros(N * vueltas) for k in range(4)}
    p1 = p2 = 0.0
    kfb = 4 * math.pi / 2 ** (7 - fb) if fb else 0.0
    for i in range(N * vueltas):
        o = {}
        for k in (0, 2, 1, 3):
            ph = 2 * math.pi * mul[k] * t[i]
            if k == 0: ph += kfb * (p1 + p2) / 2
            ph += 4 * math.pi * sum(o[s] for s in MODS[con].get(k, []))
            o[k] = amp[k] * math.sin(ph)
        p2, p1 = p1, o[0]
        for k in range(4): out[k][i] = o[k]
    y = sum(out[k] for k in OUTS[con])[-N:]
    return a_32(y)
def a_32(y):
    """un periodo cualquiera -> 32 muestras con los armónicos 1-15"""
    sp = np.fft.rfft(y)
    s32 = np.zeros(17, complex); s32[1:16] = sp[1:16]
    w = np.fft.irfft(s32, 32)
    if np.abs(w).max() == 0: return [0] * 32
    w = w / np.abs(w).max() * 127
    return [int(round(max(-128, min(127, x)))) for x in w]
def onda_pcm(k):
    """un periodo medio de una muestra tonal"""
    x = pcm.datos(k); f, cl, cen = pcm.f0(k)
    per = 15625.0 / f; n = len(x)
    a = n // 6; ciclos = int(min(40, (n - a) // per - 1))
    ys = []
    for c in range(ciclos):
        s = a + c * per
        idx = s + np.arange(256) * per / 256
        ys.append(np.interp(idx, np.arange(n), x))
    return a_32(np.mean(ys, axis=0))

# ---------- análisis ----------
def prepara(c):
    cfg = AR.CFG[c]; b = AR.B[c]
    T = ticks.lee('/root/pd/musica/%s.log' % b['log'], tmax=(b['S'] + b['P']) * b['dt'] + 3)
    ton = voces.tonales(T)
    PT, dt = voces.por_tick(T, ton)
    corr = AR.calibra(PT[b['S']:b['S'] + b['P']], ton); corr.update(AR.CORR)
    PT2 = [({s: ((x[0] + corr.get(s.split('.')[0], 0)) if s[0] == 'S' else x[0], x[1], x[2]) for s, x in v.items()}, g)
           for v, g in PT][:b['S'] + b['P']]
    pul = cfg['pulso']; best = None
    for k in (1, 2, 4, 8):
        U = pul * k; xx = U * dt * 50; Fb = round(xx); e = abs(Fb / xx - 1)
        if best is None or e < best[0] - 0.003: best = (e, U, Fb)
    e, U, Fb = best
    on = [i for i, ch, k, d, v in pcm.disparos(T) if v and AR.BAT.get(k[:3])]
    i0 = (on[0] % U) if on else 0
    F = voces.a_fotogramas(PT2, dt, rejilla=(U, Fb, i0))
    lazo = math.floor((b['S'] - i0) * Fb / U + 1e-9) + math.ceil(i0 * Fb / U)
    # patch más usado de cada canal FM (ponderado por ticks con la nota puesta)
    pat = collections.defaultdict(collections.Counter)
    for v, g in PT[:b['S'] + b['P']]:
        pass
    for i, tk in enumerate(T[:b['S'] + b['P']]):
        ym = tk['ym']
        for ch in range(8):
            if 'F%d' % ch in PT[i][0]:
                pat[ch][(ym[0x20 + ch], tuple(ym[0x40 + ch + 8 * s] for s in range(4)),
                         tuple(ym[0x60 + ch + 8 * s] for s in range(4)))] += 1
    patch = {ch: cnt.most_common(1)[0][0] for ch, cnt in pat.items()}
    # muestra tonal más usada como bajo
    usos = collections.Counter()
    for i, ch, k, d, vol in pcm.disparos(T):
        if k in ton: usos['S%X%02X%02X' % (k[0] >> 4, k[1], k[2])] += 1
    claves = {}
    for i, ch, k, d, vol in pcm.disparos(T):
        claves['S%X%02X%02X' % (k[0] >> 4, k[1], k[2])] = k
    return F, lazo, patch, claves, (U, Fb, i0)

def serie(F, s):
    return [(round(v[s][0]), v[s][1], v[s][2]) if s in v else None for v, g in F]
def partes_fm(F):
    """voces FM distintas: se quita la que dobla a otra (mismas notas, misma clase de altura)"""
    S = {s: serie(F, s) for s in ['F%d' % c for c in range(8)]}
    S = {s: x for s, x in S.items() if sum(1 for y in x if y) > len(F) * 0.02}
    att = {s: np.median([y[1] for y in x if y]) for s, x in S.items()}
    act = {s: sum(1 for y in x if y) for s, x in S.items()}
    orden = sorted(S, key=lambda s: (att[s], -act[s]))      # más fuerte primero
    quedan = []
    for s in orden:
        dup = None
        for q in quedan:
            j = [(a, b) for a, b in zip(S[s], S[q]) if a and b]
            if len(j) < 0.8 * act[s]: continue
            igual = sum(1 for a, b in j if a[0] % 12 == b[0] % 12)
            if igual >= 0.9 * len(j): dup = q; break
        if dup is None: quedan.append(s)
    return quedan, S, att, act

def mezcla_bajo(F, fuentes):
    """el bajo como en el arreglo PSG: primera fuente que suene, la más grave"""
    V = AR.voz(F, fuentes, 'bajo')
    out = []
    for i, x in enumerate(V):
        if x is None: out.append(None); continue
        at = min(v[1] for s, v in F[i][0].items() if any(s.startswith(f) for f in fuentes))
        out.append((int(round(x[0])), at, x[1]))
    return out

def vols(V, ref, paso=2.5, minimo=5, extra=0, tope=15):
    return [None if x is None else (x[0], max(minimo, min(tope, 15 + extra - int(round((x[1] - ref) / paso)))), x[2]) for x in V]

def octava_scc(V, lo=33):
    """el SCC no baja de A-1 (periodo de 12 bits): sube una octava lo que quede debajo"""
    return [None if x is None else ((x[0] + 12 * max(0, math.ceil((lo - x[0]) / 12))),) + tuple(x[1:]) for x in V]

def filas_voz(V, ini, fin, ins):
    f = []; prev = None if ini == 0 else V[ini - 1]; vol = None
    for i in range(ini, fin):
        x = V[i]; r = i - ini
        if x is None:
            if prev is not None: f.append('%d: REL' % r)
        else:
            m, v, nv = x
            if prev is None or m != prev[0] or nv:
                f.append('%d: %s %02X %02X' % (r, nota(m), ins, v)); vol = v
            elif vol is not None and abs(v - vol) >= 2:
                f.append('%d: --- .. %02X' % (r, v)); vol = v
        prev = x
    return f

def bateria(F):
    """bombo (PSG B) y charles (PSG C); la caja suena como un charles fuerte; sin toms"""
    K = []; H = []; uk = uh = -99
    for i, (v, g) in enumerate(F):
        cl = set(AR.BAT.get(k[:3]) for k, d, vol in g if vol)
        k = 'bombo' in cl and i - uk >= 2
        h = None
        if 'caja' in cl: h = 'caja'
        elif 'abierto' in cl: h = 'abierto'
        elif 'charles' in cl: h = 'charles'
        if h and i - uh < (2 if h == 'caja' else 4): h = None
        if k: uk = i
        if h: uh = i
        K.append(k); H.append(h)
    return K, H

INS_PSG = [
 dict(name='PSG bombo', chip='psg', macros=dict(arp=dict(seq='57 50 45 40 36 33', fixed=True), vol='15 14 12 9 6 3 0',
      mode='3 1', noise='10')),
 dict(name='PSG charles', chip='psg', macros=dict(vol='13 10 6 3 0', mode='2', noise='1')),
 dict(name='PSG charles fuerte (caja)', chip='psg', macros=dict(vol='15 13 10 7 4 2 0', mode='2', noise='2')),
 dict(name='PSG charles abierto', chip='psg', macros=dict(vol='13 12 10 9 7 5 4 3 2 1 0', mode='2', noise='1')),
 dict(name='PSG voz', chip='psg', macros=dict(vol='13 13 12 | 11 / 8 5 2 0', mode='1')),
]
def filas_bat(K, H, ini, fin, quien, vk=11):
    f = []
    for i in range(ini, fin):
        if quien == 'K' and K[i]: f.append('%d: C-4 00 %02X' % (i - ini, vk))
        if quien == 'H' and H[i]:
            f.append('%d: C-4 %02X %02X' % (i - ini, {'charles': 1, 'caja': 2, 'abierto': 3}[H[i]], 15))
    return f

def guion(c, salida):
    cfg = AR.CFG[c]
    F, lazo, patch, claves, rej = prepara(c)
    n = len(F)
    fm, S, att, act = partes_fm(F)
    # la melodía del arreglo PSG va primero; luego por volumen
    mel = [s for s in cfg['mel'] if s in fm]
    fm = mel + [s for s in fm if s not in mel]
    bajo_src = cfg['bajo']
    if bajo_src[0].startswith('F'):          # 94h: el bajo es una voz FM
        fm = [s for s in fm if s not in bajo_src]
    ref = min(att[s] for s in fm) if fm else 0
    scc_fm = fm[:4]; psg_a = fm[4] if len(fm) > 4 else None
    waves = []; ins = []
    # bajo
    if bajo_src[0].startswith('S'):
        k = claves[bajo_src[0]]; waves.append(dict(name='Bajo (muestra %s)' % bajo_src[0], data=onda_pcm(k)))
    else:
        waves.append(dict(name='Bajo (FM %s)' % bajo_src[0], data=onda_fm(patch[int(bajo_src[0][1])])))
    ins.append(dict(name='SCC bajo', chip='scc', macros=dict(vol='15 15 14 | 13 / 10 7 4 2 0'), scc=dict(wave=0)))
    for j, s in enumerate(scc_fm):
        waves.append(dict(name='FM %s' % s, data=onda_fm(patch[int(s[1])])))
        env = '15 15 14 | 13 / 10 7 4 2 0' if j == 0 else '14 14 13 | 12 / 9 6 3 1 0'
        ins.append(dict(name='SCC %s%s' % ('melodía ' if j == 0 else 'voz ', s), chip='scc',
                        macros=dict(vol=env), scc=dict(wave=len(waves) - 1)))
    # SCC 4 y 5 comparten onda en el SCC original: el 5 usa la del 4
    if len(scc_fm) == 4: ins[4]['scc']['wave'] = ins[3]['scc']['wave']
    base_psg = len(ins)
    ins += INS_PSG
    # voces
    Vb = octava_scc(mezcla_bajo(F, bajo_src))
    refb = np.median([x[1] for x in Vb if x]) if any(Vb) else 0
    m93 = 2 if c == '93' else 0        # la 93h: 2 pasos menos (la melodía empataba con el bajo)
    Vb = vols(Vb, refb, minimo=7, extra=-3 - m93, tope=12 - m93)
    Vs = [vols(octava_scc(S[s]), ref, extra=(1 if j == 0 else -3 - m93), tope=(15 if j == 0 else 11 - m93)) for j, s in enumerate(scc_fm)]
    Va = vols(S[psg_a], ref, extra=-3, tope=11) if psg_a else [None] * n
    Va = [None if x is None else (max(48, x[0]) if x[0] >= 36 else x[0] + 12,) + x[1:] for x in Va]
    K, H = bateria(F)
    FILAS = 128 if n > 250 * 64 else 64
    cortes = [0]
    if lazo % FILAS: cortes.append(lazo % FILAS)
    while cortes[-1] + FILAS < n: cortes.append(cortes[-1] + FILAS)
    cortes.append(n)
    tramos = list(zip(cortes[:-1], cortes[1:]))
    pos_bucle = next(k for k, (a, b) in enumerate(tramos) if a == lazo)
    nombres = ['PSG A · %s' % (('voz ' + psg_a) if psg_a else 'libre'), 'PSG B · Bombo', 'PSG C · Charles (y caja)',
               'SCC 1 · Bajo'] + ['SCC %d · %s' % (j + 2, ('Melodía ' if j == 0 else 'Voz ') + s) for j, s in enumerate(scc_fm)]
    while len(nombres) < 8: nombres.append('SCC %d · libre' % (len(nombres) - 2))
    papel = ['acompanamiento', 'bateria', 'bateria', 'bajo', 'melodia', 'acompanamiento', 'acompanamiento', 'acompanamiento']
    canales = [dict(name=nombres[k], papel=papel[k], fx=1, patterns=[]) for k in range(8)]
    order = []
    for t, (a, b) in enumerate(tramos):
        fl = [filas_voz(Va, a, b, base_psg + 4), filas_bat(K, H, a, b, 'K', 15),
              [x.replace(' 01 ', ' %02X ' % (base_psg + 1)).replace(' 02 ', ' %02X ' % (base_psg + 2)).replace(' 03 ', ' %02X ' % (base_psg + 3)) for x in filas_bat(K, H, a, b, 'H')],
              filas_voz(Vb, a, b, 0)]
        fl[1] = [x.replace(' 00 ', ' %02X ' % base_psg) for x in fl[1]]
        for j in range(4):
            fl.append(filas_voz(Vs[j], a, b, j + 1) if j < len(Vs) else [])
        largo = b - a
        ef = None
        if largo < FILAS: ef = '0D00' if t < len(tramos) - 1 else '0B%02X' % pos_bucle
        elif t == len(tramos) - 1: ef = '0B%02X' % pos_bucle
        if ef:   # el salto va en el canal SCC 1 (bajo), en la última fila del tramo
            ult = largo - 1; ch = 3
            resto = [x for x in fl[ch] if int(x.split(':')[0]) != ult]
            esa = [x for x in fl[ch] if int(x.split(':')[0]) == ult]
            tk = esa[0].split(':', 1)[1].split() if esa else []
            if tk == ['REL']: tk = ['REL']
            while len(tk) < 3: tk.append('---' if not tk else '..')
            fl[ch] = resto + ['%d: %s %s' % (ult, ' '.join(tk[:3]), ef)]
        fila = []
        for k in range(8):
            pats = canales[k]['patterns']
            if fl[k] in pats: fila.append(pats.index(fl[k]))
            else: pats.append(fl[k]); fila.append(len(pats) - 1)
        order.append(fila)
    d = dict(format='chipforge.script', version=1,
             meta=dict(title='Power Drift %sh (SCC)' % c, author='Arreglo SCC (araubi) desde la recreativa'),
             notas=('Power Drift (Sega, 1988), música %sh de la recreativa (YM2151 + SegaPCM, captura de MAME) '
                    'pasada a PSG + SCC. SCC 1 bajo (onda de la muestra PCM), SCC 2-5 voces FM distintas (onda '
                    'calculada del patch FM; las voces que solo doblan a otra se quitan; SCC 4 y 5 comparten onda), '
                    'PSG A otra voz FM si sobra, PSG B bombo, PSG C charles que también hace de caja. '
                    'Una fila por fotograma de 50 Hz.' % c),
             chips=['psg', 'scc'], waves=waves, instruments=ins,
             subsongs=[dict(name='Main', hz=50, speed=1, rows=FILAS, highlight=[8, 32], channels=canales, order=order,
                            sections=([dict(name='intro', start=0, length=pos_bucle)] if pos_bucle else []) +
                                     [dict(name='tema-a', start=pos_bucle, length=len(order) - pos_bucle)])])
    json.dump(d, open(salida, 'w'), ensure_ascii=False, indent=1)
    return dict(fm=fm, scc=scc_fm, psgA=psg_a, bajo=bajo_src, ordenes=len(order), bucle=pos_bucle,
                pats=[len(ch['patterns']) for ch in canales])

if __name__ == '__main__':
    os.makedirs('/root/pd/musica/scc/guiones', exist_ok=True)
    for c in (sys.argv[1:] or ['90', '92', '93', '94', '95', '96', '97']):
        print(c, guion(c, '/root/pd/musica/scc/guiones/PowerDrift_%sh.cfscript.json' % c), flush=True)
