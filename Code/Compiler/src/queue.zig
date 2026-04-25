// A producer-consumer queue.
// The producer can add items to one end of the queue and the consumer can remove or iterate over items from the other end.
// Backed by a zig standard arraylist. Stores just u64 values.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Queue(comptime t: type, comptime default: t) type {
    return struct {
        const Self = @This();
        // const Allocator = std.heap.page_allocator;
        const ArrayList = std.array_list.Aligned(t, null);

        list: ArrayList,
        allocator: Allocator,
        head: usize,
        tail: usize,
        default: t = default,

        pub fn init(allocator: Allocator) !Self {
            const list = try ArrayList.initCapacity(allocator, 0);
            return Self{
                .list = list,
                .allocator = allocator,
                .head = 0,
                .tail = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }

        pub fn reserve(self: *Self, newCapacity: usize) !void {
            try self.list.ensureTotalCapacity(self.allocator, newCapacity);
        }

        pub fn push(self: *Self, value: t) void {
            // std.debug.print("pushing value to queue {any}\n", .{value});
            std.debug.assert(self.tail <= self.list.capacity);
            self.list.appendAssumeCapacity(value);
            self.tail += 1;
        }

        // Push - may resize. Only meant to be used by the lexer.
        pub fn pushDynamic(self: *Self, value: t) !void {
            try self.list.append(self.allocator, value);
            self.tail += 1;
        }

        pub fn reset(self: *Self) void {
            self.head = 0;
            self.tail = 0;
            self.list.clearRetainingCapacity();
        }

        pub fn pop(self: *Self) t {
            if (self.head == self.tail) {
                return default;
            }

            const value = self.list.items[self.head];
            self.head += 1;
            return value;
        }

        pub fn peek(self: *Self) t {
            if (self.head == self.tail) {
                return default;
            }
            return self.list.items[self.head];
        }
    };
}

pub const Range = packed struct(u64) {
    start: u32, // Precomputed from the results of Parser's kind count
    end: u32, // Incremented as elements are added.
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

        pub fn reserve(self: *Self, ranges: [64]u32) !void {
            // TODO: The current scheme makes it hard to know where the last one ends.
            // Maybe the layer below returns sizes not indexes? So indexes are off by one?
            for (0..64) |i| {
                self.ranges[i].start = ranges[i];
            }
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }
    };
}
