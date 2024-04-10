// A producer-consumer queue.
// The producer can add items to one end of the queue and the consumer can remove or iterate over items from the other end.
// Backed by a zig standard arraylist. Stores just u64 values.

const std = @import("std");
const Allocator = std.mem.Allocator;


pub const Queue = struct {
    // const Allocator = std.heap.page_allocator;
    const ArrayList = std.ArrayList(u64);

    list: ArrayList,
    head: usize,
    tail: usize,

    pub fn init(allocator: Allocator) Queue {
        return Queue{
            .list = ArrayList.init(allocator),
            .head = 0,
            .tail = 0,
        };
    }

    pub fn push(self: *Queue, value: u64) void {
        self.list.append(value);
        self.tail += 1;
    }

    pub fn next(self: *Queue) ?u64 {
        if (self.head == self.tail) {
            return null;
        }

        const value = self.list[self.head];
        self.head += 1;
        return value;
    }
};
