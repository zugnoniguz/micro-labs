; Lab3
; Created: 9/23/2024 7:53:38 AM
; Author : Guzman Zugnoni

.org 0x00
jmp setup

; salto a la subrutina de comparacion del timer0
.org 0x001C
jmp _tmr0_int

setup:
	cli
	; configuro los puertos:
	; PB2 PB3 PB4 PB5	- son los LEDs del shield
	; PB0 es SD (serial data) para el display 7seg
	; PD7 es SCLK, el reloj de los shift registers del display 7seg
	; PD4 es LCH, transfiere los datos que ya ingresaron en serie, a la salida del registro paralelo
	; PC son entradas para los botones

	ldi r16, 0b00111101
	; 4 LEDs del shield son salidas
	out	DDRB, r16
	; Los LEDs empiezan apagados
	out	PORTB, r16

	ldi	r16, 0b00000000
	; 3 botones del shield son entradas
	out	DDRC, r16

	ldi	r16, 0b10010000
	; PD4 y PD7 son salidas
	out	DDRD, r16
	; PD7 (SCLK) a 0
	cbi	PORTD, 7
	; PD4 (LCHCLK) a 0
	cbi	PORTD, 4

	; configuro para que TMR0 cuente hasta OCR0A
	; y luego reinicie su valor
	; (CTC (Clear Timer on Compare))
	ldi r16, 0b00000010
	out TCCR0A, r16

	; prescaler = 1024
	ldi r16, 0b00000101
	out TCCR0B, r16

	; comparo con 125
	ldi r16, 124
	out OCR0A, r16

	; habilito la interrupción del timer (falta global)
	ldi r16, 0b00000010
	sts TIMSK0, r16

	; contador hasta 125 para ajustar el reloj a 1Hz
	eor r24, r24

	; Apago todo el 7seg
	ldi r16,0b11111111
	ldi r17,0b11110000
	call bin7seg

	; segundos1
	eor r20, r20
	; segundos2
	eor r21, r21
	; minutos1
	eor r22, r22
	; minutos2
	eor r23, r23

	sei



;-------------------------------------------------------------------------------------
; Observar la rutina sacanum, utiliza r16 para los LEDs del numero que quiero mostar, r17 para indicar dónde lo quiero mostrar
; En main: cargo en r16 los leds a encender para formar el '0', y en r17 indico es el primero de los 4 dígitos.
; Luego se llama la rutina de sacar la iformación serial.
;
; En el ejemplo para ver el numero 0, r16 debe ser 0b00000011 (orden de segmentos es abcdefgh, h es el punto)
; y r17 debe ser 0b00010000 (dígito display de más a la derecha)


main:
	mov r16, r23
	ldi r17, 0b10000000
	call dec7seg

	mov r16, r22
	ldi r17, 0b01000000
	call dec7segdot

	mov r16, r21
	ldi r17, 0b00100000
	call dec7seg

	mov r16, r20
	ldi r17, 0b00010000
	call dec7seg

	rjmp main

dec7segdot:
	call dec7segval
	ori r16, 0x01

	; dependemos de este ret
	rjmp bin7seg


dec7seg:
	call dec7segval

	; dependemos de este ret
	rjmp bin7seg

dec7segval:
	push r19
	in r19, SREG
	push r19

	mov r19, r16

	ldi r16, 0b00011001
	cpi r19, 9
	breq dec7segval_exit

	ldi r16, 0b00000001
	cpi r19, 8
	breq dec7segval_exit

	ldi r16, 0b00011111
	cpi r19, 7
	breq dec7segval_exit

	ldi r16, 0b01000001
	cpi r19, 6
	breq dec7segval_exit

	ldi r16, 0b01001001
	cpi r19, 5
	breq dec7segval_exit

	ldi r16, 0b10011001
	cpi r19, 4
	breq dec7segval_exit

	ldi r16, 0b00001101
	cpi r19, 3
	breq dec7segval_exit

	ldi r16, 0b00100101
	cpi r19, 2
	breq dec7segval_exit

	ldi r16, 0b10011111
	cpi r19, 1
	breq dec7segval_exit

	ldi r16, 0b00000011
	cpi r19, 0
	breq dec7segval_exit

	ret

dec7segval_exit
	pop r19
	out SREG, r19
	pop r19

	ret

; La rutina to_7seg envía r16 y r17 al display de 7 segmentos
; r16 - es el estado de un digito.
; r17 - contiene el estado de un digito en sus primeros 4 bits.
bin7seg:
	push r19
	in r19, SREG
	push r19

	call send_data
	mov r16, r17
	call send_data

	; Toggle LCHCLK
	sbi PORTD, 4
	cbi	PORTD, 4

	pop r19
	out SREG, r19
	pop r19

	ret

; Esta subrutina manda un byte a los decodificadores del 7seg
send_data:
	; contador para 8 bits
	ldi		r18, 0x08

loop:
	; SFTCLK = 0
	cbi PORTD, 7
	; bit de la derecha se coloca en C
	sbi PORTB, 0
	lsr r16
	; SDI = 1
	brcs loop_exit
	; Si el bit era 0, no salto y pongo en 0
	cbi PORTB, 0
	rjmp loop_exit

loop_exit:
	; SFTCLK = 1
	sbi PORTD, 7
	dec	r18
	; cuando r18 llega a 0 me voy
	brne loop
	ret

_tmr0_int:
	push r16
	in r16, SREG
	push r16

	inc r24
	; frq_tmr / 125 = 1Hz
	cpi r24, 124

	breq _tmr0_eq
	rjmp _tmr0_exit

; reloj de 1Hz
; al final de la subrutina el puntero de la pila debe permanecer igual
_tmr0_eq:
	push r19
	in r19, SREG
	push r19

	eor r24, r24

	call inc_timer

	pop r19
	out SREG, r19
	pop r19

	rjmp _tmr0_exit

_tmr0_exit:
	pop r16
	out SREG, r16
	pop r16
	reti


inc_timer:
	inc r20
	cpi r20, 10
	breq s1_overflow

	ret

s1_overflow:
	eor r20, r20
	inc r21
	cpi r21, 6
	breq s2_overflow

	ret

s2_overflow:
	eor r21, r21
	inc r22
	cpi r22, 10
	breq m1_overflow

	ret

m1_overflow:
	eor r22, r22
	inc r23
	ldi r16, 6
	cpse r23, r16
	ret

	eor r23, r23
	ret
