const std = @import("std");
const offsetarray = @import("../datastructures/offsetarray.zig");

const OffsetArray = offsetarray.OffsetArray;
const OffsetIterator = offsetarray.OffsetIterator;
const offsetJoin = offsetarray.offsetJoin;

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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
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
    var merged_rows = std.array_list.AlignedManaged(u32, null).init(test_allocator);
    defer merged_rows.deinit();

    try offsetJoin(iterators[0..], &merged_rows);

    try expectEqual(@as(usize, expected.len), merged_rows.items.len);
    for (expected, 0..) |value, i| {
        try expectEqual(value, merged_rows.items[i]);
    }
}
