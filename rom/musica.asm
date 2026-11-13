; =============================================================================
; Power Drift ROM SCC: lector de la música (PSG + SCC). Va copiado al principio de CADA
; banco de música (4000h-41FFh), así puede cambiar de banco en mitad de una canción.
; Se llama desde MUS_TICK con la ROM en la página 1, el banco MUS_BNK puesto y la pila
; propia. Pone también la ROM en la página 2 para llegar al SCC (9800h, con 3Fh en 9000h)
; y al acabar devuelve la RAM. Los datos siguen en 4500h-7FFFh (v8: lector de 1,25 KB) de cada banco.
; Formato: musica/scc/codifica5.py. CC BY-NC-SA 4.0.
; =============================================================================
	INCLUDE "comun.inc"
	INCLUDE "residente_sim.inc"
	INCLUDE "juego_sim.inc"
SCC_ONDA	EQU 9800h
SCC_PER		EQU 9880h
SCC_VOL		EQU 988Ah
SCC_ON		EQU 988Fh
	ORG 4000h
LECTOR:			; = ROM_TICK (4000h)
	LD	A,(CAB_REQ)	; (v9) ¿pintar la cabeza del cartel?
	OR	A
	JP	NZ,ICONO_ROM
	LD	A,(ROMSLOT)	; el cartucho también en la página 2 (el SCC)
	LD	C,2
	CALL	PON_SLOT
	LD	HL,9000h	; (OCM) LD (HL),n: que SofaROM no lo tome por un cambio de banco
	LD	(HL),3Fh
	LD	HL,MUS_INI
	LD	A,(HL)
	LD	(HL),0
	CP	2
	JP	Z,PARA
	OR	A
	LD	HL,(MUS_PTR)
	JR	Z,RT_1
	LD	DE,MUS_BNK	; canción nueva: banco, puntero, banco y puntero del bucle
	LD	BC,6
	LDIR
	LD	A,(MUS_BNK)
	RST	00h
	LD	HL,(MUS_PTR)
	LD	A,0FFh		; (v6) la guitarra calla hasta su primera nota
	LD	(G_T),A
	LD	DE,SCC_ONDA	; las 4 ondas (el canal 5 usa la del 4)
	LD	B,128
RT_O:	CALL	LEE
	LD	(DE),A
	INC	DE
	DJNZ	RT_O
RT_1:	LD	A,(MUS_MUTE)	; en la pausa el SCC calla y la canción espera
	OR	A
	LD	A,0
	JR	NZ,RT_3
	LD	A,1Fh
	LD	(SCC_ON),A
	LD	A,(MUS_ESP)	; (SCC v4) cuadros sin cambios: los cuenta el lector
	SUB	1
	JR	C,RT_2
	LD	(MUS_ESP),A
	JR	RT_5
RT_2:	CALL	CUADRO
RT_5:	CALL	GUITARRA
	CALL	MOTOR
	JR	RT_4
RT_3:	LD	(SCC_ON),A
RT_4:	LD	(MUS_PTR),HL
FIN:	LD	A,(RAMSLOT)	; la RAM otra vez en la página 2
	LD	C,2
	JP	PON_SLOT

; (v9) ICONO_ROM: la cabeza del piloto (dibujo 4, el de 126Fh en el original) en el cartel
; del puesto. Los dibujos de los 12 pilotos (112 bytes cada uno) están en el banco ICO_BANCO,
; que empieza con este mismo lector: tras RST 00h el código sigue igual. IX = cartel.
ICO_BANCO	EQU 31
ICONO_ROM:
	XOR	A
	LD	(CAB_REQ),A
	LD	A,ICO_BANCO
	RST	00h
	LD	A,(J_PILOTO)
	LD	L,A
	LD	H,0
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	LD	D,H
	LD	E,L		; DE = p x 16
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL		; HL = p x 128
	OR	A
	SBC	HL,DE		; p x 112
	LD	DE,MUS_DATOS
	ADD	HL,DE
	LD	E,(IX)
	LD	D,(IX+1)
	LD	B,14
	LD	A,I		; (v11) sin interrupciones mientras dibuja: FIGURA_MASCARA_1 lee
	PUSH	AF		; los datos con POP (SP apunta a la ROM); una interrupción ahí
	DI			; guardaba su vuelta en la ROM y se colgaba (al acabar la carrera)
	CALL	J_FIGURA_MASCARA_1
	POP	AF
	JP	PO,IR_1
	EI
