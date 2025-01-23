/// Value representation.
/// We encode AST nodes and dynamic values in-language in a NaN tagged 64 bit value.
/// 0 00000001010 0000000000000000000000000000000000000000000000000001 = Float number
/// 1 11111111111 1000000000000000000000000000000000000000000000000000 = NaN
///
/// The 51 unused bits of NaN is used to represent type-tagged values.
const std = @import("std");

// // x86 - 1 if quiet. 0 if signaling.
// const QUIET_NAN: u64 = 0x7FF8_0000_0000_0000; // Actual NaN from operations.
// const SIGNALING_NAN: u64 = 0x7FF0_0000_0000_0000;
const UNSIGNED_ANY_NAN: u64 = 0x7FF0_0000_0000_0000;
// const CANONICAL_NAN: u64 = 0x7FF8_0000_0000_0000; // WASM Canonical NaN.

// // 0x0007 if we want the type bits. This mask ensure it's NaN and it's the given type.
// const MASK_TYPE: u64 = 0x7FF7_0000_0000_0000;
// const MASK_PAYLOAD: u64 = 0x0000_FFFF_FFFF_FFFF; // High 48.
// const BASE_TYPE: u16 = 0x7FF0;

pub const QUIET_NAN_HEADER: u12 = 0b111_1111_1111_1;

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
    sign: u1 = 0,
    _reserved_nan: u13 = QUIET_NAN_HEADER,
    tag: u3,
    payload: u48,
};

// Pointers: 6 bytes of data (48 bits).
const Ptr = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.ptr, pointer: u48 };

// 1 byte type header and 5 bytes of inline data. Bool, symbol, null, etc.
const Data = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.data, header: u8, data: u40 };

// 2 byte table type header. 4 byte data reference into constant table (string, class, etc.)
const TblRef = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.tblref, header: u16, data: u32 };

// Unused. Data split into two equal parts.
const Split = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.split, header: u24, data: u24 };

// Object/array interior reference.
// 2 bytes - region/class ID.
// 3 bytes - Object ID.
// 1 byte - interior offset reference.
const Obj = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.obj, header: u8, ref: u16, data: u24 };

const Instruction = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.instruction, op: u8, register: u8, data: u32 };
// const ThreeAddr = packed struct { _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.instruction, op: u8, reg0: u8, mem1: u16, mem2: u16 };

// Inline string. Can store up to 8 6-bit characters encoding uppercase, lowercase, digits and _.
const InlineString = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.inline_string, data: u48 };

const InlineBitset = packed struct { sign: u1 = 0, _reserved_nan: u13 = QUIET_NAN_HEADER, _tag: Tag = Tag.inline_bitset, data: u48 };

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

pub fn encodeInlineString(str: []const u8) InlineString {
    var chars: u48 = 0;
    if (str.len > 8) unreachable;
    for (str) |c| {
        const minCh: u6 = @truncate(switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10, // Arranged this way, so hex encode is easy.
            'a'...'z' => c - 'a' + 10 + 26,
            '_' => 62,
            // 63 = null terminator. TODO: May revisit this. Using 0 is nicer, but this representation allows easy conversion which may be moot for our use-case.
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

const expect = std.testing.expect;
const print = std.debug.print;

test "Test inline strings" {
    const encoded = encodeInlineString("Hello");
    print("val: {any}\n", .{encoded});
    // try expect(val == 0x7FF6_0000_0000_002B);

    var str2 = std.mem.zeroes([8]u8);
    decodeInlineString(encoded, &str2);
    print("String(\"{s}\")\n", .{str2});
}
