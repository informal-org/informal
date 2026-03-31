const std = @import("std");
const sparsearray = @import("../datastructures/sparsearray.zig");

const TaggedPointer = sparsearray.TaggedPointer;
const SparseArray = sparsearray.SparseArray;

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

test "TaggedPointer basic functionality" {
    const TestTag = enum(u2) {
        First = 0,
        Second = 1,
        Third = 2,
    };
    const val: u64 = 12309123009;

    const TestStruct = struct {
        value: u64,
    };

    var test_struct = TestStruct{ .value = val };
    const TaggedTestPtr = TaggedPointer(TestTag, TestStruct);

    var tagged = TaggedTestPtr.init(TestTag.Second, &test_struct);
    try expectEqual(tagged.tag, TestTag.Second);

    const retrieved_ptr = tagged.getPointer();
    try expectEqual(retrieved_ptr.?.value, val);

    // Test with larger tags
    const LargeTag = enum(u8) {
        First = 0,
        Second = 1,
        Third = 2,
    };
    const TaggedLargePtr = TaggedPointer(LargeTag, TestStruct);
    const large_taged = TaggedLargePtr.init(LargeTag.Third, &test_struct);
    try expectEqual(large_taged.tag, LargeTag.Third);
    const large_retrieved_ptr = large_taged.getPointer();
    try expectEqual(large_retrieved_ptr.?.value, val);
}

test "PopCountArray size" {
    const PCA = SparseArray(u64, u64);
    try expectEqual(24, @sizeOf(PCA));
}

test "PopCountArray basic functionality" {
    const PCA = SparseArray(u64, u64);
    var pca = PCA.init();
    defer pca.deinit(test_allocator);
    try expectEqual(pca.getIndex(6), 0);
    try pca.set(test_allocator, 5, 1);
    try expectEqual(pca.getIndex(5), 0);
    try expectEqual(pca.getIndex(4), 0);
    try expectEqual(pca.getIndex(6), 1);
    try pca.set(test_allocator, 1, 2);
    try pca.set(test_allocator, 3, 3);
    try expectEqual(pca.get(5), 1);
    try expectEqual(pca.get(1), 2);
    try expectEqual(pca.get(3), 3);
    try expectEqual(pca.get(2), null);
}