IR_1:	LD	A,(MUS_BNK)
	RST	00h
	RET

; PARA: MUS_CALLA pidió parar: SCC y PSG sin volumen, el R7 del juego y MUS_ON a 0.
PARA:	XOR	A
	LD	(SCC_ON),A
	LD	(MUS_ON),A
	LD	E,A
	LD	A,8
	CALL	R_OUT
	LD	A,9
	CALL	R_OUT
	LD	A,10
	CALL	R_OUT
	LD	A,(J_PSG_R7)
	LD	E,A
	LD	A,7
	CALL	R_OUT
	JR	FIN

; CUADRO: 80h+n = n cuadros sin cambios; 00h,xx = bucle; si no, máscara M y datos.
CUADRO:	CALL	LEE
	OR	A
	JP	M,CU_ESP
	JR	NZ,CU_MASC
	LD	A,(MUS_LBNK)
	LD	(MUS_BNK),A
	RST	00h
	LD	HL,(MUS_LPTR)
	JR	CUADRO
CU_ESP:	AND	7Fh
	DEC	A
	LD	(MUS_ESP),A
	RET
CU_MASC:
	LD	C,A
	RR	C
	JR	NC,CU_S
	PUSH	BC
	CALL	LEE
	CALL	PSG_P
	POP	BC
CU_S:	LD	DE,SCC_PER	; bits 1-5: periodo de los canales SCC 1-5
	LD	B,5
CU_S1:	RR	C
	JR	NC,CU_S2
	PUSH	DE
	LD	A,B
	CP	4		; (v6) SCC 2 (B = 4): es la nota de la guitarra, la pone GUITARRA
	JR	NZ,CU_S3
	LD	DE,G_BASE
CU_S3:	CALL	LEE
	LD	(DE),A
	INC	DE
	CALL	LEE
	LD	(DE),A
	POP	DE
CU_S2:	INC	E
	INC	E
	DJNZ	CU_S1
	RR	C		; bit 6: volúmenes
	RET	NC
	CALL	LEE
	LD	C,A
	LD	DE,SCC_VOL
	LD	B,5
CU_V1:	RR	C
	JR	NC,CU_V2
	CALL	LEE
	LD	(DE),A
CU_V2:	INC	E
	DJNZ	CU_V1
	BIT	2,C		; (v6) bit 7 de V: nota nueva de la guitarra
	RET	Z
	XOR	A
	LD	(G_T),A
	RET

; PSG_P: A = máscara del PSG (la de codifica3) y sus datos.
PSG_P:	LD	C,A
	LD	B,0
	RR	C
	CALL	C,DOS_A
	LD	B,2
	RR	C
	CALL	C,DOS_B
	LD	B,4
	RR	C
	CALL	C,DOS_C
	LD	B,8
	RR	C
	CALL	C,UNO_A
	LD	B,9
	RR	C
	CALL	C,UNO_B
	LD	B,10
	RR	C
	CALL	C,UNO_C
	RR	C
	RET	NC
	LD	B,6
	CALL	UNO
	CALL	LEE		; R7: se mezcla con lo del juego
	LD	(M_REG+7),A
	CALL	MEZCLA
	LD	A,7
	JR	R_OUT

; UNO: registro B = siguiente byte, directo al PSG (canales A y C, ruido).
DOS:	CALL	UNO
	INC	B
UNO:	LD	A,(HL)
	INC	HL
	BIT	7,H
	CALL	NZ,OTRO_BANCO
	LD	E,A
	LD	A,B
R_OUT:	OUT	(0A0h),A
	LD	A,E
	OUT	(0A1h),A
	RET

; UNO_B: lo mismo para el canal B (registros 2, 3 y 9): se guarda en M_REG y no suena
; mientras el juego lo usa para un efecto.
DOS_B:	CALL	UNO_B
	INC	B
UNO_B:	LD	A,(HL)
	INC	HL
	BIT	7,H
	CALL	NZ,OTRO_BANCO
	LD	E,A
	PUSH	HL
	LD	HL,M_REG
	LD	A,L
	ADD	A,B
	LD	L,A
	LD	(HL),E
	POP	HL
	LD	A,(MUS_GB)
	OR	A
	RET	NZ
	LD	A,B
	JR	R_OUT

; UNO_A (v8): canal A (registros 0, 1 y 8). En BOTH es del motor: la voz de la música no suena.
DOS_A:	CALL	UNO_A
	INC	B
