// A sparse hierarchical bitset.
// Layer 0 - 1 if that segment in subsequent layers is set. i.e. [0 0 1 0 0 0 1 0]
// Would indicate that the range from 0 to 1*width has nothing set,
// and there is something set between 2*width to 3*width and something between [6,7]*width
// That would then subsequently be followed by popcount(layer) number of bitsets indicating the presence in subsequent layers.
// To index into lower levels, we maintain a total offset count.

const std = @import("std");
const assert = std.debug.assert;
const stdbits = std.bit_set;
const Allocator = std.mem.Allocator;
const LEVEL_WIDTH = 64;
const IntegerBitSet = stdbits.IntegerBitSet;
pub const BitSet = IntegerBitSet(LEVEL_WIDTH);
const constants = @import("constants.zig");
const DEBUG = constants.DEBUG;

pub fn TaggedPointer(comptime Tag: type, comptime Ptr: type) type {
    // There's two schemes for tagging we can use here.
    // 1. Tag the lower bits, which should always be zero due to pointer alignment.
    // 2. Tag the upper bits, relying on the fact that of the 64 bit address space, only 48 bits are generally used by OSes in practice.
    // In WASM, we'll need to fallback to a longer version (not implemented yet)
    // With Zig's comptime, we could swap between the two-options using this same abstraction if we want.
    // References this implementation: // https://zig.news/orgold/type-safe-tagged-pointers-with-comptime-ghi

    const ChoppedPtr = std.meta.Int(.unsigned, @bitSizeOf(usize) - @bitSizeOf(Tag));
    assert(@bitSizeOf(ChoppedPtr) >= 48); // Safety check - ensure we can cover the full standard virtual memory pointer space.

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

        pub fn init() Self {
            return Self{
                .head = IntegerBitSet(@bitSizeOf(T)).initEmpty(),
                .data = null,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.data != null and self.head.count() > 0) {
                allocator.free(self.data.?);
                self.data = null;
            }
        }

        fn getIndex(self: *const Self, at: IndexInt) IndexInt {
            const topNMask = (@as(T, 1) << at) - 1;
            const count = @popCount(self.head.mask & topNMask);
            // Safety check for the truncate to ensure it'll fit. This method shouldn't be used in contexts where all bits are set.
            assert(count < @bitSizeOf(T));
            return @truncate(count);
        }

        pub fn set(self: *Self, allocator: std.mem.Allocator, at: IndexInt, data: D) !void {
            if (self.head.isSet(at)) {
                // Already set - replace the item in-place
                const index = self.getIndex(at);
                self.data.?[index] = data;
            } else {
                self.head.set(at);
                const index = self.getIndex(at);
                const newSize = self.head.count();

                if (self.data == null) {
                    self.data = try allocator.alloc(D, newSize);
                    self.data.?[index] = data;
                } else {
                    // Grow capacity and shift elements over if inserting in between.
                    const oldSize = newSize - 1;
                    self.data = try allocator.realloc(self.data.?, newSize);

                    if (index < oldSize) {
                        // Move elements to make space at index
                        const src = self.data.?[index..oldSize];
                        const dest = self.data.?[index + 1 .. oldSize + 1];
                        @memcpy(dest, src);
                    }
                }
                self.data.?[index] = data;
            }
        }

        pub fn get(self: *const Self, at: IndexInt) ?D {
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

const LvlPointer = TaggedPointer(BitsetType, BitsetLevel);

const BitsetLevel = struct {
    const Self = @This();
    data: SparseArray(u64, LvlPointer),

    pub fn init() Self {
        return Self{
            .data = SparseArray(u64, LvlPointer).init(),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Recursively deinit all nested levels
        const len = self.data.head.count();
        if (len > 0 and self.data.data != null) {
            for (self.data.data.?[0..len]) |ptr| {
                if (ptr.tag == BitsetType.Nested) {
                    if (ptr.getPointer()) |nested| {
                        nested.deinit(allocator);
                        allocator.destroy(nested);
                    }
                }
            }
        }
        self.data.deinit(allocator);
    }
};

/// A compact hierarchical representation of a sparse bitset of a fixed maximum size.
/// The hierarchical structure optimizes many of the bitset operations and allows for short-circuiting.
pub fn SparseBitset(comptime Range: type) type {
    const MAX_VALUE = std.math.maxInt(Range);
    const BITS_PER_LEVEL = std.math.log2_int_ceil(Range, LEVEL_WIDTH); // 6 bits per level for 64-wide bitset.
    // How many levels it takes to store the maximum value.
    const LEVEL_COUNT = std.math.log2_int_ceil(Range, MAX_VALUE) / BITS_PER_LEVEL;

    // Bit positions within each level's sparse-array.
    const BitPositionType = std.meta.Int(.unsigned, BITS_PER_LEVEL);
    const ShiftType = std.math.Log2Int(Range);

    return struct {
        const Self = @This();
        level: BitsetLevel,

        pub fn init() Self {
            return Self{
                .level = BitsetLevel.init(),
            };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.level.deinit(allocator);
        }

        const traverse = struct {
            const Traversal = @This();
            const level_count: i32 = @intCast(LEVEL_COUNT);

            current_level: *BitsetLevel,
            level_idx: i32,
            index: Range,
            pub fn init(self: *Self, index: Range) Traversal {
                return Traversal{
                    .current_level = &self.level,
                    .level_idx = @intCast(LEVEL_COUNT),
                    .index = index,
                };
            }

            // Const version of init for isSet method
            pub fn initConst(self: *const Self, index: Range) Traversal {
                return Traversal{
                    .current_level = @constCast(&self.level),
                    .level_idx = @intCast(LEVEL_COUNT),
                    .index = index,
                };
            }

            pub fn get_bit_position(self: *Traversal) BitPositionType {
                // Get the bit position of this index within this level.
                assert(self.level_idx >= 0);
                const shift_amount: ShiftType = @intCast(self.level_idx * BITS_PER_LEVEL);
                return @intCast((self.index >> shift_amount) & (LEVEL_WIDTH - 1));
            }

            pub fn next(self: *Traversal) bool {
                // Iterate down to the next-level and return whether the bit for this index is set or not.
                // Maintains state so that we can traverse further, terminate early or create nodes as necessary.
                if (self.level_idx >= 0) {
                    const bit_position = self.get_bit_position();
                    if (self.level_idx == 0) {
                        // The root levels just use the bitset head without further references.
                        // You could optimize this further by having the leaf-pointers point directly to bitsets rather than sparse-arrays.
                        const is_set = self.current_level.data.head.isSet(bit_position);
                        if (is_set) {
                            // Mark as terminal. But don't if it's not set so that we can create it.
                            self.level_idx -= 1;
                        }
                        return is_set;
                    } else {
                        var nextLevel = self.current_level.data.get(bit_position);
                        if (nextLevel == null) {
                            return false;
                        } else {
                            self.level_idx -= 1;
                            self.current_level = nextLevel.?.getPointer().?;
                            return true;
                        }
                    }
                }
                return false;
            }

            pub fn create(self: *Traversal, allocator: Allocator) !void {
                // Ensure we're not trying to create a level below the leaf level
                if (self.level_idx < 0) return;

                const bit_position = self.get_bit_position();
                if (self.level_idx == 0) {
                    // Just set the bit directly
                    self.current_level.data.head.set(bit_position);
                    // Mark that we've reached the end of traversal
                    self.level_idx -= 1;
                } else {
                    // Create a new nested level
                    const next_level = try allocator.create(BitsetLevel);
                    next_level.* = BitsetLevel.init();

                    const tagged_lvl_pointer = LvlPointer.init(BitsetType.Nested, next_level);
                    try self.current_level.data.set(allocator, bit_position, tagged_lvl_pointer);

                    self.current_level = next_level;
                    assert(self.level_idx > 0);
                    self.level_idx -= 1;
                }
            }
        };

        pub fn set(
            self: *Self,
            allocator: Allocator,
            index: Range,
        ) !void {
            // Levels start at MSB->LSB (0)
            var iter = traverse.init(self, index);
            while (iter.level_idx >= 0) {
                // If we can't traverse further and we're not at the end, create the necessary level
                if (!iter.next()) {
                    try iter.create(allocator);
                }
            }
        }

        pub fn isSet(self: *const Self, index: Range) bool {
            var iter = traverse.initConst(self, index);
            while (iter.level_idx >= 0) {
                if (iter.level_idx == 0) {
                    return iter.next();
                } else if (!iter.next()) {
                    // Terminate early if any levels indicate there's nothing under that range.
                    return false;
                }
            }
            // If we've exhausted all levels without finding the bit, it's not set
            return false;
        }
    };
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

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
    var pca = PCA.init();
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

// SparseBitset tests
test "SparseBitset basic functionality" {
    std.debug.print("SparseBitset basic functionality\n", .{});
    // Test with u16 to keep the test simple but still require multiple levels
    const SB = SparseBitset(u16);
    var sb = SB.init();
    defer sb.deinit(test_allocator);

    // Initially, no bits should be set
    try expectEqual(sb.isSet(0), false);
    try expectEqual(sb.isSet(1), false);
    try expectEqual(sb.isSet(42), false);
    try expectEqual(sb.isSet(1000), false);

    // Set a few bits and check they're set
    try sb.set(test_allocator, 0);
    try expectEqual(sb.isSet(0), true);
    try expectEqual(sb.isSet(1), false);

    try sb.set(test_allocator, 1);
    try expectEqual(sb.isSet(1), true);

    try sb.set(test_allocator, 63);
    try expectEqual(sb.isSet(63), true);
    try expectEqual(sb.isSet(62), false);
    try expectEqual(sb.isSet(64), false);

    try sb.set(test_allocator, 64);
    try expectEqual(sb.isSet(64), true);

    try sb.set(test_allocator, 1000);
    try expectEqual(sb.isSet(1000), true);
    try expectEqual(sb.isSet(999), false);
    try expectEqual(sb.isSet(1001), false);
}

test "SparseBitset level boundaries" {
    std.debug.print("SparseBitset level boundaries\n", .{});
    // Test behavior at level boundaries
    const SB = SparseBitset(u32);
    var sb = SB.init();
    defer sb.deinit(test_allocator);

    // Test level 0 to level 1 boundary (at 64)
    try sb.set(test_allocator, 63);
    try sb.set(test_allocator, 64);
    try expectEqual(sb.isSet(63), true);
    try expectEqual(sb.isSet(64), true);

    // Test level 1 to level 2 boundary (at 64*64 = 4096)
    try sb.set(test_allocator, 4095);
    try sb.set(test_allocator, 4096);
    try expectEqual(sb.isSet(4095), true);
    try expectEqual(sb.isSet(4096), true);
}

test "SparseBitset idempotence" {
    std.debug.print("SparseBitset idempotence\n", .{});
    // Setting a bit multiple times should have the same effect as setting it once
    const SB = SparseBitset(u32);
    var sb = SB.init();
    defer sb.deinit(test_allocator);

    try sb.set(test_allocator, 42);
    try expectEqual(sb.isSet(42), true);

    // Set the same bit again
    try sb.set(test_allocator, 42);
    try expectEqual(sb.isSet(42), true);

    // Set a bit at a higher level
    try sb.set(test_allocator, 1000);
    try expectEqual(sb.isSet(1000), true);

    // Set it again
    try sb.set(test_allocator, 1000);
    try expectEqual(sb.isSet(1000), true);
}

test "SparseBitset sparse patterns" {
    std.debug.print("SparseBitset sparse patterns\n", .{});
    // Test with very sparse patterns to ensure the hierarchical structure works correctly
    const SB = SparseBitset(u32);
    var sb = SB.init();
    defer sb.deinit(test_allocator);

    // Set bits with large gaps
    const test_bits = [_]u32{ 0, 63, 64, 127, 128, 4095, 4096, 8191, 8192, 100000 };

    // Set each bit
    for (test_bits) |bit| {
        try sb.set(test_allocator, bit);
    }

    // Verify each bit is set
    for (test_bits) |bit| {
        try expectEqual(sb.isSet(bit), true);
    }

    // Check some bits in between are not set
    const unset_bits = [_]u32{ 1, 62, 65, 1000, 4097, 9000, 99999, 100001 };
    for (unset_bits) |bit| {
        try expectEqual(sb.isSet(bit), false);
    }
}

test "SparseBitset edge cases" {
    // Test extremes and edge cases
    {
        // Test with u8 (small range)
        const SB8 = SparseBitset(u8);
        var sb = SB8.init();
        defer sb.deinit(test_allocator);

        try sb.set(test_allocator, 0);
        try sb.set(test_allocator, 255); // Max u8 value
        try expectEqual(sb.isSet(0), true);
        try expectEqual(sb.isSet(255), true);
    }

    {
        // Test with u16
        const SB16 = SparseBitset(u16);
        var sb = SB16.init();
        defer sb.deinit(test_allocator);

        try sb.set(test_allocator, 0);
        try sb.set(test_allocator, 65535); // Max u16 value
        try expectEqual(sb.isSet(0), true);
        try expectEqual(sb.isSet(65535), true);
    }
}

test "SparseBitset consecutive ranges" {
    // Test setting and checking consecutive ranges of bits
    const SB = SparseBitset(u16);
    var sb = SB.init();
    defer sb.deinit(test_allocator);

    // Set a full consecutive range within one level
    for (0..64) |i| {
        try sb.set(test_allocator, @intCast(i));
    }

    // Verify all bits in the range are set
    for (0..64) |i| {
        try expectEqual(sb.isSet(@intCast(i)), true);
    }

    // Set a range that crosses a level boundary
    for (60..70) |i| {
        try sb.set(test_allocator, @intCast(i));
    }

    // Verify the cross-boundary range
    for (60..70) |i| {
        try expectEqual(sb.isSet(@intCast(i)), true);
    }
}

test "SparseBitset memory leaks" {
    // This test doesn't directly verify memory leaks but uses defer to ensure
    // proper cleanup. Memory tools like valgrind or ASAN would catch leaks.
    var iterations: usize = 0;
    while (iterations < 10) : (iterations += 1) {
        const SB = SparseBitset(u32);
        var sb = SB.init();
        defer sb.deinit(test_allocator);

        // Create a complex hierarchy to test deinit
        const test_bits = [_]u32{ 0, 67, 134, 4097, 8194, 100000 };
        for (test_bits) |bit| {
            try sb.set(test_allocator, bit);
            try expectEqual(sb.isSet(bit), true);
        }
    }
    // If there are memory leaks, the test allocator will report them
}
