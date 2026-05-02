const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
const TK = tok.Kind;

pub const Range = packed struct(u64) {
    start: u32, // Incremented on add
    end: u32, // Precomputed from the results of Parser's kind count
};

pub const Node = packed union {
    raw: u64,
    args: Args,

    pub const Args = packed struct(u64) {
        left: u32,
        right: u32,
    };
};

pub fn args(left: u32, right: u32) Node {
    return Node{ .args = .{ .left = left, .right = right } };
}

pub fn IRQueue(comptime t: type, comptime default: t) type {
    return struct {
        const Self = @This();
        const ArrayList = std.array_list.Aligned(t, null);
        ranges: [64]Range = [_]Range{Range{ .start = 0, .end = 0 }} ** 64,
        list: ArrayList,
        stack: ArrayList,

        default: t = default,

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .allocator = allocator,
                .list = try ArrayList.initCapacity(allocator, 0),
                .stack = try ArrayList.initCapacity(allocator, 0),
            };
        }

        pub fn reserve(self: *Self, kindCounts: [64]u32, maxDepth: usize) !void {
            var tail: u32 = 0;
            for (0..64) |i| {
                self.ranges[i].start = tail;
                tail += kindCounts[i];
                self.ranges[i].end = tail;
            }
            try self.list.ensureTotalCapacity(self.allocator, tail + 1);
            try self.stack.ensureTotalCapacity(self.allocator, maxDepth);
        }

        pub fn emitKind(self: *Self, kind: TK, value: Node) u32 {
            const index = self.ranges[@intFromEnum(kind)].start;
            std.debug.assert(index < self.list.capacity);
            std.debug.assert(index <= self.ranges[@intFromEnum(kind)].end);
            self.list.insertAssumeCapacity(index, value);
            self.ranges[@intFromEnum(kind)].start += 1;
            return index;
        }

        pub fn pushArg(self: *Self, left: u32, right: u32) void {
            self.stack.appendAssumeCapacity(args(left, right));
        }

        pub fn popUnary(self: *Self) Node {
            return self.stack.pop() orelse self.default;
        }

        pub fn popBinary(self: *Self) Node {
            const right = self.stack.pop() orelse self.default;
            const left = self.stack.pop() orelse self.default;
            return Node{ .left = left.left, .right = right.left };
        }

        pub fn emitCallArgs(_: *Self, _: usize) void {
            // todo
        }

        // pub fn popArgs(self: *Self, count: usize) Node {
        //     std.debug.assert(count > 0);
        //     if (count == 1) {
        //         // Unary fn.
        //         return self.stack.pop() orelse self.default;
        //     } else if (count == 2) {
        //         // Pop and merge
        //         const right = self.stack.pop() orelse self.default;
        //         const left = self.stack.pop() orelse self.default;
        //         return Node{ .left = left.left, .right = right.left };
        //     } else {
        //         // N-ary function call. Need to construct a frame instead.
        //     }
        // }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }
    };
}
