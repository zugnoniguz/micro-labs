;
; Programa Ta-Te-Ti
;
; Created: 19/11/2024
; Author : Martony - Weyrauch - Zugnoni - Lorenzo
;

.include "m328Pdef.inc"

; Breve descripción:
; Programa para jugar al Ta-Te-Ti.
; Defino una memoria de pantalla en RAM de 1024bytes. 1byte = 1 pixel (32 x 32 = 1024)
; de c/u uso solo 3 bits que indican el RGB del pixel (solo on/off).
;
; configuro el timer0 para interrumpir 1250 veces por segundo. luego en cada
; interrupción barro 1 linea cada vez.
;
; configuro el timer1 para interrumpir 1 vez por segundo, puede utilzar para
; hacer un reloj. por ahora solo modifica el color de 1 pixel para
; confirmar que el timer1 funciona correctamente.
;
; Pines de control del display:
;   PB5:PB0 = RGB1:RGB0
;   PC6:PC0 = LE:Clk:OE:ABCD
;
; Importante: la interrupción del timer0 utiliza el registro Y(r29:r28) y r25,
; no se pueden utilizar en otras rutinas.
; Y(r29:r28) - dirección en la RAM de oantalla de la próxima linea a barrer
; r25 - #de linea a barrer en la próxima interrupción.

.DSEG
; reservo 1024 bytes para la memoria de pantalla. lo escrito aquí se manda a la pantalla.
screen: .byte 1024
; solo para marcar el final del buffer
screen_end: .byte 1
; memoria para las celdas del tablero
tablero: .byte 9
; solo para marcar el final del buffer
tablero_end: .byte 1

.CSEG

; vectores de interrupción

; dirección de comienzo (vector de reset).
.ORG 0x0000
	jmp reset
; Cambio de estado de PINC (los botone).
.ORG 0x008
	jmp _puertoc_int
; comparación A del timer 1
.ORG 0x0016
	jmp _tmr1_int
; comparación A del timer 0
.ORG 0x001C
	jmp _tmr0_int


; ---------------------------------------------------------------------------------------
; acá empieza el programa
reset:
	; configuro los puertos:
	; PB0 PB1 PB2 - RGB0
	; PB3 PB4 PB5 - RGB1

	; PB0 a PB5 son salidas
	ldi r16, 0b00111111
	out DDRB, r16
	; apago PORTB
	ldi r16, 0x00
	out PORTB, r16

	; PD0:7 no se va a usar, lo configuro como entradas.
	ldi r16, 0b00000000
	out DDRC, r16

	; PD3 a PD0 = ABCD indica la línea del display que estoy escribiendo
	; PD4 = OE(asumo activa nivel alto), PD5 = Clk serial, PD6 = LE (STB del Latch)

	; configuro PD.0 a PD.6 como salidas
	ldi r16, 0b01111111
	out DDRD, r16
	; apago PORTD
	ldi r16, 0b00000000
	out PORTD, r16

	;-------------------------------------------------------------------------------------
	; Configuro el TMR0 y su interrupcion.

	; cuenta hasta OCR0A y vuelve a cero (reset on compare), ahí dispara la interrupción
	ldi r16, 0b00000010
	out TCCR0A, r16
	; prescaler = 256
	ldi r16, 0b00000100
	out TCCR0B, r16
	; comparo con 49
	; fint0 = 16000000/256/50 = 1250Hz
	ldi r16, 24
	out OCR0A, r16
	; habilito la interrupción (falta habilitar global)
	ldi r16, 0b00000010
	sts TIMSK0, r16

	;-------------------------------------------------------------------------------------
	; Configuro el TMR1 y su interrupcion.

	; cuenta hasta OCR0A y vuelve a cero (reset on compare), ahí dispara la interrupción
	ldi r16, 0b00000000
	sts TCCR1A, r16
	; prescaler = 1024
	ldi r16, 0b00001101
	sts TCCR1B, r16
	; OCR1A = 15625
	; fint0 = 16000000/1024/15625 = 1Hz
	ldi r16, high(15624)
	sts OCR1AH, r16
	ldi r16, low(15624)
	sts OCR1AL, r16

	; habilito la interrupción (falta habilitar global)
	ldi r16, 0b00000010
	sts TIMSK1, r16

	;------------------------------------------------------------------------------------
	; configuro botones
	; habilita PCI1 (PCINT14..8)
	ldi r16, 0b00000010
	sts PCICR, r16
	; habilita PCINT9, PCINT10, PCINT11 (los botones)
	ldi r16, 0b00001110
	sts PCMSK1, r16


	;-------------------------------------------------------------------------------------
	; Inicializo algunos registros que voy a usar como variables.

	; r25 indica qué línea estoy barriendo del display.
	ldi r25, 0x00
	; Y apunta al primer byte de la pantalla
	ldi YL, low(screen)
	ldi YH, high(screen)
	; indica en qué celda está parado el jugador (0-8)
	clr r22
	; indica si el cursor debe ser visible o no
	clr r23
	; indica de quién es el turno actual (0 cruz, 1 círculo)
	clr r24

	;-------------------------------------------------------------------------------------
	; Limpio el tablero
	ldi XL, low(tablero)
	ldi XH, high(tablero)

