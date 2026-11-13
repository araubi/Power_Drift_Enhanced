"""(SCC v6) Música PSG + SCC con la guitarra de ChipForge en el canal SCC 2 (melodía).
Formato de codifica5 y además, en el byte V (volúmenes SCC), bit 7 = nota nueva de la guitarra.
El bend, el vibrato y el paso de la onda de púa a la saturada (morph) los hace el reproductor
(GUITARRA en musica.asm) con las tablas de la «guitarra saturada de solo» de fábrica de ChipForge
(scc-lead-guitarra-solo): en los datos el periodo del SCC 2 es el de la nota (sin bend ni vibrato).
El PSG sale de la música anterior (.mus de codifica5); el SCC, de la traza de ChipForge (formato neutro,
nivel escrituras) del guion con la guitarra. CC BY-NC-SA 4.0 (araubi / Claude)."""
import sys, os, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import neutro, codifica5
from codifica3 import norm

# macro de altura relativa de la guitarra (unidades = periodo SCC, con el signo al revés) y su bucle
PITCH = [-16, 2, 2, 2, 2, 2, 2, 2, 2] + [0] * 16 + [2, 2, 2, 2, 1, -1, -2, -2, -2, -2]
LOOP = 25
OFFS = [-sum(PITCH[:t + 1]) for t in range(len(PITCH))]    # periodo = nota + OFFS[t]
NMORPH = 9

def sig(t): return t + 1 if t + 1 < len(PITCH) else LOOP

def estructura(b, lo):
    p = 128; n = 0; nl = None
    while True:
        if p == lo: nl = n
        x = b[p]; p += 1
        if x & 0x80: n += x & 0x7F; continue
        if x == 0: return n, nl
        if x & 1:
            P = b[p]; p += 1; p += sum((2, 2, 2, 1, 1, 1, 2)[k] for k in range(7) if P >> k & 1)
        p += 2 * bin(x & 0x3E).count('1')
        if x & 64:
            V = b[p]; p += 1 + bin(V & 31).count('1')
        n += 1

def estados(neu, mus_viejo, tabla):
    """-> cuadros (psg, sp, sv, nota_nueva) con sp[1] = periodo de la nota, el bucle, la cabecera y
    los cuadros de la traza (para comprobar)"""
    fr, _, e = neutro.estados(neu)
    fr = [(a, b_, c, d[1]) for a, b_, c, d in fr]      # solo la onda del canal SCC 2
    m = open(mus_viejo, 'rb').read(); lo = struct.unpack('<H', m[:2])[0]; b = m[2:]
    n, lazo = estructura(b, lo); fr = fr[:n]
    dec = codifica5.decodifica(b, lo, n)
    cab = [list(b[32*k:32*k+32]) for k in range(4)]
    cab[1] = [x & 255 for x in tabla[0]]
    out = []; t = None; base = 0
    for i, (d, f) in enumerate(zip(dec, fr)):
        w = tabla.index(f[3]) if any(f[3]) else None
        nueva = False
        if w == 0:
            esperado = (base + OFFS[sig(t)]) if t is not None else None
            wprev = tabla.index(fr[i-1][3]) if i and any(fr[i-1][3]) else None
            if wprev != 0 or f[1][1] != esperado or t is None:
                nueva = True; t = 0; base = f[1][1] - OFFS[0]
            else: t = sig(t)
        elif t is not None: t = sig(t)
        sp = list(f[1]); sp[1] = base if t is not None else sp[1]
        out.append((d[0], sp, f[2], nueva))
    return out, lazo, cab, fr

def codifica(fr, loop, cab):
    out = bytearray(); prev = None; wait = 0; loopoff = None
    def flush():
        nonlocal wait
        while wait > 0:
            k = min(wait, 127); out.append(0x80 | k); wait -= k
    for i, (psg, sp, sv, nueva) in enumerate(fr):
        r = norm(psg); sp = list(sp); sv = [v & 15 for v in sv]
        if i == loop: flush(); loopoff = len(out); prev = None
        if prev is None: prev = ([-1] * 11, [-1] * 5, [-1] * 5)
        pr, pp, pv = prev
        P = 0; dp = bytearray()
        if r[0:2] != pr[0:2]: P |= 1; dp += bytes(r[0:2])
        if r[2:4] != pr[2:4]: P |= 2; dp += bytes(r[2:4])
        if r[4:6] != pr[4:6]: P |= 4; dp += bytes(r[4:6])
        if r[8] != pr[8]: P |= 8; dp.append(r[8])
        if r[9] != pr[9]: P |= 16; dp.append(r[9])
        if r[10] != pr[10]: P |= 32; dp.append(r[10])
        if r[6:8] != pr[6:8]: P |= 64; dp += bytes(r[6:8])
        M = 0; d = bytearray()
        if P: M |= 1; d.append(P); d += dp
        for k in range(5):
            if sp[k] != pp[k]: M |= 2 << k; d += bytes([sp[k] & 255, sp[k] >> 8])
        V = 0x80 if nueva else 0; dv = bytearray()
        for k in range(5):
            if sv[k] != pv[k]: V |= 1 << k; dv.append(sv[k])
        if V: M |= 64; d.append(V); d += dv
        if M == 0: wait += 1
        else: flush(); out.append(M); out += d
        prev = (r, sp, sv)
    flush(); out += bytes([0, 0])
    hdr = bytes((x & 255) for o in cab for x in o)
    return hdr + bytes(out), 128 + (loopoff or 0)

