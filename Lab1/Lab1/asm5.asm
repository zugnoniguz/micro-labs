;
; AssemblerApplication6.asm
;
; Created: 31/8/2021 15:27:54
; Author : Administrador
;
.include "./m328Pdef.inc"
.equ first_delay = 0xFF
.equ second_delay = 0xFF
.equ third_delay = 0x51
.org 0x00 ;aca arranca el programa

setup:
	ldi r16, 0b00111100
	out DDRB, r16
	ldi r16, 0xFF
	out PORTB, r16

start:
	ldi r16, 0b11111011
	out PORTB, r16
	rcall resetdelay
	rcall delay0
	ldi r16, 0b11111111
	out PORTB, r16
	rcall resetdelay
	rcall delay0

resetdelay:
	; (6 + (3*r17 + 5)*r18)*r19 + 3 (ninguno es 0)
	ldi r17, first_delay
	ldi r18, second_delay
	ldi r19, third_delay
	ret

delay0:
	dec r17
	brne delay0
	rjmp delay1

delay1:
	ldi r17, first_delay
	dec r18
	brne delay0
	rjmp delay2

delay2:
	ldi r17, first_delay
	ldi r18, second_delay
	dec r19
	brne delay0
	ret