# Historial de cambios (versiones de trabajo)

La v1.0 publicada es la versión de trabajo v12 (13-11-2026). Antes de la música SCC hubo una
ROM optimizada ASCII16 con música PSG (v1-v9: cabeza del piloto en sprites, velocidad, opción
MUSIC/ENGINE/BOTH); la ROM SCC parte de su v8. Abajo, las notas de la ROM SCC, de la más nueva a la más vieja.

**v12 (13-11-2026):** la etapa 3 suena con la música de la etapa 1 (92h) en vez de la suya (94h), que a araubi no le gusta. La 94h ya no va en la ROM: en la tabla de canciones, la entrada de la 94h apunta a los datos de la 92h (`IGUAL_QUE` en build_rom.py).

**v11 (13-11-2026), arreglado el cuelgue al acabar una carrera:**
- Se colgaba en el cartel del puesto al acabar la etapa (grabación de araubi, primera etapa ganada). Venía de la v9: la cabeza del piloto del cartel la pinta el lector de la música con la rutina del juego que lee el dibujo con POP (la pila apunta a los datos, en la ROM), y las interrupciones seguían activas. Si llegaba una, guardaba su dirección de vuelta en la ROM (donde no se puede escribir) y al volver saltaba a cualquier sitio.
- Ahora esa rutina se llama sin interrupciones, y se devuelven como estaban al acabar. Con la grabación, el juego pasa el cartel y sigue en la etapa 2.

**v10 (13-11-2026), solo tiempo real y teclado sin toques perdidos:**
- Queda una sola ROM, `PowerDrift_SCC.rom`, con el reloj de la carrera en tiempo real (la antigua `reloj_real`). La de 8 centésimas por imagen desaparece.
- En carrera el juego solo lee los controles una vez por imagen (cada 130-250 ms). Un toque más corto se perdía: el cambio de marcha (ESPACIO) solo entraba 1 de cada 10 veces con toques de 30 ms y 8 de cada 10 con 100 ms (openMSX, HB-20P).
- Ahora, en cada cuadro de 50/60 Hz, se apuntan las 8 teclas definidas, y la siguiente lectura del juego las ve aunque ya se hayan soltado. Con toques de 30, 60, 100, 150 y 250 ms entran 10 de 10 en el HB-20P y en el HB-F900. Si el juego pasa 15 cuadros sin leer los controles (salida, carteles), lo apuntado se olvida, para que no entre de golpe una tecla vieja.
- El teclado se mira ahora cada 18 ms de media en carrera y en la pausa (antes, cada 130 ms). Cuesta alrededor de un 1,5 % de velocidad (7,30 img/s en el HB-20P y 7,52 en el HB-F900, en BOTH).
- El código va en FF00h-FF43h, una zona de la página 3 que el juego no usa (ganchos de la BIOS copiados de la cinta).
- Sin cambios: el joystick (la BIOS lo lee aparte), el menú (ya leía cada 22 ms y no pierde toques de 20 ms) y los ratos en que el propio juego no mira el teclado (los primeros 3 s del giro del logotipo y la salida de cada etapa).

**v9 (10-11-2026), arreglado el kart de frente del cartel de llegada:**
- Al acabar la etapa, el cartel del puesto (el kart de frente a la izquierda) alterna dos dibujos del piloto: su cara y su cabeza. La cabeza la tomaba el juego de 126Fh, de la zona de la cabeza del piloto que desde la v2 (cabeza en sprites) ocupa código nuevo, así que pintaba basura (araubi lo vio en la celebración). Pasaba en todas las ROM con la cabeza en sprites, también en las PSG.
- Ahora el cartel llama a ICONO y el lector pinta ese dibujo desde la ROM: en el banco 31 van el lector y los dibujos 4 de las cabezas de los 12 pilotos (112 bytes cada uno, sacados de la cara 2). Comprobado en openMSX: salen las dos posturas limpias.
- Lo demás, igual que la v8.

**v8 (10-11-2026), música de la v5, motor audible, frenada y derrape:**
- Música: vuelven los arreglos de la v5 en todas las canciones salvo la 95h (etapa 4), que se queda con la guitarra de la v7 en Mi estándar (araubi: «sonaban mejor antes»). El lector solo aplica la guitarra si la canción la trae.
- Motor del kart (BOTH): ahora tiene el canal A del PSG para él solo, a volumen 15 y una octava más agudo que en la v5 (63 Hz al ralentí y ~110-180 Hz lanzado, antes 31-90 Hz, casi debajo del bajo). La voz de acompañamiento del PSG A calla en BOTH: era la más baja de la mezcla (−40 dB). El charles vuelve a tener el canal C entero.
- Frenada y derrape (MUSIC y BOTH), en el canal C (el charles calla mientras suenan), solo con el coche lanzado (velocidad ≥ 40h) y sin chocar:
  - Derrape: con el volante girado del todo (0E462h = ±10, el dibujo del coche más girado). Chirrido de tono que tiembla en torno a 1 kHz, volumen 12.
  - Frenada: con el freno pisado (gancho FRENA en ACE9h, como ACEL). Chirrido más agudo (~1,3 kHz) con ruido, volumen 12.
  - En ENGINE no suenan (allí no corre el lector de la música).
