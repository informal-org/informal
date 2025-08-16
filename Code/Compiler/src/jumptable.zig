const std = @import("std");
const tok = @import("token.zig");
const bitset = @import("bitset.zig");

const BitSet64 = bitset.BitSet64;
const isKind = bitset.isKind;

/// Compile-time jumptable abstraction for token-based dispatch using multi array list.
/// Takes a list of (bitset, target) pairs and provides efficient jump functions with
/// improved cache locality by storing bitsets and targets in separate arrays.
///
/// Example usage:
/// const ParserAction = enum { expect_binary, expect_unary, expect_literal };
/// const parser_table = JumpTable(ParserAction, &[_]JumpEntry(ParserAction){
///     .{ .bitset = tok.LITERALS, .target = .expect_literal },
///     .{ .bitset = tok.UNARY_OPS, .target = .expect_unary },
///     .{ .bitset = tok.BINARY_OPS, .target = .expect_binary },
/// });
///
/// if (parser_table.jump_iterative(token.kind)) |action| {
///     // dispatch to action
/// }
pub fn JumpTable(comptime EntryType: type, comptime entries: []const JumpEntry(EntryType)) type {
    return struct {
        const Self = @This();

        const bitsets: [entries.len]BitSet64 = blk: {
            var result: [entries.len]BitSet64 = undefined;
            for (entries, 0..) |entry, i| {
                result[i] = entry.bitset;
            }
            break :blk result;
        };

        const targets: [entries.len]EntryType = blk: {
            var result: [entries.len]EntryType = undefined;
            for (entries, 0..) |entry, i| {
                result[i] = entry.target;
            }
            break :blk result;
        };

        pub inline fn jump_iterative(kind: tok.Kind) ?EntryType {
            inline for (bitsets, targets) |bs, target| {
                if (isKind(bs, kind)) {
                    return target;
                }
            }
            return null;
        }

        pub inline fn jump_branchless(kind: tok.Kind) ?EntryType {
            var index: u64 = 0;
            const kind_int: u6 = @intCast(@intFromEnum(kind));
            const mask: u64 = @as(u64, 1) << kind_int;

            inline for (bitsets, 0..) |bs, i| {
                const intersection = bs.mask & mask;
                const popcount = @popCount(intersection);
                index += (@as(u64, popcount) << @intCast(i));
            }

            if (index == 0) return null;

            const matched_index = @ctz(index);
            return targets[matched_index];
        }
    };
}

pub fn JumpEntry(comptime EntryType: type) type {
    return struct {
        bitset: BitSet64,
        target: EntryType,
    };
}
