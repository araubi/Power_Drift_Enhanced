#!/usr/bin/env python3
# Power Drift (MSX1): monta la ROM optimizada ASCII16 de 512 KB (v3: con música) desde los fuentes.
#   python3 build_rom.py  -> PowerDrift_SCC.rom (reloj de la carrera en tiempo real)
# Necesita el desensamblado (../desensamblado: juego.asm, pantalla.asm, ladoB.asm) y los datos del
# juego sacados de la cinta del usuario con ../tools/extrae_originales.py (../originales).
# El desensamblado publicado no lleva los datos: cada DB va como DS n,RELLENO; aquí se ensambla dos
# veces (RELLENO 00h y FFh), lo que cambia son los huecos y se rellenan con los bytes de la cinta.
# Ensambla con sjasmplus (variable SJASMPLUS o en el PATH) o con pasmo. Licencia MIT.
import os, sys, re, subprocess, shutil
AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTES = os.environ.get('PD_FUENTES') or os.path.join(AQUI, '..', 'desensamblado')
ORIG = os.environ.get('PD_ORIGINALES') or os.path.join(AQUI, '..', 'originales')
SJ = os.environ.get('SJASMPLUS') or shutil.which('sjasmplus')
os.chdir(AQUI)

def ensambla(texto, nombre, simbolos=False):
    src = '_' + nombre + '.asm'; out = '_' + nombre + '.bin'; sym = '_' + nombre + '.sym'
    open(src, 'w').write(texto)
    if SJ:
        cmd = [SJ, '--nologo', '--msg=err', '--raw=' + out, src] + (['--sym=' + sym] if simbolos else [])
    else:
        cmd = ['pasmo', '--bin', src, out] + ([sym] if simbolos else [])
    subprocess.run(cmd, check=True)
    d = open(out, 'rb').read()
    s = {}
    if simbolos:
        for l in open(sym):
            m = re.match(r'\s*(\w+):?\s+EQU\s+(?:0x)?([0-9A-Fa-f]+)H?\s*$', l)
            if m: s[m.group(1)] = int(m.group(2), 16)
    for f in (src, out, sym):
        if os.path.exists(f): os.remove(f)
    return d, s

def org_de(texto):            # dirección más baja con ORG (pasmo empieza el binario ahí)
    return min(int(m.group(1).rstrip('hH'), 16) for m in re.finditer(r'^\s*ORG\s+0?([0-9A-Fa-f]+h?)', texto, re.M | re.I))

def con_datos(texto, nombre, original, simbolos=False):
    # ensambla el desensamblado y pone los datos del juego (de la cinta del usuario) en los huecos
    if 'RELLENO' not in texto: return ensambla(texto, nombre, simbolos)
    a, s = ensambla('RELLENO EQU 0\n' + texto, nombre, simbolos)
    b, _ = ensambla('RELLENO EQU 0FFh\n' + texto, nombre)
    o = open(os.path.join(ORIG, original), 'rb').read()
    assert len(a) == len(b) == len(o), (nombre, len(a), len(o))
    return bytes(o[i] if a[i] != b[i] else a[i] for i in range(len(a))), s

# 1. el juego (variante de la cinta TSX: CAS EQU 0) y los otros bloques
juego, sj = con_datos('CAS EQU 0\n' + open(os.path.join(FUENTES, 'juego.asm')).read(), 'juego', 'juego.bin', True)
assert len(juego) == 65000
pant, _ = con_datos(open(os.path.join(FUENTES, 'pantalla.asm')).read(), 'pant', 'pantalla.bin')
cabezas, _ = con_datos(open(os.path.join(FUENTES, 'ladoB.asm')).read(), 'ladob', 'ladoB.bin')
assert len(pant) == 7200 and len(cabezas) == 6720
with open('juego_sim.inc', 'w') as f:
    for k, v in sorted(sj.items()):
        if not re.match(r'L[0-9A-F]{4}$', k) and k != 'CAS':
            f.write('J_%s EQU 0%04Xh\n' % (k, v))
pon = open('pon_slot.asm').read()
LIMITES = {'SEC52': 0x6139, 'SEC51': 0x0500, 'SEC43': 0x1084, 'SEC42': 0xBCC1, 'SEC40': 0xA49A, 'SEC41': 0xA65A, 'SEC22': 0x9895, 'SEC23': 0x1084, 'SEC24': 0xA49A, 'SEC0': 0x01DD, 'SEC27': 0x116B, 'SEC39': 0x12DF, 'SEC28': 0xA632, 'SEC67': 0xFFE5, 'SEC23': 0x1076, 'SEC24': 0xA461}

