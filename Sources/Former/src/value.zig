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
const TAG_PTR: u16 = BASE_TYPE | 0x0000; // H0 [000] 6 byte data. Typically pointers.
const TAG_DATA: u16 = BASE_TYPE | 0x0001; // H1 [001] 1 byte header. 5 byte inline data. Bool, symbol, null, etc.
const TAG_TBLREF: u16 = BASE_TYPE | 0x0002; // H2 [110] 2 byte header. 4 byte data. Index into a table (i.e. string, class).
const TAG_HEADER3: u16 = BASE_TYPE | 0x0003; // [011] 3 byte header. 3 byte data.
const TAG_OBJ: u16 = BASE_TYPE | 0x0004; // [100] 1 byte header. 2 byte data. 3 byte data.
const TAG_INSTRUCTION: u16 = BASE_TYPE | 0x0005; // [101] 1 byte header. 1 byte data. 4 byte data.
const TAG_INLINE_STRING: u16 = BASE_TYPE | 0x0006; // [110] Inline string up to 5 ascii chars inline.
const TAG_INLINE_BITSET: u16 = BASE_TYPE | 0x0007; // [111] Inline bitset.

const TYPE_PTR: u64 = @as(u64, TAG_PTR) << 48;
const TYPE_DATA: u64 = @as(u64, TAG_DATA) << 48;
const TYPE_TBLREF: u64 = @as(u64, TAG_TBLREF) << 48;
const TYPE_HEADER3: u64 = @as(u64, TAG_HEADER3) << 48;
const TYPE_OBJ: u64 = @as(u64, TAG_OBJ) << 48;
const TYPE_INSTRUCTION: u64 = @as(u64, TAG_INSTRUCTION) << 48;
const TYPE_INLINE_STRING: u64 = @as(u64, TAG_INLINE_STRING) << 48;
const TYPE_INLINE_BITSET: u64 = @as(u64, TAG_INLINE_BITSET) << 48;

const DATA_BOOL: u8 = 2;
const DATA_SYMBOL: u8 = 3;

const QUIET_NAN_HEADER: u13 = 0b0111_1111_1111_1;

pub const Tag = enum(u3) {
    ptr,
    data,
    tblref,
    split,
    obj,
    instruction,
    inline_string,
    inline_bitset,
};

// NaN tagged 64 bit value types.
const TaggedValue = packed struct {
    _reserved_nan: u13 = QUIET_NAN_HEADER,
    tag: u3,
    payload: u48,
};

const Ptr = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.ptr, pointer: u48 };

// 5 bytes of inline data. Bool, symbol, null, etc.
const Data = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.data, header: u8, data: u40 };

// 2 byte type header. 4 byte data reference into constant table (string, class, etc.)
const TblRef = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.tblref, header: u16, data: u32 };

// Header and data are evenly split with 3 bytes each.
const Split = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.split, header: u24, data: u24 };

const Obj = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.obj, header: u8, ref: u16, data: u24 };

const Instruction = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.instruction, op: u8, register: u8, data: u32 };

// Inline string. Can store up to 8 6-bit characters encoding uppercase, lowercase, digits and _.
const InlineString = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.inline_string, data: u48 };

const InlineBitset = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.inline_bitset, data: u48 };

pub fn getHeader(val: u64) u64 {
    const header = switch (val & MASK_TYPE) {
        TAG_DATA => (val & MASK_HIGH8) >> 40,
        TAG_TBLREF => (val & MASK_HIGH16) >> 32,
        TAG_HEADER3 => (val & MASK_HIGH24) >> 24,
        TAG_OBJ => (val & MASK_HIGH32) >> 16,
        TAG_INSTRUCTION => (val & MASK_HIGH40) >> 8,
        else => 0,
    };
    return header;
}

pub fn getPayload(val: u64) u64 {
    const payload = switch (val & MASK_TYPE) {
        TAG_DATA => (val & MASK_LOW40),
        TAG_TBLREF => (val & MASK_LOW32),
        TAG_HEADER3 => (val & MASK_LOW24),
        TAG_OBJ => unreachable, // (val & MASK_LOW40) is a valid interpretation, but you should use arg0 and arg1 instead.
        TAG_INSTRUCTION => unreachable,
        else => val & MASK_PAYLOAD, // Header 0
    };
    return payload;
}

pub fn getArg0(val: u64) u64 {
    const arg0 = switch (val & MASK_TYPE) {
        TAG_OBJ => (val & 0x0000_00FF_FF00_0000),
        TAG_INSTRUCTION => (val & 0x0000_00FF_0000_0000),
        else => unreachable,
    };
    return arg0;
}

pub fn getArg1(val: u64) u64 {
    const arg1 = switch (val & MASK_TYPE) {
        TAG_OBJ => (val & MASK_LOW24),
        TAG_INSTRUCTION => (val & MASK_LOW32),
        else => unreachable,
    };
    return arg1;
}