- El lector crece a 1,25 KB por banco (datos en 4500h-7FFFh, bancos 6-29). La mezcla del R7 la calcula el lector (M_REG+0/+1) y MEZCLA solo la aplica.
- Velocidad: 7,30 img/s en MSX1 y 7,63 en MSX2 (−1 % frente a la v7). Pausa: calla todo.

**v7 (10-11-2026), la etapa 4 (95h) con la guitarra en Mi estándar:**
- La guitarra de la 95h baja una octava (araubi: «demasiado aguda, como si la tocase Metallica»). Antes iba de Si3 a La#5 con la mitad de las notas por encima de Mi4; ahora va de Do3 a Si4, con la mitad por encima de Mi3: el registro de una guitarra en Mi estándar (cuerda grave Mi2).
- Hecho en el guion de ChipForge (`musica_scc/guitarra/PowerDrift_95h_metal.cfscript.json`: las 393 notas del SCC 2 una octava abajo), validado, compilado y exportado con su CLI. Niveles iguales a la v6 (el SCC 2 cambia 0,1 dB). El bend y el vibrato siguen siendo los de ChipForge: comprobado cuadro a cuadro, 0 diferencias.
- Las otras 6 canciones no cambian.

**v6 (10-11-2026), la melodía con guitarra saturada (ChipForge):**
- El SCC 2 (melodía) toca con el sonido de fábrica de ChipForge «guitarra saturada de solo» (`scc-lead-guitarra-solo`): al empezar cada nota la onda pasa de púa a saturada en 9 cuadros, la nota entra con un bend de un semitono (sube en 8 cuadros) y a partir del cuadro 25 lleva vibrato de mano (6 Hz). El volumen sigue el ADSR del sonido (púa a 15, sostenido a 13).
- Hecho con ChipForge (CLI en el PC): `biblioteca usar` sobre los guiones de la v5, `script compilar` y `exportar neutro --nivel escrituras` (traza exacta de los registros). Detalle en `musica_scc/guitarra/INFORME_GUITARRA.md` (con el guion de la etapa 1 de ejemplo).
- Para que quepa (con el bend y el vibrato en los datos salían 488 KB), los datos solo llevan la nota y un aviso de «nota nueva»; el bend, el vibrato y las 9 ondas los pone el lector (`GUITARRA` en `musica.asm`, tablas en `guitarra.inc`). Comprobado cuadro a cuadro: el periodo y la onda que salen son los de ChipForge en las 7 canciones (0 diferencias). Datos: 360 KB en los bancos 6-29; el lector ocupa 930 bytes (1 KB por banco).
- El PSG (bombo, charles, voz A) y el motor del kart (v5, volumen 13) no cambian.
- Velocidad: 7,37 img/s en MSX1 (7,40 la v4) y 7,70 en MSX2 (7,73): −0,4 %.
- La melodía queda un poco más baja que antes: el sostenido de la guitarra va a 13 y la saturación reparte la energía. En la misma carrera, el nivel total baja un 3 %.

**v5 (10-11-2026):** el motor del kart sube de volumen 10 a 13 (el mismo que el motor original), unos 5,5 dB más que en la v4 (araubi: «casi no se oye»). Sigue compartiendo el canal C con el charles.

**v4 (10-11-2026), motor del kart como en Continental Circus (modo BOTH):**
- En BOTH, el canal C del PSG lleva un motor nuevo con la fórmula del Hyper Rally que usamos en Continental Circus: dos periodos que se alternan cada 2 cuadros (0DE0h/0DE8h menos un paso), y el paso sale de la velocidad (×0,69, la escala del Hyper Rally), de la marcha y del acelerador. En corta y pisando sube de vueltas; en larga o sin pisar, va más grave.
- Va a volumen 10 (el motor original iba a 13), unos 10 dB por debajo de la música. Medido en openMSX: el canal del motor tiene la mitad de nivel que en la v3.
- El charles vuelve a sonar en BOTH: mientras suena, el canal C es suyo (ruido a su volumen) y el motor sigue en cuanto acaba.
- El motor del juego original ya no pasa al PSG en BOTH. MUSIC y ENGINE no cambian.
- El motor se actualiza 50 veces por segundo (el lector de la música corre también en los cuadros sin cambios). Coste: unas 7,40 img/s frente a 7,57 en un MSX1 a 60 Hz (−2 %); 7,73 frente a 7,90 en MSX2.
- La pausa sigue callándolo todo.

