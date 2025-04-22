const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub const OffsetArray = struct {
    /// An abstraction for storing series of indexes as offsets.
    /// Most offsets are small, fitting in a byte.
    /// An offset of 0 is used for overflow - it indicates the next 4 bytes represent an absolute 32-bit value.
    /// When you have two offsets that are exactly the same, the next value will represent a 'run' for run-length encoding.
    offsets: std.ArrayList(u8),
    lastIndex: u32 = 0, // Absolute value of the last index.
    // lastOffset and runLength can be figured out from the offsets array, but reading that array backwards is complex and very branchy.
    lastOffset: u32 = 0,
    runLength: u32 = 0,

    pub fn init(allocator: Allocator) OffsetArray {
        return OffsetArray{
            .offsets = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn pushFirst(self: *OffsetArray, index: u32) !void {
        // Only call this the very first time.
        assert(self.offsets.items.len == 0);
        // First is the only case where a zero-index could happen.
        // Which typically indicate an extended byte-value.
        if (index == 0) {
            // One indicator byte, and 4 value bytes.
            try self.offsets.appendSlice(&[_]u8{ 0, 0, 0, 0, 0 });
        } else {
            try self.pushValue(index);
        }
        self.lastIndex = index;
        self.lastOffset = index;
    }

    pub fn deinit(self: *OffsetArray) void {
        self.offsets.deinit();
    }

    fn pushValue(self: *OffsetArray, offset: u32) !void {
        if (offset < 255) {
            try self.offsets.append(@truncate(offset));
        } else {
            // Use 0 as a marker to indicate overflow, and store larger offsets directly.
            try self.offsets.append(0);
            try self.offsets.appendSlice(&std.mem.toBytes(offset));
        }
    }

    pub fn push(self: *OffsetArray, index: u32) !void {
        const offset = index - self.lastIndex;
        if (offset == self.lastOffset) {
            self.runLength += 1;
            if (self.runLength == 1) {
                // This is the first run. Write the double-value and the index
                try self.pushValue(offset);
                try self.offsets.append(@truncate(self.runLength));
            } else {
                // Just increment the run-length. Overflow when necessary.
                if (self.runLength < 255) {
                    self.offsets.items[self.offsets.items.len - 1] += 1;
                } else if (self.runLength == 255) {
                    // Initial overflow case.
                    try self.pushValue(offset);
                    try self.offsets.append(0);
                    try self.offsets.appendSlice(&std.mem.toBytes(self.runLength));
                } else {
                    // Replace the last 4 bytes with the incremented runLength.
                    const runLengthBytes = std.mem.toBytes(self.runLength);
                    const runLengthBytesIndex = self.offsets.items.len - 4;
                    for (0..4) |i| {
                        self.offsets.items[runLengthBytesIndex + i] = runLengthBytes[i];
                    }
                }
            }
        } else {
            self.lastOffset = offset;
            self.runLength = 0;
            try self.pushValue(offset);
        }
        self.lastIndex = index;
    }
};

pub const OffsetIterator = struct {
    offsetArray: *OffsetArray,
    offsetIndex: usize = 0,
    currentIndex: u32 = 0,
    lastOffset: u32 = 0,
    runLength: u32 = 0,

    pub fn next(self: *OffsetIterator) ?u32 {
        if (self.runLength > 0) {
            // std.debug.print("Run length: {d}\n", .{self.runLength});
            self.runLength -= 1;
            self.currentIndex += self.lastOffset;
            return self.currentIndex;
        }
        if (self.offsetIndex >= self.offsetArray.offsets.items.len) {
            return null;
        }
        // std.debug.print("OffsetIndex: {d} len {d}\n", .{ self.offsetIndex, self.offsetArray.offsets.items.len });
        const nextByte = self.offsetArray.offsets.items[self.offsetIndex];
        self.offsetIndex += 1;
        var offset: u32 = 0;

        if (nextByte == 0) {
            // Next 4 bytes are a larger offset
            assert(self.offsetIndex + 4 <= self.offsetArray.offsets.items.len);
            const offset_bytes = self.offsetArray.offsets.items[self.offsetIndex .. self.offsetIndex + 4];
            offset = std.mem.bytesToValue(u32, offset_bytes[0..4]);
            // std.debug.print("Large offset: {d}\n", .{offset});
            self.offsetIndex += 4;
        } else {
            // std.debug.print("Small offset: {d}\n", .{nextByte});
            offset = nextByte;
        }

        if (offset == self.lastOffset and offset != 0) {
            self.getRunLength();
        } else {
            self.lastOffset = offset;
            self.runLength = 0;
        }

        self.currentIndex += offset;
        return self.currentIndex;
    }

    pub fn peek(self: *OffsetIterator) ?u32 {
        if (self.runLength > 0) {
            // std.debug.print("Run length: {d}\n", .{self.runLength});
            return self.currentIndex + self.lastOffset;
        }
        if (self.offsetIndex >= self.offsetArray.offsets.items.len) {
            return null;
        }
        // std.debug.print("OffsetIndex: {d} len {d}\n", .{ self.offsetIndex, self.offsetArray.offsets.items.len });
        var offsetIndex = self.offsetIndex;
        const nextByte = self.offsetArray.offsets.items[offsetIndex];

        offsetIndex += 1;
        var offset: u32 = 0;

        if (nextByte == 0) {
            // Next 4 bytes are a larger offset
            assert(offsetIndex + 4 <= self.offsetArray.offsets.items.len);
            const offset_bytes = self.offsetArray.offsets.items[offsetIndex .. offsetIndex + 4];
            offset = std.mem.bytesToValue(u32, offset_bytes[0..4]);
            // std.debug.print("Large offset: {d}\n", .{offset});
            offsetIndex += 4;
        } else {
            // std.debug.print("Small offset: {d}\n", .{nextByte});
            offset = nextByte;
        }

        return self.currentIndex + offset;
    }

    fn getRunLength(self: *OffsetIterator) void {
        // Two same values back-to-back indicates a run. The next value indicates the count of the run.
        const runLength = self.offsetArray.offsets.items[self.offsetIndex];
        if (runLength == 0) {
            // Read large runLength
            const runLengthBytes = self.offsetArray.offsets.items[self.offsetIndex + 1 .. self.offsetIndex + 5];
            self.runLength = std.mem.bytesToValue(u32, runLengthBytes[0..4]);
            self.offsetIndex += 5;
        } else {
            self.runLength = runLength;
            self.offsetIndex += 1;
        }
        // Run-lengths are always 1+. We subtract one since the first run is already emitted in-place.
        self.runLength -= 1;
    }
};

pub fn offsetJoin(offset_iterators: []OffsetIterator, merged_rows: *std.ArrayList(u32)) !void {
    // Each offset iterator specifies the row indexes where that column matches.
    // Intersect those to find the rows where they all match
    // We iterate through each absolute index and see if all columns contain it.
    // Ignore any indexes in columns below that watermark.
    // Any higher values indicate we can skip the current value we're dealing with.
    // When any column is exhausted, we're done.
    var done = false;
    assert(offset_iterators.len > 0);
    var candidate_index: ?u32 = offset_iterators[0].peek();

    while (!done) {
        var all_match = true;
        for (offset_iterators[0..]) |*ref| {
            var next_index = ref.peek();
            // Skip all elements which are lower
            while (next_index != null and next_index.? < candidate_index.?) {
                _ = ref.next();
                next_index = ref.peek();
            }
            if (next_index == null) {
                done = true;
                all_match = false;
                break;
            }
            if (next_index.? > candidate_index.?) {
                candidate_index = next_index;
                all_match = false;
                break;
            }
            // Else, next_index == candidate_index. Continue on to see if other columns match.
            _ = ref.next();
        }
        if (all_match) {
            try merged_rows.append(candidate_index.?);
        }
        candidate_index = offset_iterators[0].peek();
    }
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

test "OffsetArray - Basic functionality" {
    var offset_array = OffsetArray.init(test_allocator);
    defer offset_array.deinit();

    // Test with a simple sequence of values
    try offset_array.push(3);
    try offset_array.push(10);
    try offset_array.push(25);

    try expectEqual(@as(u32, 25), offset_array.lastIndex);
    try expectEqual(@as(u32, 15), offset_array.lastOffset); // 25 - 10 = 15
}

test "OffsetArray - Run-length encoding" {
    var offset_array = OffsetArray.init(test_allocator);
    defer offset_array.deinit();

    // Test run-length encoding with repeated offsets
    try offset_array.push(10);
    try offset_array.push(20); // offset 10
    try offset_array.push(30); // offset 10 (should trigger run-length encoding)
    try offset_array.push(40); // offset 10 (should increment run-length)

    try expectEqual(@as(u32, 40), offset_array.lastIndex);
    try expectEqual(@as(u32, 10), offset_array.lastOffset);
    try expectEqual(@as(u32, 3), offset_array.runLength); // 3 occurrences of offset 10
}

test "OffsetArray - Large offsets" {
    var offset_array = OffsetArray.init(test_allocator);
    defer offset_array.deinit();

    // Test with large offsets
    try offset_array.push(10);
    try offset_array.push(300); // offset 290 (> 255, should use large offset encoding)

    try expectEqual(@as(u32, 300), offset_array.lastIndex);
    try expectEqual(@as(u32, 290), offset_array.lastOffset);

    // Verify the large offset is correctly stored
    try expectEqual(@as(u8, 0), offset_array.offsets.items[1]); // Marker for large offset
    const large_offset_bytes = offset_array.offsets.items[2..6];
    const large_offset = std.mem.bytesToValue(u32, large_offset_bytes[0..4]);
    try expectEqual(@as(u32, 290), large_offset);
}

test "OffsetArray - Iterator" {
    var offset_array = OffsetArray.init(test_allocator);
    defer offset_array.deinit();

    const expected_values = [_]u32{ 3, 10, 25, 300, 350, 400, 700 };
    for (expected_values) |value| {
        try offset_array.push(value);
    }
    var iterator = OffsetIterator{ .offsetArray = &offset_array };

    var index: usize = 0;
    while (iterator.next()) |value| {
        try expectEqual(expected_values[index], value);
        index += 1;
    }
    try expectEqual(expected_values.len, index);
}

test "offsetJoin - Single iterator" {
    var offset_array = OffsetArray.init(test_allocator);
    defer offset_array.deinit();

    const values = [_]u32{ 5, 10, 15, 20 };
    for (values) |value| {
        try offset_array.push(value);
    }

    const iterator = OffsetIterator{ .offsetArray = &offset_array };
    var iterators = [_]OffsetIterator{iterator};
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, values.len), merged_rows.items.len);
    for (values, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}

test "offsetJoin - Multiple iterators with exact match" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    const values = [_]u32{ 5, 10, 15, 20 };
    for (values) |value| {
        try array1.push(value);
        try array2.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, values.len), merged_rows.items.len);
    for (values, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}

test "offsetJoin - Multiple iterators with intersection" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    const values1 = [_]u32{ 5, 10, 15, 20, 25 };
    const values2 = [_]u32{ 7, 10, 15, 22, 25 };
    const expected = [_]u32{ 10, 15, 25 }; // Intersection

    for (values1) |value| {
        try array1.push(value);
    }

    for (values2) |value| {
        try array2.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, expected.len), merged_rows.items.len);
    for (expected, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}

test "offsetJoin - Multiple iterators with no intersection" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    const values1 = [_]u32{ 5, 10, 15 };
    const values2 = [_]u32{ 6, 11, 16 };

    for (values1) |value| {
        try array1.push(value);
    }

    for (values2) |value| {
        try array2.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, 0), merged_rows.items.len); // No intersection
}

test "offsetJoin - Three iterators with intersection" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    var array3 = OffsetArray.init(test_allocator);
    defer array3.deinit();

    const values1 = [_]u32{ 5, 10, 15, 20, 25, 30 };
    const values2 = [_]u32{ 7, 10, 15, 22, 25, 30 };
    const values3 = [_]u32{ 8, 10, 16, 25, 30, 35 };
    const expected = [_]u32{ 10, 25, 30 }; // Intersection of all three

    for (values1) |value| {
        try array1.push(value);
    }

    for (values2) |value| {
        try array2.push(value);
    }

    for (values3) |value| {
        try array3.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    const iterator3 = OffsetIterator{ .offsetArray = &array3 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2, iterator3 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, expected.len), merged_rows.items.len);
    for (expected, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}

test "offsetJoin - With large values" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    const values1 = [_]u32{ 256, 512, 1024, 2048 };
    const values2 = [_]u32{ 128, 256, 768, 1024, 2048 };
    const expected = [_]u32{ 256, 1024, 2048 }; // Intersection

    for (values1) |value| {
        try array1.push(value);
    }

    for (values2) |value| {
        try array2.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, expected.len), merged_rows.items.len);
    for (expected, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}

test "offsetJoin - With run-length encoded values" {
    var array1 = OffsetArray.init(test_allocator);
    defer array1.deinit();

    var array2 = OffsetArray.init(test_allocator);
    defer array2.deinit();

    // Create array with run-length encoding
    try array1.push(10);
    try array1.push(20); // offset 10
    try array1.push(30); // offset 10 (triggers run-length encoding)
    try array1.push(40); // offset 10 (increments run-length)
    try array1.push(50); // offset 10

    // Standard array with some matching values
    const values2 = [_]u32{ 15, 30, 40, 60 };
    const expected = [_]u32{ 30, 40 }; // Intersection

    for (values2) |value| {
        try array2.push(value);
    }

    const iterator1 = OffsetIterator{ .offsetArray = &array1 };
    const iterator2 = OffsetIterator{ .offsetArray = &array2 };
    var iterators = [_]OffsetIterator{ iterator1, iterator2 };
    var merged_rows = std.ArrayList(u32).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, expected.len), merged_rows.items.len);
    for (expected, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}