loop_clean_tablero:
	st X+, r22

	cpi XL, low(tablero_end)
	brne loop_clean_tablero
	cpi XH, high(tablero_end)
	brne loop_clean_tablero


	;-------------------------------------------------------------------------------------
	; habilito las interrupciones globales(set interrupt flag)
	sei
	;-------------------------------------------------------------------------------------

;-------------------------------------------------------------------------------------
; Programa principal
;-------------------------------------------------------------------------------------
start:
	; borra el panel
	call borra_panel

	; copia una imagen de fondo en el panel
	; apunto Z a la imagen de fondo a copiar y luego efectivamente la copia.
	ldi ZL, low(Imagen_1<<1)
	ldi ZH, high(Imagen_1<<1)

	call copia_img


; Ahora me quedo esperando sin hacer nada o puedo hacer otras tareas;
; una vez que la memoria pantalla fué escrita se encarga la interrupcion del timer0.
espero:
	nop
	nop
	nop
	rjmp espero


;RUTINAS
;-------------------------------------------------------------------------------------

;timer0:
;--------
;rutina de barrido que saca 192 bits de RGB por el display, recordar que en cada paso saco por el peurto
;PORTB 6 bits, RGB0 - Pixel de la mitad de arriba y RGB1 - Pixel de la mitad de abajo.
;RGB = color, solo puedo hacer combinaciones R, G, B, (R+G), (G+B), (R+B), y (R+G+B) = blanco
;
;Cada 32 Bytes de la memoria de pantalla, saco 192 bits (96 de una linea de arriba, 96 de una linea de abajo).
;En Y se supone está la dirección de donde comienzo a sacar los bits.
;
;Uso algunos registros exclusivos:
;	Y (YH:YL) memoriza la dirección de pantalla que estoy recorriendo
;	R25 memoriza la linea siguiente a iluminar
;-------------------------------------------------------------------------------------

;(sacaLED)
_tmr0_int:
	push	r16			; guardo contexto: registros a usar y banderas
	in		r16,	SREG
	push	r16
	push	r17
	push	r18
	push	r27
	push	r26

	movw	XH:XL, YH:YL						;Y apunta a la mitad de abajo
	inc		R27							;le sumo 512 a X para apuntar a la parte de abajo de la pantalla
	inc		R27

	ldi		r16, 0
	cbi		PORTD, 6					;LE = 0

LED_loop:
	cbi		PORTD, 5					;SCLK = 0

	ld		r17,	Y+					;traigo 2 bytes a sacar por la pantalla
	ld		r18,	X+					;este es de las lineas de abajo