**v3 (8-11-2026), compatible con los cargadores del One Chip MSX (OCM):**
- La ROM averigua al arrancar con qué mapper la han cargado (Konami SCC, ASCII16 o ASCII8) y cambia de banco con los registros de ese mapper, con `LD (HL),A` para que SofaROM no lo retoque. La activación del SCC (3Fh en 9000h) también va con `LD (HL),n`.
- Probada en openMSX forzando cada mapper: todo funciona igual con los tres. Con ASCII16 o ASCII8 no hay chip SCC, así que solo suenan las voces del PSG. Para oírla entera en un OCM: `mglocm /s`. Con Konami sin SCC se queda con el borde rojo.
- No está probada en un OCM real. El resto es igual que la v2.

**v2 (6-11-2026):**
- Batería con más presencia: bombo y charles a volumen 15, y el charles más largo y fuerte.
- La cabeza del piloto vuelve a ser amarilla (color 10), como antes del rojo.
- La opción de música empieza en BOTH.
- Menú más ágil: el logotipo da la misma vuelta en 17 imágenes en vez de 33 (6 s en vez de 10,5 hasta que sale el menú solo) y en la elección de piloto las caras pasan en 3 pasos en vez de 6 (0,25 s por piloto en vez de 0,5).

## La ROM (Konami SCC, 512 KB; openMSX y BlueMSX la detectan sola)

`PowerDrift_SCC.rom`: reloj de la carrera en tiempo real (cuenta las interrupciones del VDP, 50 o 60 Hz). Desde la v10 es la única.

El SCC va en el propio cartucho (mapper Konami SCC). En una máquina real hace falta un cartucho flash que haga de Konami SCC con su SCC (por ejemplo una MegaFlashROM SCC+).

## Música

| Dónde | Canción |
|---|---|
| Menú y elección de piloto | 90h |
| Etapas 1-5 | 92h, 93h, 92h (desde la v12), 95h, 96h |
| Etapa extra | 97h |

- **Reparto:** SCC 1 bajo (onda sacada de la muestra PCM del arcade), SCC 2 melodía (guitarra saturada solo en la 95h desde la v8), SCC 3-5 otras voces FM (ondas calculadas de los patches del YM2151; las voces que solo doblaban a otra se quitan), PSG A otra voz FM, PSG B bombo, PSG C charles (también hace de caja).
- **MUSIC:** todo lo anterior; los efectos del juego toman el canal B del PSG mientras suenan (el bombo calla en ese rato).
- **ENGINE:** el motor original, sin música en carrera (el SCC calla).
- **BOTH:** la música del SCC y del PSG B y C; en el PSG A, el motor del kart (v8). Frenada y derrape en el PSG C (MUSIC y BOTH).
- **Pausa (RETURN):** el SCC y el PSG callan y la canción sigue donde estaba.
- Los datos son los mismos guiones de ChipForge de la entrega de música SCC (mismos volúmenes), pasados a un estado por cuadro: unos 360 KB en los bancos 6-29 (desde la v8, a partir de 4500h). Reproductor propio (`musica.asm`), no el de ChipForge.

## Cambios frente a la ROM ASCII16

- Bancos: la página 1 se cambia con dos bancos de 8 KB (5000h y 7000h) desde `BANCO` (RST 00h, en 0000h-0007h y 0019h-001Dh).
- Para llegar al SCC el lector pone el cartucho también en la página 2 (9000h = 3Fh, registros en 9800h) y luego devuelve la RAM.
- La parada de la música la hace el lector en el cuadro siguiente (calla PSG y SCC). La pausa no llama a los sondeos, así que al entrar en ella se fuerza un cuadro que calla el SCC.

## Medidas en openMSX (30 s desde la salida de la etapa 1, ARRIBA pulsado)

| Versión | HB-20P | HB-F900 |
|---|---|---|
| Original | 6,77 img/s | 6,77 |
| ROM v8 PSG, MUSIC | 7,67 | 8,07 |
| ROM SCC, MUSIC | 7,50 | 7,87 |

La música avanza a 50,15 cuadros/s en el HB-20P.
