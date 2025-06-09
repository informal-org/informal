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
/// TODO: A variant of this which grows dynamically by doubling with empty slots in between.
/// This variant is more compact and optimized for static data. The dynamic version will be better for dynamic inserts.
/// There is a neat approach to figuring out the indexing with that. We know the array length from data.len, and we know
/// occupancy from head.popcount(). Assume len will always be a power of 2.
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
