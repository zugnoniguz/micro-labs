;	aleatorios -	genera el vector de 512 números pseudoaleatorios en el vector de RAM msg_buffer, utilizando algoritmo
;					XORSHIFT de 32 bits (https://en.wikipedia.org/wiki/Xorshift)
;
;	Chksum_512 -	Calcula el checksum de los 512 bytes en msg_buffer,
;					guarda el resultado en r5:r4
;
;	TX_512	-		Transmite por el USART, los 1024 bytes de buffer_hamm
;
;	RX_512	-		Recibe por el usart, los 1024 bytes.
;					que transmite la otra placa y lo coloca en buffer_hamm.
;
;	_pcint1_int	-		Rutina de atención a la interrupción de los botones. Cuando entra
;					si algún botón está apretado pone el bit0 de r26 en '1'.
;
;	_tmr0_int -		Rutina de atención a la interupción del timer0, interrumpe 250 veces por
;					segundo. Esta rutina saca por el disply r5:r4 para ver el checksum.
;
;
;	Registros reservados (uso global):
;				r5:r4			-	Cheksum de 16 bits, es necesario preservar este valor para poder mostrar por display.
;				r25				-	Contiene el dígito en el display que estoy mostrando en este momento.
;				r26				-	Bit0: indica si se apretó un botón.
;
;	Otros:
; 			r19:r18:r17:r16 -	semilla de los números pseudoaleatorios ... pero se pueden usar libremente,
;								solo los usa aleatorios cuando está generando numeros.

.include "m328Pdef.inc"

; vectores de interrupción

; vector de reset (dirección de comienzo)
.ORG 0x0000
jmp system_init

; vector de cambio para los pines 8..14 (botones)
.ORG 0x0008
jmp _pcint1_int

; vector de comparación A del timer 0
.ORG 0x001C
jmp _tmr0_int

; Data segment
.DSEG

; vector de números aleatorios a transmitir.
msg_buffer: .byte 512
; solo para marcar el final del buffer
msg_buffer_end: .byte 1


.CSEG

; comienzo del programa principal
system_init:
	; Puertos:
	;	PB2 PB3 PB4 PB5	- son los LEDs del shield
	;	PB0 es SD (serial data) para el display 7seg
	;	PD7 es SCLK, el reloj de los shift registers del display 7seg
	;	PD4 es LCHCLK, el reloj para decodificar los datos de los shift registers al display 7seg

	; PB0,2,3,4,5 son salidas
	ldi r16, 0b00111101
	out DDRB, r16
	; apago los LEDs
	ldi r16, 0b00111100
	out PORTB, r16

	; 3 botones del shield son entradas
	ldi r16, 0b00000000
	out DDRC, r16

	; PD0,4,7 son salidas
	ldi r16, 0b10010001
	out DDRD, r16

	; SCLK a 0
	cbi PORTD, 7
	; LCHCLK a 0
	cbi PORTD, 4

	; Configuración de interrupción por cambio de estado de botones
	ldi r16, 0b00000010
	; Recepción de interrupciones de PCI1 (PCI8:PCI14)
	sts PCICR, r16
	ldi r16, 0b00001110
	; Detectar cambios en (PCI9,PCI10,PCI11)
	sts PCMSK1, r16

	; Configuración de interrupciones TMR0
	; Freq = Fclk/(prescaler * (1+OCR0A)
	ldi r16, 0b00000010
	; Cuenta hasta OCR0A y vuelve a cero (Clear Timer on Compare) (cada compare dispara la interrupción).
	out TCCR0A, r16
	ldi r16, 0b00000100
	; prescaler = 256
	out TCCR0B, r16
	ldi r16, 249
	; comparo con 249
	out OCR0A, r16
	ldi r16, 0b00000010
	; se habilitan interrupciones del timer
	sts TIMSK0, r16

	; Inicializo USART para transmitir
	; TODO: Add docs
	ldi r16, 0b00001000
	sts UCSR0B, r16
	ldi r16, 0b00000110
	sts UCSR0C, r16
	ldi r16, 0x00
	sts UBRR0H, r16
	ldi r16, 0x67
	sts UBRR0L, r16

	; TODO: This should be a memory location
	; indica qué digito sale del display (00010000, 00100000, 01000000, 10000000)
	ldi r25, 0x10

	; habilito interrupciones (display y botones)
	sei

start:
	; bandera teclado
	ldi r26, 0x00
	; checksum a 0
	mov r5, r26
	mov r4, r26

	rjmp modo_transmisor


modo_transmisor:
	ldi r16, 0xA3				;semilla de los números seudo-aleatorios (arbitraria)
	ldi r17, 0x82
	ldi r18, 0xF0
	ldi r19, 0x05

modo_transmisor_2:
	rcall aleatorios					;Genero los números aleatorios (genero un msg_buffer aleatorio)
	rcall Chksum_512					;Genero Checksum
	ldi r26, 0

wait_4TX:							;acá me pongo a esperar que alguien presione cualquier botón
	sbrs r26, 0			    ;Nota: la interrupcion del boton pone r26-bit0 en 1.
	rjmp wait_4TX

	cli									;deshabilito interrupciones para display y botones
	rcall TX_512
	sei									;habilito interrupciones para disply y botones

	rjmp modo_transmisor_2				;empiezo todo de nuevo



modo_receptor:
	ldi		r26,	0

wait_4RX:							;acá me pongo a esperar que alguien presione cualquier botón
	sbrs r26, 0			    ;Nota: la interrupcion del boton cambia r26:0.
	rjmp wait_4RX

	; recibo 512 bytes y los dejo en msg_buffer
	lds r16, UDR0			;me aseguro que el buffer esté vacio
	lds r16, UDR0
	lds r16, UDR0
	cli									;deshabilito interrupciones para disply y botones
	rcall RX_512					    ;recibo 512 bytes por poling (es muy ineficiente)
	sei									;habilito interrupciones para disply y botones
	rcall Chksum_512					;calculo el nuevo Cheksum ... debería ser igual al original incluso si introduje errores
	rjmp modo_receptor



;---------------------------------------------------------------------------------
;Chksum	- calcula el Checksum del vector msg_buffer (512 valores, r5:r4 = chksum)
;---------------------------------------------------------------------------------
Chksum_512:
	;apunto Y al primer byte del mensaje

	;implementar
	;implementar
	;implementar

chksum_loop:
	;traigo 1 byte a sumar
	;la suma la voy acumulando en r5:r4

	;implementar
	;implementar
	;implementar

	ret

;-----------------------------------------------------------------------------------------
;TX - rutina de transmisión serial USART. Transmite los 512 bytes de msg_buffer
;-----------------------------------------------------------------------------------------
TX_512:
;inicialización
	;apunto Z al primer byte del vector de 512 bytes
	;configuro usart como transmisor (UCSR0B)

TX_loop1:
	;traigo el Byte a transmitir
	;pongo a transmitir (UDR0)

TX_loop2:
	;espero a que termine la transmisión del byte por poling (UCSR0A)


;chequeo si llegué al final del buffer

	ret



;------------------------------------------------------------------------------
;RX - rutina de recepción usart. Recibe 1024 bytes y los deja en de msg_buffer
;IMPORTANTE: acá está SIN INTERRUPCIONES lo cual es ineficiente
;------------------------------------------------------------------------------
RX_512:
;inicialización
	;apunto Z al primer byte del vector de 512 bytes
	;configuro el USART como receptor (UCSR0B)

RX_Wait:
	;ahora poling para esperar recibir algo	(UDR0)

	;llego aquí solo si recibí algo
	; guardo lo que recibí


	;chequeo si llegué al final del buffer

	ret






;-------------------------------------------------------------------------------------
;					*****			RUTINAS			*****
;-------------------------------------------------------------------------------------

; genera 512 bytes pseudo-aleatorios en msg_buffer
aleatorios:
	; Y apunta al primer byte del buffer
	ldi r28, low(msg_buffer)
	ldi r29, high(msg_buffer)

aleatorios_loop:
	; genero un número de 32bits nuevo usando XORSHIFT de 32 bits (https://en.wikipedia.org/wiki/Xorshift)
	ldi r20, 13
	call aleatorios_loop_l
	ldi r20, 17
	call aleatorios_loop_r
	ldi r20, 5
	call aleatorios_loop_l

	; ya se calculó el numero pseudo-aleatorio de 32bits, voy a guardar los 32 bits (podria solo ir guardando de a 8)

	; el número aleatorio lo guardo a partir de adonde apunta el registro Y, voy recorriendo hasta 512
	st Y+, r16
	st Y+, r17
	st Y+, r18
	st Y+, r19
	cpi YL, low(msg_buffer_end)
	brne aleatorios_loop
	cpi YH, high(msg_buffer_end)
	brne aleatorios_loop
	ret

aleatorios_loop_l:
	mov r0, r16
	mov r1, r17
	mov r2, r18
	mov r3, r19
ale_rota_l:
	clc
	rol r0
	rol r1
	rol r2
	rol r3
	dec r20
	brne ale_rota_l
	rjmp ale_rota_out

aleatorios_loop_r:
	mov r0, r16
	mov r1, r17
	mov r2, r18
	mov r3, r19

ale_rota_r:
	clc
	ror r3
	ror r2
	ror r1
	ror r0
	dec r20
	brne ale_rota_r

ale_rota_out:
	eor r16, r0
	eor r17, r1
	eor r18, r2
	eor r19, r3
	ret



;-------------------------------------------------------------------------------------
;   SACANUM
;-------------------------------------------------------------------------------------
;rutina que saca un número por el display,
;paso en r16 el número a sacar en el nibble bajo, y en cuál de los 4 dígitos es, en el nibble alto de r16
;r16 = 1000xxxx dígito menos significativo, r16 = 0100xxxx segundo dígito, r16 = 0010xxxx tercer dígito, r16 = 0001xxxx dígito más significativo.
;Ejemplo:	r16 = 0b01000111 = 0x47, saca el número 7 en el dígito 2 del display de 7segmentos.

sacanum:
	push r16					; guardo una copia de r16
	ldi zh, high(segmap<<1) ; Initialize Z-pointer
	ldi zl, low(segmap<<1)
	andi r16, 0x0F
	add zl, r16
	clr r16
	adc zh, r16
	lpm r16, Z				; traigo de la memoria de Programa el 7-Seg
	call sacabyte
	pop r16
	call sacabyte
	sbi PORTD, 4		;PD.4 a 1, es el reloj del latch
	cbi PORTD, 4		;PD.4 a 0, es el reloj del latch
	ret

;-------------------------------------------------------------------------------------
;   SACABYTE
;-------------------------------------------------------------------------------------

sacabyte:
	ldi r17, 0x08

loop_byte1:
	; SCLK = 0
	cbi PORTD, 7
	lsr r16
	brcs loop_byte2
	; Si el LSB de r16 era 0, SD = 0
	cbi PORTB, 0
	rjmp loop_byte3
loop_byte2:
	; Si el LSB de r16 era 1, SD = 1
	sbi PORTB, 0
loop_byte3:
	; Después de escribir a SD, SCLK = 1
	sbi PORTD, 7
	dec r17
	brne loop_byte1
	ret

segmap:
.db	0b00000011, 0b10011111,	0b00100101, 0b00001101 ;"0" "1" "2" "3"
.db	0b10011001,	0b01001001, 0b01000001,	0b00011111 ;"4" "5" "6" "7"
.db	0b00000001, 0b00001001, 0b00010001, 0b11000001 ;"8" "9" "A" "b"
.db	0b01100011, 0b10000101, 0b01100001, 0b01110001 ;"C" "d" "E" "F"


; ------------------------------------------------
; Rutina de atención a la interrupción del Timer0.
; ------------------------------------------------
; como fue configurado el reloj interrumpe 250 veces/segundo
;
; Esta rutina hace varias cosas:
; 1 - salva contexto de registros que utiliza
; 2	- cada entrada a la interupción se saca un dígito del checksum por el display
; Registros utilizados:
;				r25 - indica el próximo digito a sacar, r25 = 00010000 ; 00100000 ; 01000000 ; 10000000 cambia cada entrada a la rutina.

_tmr0_int:

	;implemente el codigo aqui
	;implemente el codigo aqui
	;implemente el codigo aqui

	reti

; ---------------------------------------------------------------------------
; Rutina de atención a la interrupción por cambio en el estado de los botones
; ---------------------------------------------------------------------------
; recordar que se configuró la detección por cambio para que ante un cambio en el valor lógico de cualquiera de los 3 botones
; se dispara la interrupción. LA interrupción no distingué qué botón se apretó de modo que lo verifico dentro de la interrupción.
; Los botones se encuentran en PC.1, PC.2, PC.3 y recordar del esquemático del shield, que son activos por nivel bajo.
;
_pcint1_int:

	;implemente el codigo aqui
	;implemente el codigo aqui
	;implemente el codigo aqui

	reti
