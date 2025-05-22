// Radix Tree

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const IntegerBitSet = std.bit_set.IntegerBitSet;
const sparsebit = @import("sparsebit.zig");
const TaggedPointer = sparsebit.TaggedPointer;

/// A variant of radix tree optimized for sparse, non-uniformly distributed data.
/// It addresses a common weakness of normal radix trees in handling lots of low values with a few high values.
/// At a basic level, the bucket is determined by the top set bit. We maintain a mask of the 'relevant' bits which are set.
/// If we had a lot of low-value 64 bit values and a few in higher ranges, this would compress that address space down and eliminate zeroes.
/// Conceptually, each bucket will store all values >= N. Which does skew the data such that the top bits are hot and accessed often.
/// When things fill up, we vacate the lowest set bit in favor of higher ones and merge that bucket contents with the next highest.
pub fn LogRadixTree(comptime Data: type) type {
    const RadixLevelType = enum(u2) {
        Data,
        Level,
    };

    const RadixLvlPtr = TaggedPointer(RadixLevelType, Data);

    return struct {
        const Self = @This();
        head: *IntegerBitSet,
        buckets: sparsebit.SparseArray(u64, RadixLvlPtr),
    };
}
