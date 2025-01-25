const std = @import("std");
const Allocator = std.mem.Allocator;
const leb128 = std.leb;
const encodeUnsigned = leb128.writeUleb128;

pub fn encodeString(allocator: Allocator, s: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try encodeUnsigned(buffer.writer(), s.len);
    try buffer.appendSlice(s);

    return buffer.toOwnedSlice();
}

pub fn encodeVector(allocator: Allocator, v: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try encodeUnsigned(buffer.writer(), v.len);
    try buffer.appendSlice(v);

    return buffer.toOwnedSlice();
}

pub fn encodeNestedVector(allocator: Allocator, v: []const []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try encodeUnsigned(buffer.writer(), v.len);
    // Append sub-vectors
    for (v) |sv| {
        try buffer.appendSlice(sv);
    }

    return buffer.toOwnedSlice();
}

pub fn encodeSection(allocator: Allocator, section: u8, data: []const u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append(section);
    const encoded_data = try encodeVector(allocator, data);
    defer allocator.free(encoded_data);
    try buffer.appendSlice(encoded_data);

    return buffer.toOwnedSlice();
}

test "encodeVector" {
    const testing = std.testing;
    const test_data = &[_]u8{ 0x01, 0x60, 0x02, 0x7d, 0x7d, 0x01, 0x7d };
    const expected = &[_]u8{ 0x07, 0x01, 0x60, 0x02, 0x7d, 0x7d, 0x01, 0x7d };

    const result = try encodeVector(testing.allocator, test_data);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, expected, result);
}
