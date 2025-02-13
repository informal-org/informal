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
        bs.set(@intFromEnum(token));
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
