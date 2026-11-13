; =============================================================================
; Power Drift - ROM SCC (mapper Konami SCC, 512 KB). Banco 0: cabecera y arranque.
; Juego: (C) SEGA 1989 / Activision; conversión MSX de New Frontier. Este arranque y
; los parches: Claude para araubi, 2026. CC BY-NC-SA 4.0.
;
; Bancos: 0 = esto + bloque bajo + volcados + pantalla de carga + 12 cabezas de piloto
;         1-4 = la RAM del juego (páginas 0-3) tal como la dejaba la cinta, ya parcheada
;         5-7 = relleno
; El arranque usa la BIOS para saber los slots, poner SCREEN 2 y enseñar la pantalla de
; carga; luego pone RAM en la página 0, copia allí el bloque bajo y salta a COPIADOR.
; =============================================================================
	INCLUDE "comun.inc"
	INCLUDE "residente_sim.inc"
RSLREG	EQU 0138h
INIGRP	EQU 0072h
GTTRIG	EQU 00D8h
EXPTBL	EQU 0FCC1h
T_ROM	EQU TMP
T_RAM	EQU TMP+1
T_MSX2	EQU TMP+2
T_60	EQU TMP+3
T_MAPA	EQU TMP+4	; (OCM) 0 ASCII16, 1 ASCII8, 2 Konami SCC, 3 Konami
T_DET	EQU TMP+10h	; (OCM) DETECTA corre aquí, en la RAM

	ORG 4000h
	DB "AB"
	DW INICIO
	DW 0,0,0
	DS 6
INICIO:
	DI
	LD	HL,DETECTA	; (OCM) qué mapper ha puesto el ordenador o el cargador
	LD	DE,T_DET
	LD	BC,FIN_DET-DETECTA
	LDIR
	CALL	T_DET
	LD	A,(T_MAPA)
	CP	3
	JR	C,IN_0
	LD	A,8		; Konami sin SCC: no vale (4000h-5FFFh fijo). Borde rojo y parada
	OUT	(99h),A
	LD	A,87h
	OUT	(99h),A
	HALT
IN_0:
	CALL	RSLREG		; slot de la página 1 (este cartucho)
	RRCA
	RRCA
	CALL	SLOT_ID
	LD	(T_ROM),A
	CALL	RSLREG		; slot de la página 3 (RAM)
	RLCA
	RLCA
	CALL	SLOT_ID_3
	LD	(T_RAM),A
	LD	A,(002Dh)	; 0 = MSX1
	OR	A
	JR	Z,IN_1
	LD	A,1
IN_1:
	LD	(T_MSX2),A
	LD	A,(002Bh)	; bit 7: 1 = 50 Hz
	CPL
	RLCA
	AND	1
	LD	(T_60),A
	CALL	INIGRP		; SCREEN 2 (como el SCREEN 2,0,0 del BASIC de la cinta)
	LD	A,(002Dh)	; turbo R: R800 en modo ROM (como en Continental Circus)
	CP	3
	JR	C,IN_2
	LD	A,81h
	CALL	0180h		; CHGCPU
IN_2:
	DI
	LD	A,(T_ROM)	; (SCC) el cartucho en la página 2: SCC callado
	LD	C,2
	CALL	B_PON_SLOT
	LD	HL,9000h	; (OCM) LD (HL),n
	LD	(HL),3Fh
	LD	HL,988Fh
	LD	(HL),0
	LD	A,(T_RAM)
	LD	C,2
	CALL	B_PON_SLOT	; RAM en la página 2
	LD	HL,PANT_ROM
	LD	DE,88B8h
	LD	BC,1C20h
	LDIR
	CALL	0A3B8h		; MUESTRA_PANTALLA (rutina de la propia pantalla)
	EI
	LD	B,150		; unos 3 segundos o hasta pulsar
ESPERA:
	HALT
	PUSH	BC
	XOR	A
	CALL	GTTRIG
	LD	C,A
	LD	A,1
	PUSH	BC
	CALL	GTTRIG
	POP	BC
	OR	C
	POP	BC
	JR	NZ,ESP_FIN
	DJNZ	ESPERA
ESP_FIN:
	DI
	LD	A,(T_RAM)
	LD	C,0
	CALL	B_PON_SLOT	; RAM en la página 0 (adiós BIOS)
	LD	HL,BAJO_ROM
	LD	DE,0
	LD	BC,01FDh
	LDIR
	LD	A,(T_ROM)
	LD	(ROMSLOT),A
	LD	A,(T_RAM)
	LD	(RAMSLOT),A
	LD	A,(T_MSX2)
	LD	(ES_MSX2),A
	LD	A,(T_60)
	LD	(HZ60),A
	LD	A,(T_ROM)	; (OCM) el cartucho en la página 2 para poner su banco (los
	LD	C,2		; registros del SCC están en 9000h-BFFFh)
	CALL	B_PON_SLOT
	LD	A,(T_MAPA)	; BANCO (RST 00h) con los registros de este mapper
	LD	L,A
	ADD	A,A
	ADD	A,L
	ADD	A,A
	ADD	A,A		; x 12
	LD	E,A
	LD	D,0
	LD	HL,MAPAS
	ADD	HL,DE
	LD	A,(HL)
	LD	(B_OP1),A
	INC	HL
	CALL	LEE_DE
	LD	(B_R1+1),DE
	LD	A,(HL)
	LD	(B_OP2),A
	INC	HL
	CALL	LEE_DE
	LD	(B_R2+1),DE
	LD	B,2		; banco 2 de 16 KB (página 1 del juego) en 8000h: COPIADOR lo copia
