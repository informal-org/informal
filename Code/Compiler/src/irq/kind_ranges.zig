const std = @import("std");
const tok = @import("../token.zig");

const TK = tok.Kind;

pub const KIND_COUNT = 64; // IR queues track the first 64 token kinds.
// Power of two sized buckets to slice the entire range into an inverted index
// of range-bucket -> kinds present within that range.
const INDEX_KIND_MAP_BUCKET_COUNT_SHIFT = 5;
const INDEX_KIND_MAP_BUCKET_COUNT = 1 << INDEX_KIND_MAP_BUCKET_COUNT_SHIFT;
pub const KindBitSet = std.bit_set.IntegerBitSet(KIND_COUNT);
pub const KindBitSetIterator = KindBitSet.Iterator(.{});

const Range = packed struct(u64) {
    cursor: u32, // Incremented on add
    end: u32, // Precomputed from the results of Parser's kind count
};

pub const KindRanges = struct {
    const Self = @This();

    // Reserved ranges keyed by kind. cursor is advanced by emitKind, while
    // end remains fixed.
    ranges: [KIND_COUNT]Range = std.mem.zeroes([KIND_COUNT]Range),
    // Inverted index from index bucket to kinds present within that bucket.
    // Each entry is a bitset of token kinds whose reserved ranges overlap
    // that bucket. indexToKind uses this to avoid scanning every kind.
    indexKindMap: [INDEX_KIND_MAP_BUCKET_COUNT]KindBitSet = [_]KindBitSet{KindBitSet.initEmpty()} ** INDEX_KIND_MAP_BUCKET_COUNT,
    // log2(bucket width). Computed once in reserve so hot lookups use a
    // shift instead of a division.
    indexKindMapWidthShift: u5 = 0,

    pub fn reserve(self: *Self, kindCounts: [KIND_COUNT]u32) u32 {
        var tail: u32 = 0;
        for (0..KIND_COUNT) |i| {
            self.ranges[i].cursor = tail;
            tail += kindCounts[i];
            self.ranges[i].end = tail;
        }
        self.buildIndexKindMap(tail);
        return tail;
    }

    pub fn cursor(self: *const Self, kind: TK) u32 {
        return self.ranges[@intFromEnum(kind)].cursor;
    }

    pub fn nextIndex(self: *Self, kind: TK) u32 {
        const kindIndex = @intFromEnum(kind);
        const index = self.ranges[kindIndex].cursor;
        std.debug.assert(index < self.ranges[kindIndex].end);
        self.ranges[kindIndex].cursor += 1;
        return index;
    }

    pub fn emittedCursor(self: *const Self, kindIndex: usize) u32 {
        return self.ranges[kindIndex].cursor;
    }

    pub fn reservedStart(self: *const Self, kindIndex: usize) u32 {
        // ranges[kind].cursor is an emit cursor, so recover the stable
        // reserved start from the previous kind's end.
        return if (kindIndex == 0) 0 else self.ranges[kindIndex - 1].end;
    }

    pub fn reservedLen(self: *const Self, kindIndex: usize) u32 {
        return self.ranges[kindIndex].end - self.reservedStart(kindIndex);
    }

    pub fn relativeIndex(self: *const Self, kindIndex: usize, index: u32) u32 {
        const start = self.reservedStart(kindIndex);
        std.debug.assert(start <= index);
        std.debug.assert(index < self.ranges[kindIndex].end);
        return index - start;
    }

    fn indexKindMapIndex(self: *const Self, index: u32) usize {
        const mapIndex: usize = @intCast(index >> self.indexKindMapWidthShift);
        std.debug.assert(mapIndex < INDEX_KIND_MAP_BUCKET_COUNT);
        return mapIndex;
    }

    fn buildIndexKindMap(self: *Self, totalLen: u32) void {
        // Build the inverted index that'll help us map from an index to which kinds are present in that range.
        self.indexKindMap = [_]KindBitSet{KindBitSet.initEmpty()} ** INDEX_KIND_MAP_BUCKET_COUNT;
        self.indexKindMapWidthShift = 0;
        if (totalLen > 1) {
            // Round the ideal 1/32 slice width up to a power of two. This can
            // leave high buckets unused, but guarantees index >> shift is in
            // bounds for every valid queue index.
            const bucketLen = std.math.divCeil(u32, totalLen, INDEX_KIND_MAP_BUCKET_COUNT) catch unreachable;
            self.indexKindMapWidthShift = @intCast(std.math.log2_int_ceil(u32, bucketLen));
        }
        if (totalLen == 0) return;

        for (0..KIND_COUNT) |kindIndex| {
            const start = self.reservedStart(kindIndex);
            const end = self.ranges[kindIndex].end;
            // Skip setting the bits for empty-ranges.
            if (start == end) continue;

            const firstMapIndex = self.indexKindMapIndex(start);
            const lastMapIndex = self.indexKindMapIndex(end - 1);
            for (firstMapIndex..lastMapIndex + 1) |mapIndex| {
                self.indexKindMap[mapIndex].set(kindIndex);
            }
        }
    }

    pub fn indexToKind(self: *const Self, index: u32) TK {
        const mapIndex = self.indexKindMapIndex(index);
        const indexKinds = self.indexKindMap[mapIndex];
        // Fast-path - just one kind set. Kind of redundant, but avoids the loop overhead.
        if (indexKinds.count() == 1) {
            const kindIndex = indexKinds.findFirstSet() orelse unreachable;
            return @enumFromInt(kindIndex);
        }
        var iter = indexKinds.iterator(.{});
        while (iter.next()) |kindIndex| {
            const start = self.reservedStart(kindIndex);
            const end = self.ranges[kindIndex].end;
            if (start <= index and index < end) return @enumFromInt(kindIndex);
        }

        unreachable;
    }
};
