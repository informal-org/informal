/// Value representation.
/// We encode AST nodes and dynamic values in-language in a NaN tagged 64 bit value.
/// 0 00000001010 0000000000000000000000000000000000000000000000000000 = Number 64
/// 1 11111111111 1000000000000000000000000000000000000000000000000000 = NaN
///
/// The 51 unused bits of NaN is used to represent type-tagged values.
const std = @import("std");

// x86 - 1 if quiet. 0 if signaling.
const QUIET_NAN: u64 = 0x7FF8_0000_0000_0000; // Actual NaN from operations.
const SIGNALING_NAN: u64 = 0x7FF0_0000_0000_0000;
const UNSIGNED_ANY_NAN: u64 = 0x7FF0_0000_0000_0000;
const CANONICAL_NAN: u64 = 0x7FF8_0000_0000_0000; // WASM Canonical NaN.

// 0x0007 if we want the type bits. This mask ensure it's NaN and it's the given type.
const MASK_TYPE: u64 = 0x7FF7_0000_0000_0000;
const MASK_PAYLOAD: u64 = 0x0000_FFFF_FFFF_FFFF; // High 48.
const BASE_TYPE: u16 = 0x7FF0;

const MASK_HIGH8: u64 = 0x0000_FF00_0000_0000;
const MASK_HIGH16: u64 = 0x0000_FFFF_0000_0000;
const MASK_HIGH24: u64 = 0x0000_FFFF_FF00_0000;
const MASK_HIGH32: u64 = 0x0000_FFFF_FFFF_0000;
const MASK_HIGH40: u64 = 0x0000_FFFF_FFFF_FF00;

const MASK_LOW8: u64 = 0x0000_0000_0000_00FF;
const MASK_LOW16: u64 = 0x0000_0000_0000_FFFF;
const MASK_LOW24: u64 = 0x0000_0000_00FF_FFFF;
const MASK_LOW32: u64 = 0x0000_0000_FFFF_FFFF;
const MASK_LOW40: u64 = 0x0000_00FF_FFFF_FFFF;

// The 51 bit NaN space is divided into a 3 bit tag + 48 bits of payload.
// The tag represents how that payload is divided into headers + data, or inline types.
const TAG_HEADER0: u16 = BASE_TYPE | 0x0000; // [000] 6 byte data. Typically pointers.
const TAG_HEADER1: u16 = BASE_TYPE | 0x0001; // [001] 1 byte header. 5 byte data.
const TAG_HEADER2: u16 = BASE_TYPE | 0x0002; // [110] 2 byte header. 4 byte data.
const TAG_HEADER3: u16 = BASE_TYPE | 0x0003; // [011] 3 byte header. 3 byte data.
const TAG_HEADER4: u16 = BASE_TYPE | 0x0004; // [100] 4 byte header. 2 byte data.
const TAG_HEADER5: u16 = BASE_TYPE | 0x0005; // [101] 5 byte header. 1 byte data.
const TAG_INLINE_STRING: u16 = BASE_TYPE | 0x006; // [110] Inline string up to 5 ascii chars inline.
const TAG_INLINE_BITSET: u16 = BASE_TYPE | 0x007; // [111] Inline bitset.

const TYPE_HEADER0: u64 = @as(u64, TAG_HEADER0) << 48;
const TYPE_HEADER1: u64 = @as(u64, TAG_HEADER1) << 48;
const TYPE_HEADER2: u64 = @as(u64, TAG_HEADER2) << 48;
const TYPE_HEADER3: u64 = @as(u64, TAG_HEADER3) << 48;
const TYPE_HEADER4: u64 = @as(u64, TAG_HEADER4) << 48;
const TYPE_HEADER5: u64 = @as(u64, TAG_HEADER5) << 48;
const TYPE_INLINE_STRING: u64 = @as(u64, TAG_INLINE_STRING) << 48;
const TYPE_INLINE_BITSET: u64 = @as(u64, TAG_INLINE_BITSET) << 48;

// The header portion has a further-tag indicating what the header and data represent.
// Pointers are 64 bit aligned, thus the bottom 3 bits are used for pointer tagging.
const H_PTR64: u3 = 0b000; // Pointer + length.
const H_PTR32: u3 = 0b001; // Shift >> 1
const H_PTR16: u3 = 0b010; // Shift >> 2
const H_PTR8: u3 = 0b011; // Shift >> 3
const H_OBJ_LEN: u3 = 0b100;
const H_OBJ_OFFSET: u3 = 0b101;
const H_PTR_MASK: u3 = 0b110;
const H_IMMEDIATE: u3 = 0b111; // Inline object.

