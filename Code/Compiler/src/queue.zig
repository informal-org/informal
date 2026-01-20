// A producer-consumer queue.
// The producer can add items to one end of the queue and the consumer can remove or iterate over items from the other end.
// Backed by a zig standard arraylist. Stores just u64 values.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Queue(comptime t: type, comptime default: t) type {
    return struct {
        const Self = @This();
        // const Allocator = std.heap.page_allocator;
        const ArrayList = std.array_list.AlignedManaged(t, null);

        list: ArrayList,
        head: usize,
        tail: usize,
        default: t = default,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .list = ArrayList.init(allocator),
                .head = 0,
                .tail = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit();
        }

        pub fn push(self: *Self, value: t) !void {
            // std.debug.print("pushing value to queue {any}\n", .{value});
            try self.list.append(value);
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

        pub fn popLast(self: *Self) t {
            return self.list.pop() orelse default;
        }
    };
}
