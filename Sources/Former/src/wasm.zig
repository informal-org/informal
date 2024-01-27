// Wasm backend.
const Parser = @import("parser.zig").Parser;
const Location = @import("ast.zig").Location;
const val = @import("value.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

const operations = [_][]const u8{
    "f64.add",
    "f64.sub",
    "f64.mul",
    "f64.div",
};

const header = \\(module
\\  (func (export "_start") (result f64)
;

const footer = \\))
;

fn getLoc(parser: *Parser, loc: Location) []const u8 {
    return parser.buffer[loc.start..loc.end];
}

pub fn emit(parser: *Parser) !void {
    var index: usize = 0;
    try stdout.print("{s}\n", .{header});
    while (index < parser.ast.len) {
        const tok = parser.ast.get(index);

        if (val.isNan(tok.value)) {
            const opcode = val.getOpcode(tok.value);
            if(opcode < operations.len) {
                try stdout.print("{s}\n", .{operations[opcode]});
            } else {
                try stdout.print(";; {s}\n", .{ getLoc(parser, tok.loc ) });
            }
        } else {
            try stdout.print("f64.const {d}\n", .{tok.value});
        }

        index += 1;
    }
    try stdout.print("{s}\n", .{footer});
}
