#!/usr/bin/env python3
# Músicas para el reproductor de 3 canales (v11). Estados por tick de 1/50 s (registros 0-10 del PSG)
# -> bytes. Formato:
#   80h+n     : n ticks (1-127) sin cambios
#   00h,00h   : bucle (vuelve al punto de bucle de la canción);  00h,01h : fin (se calla)
#   máscara   : bit 0 periodo A (2 bytes), 1 periodo B (2), 2 periodo C (2), 3 vol. A, 4 vol. B,
#               5 vol. C, 6 ruido (R6) y mezclador (R7, solo bits 0-5): 2 bytes
# Devuelve (bytes, desplazamiento del bucle).
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import frames as FR
except ImportError:
    FR = None

def norm(r):
    r = list(r[:11])
    r[1] &= 15; r[3] &= 15; r[5] &= 15; r[6] &= 31; r[7] &= 0x3F
    for k in (8, 9, 10): r[k] &= 15          # sin envolvente
    return r

def codifica(fr, loop=None, fin=False):
    out = bytearray(); prev = None; wait = 0; loopoff = None
    def flush():
        nonlocal wait
        while wait > 0:
            k = min(wait, 127); out.append(0x80 | k); wait -= k
    for i, r in enumerate(fr):
        r = norm(r)
        if i == loop:
            flush(); loopoff = len(out); prev = None    # en el bucle se escribe todo
        if prev is None: prev = [-1] * 11
        m = 0; d = bytearray()
        if r[0:2] != prev[0:2]: m |= 1; d += bytes(r[0:2])
        if r[2:4] != prev[2:4]: m |= 2; d += bytes(r[2:4])
        if r[4:6] != prev[4:6]: m |= 4; d += bytes(r[4:6])
        if r[8] != prev[8]: m |= 8; d.append(r[8])
        if r[9] != prev[9]: m |= 16; d.append(r[9])
        if r[10] != prev[10]: m |= 32; d.append(r[10])
        if r[6:8] != prev[6:8]: m |= 64; d += bytes(r[6:8])
        if m == 0: wait += 1
        else: flush(); out.append(m); out += d
        prev = r
    flush()
    out += bytes([0, 1 if fin else 0])
    return bytes(out), (loopoff if loopoff is not None else 0)

def decodifica(b, loopoff, n):
    """simula el reproductor: n ticks -> estados (para comprobar)"""
    reg = [0] * 11; reg[7] = 0x3F; p = 0; esp = 0; res = []
    while len(res) < n:
        if esp: esp -= 1; res.append(list(reg)); continue
        c = b[p]; p += 1
        if c & 0x80: esp = (c & 0x7F) - 1; res.append(list(reg)); continue
        if c == 0:
            if b[p] == 1: break
            p = loopoff; continue
        if c & 1: reg[0], reg[1] = b[p], b[p+1]; p += 2
        if c & 2: reg[2], reg[3] = b[p], b[p+1]; p += 2
        if c & 4: reg[4], reg[5] = b[p], b[p+1]; p += 2
        if c & 8: reg[8] = b[p]; p += 1
        if c & 16: reg[9] = b[p]; p += 1
        if c & 32: reg[10] = b[p]; p += 1
        if c & 64: reg[6], reg[7] = b[p], b[p+1]; p += 2
        res.append(list(reg))
    return res

def desde_v6(b):
    """formato de la v6 (2 canales, Amiga) -> estados por tick (C callado) y bucle al principio"""
    reg = [0] * 11; reg[7] = 0x18; p = 0; res = []
    while True:
        c = b[p]; p += 1
        if c & 0x80:
            for _ in range((c & 0x7F) + 1): res.append(list(reg))
            continue
        if c == 0x40: break
        if c & 1: reg[0], reg[1] = b[p], b[p+1]; p += 2
        if c & 2: reg[8] = b[p]; p += 1
        if c & 4: reg[2], reg[3] = b[p], b[p+1]; p += 2
        if c & 8: reg[9] = b[p]; p += 1
        if c & 16:
            a = b[p]; p += 1
            if a & 0x80: reg[6] = a & 31; reg[7] = 0x0A
            else: reg[7] = 0x18
        res.append(list(reg))
    return res

if __name__ == '__main__':
    M = '/root/mus'; S = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'musica')
    canciones = []
    for n in ('title', 'hiscore'):
        fr = desde_v6(open(os.path.join(S, n + '.psg'), 'rb').read())
        canciones.append((n, fr, 0, False))
    for n, f in (('nivel1', '02_Stages_1__6'), ('nivel3', '04_Stage_3'), ('nivel4', '05_Stage_4'), ('gameover', '09_Game_Over')):
        fr, lp = FR.vgm(os.path.join(M, f + '.vgm'))
        canciones.append((n, fr, lp, n == 'gameover'))
    for n, f in (('nivel2', 'opening'), ('jefe', 'boss')):
        fr, ts = FR.olog2(os.path.join(M, f + '.log'))
        S0, P = {'nivel2': (1, 4930), 'jefe': (1, 2560)}[n]   # bucles hallados con frames.bucle()
        canciones.append((n, fr[S0:S0 + P], 0, False))
    tot = 0
    for n, fr, lp, fin in canciones:
        b, lo = codifica(fr, lp, fin)
        chk = decodifica(b, lo, len(fr) + 300)
        L = len(fr)
        assert [norm(x) for x in fr] == chk[:L], n
        if not fin:
            P = L - lp
            assert chk[L:L + 300] == [norm(x) for x in (fr[lp:] * 3)][:300], n + ' bucle'
        open(os.path.join(S, n + '.p3'), 'wb').write(b); open(os.path.join(S, n + '.lazo'), 'w').write(str(lo)); tot += len(b)
        print('%-9s %6d ticks %6.1f s bucle %5d -> %6d bytes' % (n, L, L / 50, lp, len(b)))
    print('total', tot)
