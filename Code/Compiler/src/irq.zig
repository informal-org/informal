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

pub fn IRQueue(comptime t: type) type {
    return struct {
        const Self = @This();
        const ArrayList = std.array_list.Aligned(t, null);
        ranges: [64]Range = std.mem.zeroes([64]Range),
        list: ArrayList,
        stack: ArrayList,

        fn zeroValue() t {
            if (t == Node) return @as(t, Node{ .raw = std.mem.zeroes(u64) });
            return std.mem.zeroes(t);
        }

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .list = try ArrayList.initCapacity(allocator, 0),
                .stack = try ArrayList.initCapacity(allocator, 0),
            };
        }

        // reserve is the queue's allocation path and is meant to be called once after init.
        pub fn reserve(self: *Self, allocator: Allocator, kindCounts: [64]u32, maxDepth: usize) !void {
            var tail: u32 = 0;
            for (0..64) |i| {
                self.ranges[i].start = tail;
                tail += kindCounts[i];
                self.ranges[i].end = tail;
            }

            const totalLen: usize = @intCast(tail);
            self.list.clearRetainingCapacity();
            self.stack.clearRetainingCapacity();
            try self.list.ensureTotalCapacity(allocator, totalLen);
            try self.stack.ensureTotalCapacity(allocator, maxDepth);
            self.list.appendNTimesAssumeCapacity(zeroValue(), totalLen); // TODO: Could I just use @memset here
        }

        fn kindStart(self: *Self, kind: TK) u32 {
            return self.ranges[@intFromEnum(kind)].start;
        }

        pub fn emitKind(self: *Self, kind: TK, value: Node) u32 {
            const kindIndex = @intFromEnum(kind);
            const index = self.kindStart(kind);
            std.debug.assert(index < self.ranges[kindIndex].end);
            self.set(index, value);
            self.ranges[kindIndex].start += 1;
            return index;
        }

        pub fn get(self: *Self, index: u32) t {
            std.debug.assert(index < self.list.items.len);
            return self.list.items[index];
        }

        pub fn set(self: *Self, index: u32, value: t) void {
            std.debug.assert(index < self.list.items.len);
            self.list.items[index] = value;
        }

        pub fn pushArg(self: *Self, left: u32, right: usize) void {
            std.debug.assert(self.stack.items.len < self.stack.capacity);
            self.stack.appendAssumeCapacity(args(left, @intCast(right)));
        }

        pub fn popUnary(self: *Self) Node {
            return self.stack.pop() orelse zeroValue();
        }

        pub fn popBinary(self: *Self) Node {
            const right = self.stack.pop() orelse zeroValue();
            const left = self.stack.pop() orelse zeroValue();
            return args(left.args.left, right.args.left);
        }

        pub fn createFrame(self: *Self, argCount: u32) u32 {
            const argIndex = self.kindStart(TK.ir_arg);
            return self.emitKind(TK.ir_frame, args(argIndex, argCount));
        }

        pub fn createParam(self: *Self) u32 {
            const paramIndex = self.kindStart(TK.ir_param);
            // Arg tail, ref tail (TODO: Is ref tail useful?)
            self.emitKind(TK.ir_param, args(paramIndex, 0));
            return paramIndex;
        }

        pub fn createFrameArg(self: *Self, paramIndex: u32, value: u32) u32 {
            var param = self.get(paramIndex);
            const argTail = param.args.left;
            const argIndex = self.emitKind(TK.ir_arg, args(value, argTail));
            param.args.left = argIndex;
            self.set(paramIndex, param);
            return argIndex;
        }

        // pub fn popArgs(self: *Self, count: usize) Node {
        //     std.debug.assert(count > 0);
        //     if (count == 1) {
        //         // Unary fn.
        //         return self.stack.pop() orelse zeroValue();
        //     } else if (count == 2) {
        //         // Pop and merge
        //         const right = self.stack.pop() orelse zeroValue();
        //         const left = self.stack.pop() orelse zeroValue();
        //         return args(left.args.left, right.args.left);
        //     } else {
        //         // N-ary function call. Need to construct a frame instead.
        //     }
        // }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.list.deinit(allocator);
            self.stack.deinit(allocator);
        }
    };
}
