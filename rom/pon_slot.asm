; @PON_SLOT: pone en la página C (0-3) el slot A (formato E000SSPP, como EXPTBL/ENASLT).
; Sin BIOS y sin pila entre medias (sirve con la página 3 cambiada un momento).
; Solo usa saltos relativos. Estropea AF, BC, DE, HL. Con las interrupciones cortadas.
@PON_SLOT:
	LD	B,A
	AND	3
	LD	L,A		; L = primario
	LD	A,B
	RRCA
	RRCA
	AND	3
	LD	E,A		; E = secundario
	LD	H,3		; H = máscara de la página
	LD	A,C
	OR	A
	JR	Z,@PS_2
@PS_1:
	SLA	H
	SLA	H
	SLA	L
	SLA	L
	SLA	E
	SLA	E
	DEC	A
	JR	NZ,@PS_1
@PS_2:
	BIT	7,B
	JR	Z,@PS_3
	LD	A,B		; slot expandido: hay que tocar su FFFFh
	RRCA
	RRCA
	AND	0C0h
	LD	D,A		; primario en los bits de la página 3
	IN	A,(0A8h)
	LD	C,A
	AND	3Fh
	OR	D
	OUT	(0A8h),A	; página 3 = ese primario (sin pila)
	LD	A,(0FFFFh)
	CPL
	LD	D,A
	LD	A,H
	CPL
	AND	D
	OR	E
	LD	(0FFFFh),A
	LD	A,C
	OUT	(0A8h),A
@PS_3:
	IN	A,(0A8h)
	LD	D,A
	LD	A,H
	CPL
	AND	D
	OR	L
	OUT	(0A8h),A
	RET
