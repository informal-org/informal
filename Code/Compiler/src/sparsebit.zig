// A sparse hierarchical bitset.
// Layer 0 - 1 if that segment in subsequent layers is set. i.e. [0 0 1 0 0 0 1 0]
// Would indicate that the range from 0 to 1*width has nothing set,
// and there is something set between 2*width to 3*width and something between [6,7]*width
// That would then subsequently be followed by popcount(layer) number of bitsets indicating the presence in subsequent layers.
// To index into lower levels, we maintain a total offset count.

const std = @import("std");
const assert = std.debug.assert;
const stdbits = std.bit_set;

const LEVEL_WIDTH = 64;
const IntegerBitSet = stdbits.IntegerBitSet;
pub const BitSet = IntegerBitSet(LEVEL_WIDTH);

pub fn TaggedPointer(comptime Tag: type, comptime Ptr: type) type {
    // There's two schemes for tagging we can use here.
    // 1. Tag the lower bits, which should always be zero due to pointer alignment.
    // 2. Tag the upper bits, relying on the fact that of the 64 bit address space, only 48 bits are generally used by OSes in practice.
    // In WASM, we'll need to fallback to a longer version.
    // With Zig's comptime, we could swap between the two-options using this same abstraction if we want.
    // References this implementation: // https://zig.news/orgold/type-safe-tagged-pointers-with-comptime-ghi

    const ChoppedPtr = std.meta.Int(.unsigned, @bitSizeOf(usize) - @bitSizeOf(Tag));

    //     // var info = @typeInfo(usize);
    //     // info.int.bits -= @bitSizeOf(Tag);
    //     break :ptr_type @Type(info);
    // };
    assert(@bitSizeOf(ChoppedPtr) >= 48); // Can't go below this.

    // Safety check to ensure there's enough alignment - if we're using option 1.
    if (@ctz(@as(usize, @alignOf(Ptr))) >= @bitSizeOf(Tag)) {
        // If there are enough trailing zeroes, use the alignment approach.
        return packed struct(u64) {
            tag: Tag,
            ptr: ChoppedPtr, // Remaining size for pointer, i.e. u48, u62, etc.

            pub inline fn init(tag: Tag, ptr: ?*Ptr) @This() {
                return @This(){
                    .tag = tag,
                    // Truncate to discard the high bits and use it for tags.
                    .ptr = @intCast(@intFromPtr(ptr) >> @bitSizeOf(Tag)),
                };
            }

            pub inline fn getPointer(self: @This()) ?*Ptr {
                return @ptrFromInt(@as(usize, self.ptr) << @bitSizeOf(Tag));
            }
        };
    } else {
        // Use the top-bits instead, which is less portable but has more space for tags.
        return packed struct(u64) {
            tag: Tag,
            ptr: ChoppedPtr, // Remaining size for pointer, i.e. u48, u62, etc.

            pub inline fn init(tag: Tag, ptr: ?*Ptr) @This() {
                return @This(){
                    .tag = tag,
                    // Truncate to discard the high bits and use it for tags.
                    .ptr = @truncate(@intFromPtr(ptr)),
                };
            }

            pub inline fn getPointer(self: @This()) ?*Ptr {
                return @ptrFromInt(@as(usize, self.ptr));
            }
        };
    }
}

/// A compact sparse array where only certain elements, denoted by a bitset, are set.
/// Suitable only for small-sizes (64, 128, 256, etc.)
pub fn SparseArray(comptime T: type, comptime D: type) type {
    const IndexInt = std.math.Log2Int(T);
    return struct {
        const Self = @This();
        head: IntegerBitSet(@bitSizeOf(T)),
        // The Zig array slice does store the length-internally, which could be avoided since we store it via popcnt(head)
        // But then you're kinda on you're own with all system methods. So we'll stick with slices.
        data: ?[]D,

        pub fn init() !Self {
            return Self{
                .head = IntegerBitSet(@bitSizeOf(T)).initEmpty(),
                .data = &[_]D{},
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.head.count() > 0) {
                allocator.free(self.data.?);
            }
        }

        fn getIndex(self: *Self, at: IndexInt) IndexInt {
            const topNMask = (@as(T, 1) << at) - 1;
            const count = @popCount(self.head.mask & topNMask);
            // Safety check for the truncate to ensure it'll fit. This method shouldn't be used in contexts where all bits are set.
            assert(count < @bitSizeOf(T));
            return @truncate(count);
        }

        pub fn set(self: *Self, allocator: std.mem.Allocator, at: IndexInt, data: D) !void {
            // New element. Add it in the array at the right spot.
            const index = self.getIndex(at);
            if (self.head.isSet(at)) {
                // Already set - replace the item in-place
                self.data.?[index] = data;
            } else {
                // New element. Shift remaining elements down.
                const to_shift = self.head.count() - index;
                // std.debug.print("Insert at {d}. Len {d} - Shifting {d} elements\n", .{ index, self.head.count(), to_shift });
                self.head.set(at);
                const newSize = self.head.count();
                if (!allocator.resize(self.data.?, newSize)) {
                    self.data = try allocator.realloc(self.data.?, newSize);
                }
                if (to_shift > 0) {
                    @memcpy(self.data.?[index + 1 ..][0..to_shift], self.data.?[index..][0..to_shift]);
                }
                self.data.?[index] = data;
            }
        }

        pub fn get(self: *Self, at: IndexInt) ?D {
            if (self.head.isSet(at)) {
                const index = self.getIndex(at);
                return self.data.?[index];
            }
            return null;
        }
    };
}

