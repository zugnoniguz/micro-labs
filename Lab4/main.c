#define F_CPU (16 * 1000000UL)
// #define __AVR_ATmega328P__ 1

#include <avr/io.h>
#include <stdbool.h>
#include <util/delay.h>

typedef unsigned char byte;

#define LED_ON  PORTB = 0b11101111
#define LED_OFF PORTB = 0b11111111

// Defino la rutina de assembler que voy a llamar
void delay_joel() {
	for (int i = 0; i < 255; ++i) {
		for (int j = 0; j < 255; ++j) {
			for (int k = 0; k < 255; ++k) {
				continue;
			}
		}
	}
}

// Definiendo acceso a los registros
volatile byte *pr18 = (byte*)0x12;
volatile byte *pr19 = (byte*)0x13;
volatile byte *pr20 = (byte*)0x14;

int main(void)
{
	DDRB = 0b00111100;	// Output
	PORTB = 0xFF;	// Clear the PORTB
	DDRC = 0X00;

	while (true) {
		PORTB = 0b11101011;
	}
}