// Header 2
pub fn getTblHeader(val: u64) u16 {
    return @truncate((val & MASK_HIGH16) >> 32);
}

pub fn getTypeTag(val: u64) u64 {
    return val & MASK_TYPE;
}

fn isPrimitiveType(comptime pattern: u64, val: u64) bool {
    return (val & pattern) == pattern;
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

// Header 2
pub fn createTblRef(header: u16, payload: u32) u64 {
    return TYPE_TBLREF | (@as(u64, header) << 32) | @as(u64, payload);
}

// Header 1
pub fn createData(header: u8, payload: u40) u64 {
    return TYPE_DATA | (@as(u64, header) << 40) | @as(u64, payload);
}

// pub fn createInlineByteString(str: []const u8) u64 {
//     // Inline small strings of up to 6 bytes.
//     // The representation does reverse the order of bytes.
//     var payload: u64 = TYPE_INLINE_STRING;
//     if (str.len > 6) unreachable;
//     // No need for slicing. MaxLen of 6 ensures the header is preserved.
//     std.mem.copy(u8, std.mem.asBytes(&payload), str);
//     return payload;
// }

// pub fn decodeInlineByteString(val: u64, out: *[8]u8) void {
//     // TODO: Truncate to 6 bytes.
//     // asBytes - keeps original pointer. toBytes - copies.
//     return std.mem.copy(u8, out, std.mem.asBytes(&(val & MASK_PAYLOAD)));
// }

pub fn encodeInlineString(str: []const u8) InlineString {
    var chars: u48 = 0;
    if (str.len > 8) unreachable;
    for (str) |c| {
        const minCh: u6 = @truncate(switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10, // Arranged this way, so hex encode is easy.
            'a'...'z' => c - 'a' + 10 + 26,
            '_' => 62,
            // 63 = null terminator
            else => unreachable,
        });
        chars = (chars << 6) | minCh;
    }
    // Padding with 63 to indicate null termination where the string ends.
    if (str.len < 8) {
        // loop
        for (str.len..8) |_| {
            chars = (chars << 6) | 63;
        }
    }
    return InlineString{ .data = chars };
}

pub fn decodeInlineString(val: InlineString, out: *[8]u8) void {
    var chars: u48 = val.data;
    for (out, 0..) |_, i| {
        // Extract 6 bits at a time. Select the topmost bits first.
        const minCh: u8 = @truncate(chars >> 42);

        // This selects the bottom 6 bits, but we need the top.
        // const minCh: u8 = @truncate(chars & 0x3F);
        // chars >>= 6;
        chars <<= 6;
        if (minCh == 63) break;
        out[i] = switch (minCh) {
            0...9 => '0' + minCh,
            10...35 => 'A' + minCh - 10,
            36...61 => 'a' + minCh - 36,
            62 => @as(u8, '_'),
            63 => break,
            else => unreachable,
        };
    }
}

pub fn createKeyword(opcode: u8, precedence: u16) u64 {
    // Create a left-associative keyword
    return createData(opcode, precedence);
}

pub fn isKeyword(value: u64) bool {
    return isPrimitiveType(TYPE_DATA, value);
}

const expect = std.testing.expect;
const print = std.debug.print;
// test "Test byte strings" {
//     const val = createInlineByteString("+");
//     print("val: {x}\n", .{val});
//     try expect(val == 0x7FF6_0000_0000_002B);
// }

test "Test inline strings" {
    const encoded = encodeInlineString("Hello");
    print("val: {any}\n", .{encoded});
    // try expect(val == 0x7FF6_0000_0000_002B);

    var str2 = std.mem.zeroes([8]u8);
    decodeInlineString(encoded, &str2);
    print("String(\"{s}\")\n", .{str2});
}

test "Test keywords" {
    const val = createKeyword(3, 8);
    print("val: {x}\n", .{val});
    try expect(val == 0x7FF1_0300_0000_0008);
}

// The header portion has a further-tag indicating what the header and data represent.
// Pointers are 64 bit aligned, thus the bottom 3 bits are used for pointer tagging.
// const H_PTR64: u3 = 0b000; // Pointer + length.
// const H_PTR32: u3 = 0b001; // Shift >> 1
// const H_PTR16: u3 = 0b010; // Shift >> 2
// const H_PTR8: u3 = 0b011;  // Shift >> 3
// const H_OBJ_LEN: u3 = 0b100;
// const H_OBJ_OFFSET: u3 = 0b101;
// const H_PTR_MASK: u3 = 0b110;
// const H_IMMEDIATE: u3 = 0b111; // Inline object.

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
// pub const AST_SYMBOL: u8 = 0x3A; // 0x3A = ':'
// pub const AST_STRING: u8 = 0x21; // 0x22 = '"'
// pub const AST_IDENTIFIER: u8 = 0x41; // 0x41 = 'A'
// pub const AST_COMMENT: u8 = 0x27; // 0x27 = '/'
// Top most sign bit is currently unused.
