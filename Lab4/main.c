#define F_CPU (16 * 1000000UL)
// #define __AVR_ATmega328P__ 1

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdbool.h>
#include <util/delay.h>

typedef unsigned char byte;

#define BIT_MASK(bit) (1 << (bit))
#define SET_BIT(val, bit) (val |= BIT_MASK(bit))
#define CLEAR_BIT(val, bit) (val &= ~(BIT_MASK(bit)))

volatile byte *registers = 0x00;

int timer_counter = 0;
int timer_state = 0;
int secs1 = 0;
int secs2 = 0;
int mins1 = 0;
int mins2 = 0;


void send_data_to_7seg(byte binary) {
	for (int i = 0; i < 8; ++i) {
		// SCLK = 0
		CLEAR_BIT(PORTD, 7);
		// Agarro el bit en la pos i y lo pongo en bit 0
		// 0b101 & (1<<2) => 0b100
		// 0b100 >> 2 => 0b1
		//
		// 0b101 & (1<<1) => 0b00
		// 0b00 >> 2 => 0b0
		int bit = ((binary & (1 << i)) >> i) & 1;
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
			return 0b00011001;
		case 8:
			return 0b00000001;
		case 7:
			return 0b00011111;
		case 6:
			return 0b01000001;
		case 5:
			return 0b01001001;
		case 4:
			return 0b10011001;
		case 3:
			return 0b00001101;
		case 2:
			return 0b00100101;
		case 1:
			return 0b10011111;
		case 0:
			return 0b00000011;
		default:
			return 0b11111101;
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
	DDRB = 0b00111101;
	// Empiezan apagados
	PORTB = 0b00111101;

	// 3 botones del shield son entradas
	DDRC = 0b00000000;

	// PD4 (LCHCLK) y PD7 (SCLK) son salidas
	DDRD = 0b10010000;
	// SCLK empieza en 0
	CLEAR_BIT(PORTD, 7);
	// LCHCLK empieza en 0
	CLEAR_BIT(PORTD, 4);

	// TMR0 cuenta hasta OCR0A y luego reinicia su valor (CTC (Clear Timer on
	// Compare))
	TCCR0A = 0b00000010;
	// prescaler = 1024 y termino de configurar CTC
	TCCR0B = 0b00000101;
	OCR0A = 124;
	// Habilita recepción de interrupciones del timer0
	TIMSK0 = 0b00000010;

	// Habilita recepción de interrupciones de pin change de 8..14
	PCICR = 0b00000010;
	// Habilita recepción de interrupciones de pin change de 9,10,11
	PCMSK1 = 0b00001110;

	timer_counter = 0;
	secs1 = 0;
	secs2 = 0;
	mins1 = 0;
	mins2 = 0;
	timer_state = 0;

	// Habilita interrupciones globales
	sei();
}

void increment_timer() {
	if (++secs1 != 10) {
		return;
	}
	secs1 = 0;
	if (++secs2 != 6) {
		return;
	}
	secs2 = 0;
	if (++mins1 != 10) {
		return;
	}
	mins1 = 0;
	if (++mins2 != 6) {
		return;
	}
	mins2 = 0;
}

ISR(TIMER0_COMPA_vect) {
	if (++timer_counter == 124) {
		timer_counter = 0;
		if (timer_state == 0) {
			increment_timer();
		}
	}
}

ISR(PCINT1_vect) {
	byte tmp = TIMSK0;
	TIMSK0 = 0b00000000;
	switch(PINC) {
		case 0x4C:
			timer_state = 0;
			break;
		case 0x4A:
			timer_state = 1;
			break;
		case 0x46:
			timer_state = 0;
			mins2 = 0;
			mins1 = 0;
			secs2 = 0;
			secs1 = 0;
			break;
		default:
			break;
	}
	TIMSK0 = tmp;
}

void show_timer() {
	dec_to_7seg(mins2, 0);
	dec_to_7seg_dot(mins1, 1);
	dec_to_7seg(secs2, 2);
	dec_to_7seg(secs1, 3);
}

void loop() {
	if (timer_state == 1) {
		CLEAR_BIT(PORTB, 2);
	} else {
		SET_BIT(PORTB, 2);
	}
	show_timer();
}

int main(void) {
	setup();

	while (true) {
		loop();
	}
}

