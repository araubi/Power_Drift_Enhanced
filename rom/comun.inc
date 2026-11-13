; Power Drift ROM - direcciones fijas compartidas por residente.asm, vuelca.asm y rom0.asm
; Variables del código residente (página 0, RAM libre del juego: 0000h-01FCh)
VBL		EQU 0020h	; interrupciones de VDP vistas desde la última imagen
RESTO		EQU 0021h	; resto de centésimas a 60 Hz (x5/3)
HZ60		EQU 0022h	; 1 = máquina de 60 Hz
RELOJ_REAL	EQU 0023h	; 1 = el reloj del juego cuenta tiempo real
EN_CARRERA	EQU 0024h	; 1 = dentro del bucle de carrera (para el joystick)
CONT_LINEAS	EQU 0025h	; imágenes que faltan por repintar las 3 rayas del marcador
ROMSLOT		EQU 0026h	; slot del cartucho (formato E000SSPP)
RAMSLOT		EQU 0027h	; slot de la RAM
SP_GUARDA	EQU 0028h	; 2 bytes
ES_MSX2		EQU 002Ah	; 1 = VDP V9938 o posterior
CACHE		EQU 0040h	; 64 letras del marcador (filas 6 y 7); colores en CACHE+40h
PILA_RES	EQU 01FDh	; pila propia (crece hacia 01DDh)
; Banco 0 de la ROM (visible en 4000h-7FFFh al arrancar)
BAJO_ROM	EQU 4600h	; copia de 0000h-01FCh (509 bytes)
VUELCA1_ROM	EQU 4800h	; volcado del búfer para TMS9918 (MSX1)
VUELCA2_ROM	EQU 48B0h	; volcado del búfer para V9938 (MSX2)
TAM_VUELCA	EQU 0A7h	; 9DF5h-9E9Bh
PANT_ROM	EQU 4960h	; pantalla de carga (7200 bytes, se copia a 88B8h)
CABEZAS_ROM	EQU 6580h	; las 12 cabezas de la cara B (12 x 230h bytes)
TMP		EQU 0C000h	; variables del arranque (página 3, antes de copiar el juego)
SPR_BANCO	EQU 5		; banco de la ROM con los sprites de las cabezas (v2)
; (v3) música
MUS_ON		EQU 002Bh	; 1 = suena una canción
MUS_INI		EQU 002Ch	; 1 = falta leer su entrada de la tabla; 2 = parar (SCC)
MUS_BUSY	EQU 002Dh	; 1 = dentro de MUS_TICK
MUS_C60		EQU 002Eh	; cuenta para saltar 1 de cada 6 cuadros a 60 Hz
MUS_ESP		EQU 002Fh	; cuadros que faltan sin cambios
MUS_BNK		EQU 0030h	; banco y puntero de los datos (4000h-7FFFh)
MUS_PTR		EQU 0031h
MUS_LBNK	EQU 0033h	; banco y puntero del bucle
MUS_LPTR	EQU 0034h
MUS_GB		EQU 0036h	; 2 = el canal B es del juego (efecto)
MUS_MUTE	EQU 0037h	; 1 = pausa
MUS_GC		EQU 003Bh	; 1 = el canal C es del motor (modo BOTH)
MUS_BANCO	EQU 6		; primer banco de la música (tabla en 4000h)
ROM_TICK	EQU 4000h	; lector de la música (musica.asm), al principio de cada banco
MUS_DATOS	EQU 4500h	; (v8) lector de 1,25 KB al principio de cada banco
G_T		EQU 01D3h	; (v6) cuadro de la nota de la guitarra (0FFh = sin nota)
G_BASE		EQU 01D4h	; (v6) periodo de la nota de la guitarra (2 bytes)
MUS_G9		EQU 003Ch	; volumen B que pone el juego (para sus efectos)
MODO_MUS	EQU 003Dh	; 0 = ENGINE, 1 = MUSIC, 2 = BOTH