LED_loop3:
	andi	r17,	0b00000111
	swap	r18
	ror		r18
	andi	r18,	0b00111000
	or		r17, r18

	out		PORTB,	r17					;saco RGB1 RGB0 por el puerto B

	sbi		PORTD, 5					;SCLK = 1

	inc		r16
	cpi		r16,	32

	brne	LED_loop					;loop si no completé la linea.

	sbi		PORTD, 4					;/OE = 1 apago display por las dudas (no es necesario)
	sbi		PORTD, 6					;LE = 1

;	Ahora dibujo una nueva linea
	out		PORTD,	r25					;NOTA: aquí ademas de pasar ABCD, estoy haciendo tambien /OE=0 y LE=0
	inc		r25
	cpi		r25,	32
	brne	LED_fin						;si no llegué a la ultima linea vuelvo de la interrupción
;	fin de pantalla, llevo r25 y Y al principio.
	ldi		r25,	0
	ldi		YL,	low(screen)				;apunto de nuevo Y al primer byte de la pantalla
	ldi		YH,	high(screen)

LED_fin:
	pop		r26						;restauro registros y banderas
	pop		r27
	pop		r18
	pop		r17
	pop		r16
	out		SREG,	r16
	pop		r16
	reti

;-------------------------------------------------------------------------------------
;copia_img:
;----------
;Rutina que copia un bloque de 1024 bytes de la Flash de programa a la RAM de pantalla
;en Screen.
;
;Parámetros: debo poner en Z(ZH:ZL) la dirección de comienzo de la imagen a copiar.
;-------------------------------------------------------------------------------------

copia_img:
	ldi		XL,	low(screen)			;apunto X al primer byte de la pantalla
	ldi		XH,	high(screen)

copia_loop1:
	lpm		r17,	Z+						;traigo 1 byte a copiar a la pantalla
	st		X+,		r17						;escribo la memoria de pantalla
	cpi		XL,		low(screen_end)
	brne	copia_loop1
	cpi		XH,		high(screen_end)		;si llegué al final de la pantalla no copio más
	brne	copia_loop1
	ret

;-------------------------------------------------------------------------------------
;borra_panel:
;----------
;Rutina que borra el display LED.
;Escribe 1024 ceros en la RAM de pantalla
;-------------------------------------------------------------------------------------
borra_panel:
	ldi		XL,	low(screen)					;apunto de nuevo X al primer byte de la pantalla
	ldi		XH,	high(screen)
	ldi		r17, 0x00

borra_loop1:
	st		X+,		r17
	cpi		XL,		low(screen_end)
	brne	borra_loop1
	cpi		XH,		high(screen_end)		;si llegué al final de la pantalla no copio más
	brne	borra_loop1
	ret


borra_celdas:
	clr r21

borra_celdas_loop:
	push r21

	ldi r18, 0x00
	ldi r20, 0x00
	rcall coloca_char

	pop r21
	inc r21

	cpi r21, 9
	brne borra_celdas_loop

	ret

;-------------------------------------------------------------------------------------
;copia_char:
;----------
;Rutina que copia un caracter en la memoria de pantalla. Por ahora pensado solo para
;los números del 0 al 9 de tamaño fijo 8x10 pixeles. Por ahora solo están el '0' y el '1'
;configurados en el mapa de caracteres pero la rutina funciona igual.
;
;los carateres son de 8x10 puntos por tanto ocupan solo 10 bytes. Esta rutina toma los 10
;bytes y bit a bit va programando la memoria de pantalla.
;
;Parámetros:
;	r18 = numero a imprimir del 0 al 9 (por ahora solo 0 y 1 disponibles)
;	r16 y r17 = Fila y Columna del pixel superior izquierdo del caracter.
;	r20 = color del caracter. 1-Verde 2-Rojo 4-Azul 3-Amarillo 5-cyan 6-lila 7-blanco 0-apagado
;-------------------------------------------------------------------------------------

