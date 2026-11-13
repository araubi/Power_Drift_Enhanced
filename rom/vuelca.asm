; VUELCA_BUFER nueva (9DF5h-9E9Bh): manda a la VRAM 0800h las 16 filas del búfer EF00h-FEFFh
; de una sola tirada (la dirección de VRAM se pone una vez). Por cada celda, 8 bytes
; con LD A,(HL) / OUT / INC H: 30 ciclos entre OUT con el NOP (lo justo para el TMS9918,
; igual que el original en su par más rápido) y 25 sin él en el V9938 (MSX2).
; Al empezar cada fila mira si ha llegado la interrupción de imagen (reloj real).
; MSX2 EQU 0/1 lo pone build_rom.py. CC BY-NC-SA 4.0.
	INCLUDE "comun.inc"
	ORG 9DF5h
VUELCA:
	XOR	A
	OUT	(99h),A
	LD	A,48h		; 0800h, escritura
	OUT	(99h),A
	LD	DE,0EF00h	; D = página de la línea 0, E = byte bajo de la fila
	LD	C,16
VB_FILA:
	IN	A,(99h)
	RLA
	CALL	C,VBL_VISTO	; (v3) la cuenta y avanza la música
VB_1:
	LD	L,E
	LD	B,32
VB_CELDA:
	LD	H,D
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	H
	IF MSX2 = 0
	NOP
	ENDIF
	LD	A,(HL)
	OUT	(98h),A
	INC	L
	DJNZ	VB_CELDA
	LD	A,D
	XOR	18h		; EFh <-> F7h: filas pares e impares
	LD	D,A
	CP	0EFh
	JR	NZ,VB_2
	LD	A,E
	ADD	A,20h
	LD	E,A
VB_2:
	DEC	C
	JR	NZ,VB_FILA
	RET
VB_FIN:
