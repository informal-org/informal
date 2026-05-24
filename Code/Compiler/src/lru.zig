const std = @import("std");

pub fn Lru(comptime capacity: u8) type {
    return struct {
        const Self = @This();
        const none_handle = std.math.maxInt(u8);

        const Link = struct {
            prev: u8,
            next: u8,
        };

        links: [capacity]Link = initLinks(),
        head: u8 = none_handle,
        tail: u8 = none_handle,

        pub fn set(self: *Self, handle: u8) void {
            std.debug.assert(handle < capacity);

            if (self.tail == handle) {
                return;
            }

            if (self.isLinked(handle)) {
                self.unlink(handle);
            }
            self.pushTail(handle);
        }

        pub fn popLru(self: *Self) ?u8 {
            if (self.head == none_handle) {
                return null;
            }

            const handle = self.head;
            self.unlink(handle);
            return handle;
        }

        fn isLinked(self: *const Self, handle: u8) bool {
            const link = self.links[handle];
            return link.prev != handle or link.next != handle;
        }

        fn unlink(self: *Self, handle: u8) void {
            std.debug.assert(handle < capacity and self.isLinked(handle));

            const link = self.links[handle];

            if (link.prev == none_handle) {
                self.head = link.next;
            } else {
                self.links[link.prev].next = link.next;
            }

            if (link.next == none_handle) {
                self.tail = link.prev;
            } else {
                self.links[link.next].prev = link.prev;
            }

            self.links[handle] = vacant(handle);
        }

        fn pushTail(self: *Self, handle: u8) void {
            self.links[handle] = .{ .prev = self.tail, .next = none_handle };

            if (self.tail == none_handle) {
                self.head = handle;
            } else {
                self.links[self.tail].next = handle;
            }
            self.tail = handle;
        }

        fn initLinks() [capacity]Link {
            var links: [capacity]Link = undefined;
            for (&links, 0..) |*link, index| {
                link.* = vacant(@intCast(index));
            }
            return links;
        }

        fn vacant(handle: u8) Link {
            return .{ .prev = handle, .next = handle };
        }
    };
}

test "LRU stores links as two byte entries" {
    const Cache = Lru(32);
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Cache.Link));
}

test "LRU returns least recently set handle" {
    var cache = Lru(32){};

    cache.set(3);
    cache.set(8);
    cache.set(1);

    try std.testing.expectEqual(@as(?u8, 3), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 8), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 1), cache.popLru());
    try std.testing.expectEqual(@as(?u8, null), cache.popLru());
}

test "LRU setting middle handle makes it most recent" {
    var cache = Lru(32){};

    cache.set(3);
    cache.set(8);
    cache.set(1);
    cache.set(8);

    try std.testing.expectEqual(@as(?u8, 3), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 1), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 8), cache.popLru());
    try std.testing.expectEqual(@as(?u8, null), cache.popLru());
}

test "LRU setting head handle makes it most recent" {
    var cache = Lru(32){};

    cache.set(3);
    cache.set(8);
    cache.set(1);
    cache.set(3);

    try std.testing.expectEqual(@as(?u8, 8), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 1), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 3), cache.popLru());
    try std.testing.expectEqual(@as(?u8, null), cache.popLru());
}

test "LRU supports all handles in capacity" {
    var cache = Lru(32){};

    for (0..32) |handle| {
        cache.set(@intCast(handle));
    }

    for (0..32) |handle| {
        try std.testing.expectEqual(@as(?u8, @intCast(handle)), cache.popLru());
    }
    try std.testing.expectEqual(@as(?u8, null), cache.popLru());
}

test "LRU promotes handles in full capacity chain" {
    var cache = Lru(32){};

    for (0..32) |handle| {
        cache.set(@intCast(handle));
    }

    cache.set(0);
    cache.set(31);
    cache.set(16);

    for (1..16) |handle| {
        try std.testing.expectEqual(@as(?u8, @intCast(handle)), cache.popLru());
    }
    for (17..31) |handle| {
        try std.testing.expectEqual(@as(?u8, @intCast(handle)), cache.popLru());
    }
    try std.testing.expectEqual(@as(?u8, 0), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 31), cache.popLru());
    try std.testing.expectEqual(@as(?u8, 16), cache.popLru());
    try std.testing.expectEqual(@as(?u8, null), cache.popLru());
}
