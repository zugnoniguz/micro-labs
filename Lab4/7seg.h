#ifndef _7SEG_H
#define _7SEG_H

#include <avr/io.h>
#include "defs.h"

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
	switch (val) {
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

#endif // _7SEG_H

