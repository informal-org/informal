const std = @import("std");
const ast = @import("ast.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Parser = struct {
    const Self = @This();
    input: []const u8,
    index: u32,
    allocator: Allocator,
    ast: ArrayList(ast.AstNode),
}