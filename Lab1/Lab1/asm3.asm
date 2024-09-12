;
; AssemblerApplication6.asm
;
; Created: 31/8/2021 15:27:54
; Author : Administrador
;
.include "./m328Pdef.inc"
.org 0x00 ;aca arranca el programa

setup:
	ldi r16, 0b00111100
	out DDRB, r16
	ldi r16, 0xFF
	out PORTB, r16

start:
	ldi r16, 0b11111011
	sec

	out PORTB, r16
	rol r16
	out PORTB, r16
	rol r16
	out PORTB, r16
	rol r16
	out PORTB, r16
	
	rjmp start