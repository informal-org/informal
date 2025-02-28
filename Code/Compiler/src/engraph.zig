// A specialized graph data structure used for storing relational connection information
// Efficient lookups for connectedness, path existence, cycle checking.
// This can power a lot of datalog style queries.

const std = @import("std");
const stdbits = std.bit_set;

pub const BitSet64 = stdbits.IntegerBitSet(64);

const BitsetLevel = packed struct(u64) {
    header: u7, // Indicates which segements
    isPtr: bool, // Order matters here.
    data: u56,
};

const SparseLevelBitset = struct {
    // A sparse representation of a bitset.
    // Expectation is that set bits will mostly be clustered together.
    // Backed by an array, so merging may require a lot of shifting,
    // but should be fine as long as the sparseness assumption holds.

    const Self = @This();

    allocator: std.mem.Allocator,

    // An array of bitsets. If all of the bits to set is in 1-63, it'll just use the top-bit.
    // Else the top-layer indicates which of the 64 bit segments
    data: std.ArrayList(BitSet64),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = std.ArrayList(u64).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }
};

const NodeEngraph = struct {
    // For each node, we store a list of incoming edges.
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
};
