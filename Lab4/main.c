#define F_CPU (16 * 1000000UL)
// #define __AVR_ATmega328P__ 1

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdbool.h>
#include <util/delay.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef u8 byte;

#define BIT_MASK(bit) (1 << (bit))
#define SET_BIT(val, bit) (val |= BIT_MASK(bit))
#define CLEAR_BIT(val, bit) (val &= ~(BIT_MASK(bit)))

void send_data_to_7seg(byte binary) {
	for (u8 i = 0; i < 8; ++i) {
		// SCLK = 0
		CLEAR_BIT(PORTD, 7);
		// Agarro el bit en la pos i y lo pongo en bit 0
		// 0b101 & (1<<2) => 0b100
		// 0b100 >> 2 => 0b1
		//
		// 0b101 & (1<<1) => 0b00
		// 0b00 >> 2 => 0b0
		u8 bit = ((binary & (1 << i)) >> i) & 1;
		if (bit == 1) {
			SET_BIT(PORTB, 0);
		} else {
			CLEAR_BIT(PORTB, 0);
		}
		// SCLK = 1
		SET_BIT(PORTD, 7);
	}
	CLEAR_BIT(PORTD, 7);
}

void bin_to_7seg(byte segments, byte digit) {
	if (digit > 3) {
		return;
	}
	send_data_to_7seg(segments);
	send_data_to_7seg(BIT_MASK(7 - digit));
	SET_BIT(PORTD, 4);
	CLEAR_BIT(PORTD, 4);
}

byte dec_to_7segval(byte val) {
	switch(val) {
		case 9:
			// 0b00011001
			return 0x19;
		case 8:
			// 0b00000001
			return 0x01;
		case 7:
			// 0b00011111
			return 0x1F;
		case 6:
			// 0b01000001
			return 0x41;
		case 5:
			// 0b01001001
			return 0x49;
		case 4:
			// 0b10011001
			return 0x99;
		case 3:
			// 0b00001101
			return 0x0D;
		case 2:
			// 0b00100101
			return 0x25;
		case 1:
			// 0b10011111
			return 0x9F;
		case 0:
			// 0b00000011
			return 0x03;
		default:
			// 0b11111101
			return 0xFD;
	}
}

void dec_to_7seg(byte val, byte digit) {
	byte binval = dec_to_7segval(val);
	bin_to_7seg(binval, digit);
}

void dec_to_7seg_dot(byte val, byte digit) {
	byte binval = dec_to_7segval(val);
	CLEAR_BIT(binval, 0);
	bin_to_7seg(binval, digit);
}

void setup() {
	// Deshabilita interrupciones globales (por reset)
	cli();

	// 4 LEDs del shield son salidas, y 0 es SDI del 7seg
	DDRB = BIT_MASK(DDB5) | BIT_MASK(DDB4) | BIT_MASK(DDB3) | BIT_MASK(DDB2) | BIT_MASK(DDB0);
	// Empiezan apagados
	PORTB = BIT_MASK(PORTB5) | BIT_MASK(PORTB4) | BIT_MASK(PORTB3) | BIT_MASK(PORTB2);

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
	dec_to_7seg((val / 10) % 10,  2);
	dec_to_7seg((val / 100) % 10,  1);
	dec_to_7seg((val / 1000) % 10,  0);
}

void show_samples() {
	show_4digit(samples);
}

void loop() {
	show_samples();
}

int main(void) {
	setup();

	while (true) {
		loop();
	}
}

