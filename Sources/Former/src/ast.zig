const std = @import("std");
const ArrayList = std.ArrayList;

pub const Location = struct { start: usize, end: usize };

pub const AstNode = struct {
    loc: Location,
    // Atomic value dependent on the kind.
    // Numeric values are as-is. Float is reinterpreted.
    // Array types indicate start + end (or current + length) in AST array.
    // Operations indicate opcode. Left and right are implicitly follow the op in Ast array.
    value: u64,
    // Left-child always comes immediately after the node in the AST array due to depth-first order.
    // Index into the right-child for random access (not necessary for DFS iterations).
    right_index: usize,
};
