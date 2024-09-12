; Empiezo con los vectores de interrupción
.org 0x0000
jmp	setup ; dirección de comienzo (vector de reset)

.org 0x001C 
jmp	_tmr0_int ; salto atención a rutina de comparación A del timer 0


setup:
	; PB{2,3,4,5} - son los LEDs del shield
    ldi	r16, 0b00111101	
	; Los 4 LEDs son salidas
	out	DDRB, r16		
	; apago los LEDs
	out PORTB, r16

	; PC{2,3,4} - son los botones del shield
	ldi	r16, 0b00000000	
	; 3 botones del shield son entradas
	out	DDRC, r16

	; configuro para que TMR0 cuente hasta OCR0A 
	; y luego reinicie su valor 
	; (CTC (Clear Timer on Compare))
	ldi	r16, 0b00000010
	out TCCR0A,	r16

	; prescaler = 1024
	ldi	r16, 0b00000101
	out	TCCR0B,	r16
	
	; comparo con 125
	ldi	r16, 124
	out	OCR0A, r16
	
	; habilito la interrupción del timer (falta global)
	ldi	r16, 0b00000010
	sts	TIMSK0,	r16

	; Inicializo algunos registros que voy a usar como variables.
	; Utilizaré r24 como contador genérico
	ldi	r24, 0x00
	; r17 como bandera para el led
	ldi r17, 0x00
	sei

start:
loop1:
	nop
	nop
	nop
	nop
	ori r16, 0xFF
	nop
	nop
	nop
	brne loop1

; Rutinas de interrupción

; ------------------------------------------------
; Rutina de atención a la interrupción del Timer0.
; ------------------------------------------------
; recordar que el timer 0 fue configurado para interrumpir cada 125 ciclos (5^3), y tiene un prescaler 1024 = 2^10.
; El reloj de I/O está configurado @ Fclk = 16.000.000 Hz = 2^10*5^6; entonces voy a interrumpir 125 veces por segundo
; esto sale de dividir Fclk por el prescaler y el valor de OCR0A.

_tmr0_int:
	push r16
	in r16, SREG
	push r16

	ldi r16, 124
	inc r24
	cp r24, r16

	breq _tmr0_eq
	rjmp _tmr0_exit

_tmr0_eq:
	eor r24, r24
	push r18
	ldi r18, 0b00011110
	eor r17, r18
	out PORTB, r17
	pop r18
	rjmp _tmr0_exit

_tmr0_exit:
	pop r16
	out SREG, r16
	pop r16
	reti