// The full range of dynamic type options are unnecessary for the parser.
// So we use these bits in more constrained way for compactness, avoiding unnecessary tags.
// AST Nodes will have 4 byte header + 2 byte data.
// The header represents the ascii representation of builtin keywords.
// true, false, null, if, for, etc. Up to the first 4 chars.
// The 2 byte data is context dependent.
// It initially represents precedenec for operators. Indentation level for blocks.
// Since those are irrelevant once the AST is constructed, it's used to store relative backrefs
// to the previously seen instance of this operand (based on a similar structure in LuaJIT).
// These backrefs make certain pattern-matching ops like common-subexpression-elimination faster.
// Semantic types like Symbol, Identifier, String, Comment etc.
// use the 1 byte header + 5 byte data reference to their respective symbol table.
pub const AST_SYMBOL: u8 = 0x3A; // 0x3A = ':'
pub const AST_STRING: u8 = 0x21; // 0x22 = '"'
pub const AST_IDENTIFIER: u8 = 0x41; // 0x41 = 'A'
pub const AST_COMMENT: u8 = 0x27; // 0x27 = '/'

pub fn getTypeTag(val: u64) u64 {
    return val & MASK_TYPE;
}

fn isPrimitiveType(comptime pattern: u64, val: u64) bool {
    return (val & pattern) == pattern;
}

pub fn getHeader(val: u64) u64 {
    const header = switch (val & MASK_TYPE) {
        TAG_HEADER1 => (val & MASK_HIGH8) >> 40,
        TAG_HEADER2 => (val & MASK_HIGH16) >> 32,
        TAG_HEADER3 => (val & MASK_HIGH24) >> 24,
        TAG_HEADER4 => (val & MASK_HIGH32) >> 16,
        TAG_HEADER5 => (val & MASK_HIGH40) >> 8,
        else => 0,
    };
    return header;
}

pub fn getPayload(val: u64) u64 {
    const payload = switch (val & MASK_TYPE) {
        TAG_HEADER1 => (val & MASK_LOW40),
        TAG_HEADER2 => (val & MASK_LOW32),
        TAG_HEADER3 => (val & MASK_LOW24),
        TAG_HEADER4 => (val & MASK_LOW16),
        TAG_HEADER5 => (val & MASK_LOW8),
        else => val & MASK_PAYLOAD, // Header 0
    };
    return payload;
}

pub fn isNan(val: u64) bool {
    // Any NaN - quiet or signaling - either positive or negative.
    return isPrimitiveType(UNSIGNED_ANY_NAN, val);
}

pub fn isNumber(val: u64) bool {
    // val != val. Or check bit pattern.
    return !isNan(val);
}

pub fn isInlineString(val: u64) bool {
    return isPrimitiveType(TYPE_INLINE_STRING, val);
}

pub fn createInlineString(str: []const u8) u64 {
    // Inline small strings of up to 6 bytes.
    // The representation does reverse the order of bytes.
    var payload: u64 = TYPE_INLINE_STRING;
    if (str.len > 6) unreachable;
    // No need for slicing. MaxLen of 6 ensures the header is preserved.
    std.mem.copy(u8, std.mem.asBytes(&payload), str);
    return payload;
}

pub fn decodeInlineString(val: u64, out: *[8]u8) void {
    // TODO: Truncate to 6 bytes.
    // asBytes - keeps original pointer. toBytes - copies.
    return std.mem.copy(u8, out, std.mem.asBytes(&(val & MASK_PAYLOAD)));
}

pub fn createKeyword(str: []const u8, precedence: u16) u64 {
    if (str.len > 4) unreachable;
    return createInlineString(str) | (@as(u64, precedence) << 32);
}

pub fn createHeader2(header: u16, payload: u32) u64 {
    return TYPE_HEADER2 | (@as(u64, header) << 32) | @as(u64, payload);
}

pub fn createReference(header: u16, payload: u32) u64 {
    return createHeader2(header, payload);
}

pub const KW_ADD = createKeyword("+", 80);
pub const KW_SUB = createKeyword("-", 80);
pub const KW_MUL = createKeyword("*", 85);
pub const KW_DIV = createKeyword("/", 85);

const expect = std.testing.expect;
const print = std.debug.print;
test "Test inline strings" {
    const val = createInlineString("+");
    print("val: {x}\n", .{val});
    try expect(val == 0x7FF6_0000_0000_002B);
}

test "Test keywords" {
    const val = createKeyword("+", 8);
    print("val: {x}\n", .{val});
    try expect(val == 0x7FF6_0008_0000_002B);
}
