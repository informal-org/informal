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
            std.debug.print("Run length: {d}\n", .{self.runLength});
            self.runLength -= 1;
            self.currentIndex += self.lastOffset;
            return self.currentIndex;
        }
        if (self.offsetIndex >= self.offsetArray.offsets.items.len) {
            return null;
        }
        std.debug.print("OffsetIndex: {d} len {d}\n", .{ self.offsetIndex, self.offsetArray.offsets.items.len });
        const nextByte = self.offsetArray.offsets.items[self.offsetIndex];
        self.offsetIndex += 1;
        var offset: u32 = 0;

        if (nextByte == 0) {
            // Next 4 bytes are a larger offset
            assert(self.offsetIndex + 4 <= self.offsetArray.offsets.items.len);
            const offset_bytes = self.offsetArray.offsets.items[self.offsetIndex .. self.offsetIndex + 4];
            offset = std.mem.bytesToValue(u32, offset_bytes[0..4]);
            std.debug.print("Large offset: {d}\n", .{offset});
            self.offsetIndex += 4;
        } else {
            std.debug.print("Small offset: {d}\n", .{nextByte});
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
