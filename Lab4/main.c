#define F_CPU 16000000UL

#include <avr/io.h>
#include <avr/interrupt.h>
#include "defs.h"
#include "7seg.h"

#define SAMPLE_TIME 3
#define MAX_SAMPLES 50

typedef struct {
	u32 accumulator;
	u16 average;
	u16 samples;
} ADCState;
ADCState adcstate = {0};

ISR(ADC_vect) {
	u16 duty = ADC;

	// (Vref/1024)*(V/mV) = (5/1024)*1000 = 5000/1024
	// (No simplifico los números porque el compilador lo optimiza más con los
	// números grandes y resulta en binario más chico)
	// u16 value = (duty * 625) / 128;
	u16 value = (duty * 5000) / 1024;

	adcstate.accumulator += value;
	if (++adcstate.samples == MAX_SAMPLES) {
		adcstate.average = adcstate.accumulator / MAX_SAMPLES;
		adcstate.accumulator = 0;
		adcstate.samples = 0;
	}
}

ISR(TIMER0_COMPA_vect) {
}

void loop() {
	show_4digit(adcstate.average);
}

int main(void) {
	// Deshabilita interrupciones globales (por reset)
	cli();

	// 4 LEDs del shield son salidas, y 0 es SDI del 7seg
	DDRB = BIT_MASK(DDB5) | BIT_MASK(DDB4) | BIT_MASK(DDB3) | BIT_MASK(DDB2) | BIT_MASK(DDB0);
	// Empiezan apagados
	PORTB = BIT_MASK(PORTB5) | BIT_MASK(PORTB4) | BIT_MASK(PORTB3) | BIT_MASK(PORTB2);

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
	// 1mS at 1024
	OCR0A = (u8)(15.6 * SAMPLE_TIME);
	// Habilita recepción de interrupciones del timer0
	// Output Compare Interrupt Enable 0 A
	TIMSK0 = BIT_MASK(OCIE0A);

	// VRef = Vcc y elijo ADC0 con el mux
	ADMUX = BIT_MASK(REFS0);
	// ADEN: Enable ADC
	// ADSC: Start Conversion
	// ADATE: Enable on high trigger (of clock)
	// ADIE: Enable interrupt
	// ADPS2, ADPS1, ADPS0: Prescaler = 128 (for clock)
	ADCSRA = BIT_MASK(ADEN) | BIT_MASK(ADSC) | BIT_MASK(ADATE) | BIT_MASK(ADIE) | BIT_MASK(ADPS2) | BIT_MASK(ADPS1) | BIT_MASK(ADPS0);
	// Selects Timer0 Compare A
	ADCSRB = BIT_MASK(ADTS1) | BIT_MASK(ADTS0);

	// Interrupciones globales
	sei();

	while (1) {
		loop();
	}
}