MP_1:
	LD	C,(HL)
	INC	HL
	CALL	LEE_DE
	LD	A,C
	LD	(DE),A
	DJNZ	MP_1
	LD	A,(T_RAM)
	LD	C,2
	CALL	B_PON_SLOT	; la RAM otra vez en la página 2
	JP	COPIADOR
LEE_DE:
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	INC	HL
	RET
; por mapper: código 1, registro 1, código 2, registro 2 (BANCO, página 1) y dos pares
; valor-registro que ponen el banco 2 de 16 KB en la página 2
MAPAS:
	DB 0		; ASCII16: un registro de 16 KB (se escribe dos veces)
	DW 6000h
	DB 0
	DW 6000h
	DB 2
	DW 7000h
	DB 2
	DW 7000h
	DB 87h		; ASCII8: ADD A,A / INC A, dos registros de 8 KB
	DW 6000h
	DB 3Ch
	DW 6800h
	DB 4
	DW 7000h
	DB 5
	DW 7800h
	DB 87h		; Konami SCC
	DW 5000h
	DB 3Ch
	DW 7000h
	DB 4
	DW 9000h
	DB 5
	DW 0B000h

; (OCM) DETECTA: se copia a T_DET y corre allí (cambia la página 1). Como Black Beard v1.1:
; 3 en 6000h -> en ASCII16 se ve el banco 3 de 16 KB, en ASCII8 la página 3 de 8 KB;
; si no, 3 en 5000h -> en Konami SCC se ve la página 3 de 8 KB. Deja el banco 0 en la
; página 1 con cualquiera. Solo saltos relativos. MARCA_* y DET_OFS los pone build_rom.py.
DETECTA:
	LD	HL,6000h
	LD	(HL),3
	LD	A,(4000h+DET_OFS)
	LD	B,0
	CP	MARCA_A16
	JR	Z,DT_1
	INC	B
	CP	MARCA_8K3
	JR	Z,DT_1
	LD	H,50h
	LD	(HL),3
	LD	A,(4000h+DET_OFS)
	LD	B,2
	CP	MARCA_8K3
	JR	Z,DT_1
	INC	B
DT_1:
	LD	A,B
	LD	(T_MAPA),A
	LD	HL,6800h	; ASCII8: 6000h-7FFFh = página 1 (antes que 6000h, por si un ASCII16 decodifica 6800h)
	LD	(HL),1
	LD	H,60h		; ASCII16 y ASCII8: 4000h = banco 0
	LD	(HL),0
	LD	H,50h		; Konami SCC: 4000h = página 0, 6000h = página 1
	LD	(HL),0
	LD	H,70h
	LD	(HL),1
	RET
FIN_DET:

; SLOT_ID: A (bits 0-1) = primario de la página 1 -> A = identificador E000SSPP
SLOT_ID:
	AND	3
	LD	C,A
	LD	B,0
	LD	HL,EXPTBL
	ADD	HL,BC
	LD	A,(HL)
	AND	80h
	JR	Z,SI_1
	OR	C
	LD	C,A
	INC	HL
	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)		; SLTTBL: bits 2-3 = secundario de la página 1
	AND	0Ch
	OR	C
	RET
SI_1:
	LD	A,C
	RET
; SLOT_ID_3: lo mismo para la página 3
SLOT_ID_3:
	AND	3
	LD	C,A
	LD	B,0
	LD	HL,EXPTBL
	ADD	HL,BC
	LD	A,(HL)
	AND	80h
	JR	Z,SI_1
	OR	C
	LD	C,A
	INC	HL
	INC	HL
	INC	HL
	INC	HL
	LD	A,(HL)		; bits 6-7 = secundario de la página 3
	RRCA
	RRCA
	RRCA
	RRCA
	AND	0Ch
	OR	C
	RET

;@@B_PON_SLOT

	DS BAJO_ROM-$
	INCBIN "bajo.bin"
	DS VUELCA1_ROM-$
	INCBIN "vuelca1.bin"
	DS VUELCA2_ROM-$
	INCBIN "vuelca2.bin"
	DS PANT_ROM-$
	INCBIN "pant.bin"
	DS CABEZAS_ROM-$
	INCBIN "cabezas.bin"
	DS 8000h-$,0FFh
