# Power Drift SCC: melodía con guitarra («scc-lead-guitarra-solo»)

Fecha: 2026-11-10. Herramienta: ChipForge CLI (`<chipforge>/dist-cli/chipforge.mjs`), usada solo como herramienta; no se ha tocado nada dentro de `chipforge\`.

Sonido de fábrica: **SCC guitarra saturada de solo (bend)** (`scc-lead-guitarra-solo`): bend de entrada con la macro de altura relativa (≈1 semitono, sube en 8 fotogramas), vibrato de mano a los 25 fotogramas (6 Hz), ADSR (púa a 15, caída a 13, sostenido comprimido) y morph de onda púa → saturada. Entra con 2 ondas nuevas (5 → 7 ondas en cada guion).

## 1. Órdenes usadas

`CF = node <chipforge>/dist-cli/chipforge.mjs`, para cada `XX` de 90, 92, 93, 94, 95, 96 y 97:

```
CF biblioteca usar guiones_base/PowerDrift_XXh.cfscript.json scc-lead-guitarra-solo --reemplaza 1 --origen fabrica --salida guiones_guitarra/PowerDrift_XXh.cfscript.json --json
   (después, arreglo con Node: véase «Problemas»)
CF script validar  guiones_guitarra/PowerDrift_XXh.cfscript.json --json
CF script compilar guiones_guitarra/PowerDrift_XXh.cfscript.json cfm_guitarra/PowerDrift_XXh.cfm --json
CF script validar  guiones_base/PowerDrift_XXh.cfscript.json --json
CF script compilar guiones_base/PowerDrift_XXh.cfscript.json cfm_base/PowerDrift_XXh.cfm --json
CF exportar neutro cfm_guitarra/PowerDrift_XXh.cfm neutro/PowerDrift_XXh.neutro.json --nivel escrituras --psg-completo --json
CF exportar neutro cfm_base/PowerDrift_XXh.cfm neutro_base/PowerDrift_XXh.neutro.json --nivel escrituras --psg-completo --json
```

Escucha y medidas (92h y 95h; coste de 97h):

```
CF render  cfm_base/PowerDrift_92h.cfm     wav/PowerDrift_92h_base.wav     --vueltas 1 --json   (ídem 95h)
CF render  cfm_guitarra/PowerDrift_92h.cfm wav/PowerDrift_92h_guitarra.wav --vueltas 1 --json   (ídem 95h)
CF niveles cfm_guitarra/PowerDrift_92h.cfm --json      (y 95h; también las base, para comparar)
CF coste   cfm_guitarra/PowerDrift_97h.cfm --picos 5 --json   (y la base)
```

Las subidas de onda por segundo se han contado con un script de Node sobre la traza `escrituras` de `neutro\PowerDrift_97h.neutro.json` (escrituras del SCC en 00h-7Fh agrupadas por bloque de RAM de 32 bytes; una subida = un bloque escrito en un fotograma), porque `coste` da los bytes de onda de los fotogramas más caros, no las subidas por segundo.

Todas las validaciones: válidas, 0 errores, 0 avisos. Todas las compilaciones: bien, 0 avisos.

## 2. Problemas

1. **`biblioteca usar` reescribe el guion entero y pierde datos que no son del instrumento.** Al comparar la salida con el original, además del instrumento 1 y las ondas habían cambiado: se perdía el campo `notas` (la descripción del arreglo), los nombres de los canales (`"SCC 2 · Melodía F0"` → `"SCC 2"`), `fx: 1` de cada canal, y aparecía `meta.comment: ""`. Las casillas (notas, volúmenes y efectos) no cambiaban.
   **Arreglo:** cada guion de guitarra se ha rehecho como **el guion base tal cual, con solo `instruments` y `waves` sacados de la salida de `biblioteca usar`**. Antes he comprobado que las 5 ondas originales siguen en sus mismos índices (las 2 nuevas van detrás) y que los instrumentos 0 y 2-9 son idénticos a los originales. Así, frente al base, solo cambian `instruments[1]` y las 2 ondas añadidas. Después se ha vuelto a validar y a compilar (los .cfm salen del mismo tamaño que con la primera compilación).
2. **No hay ffmpeg** en el PC (ni en el PATH ni en Program Files): solo quedan los WAV, sin MP3.
3. **`coste` devuelve el código 1 («no cumple»)** en 97h, tanto en la base como en la guitarra: el presupuesto por defecto es del formato *stream* (media 12 %, pico 20 %) y el stream de 97h «pasa de 64 KB» en las dos versiones. Las cifras de abajo son del formato lógico, que sí sale.
4. Los .cfm ocupan 1 byte más que lo que dice `bytes` en la salida de `script compilar` (en la base y en la guitarra por igual). No tiene importancia.

## 3. Niveles (`niveles`, 1 vuelta)

Canal de la melodía = SCC 2 (canal 4). «Activo» = RMS mientras suena.

| | Mezcla pico / RMS | SCC 2 melodía activo | SCC 1 bajo | SCC 3-5 voces | PSG C (charles/caja) | Contraste |
|---|---|---|---|---|---|---|
| 92h base | −1,9 / −17,6 dB | **−21,5 dB** | −23,9 | −24,0 / −24,0 / −24,0 | −27,9 | 1,8 dB |
| 92h guitarra | −2,0 / −17,8 dB | **−23,1 dB** | −23,9 | −24,0 / −24,0 / −24,0 | −27,9 | 1,6 dB |
| 95h base | −3,0 / −19,4 dB | **−23,1 dB** | −24,1 | −29,3 / −27,0 / −29,9 | −24,6 | 0,6 dB |
| 95h guitarra | −3,8 / −19,7 dB | **−23,7 dB** | −24,1 | −29,3 / −27,0 / −29,9 | −24,6 | 0,9 dB |

Sin recortes en ninguna.

**Lectura:** la guitarra **no se come al resto**; al contrario, la melodía baja un poco frente al instrumento original (−1,6 dB en 92h y −0,6 dB en 95h), porque el ADSR cae de 15 a 13 y el sostenido baja despacio.
- **92h:** la melodía queda casi a la par del acompañamiento: solo +0,8 dB sobre el bajo y +0,9 dB sobre las voces SCC 3-5 (antes, +2,4 y +2,5 dB). Está **por encima, pero muy justa**; en el tema-a baja a −23,1 dB, prácticamente igual que las voces (−24,0). Si se quiere que destaque, subir un punto el volumen de las casillas del canal SCC 2 o bajar uno el de SCC 3-5 (no se ha hecho: las casillas no se tocan).
- **95h:** la melodía sigue por encima: +0,4 dB sobre el bajo y entre +3,3 y +6,2 dB sobre las voces SCC 3-5. Se oye bien delante.

## 4. Coste (97h)

`coste` (formato lógico, 50 Hz, 71 591 T por fotograma):

| | Media | Pico | Fotograma del pico | Bytes (lógico) | Stream |
|---|---|---|---|---|---|
| 97h base | 8,9 % | 31,9 % | 7191 | 45 129 | pasa de 64 KB |
| 97h guitarra | **11,2 %** | **36,1 %** (25 829 T) | 6903 (orden 54, fila 23-24) | 45 498 | pasa de 64 KB |

Los 4 fotogramas más caros de la guitarra (6903, 7191, 17775, 18063: 36,1 %) llevan **una subida de onda SCC (32 bytes)** más 49 escrituras; en la base, esos mismos fotogramas no subían onda.

**Subidas de onda SCC en 97h guitarra** (traza `escrituras`, una pasada = 19 288 fotogramas = 385,8 s):
- **Media: 25,8 subidas por segundo** (9 938 subidas, 318 016 bytes de onda), frente a 0,01/s en la base (solo las 4 de la puesta en marcha).
- Todas menos 3 son del bloque de RAM 1 (canal SCC 2, la melodía): 9 935.
- **Peor fotograma: 3 subidas** (fotograma 63, el mismo que en la base: coinciden la carga inicial de otros canales con la de la melodía). Fuera de eso, nunca más de 1 por fotograma.
- Peor segundo: 50 subidas (una en cada fotograma, desde el 1233): mientras suena una nota larga, el morph sube onda en todos los fotogramas. El 51,5 % de los fotogramas de la canción lleva una subida.

Para comparar, media de subidas por segundo en las demás con guitarra: 90h 11,1 · 92h 7,3 · 93h 15,8 · 94h 9,1 · 95h 16,0 · 96h 12,2 (en las base, ≈0).

## 5. Ficheros creados

Carpeta `musica_scc/guitarra/` (tamaños en bytes):

| Fichero | Bytes |
|---|---|
| guiones_guitarra/PowerDrift_90h.cfscript.json | 25 349 |
| guiones_guitarra/PowerDrift_92h.cfscript.json | 90 831 |
| guiones_guitarra/PowerDrift_93h.cfscript.json | 123 799 |
| guiones_guitarra/PowerDrift_94h.cfscript.json | 44 106 |
| guiones_guitarra/PowerDrift_95h.cfscript.json | 96 820 |
| guiones_guitarra/PowerDrift_96h.cfscript.json | 146 547 |
| guiones_guitarra/PowerDrift_97h.cfscript.json | 242 574 |
| cfm_guitarra/PowerDrift_90h.cfm | 191 409 |
| cfm_guitarra/PowerDrift_92h.cfm | 929 570 |
| cfm_guitarra/PowerDrift_93h.cfm | 1 125 949 |
| cfm_guitarra/PowerDrift_94h.cfm | 356 735 |
| cfm_guitarra/PowerDrift_95h.cfm | 879 012 |
| cfm_guitarra/PowerDrift_96h.cfm | 1 262 702 |
| cfm_guitarra/PowerDrift_97h.cfm | 2 631 404 |
| cfm_base/PowerDrift_90h.cfm | 190 576 |
| cfm_base/PowerDrift_92h.cfm | 928 737 |
| cfm_base/PowerDrift_93h.cfm | 1 125 116 |
| cfm_base/PowerDrift_94h.cfm | 355 902 |
| cfm_base/PowerDrift_95h.cfm | 878 179 |
| cfm_base/PowerDrift_96h.cfm | 1 261 869 |
| cfm_base/PowerDrift_97h.cfm | 2 630 571 |
| wav/PowerDrift_92h_base.wav | 25 338 140 |
| wav/PowerDrift_92h_guitarra.wav | 25 338 140 |
| wav/PowerDrift_95h_base.wav | 26 675 252 |
| wav/PowerDrift_95h_guitarra.wav | 26 675 252 |
| neutro/PowerDrift_90h.neutro.json | 440 429 |
| neutro/PowerDrift_92h.neutro.json | 1 651 577 |
| neutro/PowerDrift_93h.neutro.json | 3 324 341 |
| neutro/PowerDrift_94h.neutro.json | 891 941 |
| neutro/PowerDrift_95h.neutro.json | 2 676 399 |
| neutro/PowerDrift_96h.neutro.json | 8 645 700 |
| neutro/PowerDrift_97h.neutro.json | 9 381 363 |
| neutro_base/PowerDrift_90h.neutro.json | 188 624 |
| neutro_base/PowerDrift_92h.neutro.json | 850 564 |
| neutro_base/PowerDrift_93h.neutro.json | 1 137 270 |
| neutro_base/PowerDrift_94h.neutro.json | 428 214 |
| neutro_base/PowerDrift_95h.neutro.json | 905 358 |
| neutro_base/PowerDrift_96h.neutro.json | 3 452 417 |
| neutro_base/PowerDrift_97h.neutro.json | 2 342 208 |
| INFORME_GUITARRA.md | (este fichero) |

Los neutros son nivel `escrituras` con `psgCompleto: true` (R0-R12 del PSG en cada fotograma, como la VM), todas las subcanciones (una, «Main», 50 Hz). Los de guitarra pesan entre 2× y 4× los base por las subidas de onda del morph (32 pares por subida).

No se ha publicado nada ni se ha hecho ningún commit. No hay MP3 (no hay ffmpeg).