const BitsetType = enum(u2) {
    Direct, // Bitset stored directly.
    Nested, // Hiearchical. Contains further levels.
    Runs, // Runs of 1s (offset, length).
    Sparse, // Covers a larger range, with a few bits set.
    // Other options:
    // Variants of the sparse - sparse8, sparse16, sparse32
    // Selection pointer - a 16/32 bit offset and remaining bits for direct bitsets.
};

const LvlPointer = TaggedPointer(BitsetType, SparseBitsetLevel);

pub const SparseBitsetLevel = struct {
    const Self = @This();
    data: SparseArray(u64, LvlPointer),
};

const SparseLevelBitset = struct {
    const Self = @This();

    bitlevels: std.ArrayList(BitSet),
    // Level 0 starts at 0. Level 1 starts at 1, and extends till popcount of level 0 + 1.
    // Level 2 then extends from popcount(lvl0) + 1 till sum of level 1 popcounts.
    lvloffsets: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !Self {
        var bitlevels = std.ArrayList(BitSet).init(allocator);
        var lvloffsets = std.ArrayList(u32).init(allocator);
        try bitlevels.append(BitSet.initEmpty());
        try lvloffsets.append(0); // Future optimization: We can skip storing the offsets for level 0, 1 and 2 since that's trivially known.

        return Self{
            .bitlevels = bitlevels,
            .lvloffsets = lvloffsets,
        };
    }

    pub fn deinit(self: *Self) void {
        self.bitlevels.deinit();
    }

    pub fn set(self: *Self, index: u32) !void {
        var current_index = index;
        var level_index: usize = 0;
        var bs_index: usize = 0;
        while (current_index >= LEVEL_WIDTH) {
            assert(level_index < self.lvloffsets.items.len);
            // var absolute_index = self.lvloffsets.items[level_index] + level_offset;
            // Fast mod & div - as long as our level-sizes are power of two.
            const segmentIndex = current_index % LEVEL_WIDTH;

            if (self.bitlevels.items[bs_index].isSet(segmentIndex)) {} else {
                self.bitlevels.items[bs_index].set(segmentIndex);
                if (level_index > 1) {
                    self.lvloffsets.items[level_index - 1] += 1;
                }
            }
            self.bitlevels.items[bs_index].set();
            level_index += 1;
            current_index /= LEVEL_WIDTH;
            bs_index += 1;
        }
        if (bs_index >= self.bitlevels.items.len) {
            try self.bitlevels.append(BitSet.initEmpty());
        }
        self.bitlevels.items[bs_index].set(current_index);
    }

    pub fn isSet(self: *const Self, index: u32) bool {
        var current_index = index;
        var bs_index: usize = 0;

        while (current_index >= LEVEL_WIDTH) {
            if (bs_index >= self.bitlevels.items.len) {
                return false;
            }

            // Terminate early if an intermediate layer indicates there's no sparse bit set in subsequent layers.
            if (!self.bitlevels.items[bs_index].isSet(current_index % LEVEL_WIDTH)) {
                return false;
            }

            current_index /= LEVEL_WIDTH;
            bs_index += 1;
        }

        if (bs_index >= self.bitlevels.items.len) {
            return false;
        }

        return self.bitlevels.items[bs_index].isSet(current_index);
    }
};

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const constants = @import("constants.zig");

test "TaggedPointer basic functionality" {
    const TestTag = enum(u2) {
        First = 0,
        Second = 1,
        Third = 2,
    };
    const val: u64 = 12309123009;

    const TestStruct = struct {
        value: u64,
    };

    var test_struct = TestStruct{ .value = val };
    const TaggedTestPtr = TaggedPointer(TestTag, TestStruct);

    var tagged = TaggedTestPtr.init(TestTag.Second, &test_struct);
    try expectEqual(tagged.tag, TestTag.Second);

    const retrieved_ptr = tagged.getPointer();
    try expectEqual(retrieved_ptr.?.value, val);

    // Test with larger tags
    const LargeTag = enum(u8) {
        First = 0,
        Second = 1,
        Third = 2,
    };
    const TaggedLargePtr = TaggedPointer(LargeTag, TestStruct);
    const large_taged = TaggedLargePtr.init(LargeTag.Third, &test_struct);
    try expectEqual(large_taged.tag, LargeTag.Third);
    const large_retrieved_ptr = large_taged.getPointer();
    try expectEqual(large_retrieved_ptr.?.value, val);
}

test {
    if (constants.DISABLE_ZIG_LAZY) {
        @import("std").testing.refAllDecls(@This());
    }
}

test "PopCountArray size" {
    const PCA = SparseArray(u64, u64);
    // Takes 24 bytes if you use a []D
    // Only 16 bytes if you use [*]D, but it's less safe. Can come back to that at some point.
    try expectEqual(24, @sizeOf(PCA));
}

test "PopCountArray basic functionality" {
    const PCA = SparseArray(u64, u64);
    var pca = try PCA.init();
    defer pca.deinit(test_allocator);
    try expectEqual(pca.getIndex(6), 0);
    try pca.set(test_allocator, 5, 1);
    try expectEqual(pca.getIndex(5), 0);
    try expectEqual(pca.getIndex(4), 0);
    try expectEqual(pca.getIndex(6), 1);
    try pca.set(test_allocator, 1, 2);
    try pca.set(test_allocator, 3, 3);
    try expectEqual(pca.get(5), 1);
    try expectEqual(pca.get(1), 2);
    try expectEqual(pca.get(3), 3);
    try expectEqual(pca.get(2), null);
}
