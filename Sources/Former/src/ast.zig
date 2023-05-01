const std = @import("std");
const ArrayList = std.ArrayList;

pub const Location = struct { start: usize, end: usize };

pub const AstNode = struct {
    // The core AST node value is tightly encoded in this 64 bit number.
    // Numeric constants are represented as-is. Other values are embedded in the NaN tagged bits.
    // Operations indicate opcode. The left/right operands implicitly follow in the Node list.
    // Operations with variable number of operands are also supported with the value indicating their length.
    // Identifiers reference their symbol table ID.
    // The values are stored in a struct of arrays structure for cache locality.
    value: u64,

    // Location metadata into the original source files for error reporting.
    loc: Location,
    // Left and right child nodes appear immediately after in the node list.
    // We follow the left path further down. This index allows direct offset addressing to the right-grandchild.
    right_index: usize, // 0 = no right child.
};
