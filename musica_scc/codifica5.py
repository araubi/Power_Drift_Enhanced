"""Música PSG + SCC para el reproductor de la ROM SCC de Power Drift. Formato por cuadro:
  80h+n   : n cuadros sin cambios (1-127)
  00h,00h : bucle;  00h,01h : fin
  M       : máscara (01h-7Fh). bit 0: sigue P (máscara de PSG de codifica3: bit 0-2 periodos A-C,
            3-5 volúmenes A-C, 6 R6+R7) y sus datos; bits 1-5: periodo del canal SCC 1-5 (2 bytes,
            bajo y alto); bit 6: sigue V (bits 0-4 = volumen del canal SCC 1-5) y esos volúmenes.
La canción empieza con las 4 ondas (128 bytes, canales 1-4; el 5 usa la del 4)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from codifica3 import norm

def codifica(fr, loop, ondas):
    out = bytearray(); prev = None; wait = 0; loopoff = None
    def flush():
        nonlocal wait
        while wait > 0:
            k = min(wait, 127); out.append(0x80 | k); wait -= k
    for i, (psg, sp, sv) in enumerate(fr):
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
        V = 0; dv = bytearray()
        for k in range(5):
            if sv[k] != pv[k]: V |= 1 << k; dv.append(sv[k])
        if V: M |= 64; d.append(V); d += dv
        if M == 0: wait += 1
        else: flush(); out.append(M); out += d
        prev = (r, sp, sv)
    flush(); out += bytes([0, 0])
    cab = bytes((x & 255) for o in ondas for x in o)
    assert len(cab) == 128
    return cab + bytes(out), 128 + (loopoff or 0)

def decodifica(b, loopoff, n):
    reg = [0] * 11; reg[7] = 0x3F; sp = [0] * 5; sv = [0] * 5; p = 128; esp = 0; res = []
    while len(res) < n:
        if esp: esp -= 1; res.append((list(reg), list(sp), list(sv))); continue
        c = b[p]; p += 1
        if c & 0x80: esp = (c & 0x7F) - 1; res.append((list(reg), list(sp), list(sv))); continue
        if c == 0:
            if b[p] == 1: break
            p = loopoff; continue
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
        res.append((list(reg), list(sp), list(sv)))
    return res

if __name__ == '__main__':
    import struct, render
    tot = 0
    for c in sys.argv[1:] or ['90', '92', '93', '94', '95', '96', '97']:
        fr, lazo, ondas = render.render('/root/pd/musica/scc/guiones/PowerDrift_%sh.cfscript.json' % c)
        b, lo = codifica(fr, lazo, ondas)
        chk = decodifica(b, lo, len(fr) + 300)
        want = [(norm(p), list(s), [v & 15 for v in w]) for p, s, w in fr]
        assert chk[:len(fr)] == want, c
        assert chk[len(fr):len(fr) + 300] == (want[lazo:] * 3)[:300], c + ' bucle'
        os.makedirs('/root/pd/musica/scc/mus', exist_ok=True)
        open('/root/pd/musica/scc/mus/%s.mus' % c, 'wb').write(struct.pack('<H', lo) + b)
        tot += len(b); print(c, len(fr), 'cuadros', len(b), 'bytes', flush=True)
    print('total', tot)
