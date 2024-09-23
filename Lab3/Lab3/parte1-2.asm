;
; Lab3
; Created: 9/23/2024 7:53:38 AM
; Author : Guzman Zugnoni

.org 0x00
jmp setup

setup:
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

	; Apago todo el 7seg
	ldi r16,0b11111111
	ldi r17,0b11110000
	call bin7seg



;-------------------------------------------------------------------------------------
; Observar la rutina sacanum, utiliza r16 para los LEDs del numero que quiero mostar, r17 para indicar dónde lo quiero mostrar
; En main: cargo en r16 los leds a encender para formar el '0', y en r17 indico es el primero de los 4 dígitos.
; Luego se llama la rutina de sacar la iformación serial.
;
; En el ejemplo para ver el numero 0, r16 debe ser 0b00000011 (orden de segmentos es abcdefgh, h es el punto)
; y r17 debe ser 0b00010000 (dígito display de más a la derecha)


main:
	ldi r17, 0b1000_0000

	ldi r16, 9
	call dec7seg
	lsr r17

	ldi r16, 0
	call dec7seg
	lsr r17

	ldi r16, 7
	call dec7seg
	lsr r17

	ldi r16, 8
	call dec7seg

	rjmp main



dec7seg:
	push r19
	in r19, SREG
	push r19
	push r20

	mov r19, r16

	ldi r16, 0b00011001
	cpi r19, 9
	breq dec7seg_h

	ldi r16, 0b00000001
	cpi r19, 8
	breq dec7seg_h

	ldi r16, 0b00011111
	cpi r19, 7
	breq dec7seg_h

	ldi r16, 0b01000001
	cpi r19, 6
	breq dec7seg_h

	ldi r16, 0b01001001
	cpi r19, 5
	breq dec7seg_h

	ldi r16, 0b10011001
	cpi r19, 4
	breq dec7seg_h

	ldi r16, 0b00001101
	cpi r19, 3
	breq dec7seg_h

	ldi r16, 0b00100101
	cpi r19, 2
	breq dec7seg_h

	ldi r16, 0b10011111
	cpi r19, 1
	breq dec7seg_h

	ldi r16, 0b00000011
	cpi r19, 0
	breq dec7seg_h

	ret

dec7seg_h:
	call bin7seg

	pop r20
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
