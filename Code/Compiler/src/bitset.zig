const tok = @import("token.zig");
const std = @import("std");

const stdbits = std.bit_set;
pub const BitSet128 = stdbits.IntegerBitSet(128);
pub const BitSet64 = stdbits.IntegerBitSet(64);
pub const BitSet32 = stdbits.IntegerBitSet(32);

// Compile time constant function which takes a string of valid delimiter characters and returns a bitset.
// The bitset is used to quickly check if a character is a delimiter.
pub fn character_bitset(pattern: []const u8) BitSet128 {
    var bs = BitSet128.initEmpty();
    // assert - is-ascii. Just used internally with fixed compile-time patterns.
    for (pattern) |ch| {
        bs.set(ch);
    }
    return bs;
}

pub fn extend_bitset(base: BitSet128, pattern: []const u8) BitSet128 {
    var patternBs = character_bitset(pattern);
    patternBs.setUnion(base);
    return patternBs;
}

pub fn token_bitset(tokens: []const tok.Kind) BitSet64 {
    var bs = BitSet64.initEmpty();
    for (tokens) |token| {
        const val = @intFromEnum(token);
        std.debug.assert(val < 64);
        bs.set(val);
    }
    return bs;
}

pub fn index128(bitset: BitSet128, val: u8) u7 {
    // Return the bitset index indicating the index of the set bit in the bitset.
    // Val is a known set bit in the bitset.
    const v7: u7 = @truncate(val);
    const index: u7 = @truncate(@popCount(bitset.mask >> v7));
    // Convert index in range 1..128 to 0..127.
    return index - 1;
}

pub fn chToKind(bitset: BitSet128, ch: u8, offset: u7) tok.Kind {
    // Return the token kind for a given character already known to be in this bitset.
    const chIndex: u7 = index128(bitset, ch);
    return @enumFromInt(chIndex + offset);
}

pub fn isKind(bitset: BitSet64, kind: tok.Kind) bool {
    return bitset.isSet(@intFromEnum(kind));
}

pub fn dependencyBit(localIndex: u32) u64 {
    std.debug.assert(localIndex < 64);
    return @as(u64, 1) << @as(u6, @intCast(localIndex));
}

pub fn lowBits(n: usize) BitSet64 {
    std.debug.assert(n <= 64);
    const mask = if (n == 64)
        ~@as(u64, 0)
    else
        (@as(u64, 1) << @as(u6, @intCast(n))) - 1;
    return BitSet64{ .mask = mask };
}

pub fn highBits(n: usize) BitSet64 {
    std.debug.assert(n <= 64);
    return lowBits(64 - n).complement();
}

test "bit masks cover low and high bit ranges" {
    try std.testing.expectEqual(@as(u64, 0), lowBits(0).mask);
    try std.testing.expectEqual(@as(u64, 1), lowBits(1).mask);
    try std.testing.expectEqual(@as(u64, 0b1111), lowBits(4).mask);
    try std.testing.expectEqual(~@as(u64, 0), lowBits(64).mask);

    try std.testing.expectEqual(@as(u64, 0), highBits(0).mask);
    try std.testing.expectEqual(@as(u64, 0x8000_0000_0000_0000), highBits(1).mask);
    try std.testing.expectEqual(@as(u64, 0xF000_0000_0000_0000), highBits(4).mask);
    try std.testing.expectEqual(~@as(u64, 0), highBits(64).mask);
}
