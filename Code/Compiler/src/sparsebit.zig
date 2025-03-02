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

    const ChoppedPtr = ptr_type: {
        // This trick is from
        // https://zig.news/orgold/type-safe-tagged-pointers-with-comptime-ghi
        var info = @typeInfo(usize);
        info.int.bits -= @bitSizeOf(Tag);
        break :ptr_type @Type(info);
    };
    assert(@bitSizeOf(ChoppedPtr) >= 48); // Can't go beyond this.

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

pub fn PopCountArray(comptime T: type, comptime D: type) type {
    return struct {
        const Self = @This();
        head: IntegerBitSet(@bitSizeOf(T)),
        data: []D,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .head = IntegerBitSet(@bitSizeOf(T)).initEmpty(),
                .data = &[_]D{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.head.count() > 0) {
                allocator.free(self.data);
            }
        }

        pub fn set(self: *Self, index: u32) !void {
            self.head.set(index);
        }
    };
}

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
