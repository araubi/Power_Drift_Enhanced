#!/usr/bin/env python3
# Power Drift (MSX, Activision 1989): saca de la cinta del usuario los datos del juego que el
# desensamblado publicado no lleva, y los deja en ../originales:
#   juego.bin    (65000 bytes, memoria 01FDh-FFE4h: los seis bloques turbo de la cara A)
#   pantalla.bin (7200 bytes, la pantalla de carga de la cara A)
#   ladoB.bin    (6720 bytes, el bloque de la cara B: cabezas de los pilotos)
# Uso: python3 extrae_originales.py <cara A (.cas o .tsx)> <cara B (.cas o .tsx)>
# Vale para la cinta inglesa (.cas «GB») y para los .tsx de la edición española (MCM). Comprueba
# los bloques con su suma (XOR) y la imagen con su SHA-1. Licencia MIT (araubi, 2026).
import os, sys, hashlib
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import tsx2
H = bytes([0x1F, 0xA6, 0xDE, 0xBA, 0xCC, 0x13, 0x7D, 0x74])
LARGOS = {7200: 'pantalla', 10000: 'juego', 15000: 'juego', 6720: 'ladoB'}
# SHA-1 conocidos (la cinta .cas lleva el cargador cambiado: el código difiere en unos bytes,
# los datos que se usan son los mismos)
SHA = {'juego.bin': ('634c10de0804782b9a9fa02aa93d4ed2dd8d358b',    # .cas inglesa (GB)
                     'a642d1250475b9d24ba096e4795fadbcdaee77fd'),   # .tsx españoles (MCM)
       'pantalla.bin': ('a032f65d6899f48b2b4b49f6395f72169b62b8ac',),
       'ladoB.bin': ('5ff08ab3b108b05f39d613d4d88b62711ce34dfe',)}

def bloques_crudos(datos):
    if datos[:7] == b'ZXTape!':
        return [b for i, b, _ in tsx2.bloques(datos) if i in (0x10, 0x11, 0x14, 0x4B)]
    trozos = datos.split(H)[1:]
    return trozos

def turbo(blq):
    # bloque turbo: marca FFh + datos + XOR; en .cas puede llevar ceros detrás (alineación)
    if not blq or blq[0] != 0xFF: return None
    for n in sorted(LARGOS, reverse=True):
        if len(blq) >= n + 2:
            d = blq[1:n + 1]; x = 0xFF
            for b in d: x ^= b
            if x == blq[n + 1] and (len(blq) == n + 2 or not any(blq[n + 2:])):
                return d
    return None

def saca(fichero):
    out = {}
    for b in bloques_crudos(open(fichero, 'rb').read()):
        d = turbo(b)
        if d is None: continue
        out.setdefault(LARGOS[len(d)], []).append(d)
    return out

if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit('Uso: extrae_originales.py <cara A (.cas o .tsx)> <cara B (.cas o .tsx)>')
    a, b = saca(sys.argv[1]), saca(sys.argv[2])
    if len(a.get('juego', [])) != 6 or len(a.get('pantalla', [])) != 1: sys.exit('La cara A no es la de Power Drift')
    if len(b.get('ladoB', [])) != 1: sys.exit('La cara B no es la de Power Drift')
    sal = {'juego.bin': b''.join(a['juego']), 'pantalla.bin': a['pantalla'][0], 'ladoB.bin': b['ladoB'][0]}
    dest = os.path.join(AQUI, '..', 'originales'); os.makedirs(dest, exist_ok=True)
    for n, d in sal.items():
        s = hashlib.sha1(d).hexdigest()
        print('%-13s %6d bytes  SHA-1 %s %s' % (n, len(d), s, 'ok' if s in SHA[n] else '(desconocido)'))
        open(os.path.join(dest, n), 'wb').write(d)