copia_char:
	ldi		XL,	low(screen)				;X apunta al comienzo de la memoria de pantalla
	ldi		XH,	high(screen)

	ldi		ZL,	low(char_full<<1)			;apunto Z al comienzo del mapa de caracteres char_0
	ldi		ZH,	high(char_full<<1)

	;Ahora ajusto Z según el caracter que quiero imprimir
	ldi		r19,	0x08
	mul		r18,	r19				;cada 0x0A es un caracter
	clc
	add		ZL,		r0
	adc		ZH,		r1

	;Ahora ajusto X segun la fila/columna donde quiero imprimir
	ldi		r18,	0x20
	mul		r16,	r18				;cada 0x20 es un salto de renglón
	clc
	add		r0,		r17				;ahora en r1:r0 está lo que me tengo que desplazar en la pantalla
	ldi		r16,	0
	adc		r1,		r16
	clc
	add		XL,		r0
	adc		XH,		r1

;ahora que esta todo listo, en este loop copio el caracter a la pantalla.
	ldi		r16,	8					;son 10 byte por caracter
copia_char1:
	lpm		r19,	Z+					;traigo 1 Byte con los bits del caracter
	ldi		r18,	8					;8 bits por byte
copia_char2:
	ld		r17,	X					;traigo 1 byte de la memoria de pantalla
	rol		r19
	brcc	copia_char3
	mov		r17,	r20					;en r20 está el color que quiero imprimir
copia_char3:
	st		X+,		r17					;guardo el byte nuevo o el que estaba antes en la memoria de pantalla
	dec		r18
	brne	copia_char2

	adiw	XL,	0x18					;avanzo 0x18 = 24 lugares para el cambio de fila en la memoria de pantalla
										;(no es 32 porque ya avancé 8 al dibujar la linea).
	dec		r16
	brne	copia_char1
	ret

;imagen ejemplo con cuadrados de colores para pruebas
Imagen_1:
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
;Mapa de caracteres, por ahora solo '0' y '1'
char_full:
.db 0b11111111, 0b11111111
.db 0b11111111, 0b11111111
.db 0b11111111, 0b11111111
.db 0b11111111, 0b11111111

char_X:
.db 0b10000001, 0b01000010
.db 0b00100100, 0b00011000
.db 0b00011000, 0b00100100
.db 0b01000010, 0b10000001

char_O:
.db 0b00111100, 0b01000010
.db 0b10000001, 0b10000001
.db 0b10000001, 0b10000001
.db 0b01000010, 0b00111100


;-------------------------------------------------------------------------------------
;coloca_char:
;----------
; Rutina que copia un caracter en la memoria de pantalla.
;
;Parámetros:
;	r18 = numero a imprimir del 0 al 9 (por ahora solo 0 y 1 disponibles)
;	r21 = posición en la grilla (0-8)
;	r20 = color del caracter. 1-Verde 2-Rojo 4-Azul 3-Amarillo 5-cyan 6-lila 7-blanco 0-apagado
;-------------------------------------------------------------------------------------
coloca_char:
	; Primera fila
	ldi r16, 0x00

	ldi r17, 0x0C * 0
	cpi r21, 0
	breq coloca_char_exit

	ldi r17, 0x0C * 1
	cpi r21, 1
	breq coloca_char_exit

	ldi r17, 0x0C * 2
	cpi r21, 2
	breq coloca_char_exit

	; Segunda fila
	ldi r16, 0x0C

	ldi r17, 0x0C * 0
	cpi r21, 3
	breq coloca_char_exit

	ldi r17, 0x0C * 1
	cpi r21, 4
	breq coloca_char_exit

	ldi r17, 0x0C * 2
	cpi r21, 5
	breq coloca_char_exit

	; Tercera fila
	ldi r16, 0x18

	ldi r17, 0x0C * 0
	cpi r21, 6
	breq coloca_char_exit

	ldi r17, 0x0C * 1
	cpi r21, 7
	breq coloca_char_exit

	ldi r17, 0x0C * 2
	cpi r21, 8
	breq coloca_char_exit

