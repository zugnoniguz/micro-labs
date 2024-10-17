#define F_CPU (16 * 1000000UL)
// #define __AVR_ATmega328P__ 1

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdbool.h>
#include <util/delay.h>
#include "7seg.h"
#include "defs.h"

void setup() {
	// Deshabilita interrupciones globales (por reset)
	cli();

	// 4 LEDs del shield son salidas, y 0 es SDI del 7seg
	DDRB = BIT_MASK(DDB5) | BIT_MASK(DDB4) | BIT_MASK(DDB3) | BIT_MASK(DDB2) |
		BIT_MASK(DDB0);
	// Empiezan apagados
	PORTB =
		BIT_MASK(PORTB5) | BIT_MASK(PORTB4) | BIT_MASK(PORTB3) | BIT_MASK(PORTB2);

	// 3 botones del shield son entradas
	DDRC = (0 << DDC1) | (0 << DDC2) | (0 << DDC3);

	// PD4 (LCHCLK) y PD7 (SCLK) son salidas
	DDRD = BIT_MASK(PORTD7) | BIT_MASK(PORTD4);
	// SCLK empieza en 0
	CLEAR_BIT(PORTD, PORTD7);
	// LCHCLK empieza en 0
	CLEAR_BIT(PORTD, PORTD4);

	// TMR0 cuenta hasta OCR0A y luego reinicia su valor (CTC (Clear Timer on
	// Compare))
	TCCR0A = BIT_MASK(WGM01);
	// prescaler = 1024 y termino de configurar CTC
	TCCR0B = BIT_MASK(CS02) | BIT_MASK(CS00);
	OCR0A = 156;
	// Habilita recepción de interrupciones del timer0
	// Output Compare Interrupt Enable 0 A
	TIMSK0 = BIT_MASK(OCIE0A);

	ADMUX = BIT_MASK(REFS0) | BIT_MASK(MUX0);
	ADCSRA = BIT_MASK(ADEN) | BIT_MASK(ADSC) | BIT_MASK(ADATE) | BIT_MASK(ADIE);
	ADCSRB = BIT_MASK(ADTS1) | BIT_MASK(ADTS0);

	// Habilita interrupciones globales
	sei();
}

u32 accumulator = 0;
u16 average = 0;
u16 samples = 0;

ISR(ADC_vect) {
	u16 duty = ADC;
	OCR1B = duty;

	accumulator += duty;
	samples++;
	if (samples == 100) {
		average = accumulator / 100;
		accumulator = 0;
		samples = 0;
	}
}

void show_4digit(u16 val) {
	dec_to_7seg(val % 10, 3);
	dec_to_7seg((val / 10) % 10, 2);
	dec_to_7seg((val / 100) % 10, 1);
	dec_to_7seg((val / 1000) % 10, 0);
}

void show_samples() { show_4digit(accumulator); }

void loop() { show_samples(); }

int main(void) {
	setup();

	while (true) {
		loop();
	}
}

