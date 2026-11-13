; =============================================================================
; Power Drift - ROM optimizada: código residente y parches sobre el juego.
; Cada sección va entre SECn y FINn; build_rom.py las pega sobre la imagen de RAM
; (las que caen en 0000h-01FCh forman el bloque bajo que el arranque copia a la RAM).
; Desensamblado y parches: Claude para araubi, 2026. CC BY-NC-SA 4.0.
; RELOJ EQU 0/1 lo pone build_rom.py (1 = reloj en tiempo real).
; =============================================================================
	INCLUDE "comun.inc"
	INCLUDE "juego_sim.inc"

; ---------------- Bloque bajo: 0000h-01FCh -----------------------------------
	ORG 0000h
SEC0:
; (OCM) BANCO = RST 00h: A = banco de 16 KB para la página 1, con el mapper que haya.
; rom0.asm cambia B_OP1, B_R1, B_OP2 y B_R2 según el mapper que detecta al arrancar
; (ASCII16: NOP/6000h/NOP/6000h; ASCII8: ADD A,A/6000h/INC A/6800h; SCC: .../5000h/.../7000h).
; Escribe con LD (HL),A para que los cargadores del OCM no lo parcheen. Conserva todo.
BANCO:	PUSH	HL
	PUSH	AF
	JR	BANCO_2
	DS 0008h-$
; POLL (RST 08h): mira si el VDP ha dado otra interrupción de imagen (bit F) y la cuenta.
; Conserva todos los registros. Se llama con RST 08h entre las rutinas grandes.
POLL:
	PUSH	AF
	IN	A,(99h)
	RLA
	CALL	C,VBL_VISTO	; (v3) la cuenta y avanza la música
	POP	AF
	RET
BANCO_2:
B_OP1:	ADD	A,A
B_R1:	LD	HL,5000h
	LD	(HL),A
B_OP2:	INC	A
B_R2:	LD	HL,7000h
	LD	(HL),A
	POP	AF
	POP	HL
	RET
	DS 0020h-$
	DB 0,0,0,RELOJ,0,2,0,0,0,0,0	; VBL RESTO HZ60 RELOJ_REAL EN_CARRERA CONT_LINEAS ROMSLOT RAMSLOT SP_GUARDA ES_MSX2
	DS 003Ch-$
	DB 15,2			; MUS_G9 (volumen B del juego para sus efectos) y MODO_MUS (2 = BOTH, por defecto)
	DS 0040h-$
	DS 128,0FFh		; caché del marcador (0FFh = desconocido)
	DS 00C8h-$

;@@PON_SLOT