coloca_char_exit:
	rcall copia_char

	ret

_tmr1_int:
	; guardo contexto: registros y banderas
	push r16
	in r16, SREG
	push r16
	push XH
	push XL

	inc r23

	rcall refrescar_pantalla

	pop XL
	pop XH
	pop r16
	out SREG,	r16
	pop r16
	reti

refrescar_pantalla:
	push r16
	push r17
	push r18
	push r20
	push r21

	call borra_celdas

	rcall mostrar_celdas_colocadas

	rcall mostrar_cursor

refrescar_pantalla_exit:
	pop r21
	pop r20
	pop r18
	pop r17
	pop r16

	ret

; ---------------------------------------------------------------------------------------
; mostrar_cursor
; ---------------------------------------------------------------------------------------
mostrar_cursor:
	mov r21, r22

	cpi r24, 0
	breq turnoX
	cpi r24, 1
	breq turnoO

turnoX:
	ldi r18, 0x01
	ldi r20, 0x02

	rjmp mostrar_cursor_exit

turnoO:
	ldi r18, 0x02
	ldi r20, 0x05

	rjmp mostrar_cursor_exit

mostrar_cursor_exit:
	sbrs r23, 0
	call coloca_char

	ret

; ---------------------------------------------------------------------------------------
; mostrar_celdas_colocadas
; ---------------------------------------------------------------------------------------
mostrar_celdas_colocadas:
	push XL
	push XH
	push r17

	ldi XL, low(tablero)
	ldi XH, high(tablero)
	clr r17
	dec r17

celdas_colocadas_loop:
	ld r16, X+
	inc r17

	cpi r16, 0
	breq celdas_colocadas_loop_exit

	; Letra
	mov r18, r16
	; Posición
	mov r21, r17
	; Color
	cpi r16, 1
	breq celdas_colocadas_charX_color
	cpi r16, 2
	breq celdas_colocadas_charO_color

celdas_colocadas_charX_color:
	ldi r20, 0x02
	rjmp celdas_colocadas_loop_cont

celdas_colocadas_charO_color:
	ldi r20, 0x05
	rjmp celdas_colocadas_loop_cont

celdas_colocadas_loop_cont:
	push XL
	push XH
	call coloca_char
	pop XH
	pop XL

celdas_colocadas_loop_exit:
	cpi XL, low(tablero_end)
	brne celdas_colocadas_loop
	cpi XH, high(tablero_end)
	brne celdas_colocadas_loop

	pop r17
	pop XH
	pop XL

	ret

; ---------------------------------------------------------------------------------------
; _puertoc_int
; ---------------------------------------------------------------------------------------
_puertoc_int:
	push r27
	in r27, SREG
	push r27

	sbis PINC, 1
	rjmp decrementar_contador
	sbis PINC, 2
	rjmp marcar_posicion
	sbis PINC, 3
	rjmp aumentar_contador

_puertoc_int_exit:
	clr r23
	rcall refrescar_pantalla

	pop r27
	out SREG, r27
	pop r27
	reti

 decrementar_contador:
	cpi r22, 0
	breq limite_izq
	brlo limite_izq

	dec r22
	rjmp _puertoc_int_exit

limite_izq:
	ldi r22, 8
	rjmp _puertoc_int_exit

aumentar_contador:
	cpi r22, 8
	brge limite_der

	inc r22
	rjmp _puertoc_int_exit

limite_der:
	ldi r22,0
	rjmp _puertoc_int_exit

marcar_posicion:
	ldi XL, low(tablero)
	ldi XH, high(tablero)

	push r16

	add XL, r22
	clr r16
	adc XH, r16

	mov r16, r24
	inc r16
	st X, r16

	ldi r16, 1
	eor r24, r16

	pop r16

	rjmp _puertoc_int_exit
