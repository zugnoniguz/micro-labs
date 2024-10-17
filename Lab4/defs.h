#ifndef _DEFS_H
#define _DEFS_H

#include <stdint.h>

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

#endif // _DEFS_H