UNO_A:	LD	A,(MUS_GC)
	OR	A
	JR	Z,UNO
	JR	LEE
; UNO_C (v8): canal C (registros 4, 5 y 10), el charles. Mientras suena la frenada o el
; derrape (M_REG+10 > 0) el canal C es del efecto y el charles no suena.
DOS_C:	CALL	UNO_C
	INC	B
UNO_C:	LD	A,(M_REG+10)
	OR	A
	JR	Z,UNO
LEE:	LD	A,(HL)
	INC	HL
	BIT	7,H
	RET	Z
OTRO_BANCO:			; fin del banco: los datos siguen en el siguiente
	LD	HL,MUS_DATOS
	PUSH	AF
	LD	A,(MUS_BNK)
	INC	A
	LD	(MUS_BNK),A
	RST	00h
	POP	AF
	RET

;-----------------------------------------------------------------------------
; (SCC v4, v8) MOTOR: en BOTH, el motor del kart como en Continental Circus (la fórmula
; CANAL_ARPEGIO del Hyper Rally) en el canal A del PSG, solo, a volumen MOT_VOL y una octava
; por encima de la de Continental Circus (v8: no se oía bajo la música).
; Velocidad Hyper Rally = km/h x 0,72 = VELOCIDAD x 11/16 (el juego da 0,957 km/h por paso).
; Periodo = (0DE0h/0DE8h alternando cada 2 cuadros - paso) / 2; paso = v x 24 en corta
; pisando (v < 60h), (v - 5Fh) x 8 + 08E8h en corta por encima, y v x 9 en larga o sin pisar.
; Después EFECTO (v8): frenada y derrape en el canal C (en MUSIC y BOTH).
; -----------------------------------------------------------------------------
MOT_VOL	EQU 15
MOTOR:	PUSH	HL
	LD	HL,M_REG+5	; cuenta de cuadros (fase), acelerador y (M_REG+8) freno
	INC	(HL)
	INC	HL
	CALL	BAJA
	LD	L,low (M_REG+8)
	CALL	BAJA
	LD	A,(MUS_GC)
	OR	A
	JR	Z,EFECTO
	LD	A,(J_VELOCIDAD)
	SRL	A		; v/2 + v/8 + v/16
	LD	D,A
	SRL	A
	SRL	A
	LD	E,A
	SRL	A
	ADD	A,D
	ADD	A,E
	LD	E,A		; E = velocidad Hyper Rally
	LD	D,0
	LD	L,A
	LD	H,D
	LD	A,(0E6F6h)	; marcha: 0 corta
	OR	A
	JR	NZ,MO_X9
	LD	A,(M_REG+6)	; acelerador pisado hace poco
	OR	A
	JR	Z,MO_X9
	LD	A,E
	CP	60h
	JR	NC,MO_GE
	ADD	HL,HL		; v x 24
	ADD	HL,DE
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	JR	MO_PER
MO_GE:	ADD	HL,HL		; (v - 5Fh) x 8 + 08E8h = v x 8 + 05F0h
	ADD	HL,HL
	ADD	HL,HL
	LD	DE,05F0h
	ADD	HL,DE
	JR	MO_PER
MO_X9:	ADD	HL,HL		; v x 9
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,DE
MO_PER:	EX	DE,HL
	LD	A,(M_REG+5)
	AND	2
	ADD	A,A
	ADD	A,A
	OR	0E0h
	LD	L,A
	LD	H,0Dh
	SBC	HL,DE		; (OR deja el acarreo a 0; el paso máximo, ~0B60h, no pasa de la base)
	SRL	H		; (v8) una octava más aguda
	RR	L
	LD	E,L
	XOR	A
	CALL	R_OUT
	LD	E,H
	LD	A,1
	CALL	R_OUT
	LD	E,MOT_VOL
	LD	A,8
	CALL	R_OUT
