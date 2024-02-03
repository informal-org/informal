const std = @import("std");
const ArrayList = std.ArrayList;

pub const Location = struct { start: usize, end: usize };

pub const AstNode = struct {
    // The core AST node value is tightly encoded in this 64 bit number.
    // Numeric constants are represented as-is. Other values are embedded in the NaN tagged bits.
    // Identifiers reference their symbol table ID.
    // The values are stored in a struct of arrays structure for cache locality.
    // We don't need to store references to left/right due to the RPN structure of the AST node list.
    value: u64,

    // Location metadata into the original source files for error reporting.
    loc: Location,
};