def sprites_cabezas(cab):
    """(v2) Cabezas de la cara 2 (12 pilotos x 5 dibujos de 32x14, pares máscara/dibujo) ->
    por piloto 10 dibujos (5 y su espejo) x 4 sprites de 16x16 (negro izq., negro der.,
    amarillo izq., amarillo der.). Negro = tinta 1 (con cualquier máscara: el juego hace fondo AND máscara OR tinta); amarillo = máscara 0 y tinta 0,
    salvo el reborde (los que tocan la máscara 1 o el borde)."""
    out = bytearray()
    for p in range(12):
        for espejo in (0, 1):
            for k in range(5):
                b = cab[p * 560 + k * 112: p * 560 + k * 112 + 112]
                M = [[1] * 32 for _ in range(14)]; D = [[0] * 32 for _ in range(14)]
                for y in range(14):
                    for x in range(4):
                        m, d = b[y * 8 + x * 2], b[y * 8 + x * 2 + 1]
                        for bit in range(8):
                            M[y][x * 8 + bit] = (m >> (7 - bit)) & 1; D[y][x * 8 + bit] = (d >> (7 - bit)) & 1
                if espejo:
                    M = [r[::-1] for r in M]; D = [r[::-1] for r in D]
                def m1(y, x): return not (0 <= y < 14 and 0 <= x < 32) or M[y][x]
                neg = [[0] * 32 for _ in range(16)]; ama = [[0] * 32 for _ in range(16)]
                for y in range(14):
                    for x in range(32):
                        if D[y][x]: neg[y][x] = 1          # (v4) tinta = negro aunque la máscara sea 1
                        elif M[y][x]: continue
                        elif not (m1(y - 1, x) or m1(y + 1, x) or m1(y, x - 1) or m1(y, x + 1)): ama[y][x] = 1
                for img in (neg, ama):
                    for x0 in (0, 16):
                        pat = bytearray()
                        for half in (0, 8):
                            for y in range(16):
                                v = 0
                                for bit in range(8): v = v << 1 | img[y][x0 + half + bit]
                                pat.append(v)
                        out += pat
    assert len(out) == 12 * 1280
    return bytes(out)