; COPIADOR: corre en la RAM de la página 0. Copia los bancos 1-4 de la ROM a la RAM de
; las cuatro páginas (la imagen del juego tal como la dejaba la cinta) y arranca.
COPIADOR:
	LD	SP,PILA_RES
	LD	A,(ROMSLOT)
	LD	C,2
	CALL	PON_SLOT
	LD	A,(RAMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	HL,8000h
	LD	DE,4000h
	LD	BC,4000h
	LDIR
	LD	A,(ROMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	A,(RAMSLOT)
	LD	C,2
	CALL	PON_SLOT
	LD	A,3
	RST	00h		; (SCC) BANCO
	LD	HL,4000h
	LD	DE,8000h
	LD	BC,4000h
	LDIR
	LD	A,4
	RST	00h		; (SCC) BANCO
	LD	HL,4000h
	LD	DE,0C000h
	LD	BC,3FE5h
	LDIR
	LD	A,1
	RST	00h		; (SCC) BANCO
	LD	HL,41FDh
	LD	DE,01FDh
	LD	BC,3E03h
	LDIR
	XOR	A
	RST	00h		; (SCC) BANCO
	LD	HL,VUELCA1_ROM
	LD	A,(ES_MSX2)
	OR	A
	JR	Z,COP_1
	LD	HL,VUELCA2_ROM
COP_1:
	LD	DE,J_VUELCA_BUFER
	LD	BC,TAM_VUELCA
	LDIR
	LD	A,(RAMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	A,11h		; borde como lo dejaba el cargador
	OUT	(99h),A
	LD	A,87h
	OUT	(99h),A
	JP	01FDh

INVALIDA:
	PUSH	AF
	PUSH	HL
	PUSH	BC
	LD	HL,CACHE
	LD	B,128
IN_1:
	LD	(HL),0FFh
	INC	L
	DJNZ	IN_1
	LD	A,2
	LD	(CONT_LINEAS),A
	XOR	A
	LD	(EN_CARRERA),A
	CALL	OCULTA_CABEZA
	POP	BC
	POP	HL
	POP	AF
	RET
H_BORRA_PANTALLA:
	CALL	INVALIDA
	PUSH	AF
	LD	HL,0
	JP	J_BORRA_PANTALLA+4
H_BORRA_TODO:
	CALL	INVALIDA
	LD	HL,0
	JP	J_BORRA_TODO+3
; (v3) más sondeos en el menú, para la música (ver SEC43)
W_601D:	RST	08h		; cada punto del logotipo (2ª pasada)
	JP	601Dh
W_VEE:	RST	08h		; cada fila del volcado del logotipo
	JP	J_VRAM_ESCRIBE_EN
W_BB:	RST	08h		; cada celda del texto que sube (LB746)
	JP	J_BUFER_BAJA
; (SCC) MT_F: un cuadro de música ya, sin esperas (el lector, en pausa, solo calla el SCC).
MT_F:	PUSH	AF
	JP	MT_2
FIN0:

; ---------------- Parches en el sitio -------------------------------------------
	ORG 0862h		; CALL CARGA_CARA_2 -> CALL CARGA_CABEZA
SEC1:	DW CARGA_CABEZA
FIN1:
	ORG 9AD3h		; EI / HALT / DI -> espera de imagen sondeando el VDP
SEC2:	CALL	ESPERA_IMAGEN
FIN2:
	ORG 9ADAh
SEC3:	DW W_9C94	; envoltorios: RST 08h (sondeo del VDP) y salto a la rutina
FIN3:
	ORG 9AECh
SEC4:	DW W_A1EE
FIN4:
	ORG 9AEFh
SEC5:	DW W_9EE1
FIN5:
	ORG 9AF8h
SEC6:	DW W_C1F8
FIN6:
	ORG 9AFEh
SEC7:	DW W_A619
FIN7:
	ORG 9B08h
SEC8:	DW W_A49A
FIN8:
	ORG 9B1Ah
SEC9:	DW W_0EDD
FIN9:
	ORG 9B20h
SEC10:	DW W_0A15
FIN10:
	ORG 0C284h		; dentro de C1F8h: antes de dibujar cada coche
SEC11:	DW W_C2CB
FIN11:
	ORG 0C289h
SEC12:	DW W_C360
FIN12:
	ORG 9999h		; PINTA_LETRA -> primero mira la caché del marcador
SEC13:	JP	CACHE_LETRA
FIN13:
	ORG 0EDDh		; las 3 rayas del marcador solo cuando hace falta
SEC14:	CALL	LINEAS
	JR	0EEFh
FIN14:
	ORG 0F11h		; CALL NZ,L0F7C (cara de un rival que cambia)
SEC15:	DW CARA_NUEVA
FIN15:
	ORG 0E9Bh		; BORRA_PANTALLA: invalida la caché
SEC16:	JP	H_BORRA_PANTALLA
FIN16:
	ORG 1084h		; BORRA_TODO: invalida la caché
SEC17:	JP	H_BORRA_TODO
FIN17:
	ORG 0BCE8h		; LEE_CONTROLES: CALL Z,LBCFE -> CALL LBCFE (joystick siempre)
SEC18:	DB 0CDh
FIN18:
	ORG 0BCFFh		; LBCFE: AND 0E0h -> nada (teclas y joystick a la vez)
SEC19:	NOP
	NOP
FIN19:
	ORG J_TECLAS_DEFINIDAS	; por defecto: cursores (opción 2 del menú)
SEC20:	DB 0FFh,0F8h,10h,0F8h,80h,0F8h,40h,0F8h,20h,0F8h,01h,0F0h,02h,0F0h,04h,0F7h,80h
FIN20:
	ORG J_CONTROL
SEC21:	DB 1
FIN21:
	ORG 0F98h		; L0F7C: CALL L338A
SEC25:	DW W_338A
FIN25:
	ORG 0A03Bh		; CUENTA_TIEMPO: LD HL,0E6C1h / CALL SUMA_CENTESIMAS
SEC26:	DW SUMA_8
FIN26:

; LEE_JOYSTICK nueva (9864h-9894h): el puerto A del PSG queda como entrada (el original lo
; ponía como salida), devuelve los bits en positivo (el disparo original iba al revés y
; actuaba al soltar) y en carrera cambia: disparo = acelerar, arriba = cambio de marcha.
	ORG 9864h
SEC22:				; (v3) sin tocar R7: todo lo que escribe R7 deja el bit 6 a 0
	LD	A,14
	OUT	(0A0h),A
	IN	A,(0A2h)
	CPL
	LD	E,0
	RRA
	JR	NC,$+4
	SET	1,E		; arriba
	RRA
	JR	NC,$+4
	SET	2,E		; abajo
	RRA
	JR	NC,$+4
	SET	4,E		; izquierda
	RRA
	JR	NC,$+4
	SET	3,E		; derecha
	RRA
	JR	NC,$+4
	SET	0,E		; disparo
	JP	JOY_CARRERA
FIN22:

; ---------------- Código nuevo en 0FD5h-1083h (multicarga, ya sin uso) ---------
	ORG 0FD5h
SEC23:
W_9C94:
	RST	08h
	JP	9C94h
W_A1EE:	RST	08h
	JP	0A1EEh
W_9EE1:	RST	08h
	JP	9EE1h
W_C1F8:	RST	08h
	JP	0C1F8h
W_A619:	RST	08h
	JP	0A619h
W_A49A:	RST	08h
	JP	0A49Ah
W_0EDD:	RST	08h
	JP	0EDDh
W_0A15:	RST	08h
	JP	0A15h
W_C2CB:	RST	08h
	JP	0C2CBh
W_C360:	RST	08h
	JP	0C360h
W_338A:	RST	08h		; cada línea de la cara de un rival
	JP	338Ah

; ESPERA_IMAGEN: hace lo que EI/HALT/DI (esperar a la interrupción si no ha llegado
; ninguna desde la imagen anterior) pero sondeando el VDP, y calcula cuántas
; centésimas han pasado de verdad (2 por interrupción a 50 Hz, 5/3 a 60 Hz).
; Con RELOJ_REAL las pone en SUMA_CENTESIMAS (el original suma siempre 8).
ESPERA_IMAGEN:
	PUSH	HL
	PUSH	BC
	PUSH	AF
	LD	A,1
	LD	(EN_CARRERA),A
	LD	HL,VBL
EI_1:
	IN	A,(99h)
	RLA
	CALL	C,VBL_VISTO
EI_2:
	LD	A,(HL)
	OR	A
	JR	Z,EI_1
	LD	(HL),0
	CP	21
	JR	C,EI_3
	LD	A,20
EI_3:
	LD	B,A
	LD	A,(HZ60)
	OR	A
	JR	NZ,EI_60
	LD	A,B
	ADD	A,A
	JR	EI_BCD
EI_60:
	LD	A,(RESTO)
	LD	C,0
EI_6A:
	ADD	A,5
EI_6B:
	CP	3
	JR	C,EI_6C
	SUB	3
	INC	C
	JR	EI_6B
EI_6C:
	DJNZ	EI_6A
	LD	(RESTO),A
	LD	A,C
EI_BCD:
	LD	C,0
EI_B1:
	SUB	10
	JR	C,EI_B2
	INC	C
	JR	EI_B1
EI_B2:
	ADD	A,10
	LD	B,A
	LD	A,C
	RLCA
	RLCA
	RLCA
	RLCA
	OR	B
	LD	B,A
	LD	A,(RELOJ_REAL)
	OR	A
	JR	Z,EI_FIN
	LD	A,B
	LD	(J_SUMA_CENTESIMAS+2),A
EI_FIN:
	POP	AF
	POP	BC
	POP	HL
	RET

; SUMA_8: el tiempo de la etapa (E6BFh-E6C1h), del que sale la bonificación (1'34"00 menos
; ese tiempo, x64), sigue contando 8 centésimas por imagen como el original, también con
; el reloj real: así los puntos y los récords no cambian.
SUMA_8:
	LD	A,(HL)
	ADD	A,8
	DAA
	LD	(HL),A
	JP	J_SUMA_CENTESIMAS+5

; JOY_CARRERA: en carrera intercambia los bits 0 (disparo) y 1 (arriba).
JOY_CARRERA:
	LD	A,(EN_CARRERA)
	OR	A
	RET	Z
	LD	A,E
	AND	3
	RET	PE		; 00 o 11: no cambia nada
	LD	A,E
	XOR	3
	LD	E,A
	RET
FIN23:

; ---------------- Código nuevo en A3C9h-A499h (cargador de cinta, sin uso) ------
	ORG 0A3C9h
SEC24:
; CARGA_CABEZA: sustituye a la multicarga (CALL CARGA_CARA_2 de 0861h), sin pedir la cara 2
; de la cinta. (v2) Manda a la VRAM los sprites de la cabeza del piloto elegido.
CARGA_CABEZA:
	LD	A,I
	PUSH	AF		; P/V = interrupciones activas
	DI
	LD	(SP_GUARDA),SP
	LD	SP,PILA_RES	; la pila del juego está en la página 1
	LD	A,(ROMSLOT)
	LD	C,1
	CALL	PON_SLOT
	CALL	CARGA_SPRITES	; la cabeza ya no va al búfer: sprites (v2)
	LD	A,(RAMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	SP,(SP_GUARDA)
	LD	A,46h		; como lo dejaba PIDE_PARAR_CINTA
	CALL	J_BORRA_PANTALLA
	CALL	J_LETRAS_NORMALES
	POP	AF
	RET	PO
	EI
	RET

; CACHE_LETRA: entrada de PINTA_LETRA. Si la letra va al marcador (filas 6-7 del tercio
; de arriba) y ya está pintada con el mismo color, solo avanza el cursor.
CACHE_LETRA:
	EXX
	LD	C,A
	LD	HL,(J_PINTA_LETRA+12)	; cursor (operando de LD DE,nn en 99A4h)
	LD	A,H
	CP	40h
	JR	NZ,CL_PINTA
	LD	A,L
	SUB	0C0h
	JR	C,CL_PINTA
	ADD	A,40h
	LD	L,A
	LD	H,0		; HL = CACHE + índice
	LD	A,(J_PINTA_LETRA+73)	; 99E2h: <> 0 si pinta también el color
	OR	A
	JR	Z,CL_ANULA
	LD	A,(J_PINTA_LETRA+51)	; 99CCh: color
	LD	B,A
	LD	A,L
	XOR	0C0h
	LD	E,A
	LD	D,H		; DE = su color en la caché
	LD	A,C
	CP	(HL)
	JR	NZ,CL_GUARDA
	LD	A,(DE)
	CP	B
	JR	NZ,CL_GUARDA
	LD	HL,J_PINTA_LETRA+12
	INC	(HL)
	EXX
	RET
CL_GUARDA:
	LD	(HL),C
	LD	A,B
	LD	(DE),A
	JR	CL_PINTA
CL_ANULA:
	LD	(HL),0FFh
CL_PINTA:
	LD	L,C
	LD	H,0
	JP	J_PINTA_LETRA+4

; LINEAS: las tres rayas de PINTA_MARCADOR solo cuando algo las ha podido tapar
; (cara de un rival nueva o pantalla borrada). Deja HL y B como LIMPIA_FILA.
LINEAS:
	LD	A,(CONT_LINEAS)
	OR	A
	JR	Z,LI_NADA
	DEC	A
	LD	(CONT_LINEAS),A
	LD	HL,4000h
	CALL	J_LIMPIA_FILA
	LD	HL,4680h
	CALL	J_LIMPIA_FILA
	LD	HL,4780h
	JP	J_LIMPIA_FILA
LI_NADA:
	LD	HL,0407h
	LD	B,0
	RET

CARA_NUEVA:
	PUSH	AF
	LD	A,2
	LD	(CONT_LINEAS),A
	POP	AF
	JP	0F7Ch

FIN24:

	ORG 0BCDFh		; (v10) LEE_CONTROLES: LD A,E / RRCA / RRCA -> CALL LT_USA
SEC66:	CALL	LT_USA
FIN66:

; ---------------- (v10) Teclas apuntadas en cada cuadro: FF00h-FFFEh -------------
; Zona de la página 3 que el juego no usa (ganchos de la BIOS copiados de la cinta;
; comprobado en openMSX: solo la escribe COPIADOR). No tocar FFFFh (registro de slots).
	ORG 0FF00h
SEC67:
LT_KEYS:	DB 0		; teclas pulsadas desde la última lectura de LEE_CONTROLES
LT_CNT:		DB 0		; cuadros desde esa lectura

; VBL_VISTO: un sondeo ha visto una imagen nueva: primero apunta las teclas (LT_VBL),
; luego la cuenta y la música (VBL_V2).
VBL_VISTO:
	CALL	LT_VBL
	JP	VBL_V2

; LT_VBL: una vez por cuadro (50/60 Hz) lee las 8 teclas definidas (tabla BD0Ah, como
; LEE_CONTROLES) y las suma a LT_KEYS. Así un toque corto entre dos imágenes no se pierde.
; Si el juego lleva 15 cuadros sin leer los controles (salida, carteles, menús), se olvidan.
; Estropea AF; conserva lo demás.
LT_VBL:
	PUSH	HL
	LD	HL,LT_CNT
	INC	(HL)
	LD	A,(HL)
	CP	15
	JR	C,LV_0
	DEC	(HL)
	DEC	HL
	LD	(HL),0
	POP	HL
	RET
LV_0:
	PUSH	DE
	LD	HL,0BD0Ah
	LD	E,1
LV_1:
	LD	A,(HL)
	OUT	(0AAh),A	; fila (los bits altos, como los pone el juego)
	INC	HL
	IN	A,(0A9h)
	CPL
	AND	(HL)
	INC	HL
	ADD	A,0FFh		; acarreo = tecla pulsada
	RL	E
	JR	NC,LV_1
	LD	HL,LT_KEYS
	LD	A,E
	OR	(HL)
	LD	(HL),A
	POP	DE
	POP	HL
	RET

; LT_USA: desde LEE_CONTROLES (0BCDFh, en vez de LD A,E/RRCA/RRCA): suma las teclas que
; se han pulsado desde la lectura anterior, aunque ya se hayan soltado, y borra la nota.
LT_USA:
	LD	A,(LT_KEYS)
	OR	E
	LD	HL,0
	LD	(LT_KEYS),HL	; LT_KEYS y LT_CNT a 0
	RRCA
	RRCA
	RET
FIN67:

; ---------------- Parches de la cabeza en sprites (v2) --------------------------
	ORG 0A62Fh		; PINTA_CABEZA: tras LD A,postura -> sprites
SEC28:	JP	NUEVA_CABEZA
FIN28:
	ORG 9ADDh		; BUCLE_CARRERA: CALL VUELCA_BUFER
SEC29:	DW W_VUELCA
FIN29:
	ORG 0BBBAh		; podio: CALL VUELCA_BUFER
SEC30:	DW W_VUELCA
FIN30:
	ORG 0BF81h		; PREPARA_CARRERA: JP VUELCA_BUFER
SEC31:	DW W_VUELCA
FIN31:

; ---------------- Código nuevo en 10AFh-12DEh (la cabeza en el búfer, ya sin uso) ----
; La cabeza del piloto (5 dibujos de 32x14 con máscara, y su espejo) va en 4 sprites de
; 16x16: dos negros (color 1) con la tinta y dos rojos (color 9, v7) con el relleno, sin
; el reborde de la máscara. build_rom.py los saca de la cara 2 y los pone en el banco 5
; (1280 bytes por piloto). Sprites en 3800h (patrones) y 1B00h (atributos), los de SCREEN 2.
	ORG 10AFh
SEC27:
CAB_ON:	DB 0			; 1 = PINTA_CABEZA la ha puesto en esta imagen
SPR_BUF:
	DB 0,112,0,1, 0,128,4,1, 0,112,8,10, 0,128,12,10
CAB_REQ:	DB 0			; (v9) 1 = el lector debe pintar la cabeza del cartel (ICONO)

; NUEVA_CABEZA: A = dibujo del coche (0-7; 5-7 son los 0-2 una línea más abajo).
; El espejo lo da el operando de LD A,n en 0A65Bh, como en el original.
NUEVA_CABEZA:
	LD	C,64+94-1	; Y del sprite: fila 94 de la zona de juego, que empieza en la 64
	CP	5
	JR	C,NC_1
	SUB	5
	INC	C
NC_1:
	LD	B,A
	LD	A,(0A65Bh)
	OR	A
	LD	A,B
	JR	Z,NC_2
	ADD	A,5
NC_2:
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,A		; patrón = dibujo x 16
	LD	HL,SPR_BUF
	LD	B,4
NC_3:
	LD	(HL),C
	INC	HL
	INC	HL
	LD	(HL),A
	ADD	A,4
	INC	HL
	INC	HL
	DJNZ	NC_3
	LD	A,1
	LD	(CAB_ON),A
	RET

; W_VUELCA: volcado del búfer y después los sprites de la cabeza (o ninguno).
W_VUELCA:
	CALL	J_VUELCA_BUFER
	LD	A,(CAB_ON)
	OR	A
	JR	Z,OCULTA_CABEZA
	XOR	A
	LD	(CAB_ON),A
	LD	A,I
	PUSH	AF
	DI
	XOR	A
	OUT	(99h),A
	LD	A,5Bh		; 1B00h, escritura
	OUT	(99h),A
	LD	HL,SPR_BUF
	LD	B,16
WV_1:
	LD	A,(HL)
	OUT	(98h),A
	INC	HL
	DJNZ	WV_1
	NOP
	LD	A,208
	OUT	(98h),A
	POP	AF
	RET	PO
	EI
	RET

; OCULTA_CABEZA: ningún sprite (208 en el primero). Conserva todo.
OCULTA_CABEZA:
	PUSH	AF
	LD	A,I
	PUSH	AF
	DI
	XOR	A
	OUT	(99h),A
	LD	A,5Bh
	OUT	(99h),A
	EX	(SP),HL
	EX	(SP),HL
	LD	A,208
	OUT	(98h),A
	POP	AF
	JP	PO,OC_1
	EI
OC_1:
	POP	AF
	RET

; CARGA_SPRITES: (desde CARGA_CABEZA, con la página 1 en la ROM y la pila propia)
; 1280 bytes de patrones del piloto elegido a la VRAM 3800h y sprites de 16x16.
CARGA_SPRITES:
	LD	A,SPR_BANCO
	RST	00h		; (SCC) BANCO
	LD	HL,4000h
	LD	A,(J_PILOTO)
	OR	A
	JR	Z,CS_2
	LD	DE,1280
	LD	B,A
CS_1:
	ADD	HL,DE
	DJNZ	CS_1
CS_2:
	XOR	A
	OUT	(99h),A
	LD	A,78h		; 3800h, escritura
	OUT	(99h),A
	LD	DE,1280
CS_3:
	LD	A,(HL)
	OUT	(98h),A
	INC	HL
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,CS_3
	LD	A,0E2h		; registro 1: como lo deja la BIOS (E0h) y sprites de 16x16
	OUT	(99h),A
	LD	A,81h
	OUT	(99h),A
	XOR	A
	RST	00h		; (SCC) BANCO
	LD	(CAB_ON),A
	JP	OCULTA_CABEZA
FIN27:

; =============================================================================
; (v3) Música del arcade en el PSG (A bajo, B melodía, C batería).
; 90h en el menú y la elección de piloto; 92h-96h en las etapas 1-5 y 97h en la extra.
; Opción 5 del menú: MUSIC (música y efectos encima, sin motor) o ENGINE (motor original).
; Los datos van en los bancos 6 en adelante (tabla de 8 canciones x 6 bytes en el banco 6,
; 4000h). El cuadro de música (1/50 s; a 60 Hz se salta 1 de cada 6) se da en la
; interrupción en los menús y, en carrera (sin interrupciones), cada vez que un sondeo del
; VDP ve una imagen nueva (RST 08h, la espera de imagen y el volcado).
; =============================================================================
	ORG 0BB4h		; PSG_ESCRIBE -> filtro
SEC32:	JP	FILTRO
FIN32:
	ORG 0849h		; PREPARA_PARTIDA: CALL MENU
SEC33:	DW H_MENU
FIN33:
	ORG 9A53h		; PARTIDA: CALL CARRERA
SEC34:	DW H_CARRERA
FIN34:
	ORG 2860h		; MENU_PRINCIPAL: CALL COLOREA_OPCION
SEC35:	DW COLOREA2
FIN35:
	ORG 2E9Ah		; tras definir teclas: CALL COLOREA_OPCION
SEC36:	DW COLOREA2
FIN36:
	ORG 28F4h		; CP 31h / JR C / CP 35h / JR NC -> también la tecla 5
SEC37:	CALL	TECLA_MENU
	JR	C,28D0h
	NOP
	NOP
	NOP
FIN37:
	ORG 0EF49h		; MUSICA_PRESENTACION: LD HL,INT_VACIA
SEC38:	DW INT_MUS
FIN38:


; (v3) Sondeos en el logotipo giratorio del menú (va sin interrupciones ~1/4 s por imagen):
; así la música no se para.
	ORG 1076h		; resto de la multicarga
SEC43:
W_597F:	RST	08h		; cada punto del logotipo
	JP	597Fh
W_5AEF:	RST	08h		; cada línea del logotipo
	JP	5AEFh
FIN43:
	ORG 58FEh
SEC44:	DW W_597F
FIN44:
	ORG 5930h
SEC45:	DW W_597F
FIN45:
	ORG 5AE6h
SEC46:	DW W_5AEF
FIN46:
	ORG 5D72h
SEC47:	DW W_601D
FIN47:
	ORG 60B0h
SEC48:	DW W_VEE
FIN48:
	ORG 0B786h
SEC49:	DW W_BB
FIN49:

	ORG 116Bh
SEC39:
SP_MUS:	DW 0
M_REG:	DB 0,0FFh,0,0,20h,0,0,0,0,0,0	; registros 0-10 según la música (2, 3, 7 y 9)
; (SCC v4, v8) los que la música no guarda: +0/+1 = OR/AND que MEZCLA aplica al R7 (los pone
; el lector), +4 = R7 del canal C del efecto (20h tono, 00h tono y ruido), +5 = cuenta de
; cuadros, +6 y +8 = cuadros que quedan con el acelerador o el freno pisados, +10 = volumen
; de la frenada o el derrape (0 = sin efecto)

; INT_MUS: interrupción en los menús (en lugar de INT_VACIA).
INT_MUS:
	PUSH	AF
	IN	A,(99h)
	RLA
	CALL	C,MUS_TICK
	POP	AF
	EI
	RETI

; VBL_V2: un sondeo ha visto una imagen nueva: la cuenta y avanza la música.
VBL_V2:
	PUSH	HL
	LD	HL,VBL
	INC	(HL)
	POP	HL
; MUS_TICK: un cuadro de música. Conserva todos los registros. Lee la ROM poniéndola en la
; página 1 con la pila propia (la del juego está en la página 1).
MUS_TICK:
	PUSH	AF
	LD	A,(MUS_ON)
	OR	A
	JR	Z,MT_NO
	LD	A,(MUS_BUSY)
	OR	A
	JR	NZ,MT_NO
	LD	A,(HZ60)
	OR	A
	JR	Z,MT_1
	LD	A,(MUS_C60)
	INC	A
	CP	6
	JR	C,MT_0
	XOR	A
MT_0:	LD	(MUS_C60),A
	JR	NC,MT_NO
MT_1:	OR	80h		; (SCC v4) las esperas (MUS_ESP) las cuenta el lector: así el motor
	JR	MT_2		; de BOTH suena también en los cuadros sin cambios de la música
MT_NO:	POP	AF
	RET
MT_2:	LD	(MUS_BUSY),A	; (SCC) A no es 0 (80h-85h desde MT_1, o 1 desde MT_F)
	POP	AF
	LD	(SP_MUS),SP
	LD	SP,PILA_RES
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	A,(ROMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	A,(MUS_BNK)
	RST	00h		; (SCC) BANCO
	CALL	ROM_TICK	; el código que lee los datos está al principio de cada banco
	LD	A,(RAMSLOT)
	LD	C,1
	CALL	PON_SLOT
	LD	A,14		; deja elegido el R14 (por si cortamos a LEE_JOYSTICK)
	OUT	(0A0h),A
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	LD	SP,(SP_MUS)
	PUSH	AF
	XOR	A
	LD	(MUS_BUSY),A
	POP	AF
	RET
; (v9) ICONO: en CARTELES (el kart de frente del puesto al acabar), el dibujo de la cabeza
; que en el original estaba en 126Fh (dibujo 4 del piloto, ya sin uso: ahí va este código).
; Lo pinta el lector desde la ROM (banco ICO_BANCO) con FIGURA_MASCARA_1; IX = cartel.
ICONO:	LD	A,1
	LD	(CAB_REQ),A
	PUSH	AF
	JP	MT_2
PSG_OUT:
	OUT	(0A0h),A
	LD	A,E
	OUT	(0A1h),A
	RET

; MEZCLA: E = R7 de la música (con el tono B del juego durante un efecto, o todo callado
; en la pausa). Bit 7 a 1 y bit 6 a 0 (puerto A de entrada para el joystick).
MEZCLA:	LD	A,(MUS_MUTE)
	OR	A
	LD	A,0BFh
	JR	NZ,ME_1
	LD	A,(MUS_GB)
	OR	A
	LD	A,(M_REG+7)
	JR	Z,ME_0
	AND	2Dh
	OR	10h
ME_0:	LD	E,A		; (v8) mezcla del lector: M_REG+1 = AND, M_REG = OR (canal A del
	LD	A,(M_REG+1)	; motor en BOTH, canal C de la frenada o el derrape)
	AND	E
	LD	E,A
	LD	A,(M_REG)
	OR	E
ME_2:	AND	3Fh
	OR	80h
ME_1:	LD	E,A
	RET

; FILTRO: PSG_ESCRIBE (registro A = E) del juego. Sin música, tal cual. Con música solo
; pasan los efectos del canal B (registros 2, 3 y 9 con el tono B abierto), en BOTH también
; el motor en el canal C (4, 5 y 10), y el R7 decide de quién es el canal B.
FILTRO:
	PUSH	AF
	LD	A,(MUS_ON)
	OR	A
	JR	NZ,FI_MUS
	POP	AF
	OUT	(0A0h),A
	PUSH	AF
	LD	A,E
	OUT	(0A1h),A
	POP	AF
	RET
FI_MUS:	POP	AF
	PUSH	AF
	PUSH	DE
	PUSH	HL
	CALL	FI_2
	POP	HL
	POP	DE
	POP	AF
	RET
FI_2:	LD	D,A
	CP	7
	JR	Z,FI_R7
	CP	9
	JR	NZ,FI_C
	LD	A,E
	LD	(MUS_G9),A
FI_C:	LD	A,(MUS_GC)
	OR	A
	JR	Z,FI_3
	LD	A,D		; (SCC v4) en BOTH el canal C lo lleva el motor nuevo (musica.asm):
	CP	10		; el motor original del juego ya no pasa
	RET	Z
	AND	0FEh
	CP	4
	RET	Z
FI_3:	LD	A,(MUS_GB)
	OR	A
	RET	Z
	LD	A,D
	CP	9
	JP	Z,PSG_OUT
	AND	0FEh
	CP	2
	RET	NZ
	LD	A,D
	JP	PSG_OUT
FI_R7:	LD	A,(EN_CARRERA)	; en carrera, A y C cerrados = pausa: se calla todo
	OR	A
	JR	Z,FR_1
	LD	A,E
	AND	5
	CP	5
	SBC	A,A
	INC	A		; 1 = los dos cerrados
	LD	(MUS_MUTE),A
	CALL	NZ,MT_F		; (SCC) la pausa no llama a los sondeos: calla el SCC ya
FR_1:	LD	A,E
	CPL
	AND	2		; 2 = el juego abre el tono B
	LD	HL,MUS_GB
	CP	(HL)
	JR	Z,FR_FIN
	LD	(HL),A
	OR	A
	JR	Z,FR_DEV
	LD	A,(MUS_G9)
	LD	E,A
	LD	A,9
	CALL	PSG_OUT
	JR	FR_FIN
FR_DEV:	LD	HL,M_REG+2	; acaba el efecto: el canal B vuelve a la música
	LD	E,(HL)
	LD	A,2
	CALL	PSG_OUT
	INC	HL
	LD	E,(HL)
	LD	A,3
	CALL	PSG_OUT
	LD	A,(M_REG+9)
	LD	E,A
	LD	A,9
	CALL	PSG_OUT
FR_FIN:	CALL	MEZCLA
	LD	A,7
	JP	PSG_OUT

; MUS_EMPIEZA: A = canción (0 = 90h, 1-6 = 92h-97h).
MUS_EMPIEZA:
	PUSH	AF
	CALL	MUS_CALLA
	POP	AF
	LD	L,A
	ADD	A,A
	ADD	A,L
	ADD	A,A
	LD	L,A
	LD	H,MUS_DATOS/256	; la tabla abre los datos del banco 6
	LD	(MUS_PTR),HL
	LD	A,MUS_BANCO
	LD	(MUS_BNK),A
	XOR	A
	LD	(MUS_ESP),A
	LD	(MUS_GB),A
	LD	(MUS_GC),A
	LD	(MUS_MUTE),A
	INC	A
	LD	(MUS_INI),A
	LD	(MUS_ON),A
	RET
FIN39:

	ORG 0A461h		; resto del cargador de cinta
SEC40:
; Menú: línea «5. MUSIC» / «5. ENGINE» / «5. BOTH» debajo de «3. KEYBOARD»; la tecla 5 la cambia.
COLOREA2:
	CALL	J_COLOREA_OPCION
PINTA_MODO:
	LD	A,46h
	LD	(99CCh),A
	LD	HL,T_ENGINE-13
	LD	DE,13
	LD	A,(MODO_MUS)
	INC	A
PM_0:	ADD	HL,DE
	DEC	A
	JR	NZ,PM_0
	JP	J_TEXTO_EN
TECLA_MENU:
	CP	35h
	JR	Z,TM_5
	CCF
	RET	C		; mayor que '5': nada
	CP	31h		; menor que '1': nada (acarreo)
	RET
TM_5:	LD	A,(MODO_MUS)	; MUSIC (1) -> ENGINE (0) -> BOTH (2) -> MUSIC
	DEC	A
	JP	P,TM_6
	LD	A,2
TM_6:	LD	(MODO_MUS),A
	CALL	PINTA_MODO
TM_1:	CALL	J_LEE_TECLA
	OR	A
	JR	NZ,TM_1
	SCF
	RET
FIN40:

	ORG 0A632h		; resto de PINTA_CABEZA (hasta el operando de 0A65Bh)
SEC41:
T_ENGINE:			; por MODO_MUS: 0, 1 y 2, 13 bytes cada uno
	DW 5006h
	DB " 5. ENGINE",' '+80h
T_MUSIC:
	DW 5006h
	DB " 5. MUSIC ",' '+80h
T_BOTH:
	DW 5006h
	DB " 5. BOTH  ",' '+80h
FIN41:

	ORG 0BCA3h		; textos de la cinta («STOP THE TAPE AND PRESS FIRE»), sin uso
SEC42:
; MUS_CALLA: para la música y deja el PSG como lo quiere el juego (sin volumen).
MUS_CALLA:		; (SCC) la para el lector en el siguiente cuadro: calla PSG y SCC
	LD	A,2
	LD	(MUS_INI),A
	XOR	A
	LD	(MUS_ESP),A
	RET
; (SCC v4) ACEL: en CONTROL_JUGADOR, al pisar el acelerador (ACA9h: LD A,(0E6F6h)).
ACEL:	LD	A,12
	LD	(M_REG+6),A
	LD	A,(0E6F6h)
	RET
; (v8) FRENA: en CONTROL_JUGADOR, al pisar el freno (ACE9h: LD A,(VELOCIDAD)).
FRENA:	LD	A,12
	LD	(M_REG+8),A
	LD	A,(J_VELOCIDAD)
	RET
FIN42:
	ORG 0ACA9h
SEC63:	CALL	ACEL
FIN63:
	ORG 0B46Ah		; CARTELES: LD HL,126Fh / JR LB48D (la cabeza del jugador)
SEC65:	JP	ICONO
FIN65:
	ORG 0ACE9h
SEC64:	CALL	FRENA
FIN64:

; (v6) La tabla de colores de 0400h va ya hecha en la imagen (la hacía HAZ_TABLA_ATRIB al
; arrancar): su código y el texto sobrante de detrás (610Ch-6138h) quedan para los ganchos.
; De 6139h a 6181h sigue siendo la pila del juego (se ha visto bajar hasta 615Ch).
	ORG 6103h		; ARRANQUE: CALL HAZ_TABLA_ATRIB
SEC50:	NOP
	NOP
	NOP
FIN50:
	ORG 0400h
SEC51:
	DB 011h,041h,061h,0D1h,0C1h,071h,0A1h,0F1h,014h,044h,064h,0D4h,0C4h,074h,0A4h,0F4h
	DB 016h,046h,066h,0D6h,0C6h,076h,0A6h,0F6h,01Dh,04Dh,06Dh,0DDh,0CDh,07Dh,0ADh,0FDh
	DB 01Ch,04Ch,06Ch,0DCh,0CCh,07Ch,0ACh,0FCh,017h,047h,067h,0D7h,0C7h,077h,0A7h,0F7h
	DB 01Ah,04Ah,06Ah,0DAh,0CAh,07Ah,0AAh,0FAh,01Fh,04Fh,06Fh,0DFh,0CFh,07Fh,0AFh,0FFh
	DB 011h,051h,091h,0D1h,031h,071h,0B1h,0F1h,015h,055h,095h,0D5h,035h,075h,0B5h,0F5h
	DB 019h,059h,099h,0D9h,039h,079h,0B9h,0F9h,01Dh,05Dh,09Dh,0DDh,03Dh,07Dh,0BDh,0FDh
	DB 013h,053h,093h,0D3h,033h,073h,0B3h,0F3h,017h,057h,097h,0D7h,037h,077h,0B7h,0F7h
	DB 01Bh,05Bh,09Bh,0DBh,03Bh,07Bh,0BBh,0FBh,01Fh,05Fh,09Fh,0DFh,03Fh,07Fh,0BFh,0FFh
	DB 011h,041h,061h,0D1h,0C1h,071h,0A1h,0F1h,014h,044h,064h,0D4h,0C4h,074h,0A4h,0F4h
	DB 016h,046h,066h,0D6h,0C6h,076h,0A6h,0F6h,01Dh,04Dh,06Dh,0DDh,0CDh,07Dh,0ADh,0FDh
	DB 01Ch,04Ch,06Ch,0DCh,0CCh,07Ch,0ACh,0FCh,017h,047h,067h,0D7h,0C7h,077h,0A7h,0F7h
	DB 01Ah,04Ah,06Ah,0DAh,0CAh,07Ah,0AAh,0FAh,01Fh,04Fh,06Fh,0DFh,0CFh,07Fh,0AFh,0FFh
	DB 011h,051h,091h,0D1h,031h,071h,0B1h,0F1h,015h,055h,095h,0D5h,035h,075h,0B5h,0F5h
	DB 019h,059h,099h,0D9h,039h,079h,0B9h,0F9h,01Dh,05Dh,09Dh,0DDh,03Dh,07Dh,0BDh,0FDh
	DB 013h,053h,093h,0D3h,033h,073h,0B3h,0F3h,017h,057h,097h,0D7h,037h,077h,0B7h,0F7h
	DB 01Bh,05Bh,09Bh,0DBh,03Bh,07Bh,0BBh,0FBh,01Fh,05Fh,09Fh,0DFh,03Fh,07Fh,0BFh,0FFh
FIN51:
	ORG 610Ch
SEC52:
H_MENU:	XOR	A
	CALL	MUS_EMPIEZA
	JP	J_MENU
H_CARRERA:
	XOR	A		; los sondeos del menú no cuentan para el reloj de la carrera
	LD	(VBL),A
	CALL	MUS_CALLA
	LD	A,(MODO_MUS)
	OR	A
	JR	Z,HC_1
	LD	A,(J_ETAPA)
	INC	A
	CALL	MUS_EMPIEZA
	LD	A,(MODO_MUS)	; BOTH (2): el canal C queda para el motor
	DEC	A
	LD	(MUS_GC),A
HC_1:	CALL	J_CARRERA
	JP	MUS_CALLA
FIN52:

; (SCC v2) Menú más ágil (araubi: «el menú y la elección de piloto van muy lentos»).
; Logotipo giratorio: la misma vuelta en la mitad de imágenes (paso doble, 17 en vez de 33)
; y al acabar pasa por la pose final de siempre (la que pone una tecla).
	ORG 585Fh
SEC53:	DB 16			; ADD A,8 -> 16 (ángulo)
FIN53:
	ORG 5881h
SEC54:	DW 0FFFEh		; LD DE,-1 -> -2
FIN54:
	ORG 588Bh
SEC55:	DB 8			; ADD A,4 -> 8
FIN55:
	ORG 589Dh
SEC56:	DB 11h			; CP 21h -> 11h (imágenes)
FIN56:
	ORG 58A1h
SEC57:	JR	58A3h		; JR L58D0 -> a la pose final
FIN57:
; Elección de piloto: las caras pasan en 3 pasos de 16 píxeles en vez de 6 de 8.
	ORG 43EDh
SEC58:	DB 2			; derecha: empieza en el desplazamiento 2 (2, 4, 6)
FIN58:
	ORG 43F2h
SEC59:	DB 2			; paso +2
FIN59:
	ORG 4411h
SEC60:	DB 4			; izquierda: 4, 2, 0
FIN60:
	ORG 4416h
SEC61:	DB 0FEh			; paso -2
FIN61:
	ORG 443Bh
SEC62:	DB 3			; 3 pasos
FIN62:
