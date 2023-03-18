/// Value representation. 
/// 0 00000001010 0000000000000000000000000000000000000000000000000000 = Number 64
/// 1 11111111111 1000000000000000000000000000000000000000000000000000 = NaN
/// 
/// 51 bits of NaN is used to represent the following types of values
const std = @import("std");


// x86 - 1 if quiet. 0 if signaling.
const QUIET_NAN: u64 = 0x7FF8_0000_0000_0000; // Actual NaN from operations.
const SIGNALING_NAN: u64 = 0x7FF0_0000_0000_0000; 
const UNSIGNED_ANY_NAN: u64 = 0x7FF0_0000_0000_0000;

const CANONICAL_NAN: u64 = 0x7FF8_0000_0000_0000;   // WASM Canonical NaN.
// One extra bit for Intel QNaN - https://craftinginterpreters.com/optimization.html#nan-boxing
// We could use either Quiet NaN (avoiding the canonical + 1 intel QNan bit.). 0x7FFC_00..
// Or use Signaling NaN. 
// We leave the sign bit un-used to allow for flexibility to switch between QNaN and SNaN
// if needed in the future. For QNaN, sign bit behavior varies between Intel & ARM.

// 000 - Object
// 001 - Object Array
// 010 - Inline Object. 16 bit type. 32 bit payload (wrapper types = 29 bit payload + 3 bit len)
// 011 - 
// 100 - 
// 101 - Primitive Array
// 110 - String
// 111 - Bitset

// 0x0007 if we just want the type bits. This mask ensure it's NaN and it's the given type.
const MASK_TYPE: u64 = 0x7FF7_0000_0000_0000;       
const MASK_PAYLOAD: u64 = 0x0000_FFFF_FFFF_FFFF;    // High 48.

// Object, slice.
const MASK_HIGH16: u64 = 0x0000_FFFF_0000_0000;
const MASK_MID24: u64 = 0x0000_0000_FFFF_FF00;
const MASK_LOW8: u64 = 0x0000_0000_0000_00FF;

// Inline object. 8+40. Or 16+32 config.
const MASK_LOW32: u64 = 0x0000_0000_FFFF_FFFF;

// Primitive array with 64 bit pointer alignment.
const MASK_HIGH29: u64 = 0x0000_FFFF_FFF8_0000;
const MASK_LOW19: u64 = 0x0000_0000_0007_FFFF;

// Primitive wrapper object
// Objects like Point, or Complex, which are composed of primitive values, with an inline type.
const MASK_MID29: u64 = 0x0000_0000_FFFF_FFF8;
const MASK_LOW3: u64 = 0x0000_0000_0000_0007;


const TYPE_OBJECT: u64 = 0x7FF0_0000_0000_0000;         // 000  
const TYPE_OBJECT_ARRAY: u64 = 0x7FF1_0000_0000_0000;   // 001
const TYPE_INLINE_OBJECT: u64 = 0x7FF2_0000_0000_0000;  // 010
// 011, 100 - Unused
const TYPE_PRIMITIVE_ARRAY: u64 = 0x7FF5_0000_0000_0000; // 101
const TYPE_INLINE_STRING: u64 = 0x7FF6_0000_0000_0000;  // 110
const TYPE_INLINE_BITSET: u64 = 0x7FF7_0000_0000_0000;  // 111



fn isNan(val: u64) bool {
    // Any NaN - quiet or signaling - either positive or negative.
    return (val & UNSIGNED_ANY_NAN) == UNSIGNED_ANY_NAN; 
}

fn isNumber(val: u64) bool {
    // val != val. Or check bit pattern.
    return (val & UNSIGNED_ANY_NAN) != UNSIGNED_ANY_NAN; 
}


const expect = std.testing.expect;
test "Type expressions" {
    // We express these as expressions above to make the bit patterns more visually obvious.
    try expect(0x7FF0_0000_0000_0000 == TYPE_OBJECT);
    try expect(0x7FF1_0000_0000_0000 == TYPE_OBJECT_ARRAY);
    try expect(0x7FF2_0000_0000_0000 == TYPE_INLINE_OBJECT);
    try expect(0x7FF5_0000_0000_0000 == TYPE_PRIMITIVE_ARRAY);
    try expect(0x7FF6_0000_0000_0000 == TYPE_INLINE_STRING);
    try expect(0x7FF7_0000_0000_0000 == TYPE_INLINE_BITSET);


}