CANCIONES = ('90', '92', '93', '94', '95', '96', '97')   # menú, etapas 1-5 y extra
IGUAL_QUE = {'94': '92'}   # (v12, araubi 13-11) la etapa 3 suena con la música de la etapa 1
TAM_ROM = 0x80000
def musica():
    """(v3) Bancos 6 en adelante: tabla (por canción: banco, puntero, banco y puntero del
    bucle; 6 bytes) y las canciones de musica/*.mus (4 bytes (v6) con el desplazamiento del bucle
    y los datos de codifica3), una detrás de otra, vistas en 4000h-7FFFh."""
    lector, _ = ensambla(open('musica.asm').read(), 'musica')
    assert len(lector) == 0x500, len(lector)
    POR = 0x4000 - 0x500                      # datos por banco (4500h-7FFFh)
    def pos(o): return bytes([6 + o // POR]) + (0x4500 + o % POR).to_bytes(2, 'little')
    datos = bytearray(); tabla = bytearray(); base = 6 * len(CANCIONES)
    hecho = {}
    for c in CANCIONES:
        if c in IGUAL_QUE:                    # (v12) usa la entrada de otra canción
            tabla += hecho[IGUAL_QUE[c]]; continue
        m = open(os.path.join(AQUI, 'musica', c + '.mus'), 'rb').read()
        lazo = int.from_bytes(m[:2], 'little'); ini = base + len(datos)
        hecho[c] = pos(ini) + pos(ini + lazo)
        tabla += hecho[c]; datos += m[2:]
    b = bytearray(tabla + datos)
    b += bytes([0x32, 0x00, 0x90]) * ((-len(b) % POR) // 3 + 1)
    b = b[:len(b) - len(b) % POR]
    return b''.join(lector + b[i:i + POR] for i in range(0, len(b), POR))

def variante(reloj):
    txt = open('residente.asm').read().replace(';@@PON_SLOT', pon.replace('@', ''))
    txt = 'RELOJ EQU %d\n' % reloj + txt
    binr, s = ensambla(txt, 'residente', True)
    base = 0                                  # pasmo/sjasmplus --raw empiezan en el primer ORG (0000h)
    ram = bytearray(65536)
    ram[0x1FD:0x1FD + 65000] = juego
    bajo = None
    for k in sorted((k for k in s if re.match(r'SEC\d+$', k)), key=lambda k: int(k[3:])):
        a, b = s[k], s['FIN' + k[3:]]
        if k in LIMITES: assert b <= LIMITES[k], '%s no cabe: %04X > %04X' % (k, b, LIMITES[k])
        trozo = binr[a - base:b - base]
        if k == 'SEC0':
            bajo = trozo + bytes(0x1FD - len(trozo))
        else:
            ram[a:b] = trozo
    print({k: hex(v) for k, v in s.items() if k.startswith('FIN') or k in ('H_MENU','MUS_EMPIEZA','MUS_TICK','INT_MUS','VBL_VISTO','MT_2','MUS_CALLA')}) if os.environ.get('VERFIN') else None
    assert (s['M_REG'] & 0xFF) <= 0xF5        # musica.asm suma el registro solo al byte bajo
    open('bajo.bin', 'wb').write(bajo)
    with open('residente_sim.inc', 'w') as f:
        for k in ('COPIADOR', 'PON_SLOT', 'M_REG', 'CAB_REQ', 'MEZCLA', 'B_OP1', 'B_R1', 'B_OP2', 'B_R2'):
            f.write('%s EQU 0%04Xh\n' % (k, s[k]))
    for m in (0, 1):
        v, _ = ensambla('MSX2 EQU %d\nVBL_VISTO EQU 0%04Xh\n' % (m, s['VBL_VISTO']) + open('vuelca.asm').read(), 'vuelca')
        assert len(v) <= 0xA7, 'volcado: %d bytes' % len(v)
        open('vuelca%d.bin' % (m + 1), 'wb').write(v + bytes(0xA7 - len(v)))
    open('pant.bin', 'wb').write(pant)
    open('cabezas.bin', 'wb').write(cabezas)
    # (OCM) marcas para DETECTA: byte DET_OFS del banco 3 de 16 KB (ROM C000h+k), de la página 3
    # de 8 KB (ROM 6000h+k) y de la cabecera (ROM k: lo que se ve si nada cambia)
    cab = b'AB'
    k = next(k for k in range(2) if len({ram[0x8000 + k], ram[0x2000 + k], cab[k]}) == 3)
    marcas = 'DET_OFS EQU %d\nMARCA_A16 EQU %d\nMARCA_8K3 EQU %d\n' % (k, ram[0x8000 + k], ram[0x2000 + k])
    print(marcas.replace('\n', ' '))
    r0 = marcas + open('rom0.asm').read().replace(';@@B_PON_SLOT', pon.replace('@', 'B_'))
    banco0, _ = ensambla(r0, 'rom0')
    assert len(banco0) == 0x4000, len(banco0)
    # relleno de los bancos 5-7 y del hueco 0000h-01FCh del banco 1: LD (9000h),A (Konami SCC)
    # para que openMSX y BlueMSX reconozcan ASCII16 (ver lecciones/LECCIONES_MAPPER_BLUEMSX.md)
    relleno = bytes([0x32, 0x00, 0x90]) * 5462
    rom = bytearray(banco0)
    p0 = bytearray(ram[0:0x4000]); p0[0:0x1FD] = relleno[:0x1FD]
    rom += p0 + ram[0x4000:0x8000] + ram[0x8000:0xC000] + ram[0xC000:0x10000]
    spr = sprites_cabezas(cabezas)
    rom += spr + relleno[:0x4000 - len(spr)]
    rom += musica()             # necesita residente_sim.inc
    # (v9) banco 31: el lector y los dibujos 4 de las cabezas de los 12 pilotos (CARTELES)
    lector, _ = ensambla(open('musica.asm').read(), 'musica')
    assert len(rom) <= 31 * 0x4000, 'la música llega al banco 31'
    while len(rom) < 31 * 0x4000: rom += relleno[:0x4000]
    ico = b''.join(cabezas[p * 560 + 448: p * 560 + 560] for p in range(12))
    b31 = lector + ico
    rom += b31 + relleno[:0x4000 - len(b31)]
    while len(rom) < TAM_ROM: rom += relleno[:0x4000]
    assert len(rom) == TAM_ROM
    for f in ('bajo.bin', 'vuelca1.bin', 'vuelca2.bin', 'pant.bin', 'cabezas.bin', 'residente_sim.inc'):
        os.remove(f)
    return bytes(rom), ram

if __name__ == '__main__':
    # (v10) solo la de tiempo real (araubi, 13-11-2026); variante(0) sigue haciendo la del reloj original
    for reloj, nombre in ((1, 'PowerDrift_SCC.rom'),):
        rom, _ = variante(reloj)
        open(nombre, 'wb').write(rom)
        print(nombre, len(rom), 'bytes')
    os.remove('juego_sim.inc')
