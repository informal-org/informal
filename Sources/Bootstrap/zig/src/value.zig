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

fn isPrimitiveType(comptime pattern: u64, val: u64) bool {
    return (val & pattern) == pattern;
}

fn isNan(val: u64) bool {
    // Any NaN - quiet or signaling - either positive or negative.
    return isPrimitiveType(UNSIGNED_ANY_NAN, val);
}

fn isNumber(val: u64) bool {
    // val != val. Or check bit pattern.
    return !isNan(val);
}

fn isObjectReference(val: u64) bool {
    return isPrimitiveType(TYPE_OBJECT, val);
}

fn isObjectArray(val: u64) bool {
    return isPrimitiveType(TYPE_OBJECT_ARRAY, val);
}

fn isInlineObject(val: u64) bool {
    return isPrimitiveType(TYPE_INLINE_OBJECT, val);
}

fn isPrimitiveArray(val: u64) bool {
    return isPrimitiveType(TYPE_PRIMITIVE_ARRAY, val);
}

fn isInlineString(val: u64) bool {
    return isPrimitiveType(TYPE_INLINE_STRING, val);
}

fn isString(val: u64) bool {
    // TODO: Handle Object array / Primitive array pointers.
    return isInlineString(val);
}

fn createObject(region: u16, idx: u24, attr: u8) u64 {
    return TYPE_OBJECT | (@as(u64, region) << 32) | (@as(u64, idx) << 8) | attr;
}

fn createObjectArray(region: u16, idx: u24, attr: u8) u64 {
    return TYPE_OBJECT_ARRAY | (@as(u64, region) << 32) | (@as(u64, idx) << 8) | attr;
}

fn createInlineObject(objType: u16, payload: u32) u64 {
    return TYPE_INLINE_OBJECT | (@as(u64, objType) << 32) | payload;
}

fn createWrapperObject(objType: u16, pointer: u29, length: u3) u64 {
    return TYPE_INLINE_OBJECT | (@as(u64, objType) << 32) | (@as(u64, pointer) << 3) | length;
}

fn createPrimitiveArray(pointer: u29, length: u19) u64 {
    return TYPE_PRIMITIVE_ARRAY | (@as(u64, pointer) << 19) | length;
}

fn createInlineString(str: []const u8) u64 {
    // var payload: u64 = 0;
    // if(str.len > 6) unreachable;
    // // 
    // This ends up reversing the string... 
    // for(str) |c, i| {
    //     payload |= @as(u64, c) << (i * 8);
    // }
    // var payload = std.mem.bytesAsValue(u64, str);
    var payload: u64 = TYPE_INLINE_STRING;
    // 0..2 = NaN header. Copy string to payload bytes.
    std.mem.copy(u8, std.mem.asBytes(&payload)[1..8], str);
    return payload;
}

fn decodeInlineString(val: u64) []const u8 {
    // TODO: Truncate to 6 bytes.
    // asBytes - keeps original pointer. toBytes - copies.
    return std.mem.asBytes(val & MASK_PAYLOAD);
}


const expect = std.testing.expect;
const print = std.debug.print;

test "Num type check" {
    const num: u64 = @bitCast(u64, @as(f64, 3.14159265359));
    try expect(true == isNumber(num));
    try expect(false == isNan(num));
    try expect(false == isObjectReference(num));
    try expect(false == isObjectArray(num));
    try expect(false == isInlineObject(num));
    try expect(false == isPrimitiveArray(num));
    try expect(false == isInlineString(num));
    try expect(false == isString(num));
}

test "Object representation" {
    const obj = createObject(0x1234, 0x0300_03, 0x05);
    print("\nObject representation {x}\n", .{ obj });
    try expect(obj == 0x7FF0_1234_0300_03_05);
}

test "String representation" {
    const str = createInlineString("Hello");
    print("\nString representation {x}\n", .{ str });
    try expect(str == 0x7FF6_4865_6C6C_6F00_0000_0000);
    // const str2 = decodeInlineString(str);
    // print("\nString representation {s}\n", .{ str2 });
    // try expect(std.mem.eql(u8, str2, "Hello"));
}