def decodifica(b, loopoff, n):
    """estados como los deja el reproductor: periodo del SCC 2 con bend y vibrato, y la onda (0-8)"""
    reg = [0] * 11; reg[7] = 0x3F; sp = [0] * 5; sv = [0] * 5; p = 128; esp = 0; res = []; t = None
    while len(res) < n:
        if esp: esp -= 1
        else:
            c = b[p]; p += 1
            if c == 0: p = loopoff; continue
            if c & 0x80: esp = (c & 0x7F) - 1
            else:
                if c & 1:
                    P = b[p]; p += 1
                    if P & 1: reg[0], reg[1] = b[p], b[p+1]; p += 2
                    if P & 2: reg[2], reg[3] = b[p], b[p+1]; p += 2
                    if P & 4: reg[4], reg[5] = b[p], b[p+1]; p += 2
                    if P & 8: reg[8] = b[p]; p += 1
                    if P & 16: reg[9] = b[p]; p += 1
                    if P & 32: reg[10] = b[p]; p += 1
                    if P & 64: reg[6], reg[7] = b[p], b[p+1]; p += 2
                for k in range(5):
                    if c & (2 << k): sp[k] = b[p] | (b[p+1] << 8); p += 2
                if c & 64:
                    V = b[p]; p += 1
                    for k in range(5):
                        if V & (1 << k): sv[k] = b[p]; p += 1
                    if V & 0x80: t = 0
        real = list(sp); onda = None
        if t is not None:
            real[1] = sp[1] + OFFS[t]; onda = min(t, NMORPH - 1); t = sig(t)
        res.append((list(reg), real, list(sv), onda))
    return res

if __name__ == '__main__':
    neu, vie, sal = sys.argv[1:4]
    CANC = ['90', '92', '93', '94', '95', '96', '97']
    tabla = []
    for c in CANC:
        fr, _, _ = neutro.estados(os.path.join(neu, 'PowerDrift_%sh.neutro.json' % c))
        for f in fr:
            if any(f[3][1]) and f[3][1] not in tabla: tabla.append(f[3][1])
    assert len(tabla) == NMORPH
    os.makedirs(sal, exist_ok=True); tot = 0
    for c in CANC:
        fr, lazo, cab, traza = estados(os.path.join(neu, 'PowerDrift_%sh.neutro.json' % c), os.path.join(vie, '%s.mus' % c), tabla)
        b, lo = codifica(fr, lazo, cab)
        chk = decodifica(b, lo, len(fr))
        mal = [0, 0, 0]; son = 0
        for i, (d, f) in enumerate(zip(chk, traza)):
            assert d[0] == norm(fr[i][0]), (c, i, 'psg')
            assert [v & 15 for v in d[2]] == [v & 15 for v in f[2]], (c, i, 'vol')
            for k in (0, 2, 3, 4): assert d[1][k] == f[1][k] or not (f[2][k] & 15), (c, i, 'per', k)
            if f[2][1] & 15:
                son += 1
                if d[1][1] != f[1][1]: mal[0] += 1
                if any(f[3]) and d[3] != tabla.index(f[3]): mal[1] += 1
        open(os.path.join(sal, '%s.mus' % c), 'wb').write(struct.pack('<H', lo) + b)
        tot += len(b); print(c, len(fr), 'cuadros', len(b), 'bytes; guitarra sonando', son, 'cuadros; distintos de ChipForge: periodo', mal[0], 'onda', mal[1])
    with open(os.path.join(sal, 'guitarra.inc'), 'w') as f:
        f.write('; (SCC v6) Guitarra saturada de solo (ChipForge, sonido de fábrica scc-lead-guitarra-solo)\n')
        f.write('G_NONDAS\tEQU %d\nG_LARGO\tEQU %d\nG_BUCLE\tEQU %d\n' % (NMORPH, len(PITCH), LOOP))
        f.write('G_OFFS:\t; periodo = nota + G_OFFS[t]\n\tDB ' + ','.join('%d' % (x & 255) for x in OFFS) + '\n')
        f.write('G_ONDAS:\t; de la púa a la saturada, una por cuadro\n')
        for o in tabla: f.write('\tDB ' + ','.join('%d' % (x & 255) for x in o) + '\n')
    print('total', tot)
