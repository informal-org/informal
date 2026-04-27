const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const TK = tok.Kind;

pub const Range = packed struct(u64) {
    start: u32, // Incremented on add
    end: u32, // Precomputed from the results of Parser's kind count
};

pub const Node = packed struct(u64) {
    left: u32,
    right: u32,
};

pub fn IRQueue(comptime t: type, comptime default: t) type {
    return struct {
        const Self = @This();
        const ArrayList = std.array_list.Aligned(t, null);
        ranges: [64]Range = [_]Range{Range{ .start = 0, .end = 0 }} ** 64,
        list: ArrayList,

        default: t = default,

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .allocator = allocator,
                .list = try ArrayList.initCapacity(allocator, 0),
            };
        }

        pub fn reserve(self: *Self, kindCounts: [64]u32) !void {
            var tail: u32 = 0;
            for (0..64) |i| {
                self.ranges[i].start = tail;
                tail += kindCounts[i];
                self.ranges[i].end = tail;
            }
            try self.list.ensureTotalCapacity(self.allocator, tail + 1);
        }

        pub fn pushKind(self: *Self, kind: TK, value: Node) void {
            const index = self.ranges[@intFromEnum(kind)].start;
            std.debug.assert(index < self.list.capacity);
            std.debug.assert(index <= self.ranges[@intFromEnum(kind)].end);
            self.list.insertAssumeCapacity(index, value);
            self.ranges[@intFromEnum(kind)].start += 1;
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }
    };
}