; EFECTO (v8): con el coche lanzado (VELOCIDAD >= EF_VMIN) y sin chocar, derrape si el coche
; está girado del todo (volante 0E462h = +-10, el dibujo más girado) y si no, frenada si se ha
; pisado el freno hace poco (M_REG+8, lo pone FRENA). Van en el canal C y el charles calla
; mientras: M_REG+10 = su volumen (0 = el canal C es de la música) y M_REG+4 su mezcla.
EF_VMIN	EQU 40h
EFECTO:	LD	A,(EN_CARRERA)
	OR	A
	JR	Z,EF_NO
	LD	A,(0E446h)	; choque o vuelco
	OR	A
	JR	NZ,EF_NO
	LD	A,(J_VELOCIDAD)
	CP	EF_VMIN
	JR	C,EF_NO
	LD	A,(M_REG+5)
	LD	B,A
	LD	A,(0E462h)
	ADD	A,9
	CP	19
	JR	C,EF_FR
	LD	A,B		; derrape: chirrido de rueda que tiembla (~1 kHz), solo tono
	AND	3
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,70h
	LD	DE,200Ch	; mezcla 20h (tono C), volumen 12
	JR	EF_SI
EF_FR:	LD	A,(M_REG+8)
	OR	A
	JR	Z,EF_NO
	LD	A,B		; frenada: chirrido más agudo con soplido de ruido
	AND	1
	ADD	A,A
	ADD	A,A
	ADD	A,A
	ADD	A,4Ch
	LD	DE,000Ch	; mezcla 00h (tono y ruido C), volumen 12
EF_SI:	LD	B,E
	LD	E,A
	LD	A,4
	CALL	R_OUT
	LD	E,0
	LD	A,5
	CALL	R_OUT
	LD	A,D
	LD	(M_REG+4),A
	LD	E,B
	JR	EF_V
EF_NO:	LD	A,(M_REG+10)
	OR	A
	JR	Z,EF_R7
	LD	E,0		; acaba el efecto: el canal C calla hasta el siguiente charles
EF_V:	LD	A,E
	LD	(M_REG+10),A
	LD	A,10
	CALL	R_OUT
EF_R7:	LD	BC,0FF00h	; mezcla para MEZCLA: B = AND, C = OR
	LD	A,(MUS_GC)
	OR	A
	JR	Z,EF_M1
	LD	BC,0F608h	; BOTH: tono A abierto, ruido A cerrado
EF_M1:	LD	A,(M_REG+10)
	OR	A
	JR	Z,EF_M2
	LD	A,B		; efecto: el canal C con su mezcla
	AND	0DBh
	LD	B,A
	LD	A,(M_REG+4)
	OR	C
	LD	C,A
EF_M2:	LD	(M_REG),BC
	CALL	MEZCLA
	LD	A,7
	CALL	R_OUT
	POP	HL
	RET
BAJA:	LD	A,(HL)		; cuenta atrás hasta 0
	SUB	1
	ADC	A,0
	LD	(HL),A
	RET

; -----------------------------------------------------------------------------
; (v6) GUITARRA: la melodía (SCC 2) con la «guitarra saturada de solo» de ChipForge. En cada
; cuadro de nota: la onda pasa de la púa a la saturada (los 9 primeros cuadros, una onda por
; cuadro) y el periodo es la nota (G_BASE) más el bend y el vibrato de su macro de altura (G_OFFS,
; con bucle). G_T = cuadro de la nota (0FFh = sin nota). Conserva HL.
; -----------------------------------------------------------------------------
GUITARRA:
	PUSH	HL
	LD	DE,0
	LD	A,(G_T)
	INC	A
	JR	Z,GU_P		; (v8) sin nota de guitarra: el periodo tal cual (canciones sin guitarra)
	DEC	A
	CP	G_NONDAS
	JR	NC,GU_1
	LD	L,A		; onda G_T: de G_ONDAS a la onda del canal 2
	LD	H,0
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	LD	DE,G_ONDAS
	ADD	HL,DE
	LD	DE,SCC_ONDA+20h
	LD	BC,32
	LDIR
	LD	A,(G_T)
GU_1:	LD	E,A
	LD	D,0
	LD	HL,G_OFFS
	ADD	HL,DE
	LD	E,(HL)		; desplazamiento con signo
	LD	A,E
	RLA
	SBC	A,A
	LD	D,A
	LD	A,(G_T)
	INC	A
	CP	G_LARGO
	JR	C,GU_2
	LD	A,G_BUCLE
GU_2:	LD	(G_T),A
GU_P:	LD	HL,(G_BASE)
	ADD	HL,DE
	LD	A,L
	LD	(SCC_PER+2),A
	LD	A,H
	LD	(SCC_PER+3),A
	POP	HL
	RET

	INCLUDE "guitarra.inc"

FIN_LECTOR:
	DS MUS_DATOS-$,0FFh
