
;
;	Laboratorio 5 , por ahora contiene las siguientes rutinas 
;
;	aleatorios -	genera el vector de 512 números pseudoaleatorios en el vector de RAM buffer_msg, utilizando algoritmo 
;					XORSHIFT de 32 bits (https://en.wikipedia.org/wiki/Xorshift)	
;
;	Chksum_512 -	Calcula el checksum de los 512 bytes en buffer_msg, 
;					guarda el resultado en r5:r4
;					
;	TX_512	-		Transmite por el USART, los 1024 bytes de buffer_hamm 
;
;	RX_512	-		Recibe por el usart, los 1024 bytes.
;					que transmite la otra placa y lo coloca en buffer_hamm.
;  
;	_pcint1	-		Rutina de atención a la interrupción de los botones. Cuando entra
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

; empiezo con los vectores de interrupción (tal como labs anteriores)
.ORG 0x0000
	jmp		start		;dirección de comienzo (vector de reset)  
.ORG 0x0008
	jmp		_pcint1		;salto a la rutina de atención a pcint1, interrupción por cambio para los botones
.ORG 0x001C 
	jmp		_tmr0_int	;salto atención a rutina de comparación A del timer 0
; ---------------------------------------------------------------------------------------

;memoria RAM
.DSEG
buffer_msg:		.byte 512		;reservo 512 bytes para el vector de números aleatorios a transmitir.
bmsg_end:		.byte 1			;solo para marcar el final del buffer


; comienzo del programa principal
.CSEG
start:	
	call	system_init
	ldi		r26,	0x00				;bandera teclado
	mov		r5,		r26					;checksum a 0
	mov		r4,		r26
	sei									;habilito interrupciones para disply y botones

	jmp		modo_transmisor
;	jmp		modo_receptor

modo_transmisor:

	ldi		r16,	0xA3				;semilla de los números seudo-aleatorios (arbitraria)
	ldi		r17,	0x82
	ldi		r18,	0xF0
	ldi		r19,	0x05
modo_transmisor_2:
	rcall	aleatorios					;Genero los números aleatorios (genero un buffer_msg aleatorio)

	rcall	Chksum_512					;Genero Checksum

	ldi		r26,	0
wait_4TX:							;acá me pongo a esperar que alguien presione cualquier botón
	sbrs	r26,	0			    ;Nota: la interrupcion del boton pone r26-bit0 en 1.	
	rjmp	wait_4TX				

	cli									;deshabilito interrupciones para display y botones
	rcall	TX_512
	sei									;habilito interrupciones para disply y botones
	
	rjmp	modo_transmisor_2				;empiezo todo de nuevo

;-------------------------------------- 
modo_receptor:

	ldi		r26,	0
wait_4RX:							;acá me pongo a esperar que alguien presione cualquier botón
	sbrs	r26,	0			    ;Nota: la interrupcion del boton cambia r26:0.	
	rjmp	wait_4RX				

;ahora recibo 512 bytes y los dejo en buffer_msg
	lds		r16,	UDR0			;me aseguro que el buffer esté vacio	
	lds		r16,	UDR0
	lds		r16,	UDR0					
	cli									;deshabilito interrupciones para disply y botones
	rcall	RX_512					    ;recibo 512 bytes por poling (es muy ineficiente)
	sei									;habilito interrupciones para disply y botones
	rcall	Chksum_512					;calculo el nuevo Cheksum ... debería ser igual al original incluso si introduje errores
	rjmp	modo_receptor



;---------------------------------------------------------------------------------
;Chksum	- calcula el Checksum del vector buffer_msg (512 valores, r5:r4 = chksum)
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
;TX - rutina de transmisión serial USART. Transmite los 512 bytes de buffer_msg
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
;RX - rutina de recepción usart. Recibe 1024 bytes y los deja en de buffer_msg
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
						





//--------------------------------------------
system_init:
;configuro los puertos:
;	PB2 PB3 PB4 PB5	- son los LEDs del shield
;	PB0 es SD (serial data) para el display 7seg
;	PD7 es SCLK, el reloj de los shift registers del display 7seg
;	PD4 transfiere los datos que ya ingresaron en serie, a la salida del registro paralelo 

    ldi		r16,	0b00111101	
	out		DDRB,	r16			;4 LEDs del shield son salidas
	out		PORTB,	r16			;apago los LEDs
	ldi		r16,	0b00000000	
	out		DDRC,	r16			;3 botones del shield son entradas
	ldi		r16,	0b10010001
	out		DDRD,	r16			;configuro PD.0, PD.4 y PD.7 como salidas
	cbi		PORTD,	7			;PD.7 a 0, es el reloj serial del  Display, inicializo a 0
	cbi		PORTD,	4			;PD.4 a 0, es el reloj del latch del Display, inicializo a 0
;-------------------------------------------------------------------------------------
;Configuro interrupcion por cambio en PC.1, PC.2, PC.3.
	ldi		r16,	0b00000010
	sts		PCICR,	r16			;habilito PCI1 que es (PCI8:PCI14)
	ldi		r16,	0b00001110
	sts		PCMSK1,	r16			;habilito detectar cambios en PortC 1,2,3 (PCI9,PCI10,PCI11)
;-------------------------------------------------------------------------------------
;Configuro el TMR0 y su interrupcion.
	ldi		r16,	0b00000010	
	out		TCCR0A,	r16			;configuro para que cuente hasta OCR0A y vuelve a cero (reset on compare), ahí dispara la interrupción
	ldi		r16,	0b00000100	
	out		TCCR0B,	r16			;prescaler = 256
	ldi		r16,	249	
	out		OCR0A,	r16			;comparo con 249
	ldi		r16,	0b00000010	
	sts		TIMSK0,	r16			;habilito la interrupción (falta habilitar global)
;-------------------------------------------------------------------------------------
;Inicializo USART para transmitir
	ldi		r16,	0b00001000	
	sts		UCSR0B,	r16			
	ldi		r16,	0b00000110	
	sts		UCSR0C,	r16		
	ldi		r16,	0x00			//9600 baudios (baudio = bit/segundo)
	sts		UBRR0H,	r16		
	ldi		r16,	0x67		
	sts		UBRR0L,	r16		

;-------------------------------------------------------------------------------------
;Inicializo algunos registros que voy a usar como variables.
	ldi		r25,	0x10		;inicializo r25 para el display r25 = 00010000 ; 00100000 ; 01000000 ; 10000000 indica qué digito sale
;-------------------------------------------------------------------------------------
;Fin de la inicialización
	ret	

;-------------------------------------------------------------------------------------
;					*****			RUTINAS			*****
;-------------------------------------------------------------------------------------



;------------------------------------------------------------
; ALEATORIOS
;--------------------------------------------------------------
;rutina que genera 512 bytes pseudoaleatorios en buffer_msg

aleatorios:			
	ldi		r28,	low(buffer_msg)		;apunto Y al primer byte del mensaje
	ldi		r29,	high(buffer_msg)
ale_loop:
; genero un número de 32bits nuevo usando XORSHIFT de 32 bits (https://en.wikipedia.org/wiki/Xorshift)	
	ldi		r20,	13
	call	ale_loop_l
	ldi		r20,	17
	call	ale_loop_r
	ldi		r20,	5
	call	ale_loop_l
;------ acá ya tengo el numero pseudo-aleatorio de 32bits, voy a guardar los 32 bits (podria solo ir guardando de a 8)

	st		Y+,		r16					;el número aleatorio lo guardo a partir de adonde apunta el registro Y, voy recorriendo hasta 512
	st		Y+,		r17	
	st		Y+,		r18	
	st		Y+,		r19	
	cpi		YL,		low(bmsg_end)	
	brne	ale_loop
	cpi		YH,		high(bmsg_end)
	brne	ale_loop
	ret

ale_loop_l:
	mov		r0,		r16
	mov		r1,		r17
	mov		r2,		r18
	mov		r3,		r19
ale_rota_l:
	clc
	rol		r0
	rol		r1
	rol		r2
	rol		r3
	dec		r20
	brne	ale_rota_l
	rjmp	ale_rota_out

ale_loop_r:
	mov		r0,		r16
	mov		r1,		r17
	mov		r2,		r18
	mov		r3,		r19
ale_rota_r:
	clc
	ror		r3
	ror		r2
	ror		r1
	ror		r0
	dec		r20
	brne	ale_rota_r

ale_rota_out:
	eor		r16,		r0
	eor		r17,		r1
	eor		r18,		r2
	eor		r19,		r3
	ret



;-------------------------------------------------------------------------------------
;   SACANUM
;-------------------------------------------------------------------------------------
;rutina que saca un número por el display, 
;paso en r16 el número a sacar en el nibble bajo, y en cuál de los 4 dígitos es, en el nibble alto de r16
;r16 = 1000xxxx dígito menos significativo, r16 = 0100xxxx segundo dígito, r16 = 0010xxxx tercer dígito, r16 = 0001xxxx dígito más significativo.
;Ejemplo:	r16 = 0b01000111 = 0x47, saca el número 7 en el dígito 2 del display de 7segmentos.

sacanum: 
	push	r16					; guardo una copia de r16
	ldi		zh, high(segmap<<1) ; Initialize Z-pointer
	ldi		zl, low(segmap<<1)
	andi	r16, 0x0F
	add		zl, r16
	clr		r16
	adc		zh, r16 
	lpm		r16, Z				; traigo de la memoria de Programa el 7-Seg
	call	sacabyte
	pop		r16
	call	sacabyte
	sbi		PORTD, 4		;PD.4 a 1, es el reloj del latch
	cbi		PORTD, 4		;PD.4 a 0, es el reloj del latch
	ret



;-------------------------------------------------------------------------------------
;   SACABYTE
;-------------------------------------------------------------------------------------

sacabyte:
;Voy a sacar un byte por el 7seg
	ldi		r17, 0x08
loop_byte1:
	cbi		PORTD, 7		;SCLK = 0
	lsr		r16
	brcs	loop_byte2		;salta si C=1
	cbi		PORTB, 0		;SD = 0
	rjmp	loop_byte3
loop_byte2:
	sbi		PORTB, 0		;SD = 1
loop_byte3:
	sbi		PORTD, 7		;SCLK = 1
	dec		r17
	brne	loop_byte1;
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
_pcint1:
	
	;implemente el codigo aqui
	;implemente el codigo aqui	
	;implemente el codigo aqui
	
	reti