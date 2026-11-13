#!/usr/bin/env python3
# Power Drift Enhanced (MSX1, SCC): construye la ROM desde los fuentes y la cinta del usuario.
#   python3 construir.py <cara A (.cas o .tsx)> <cara B (.cas o .tsx)>
# 1) saca los datos del juego de la cinta (tools/extrae_originales.py -> originales/)
# 2) ensambla la ROM (rom/build_rom.py, con sjasmplus o pasmo) -> rom/PowerDrift_SCC.rom
# 3) la compara con la de releases/ (SHA-1). Licencia MIT (araubi, 2026).
import os, sys, subprocess, hashlib
AQUI = os.path.dirname(os.path.abspath(__file__))
REL = os.path.join(AQUI, 'releases', 'PowerDrift_SCC_v1.0.rom')
if len(sys.argv) == 3:
    subprocess.run([sys.executable, os.path.join(AQUI, 'tools', 'extrae_originales.py')] + sys.argv[1:], check=True)
elif not os.path.exists(os.path.join(AQUI, 'originales', 'juego.bin')):
    sys.exit('Uso: python3 construir.py <cara A (.cas o .tsx)> <cara B (.cas o .tsx)>')
subprocess.run([sys.executable, os.path.join(AQUI, 'rom', 'build_rom.py')], check=True)
rom = os.path.join(AQUI, 'rom', 'PowerDrift_SCC.rom')
s = hashlib.sha1(open(rom, 'rb').read()).hexdigest()
r = hashlib.sha1(open(REL, 'rb').read()).hexdigest()
print('SHA-1', s, '= releases/ (v1.0)' if s == r else '!= releases/ (%s)' % r)
