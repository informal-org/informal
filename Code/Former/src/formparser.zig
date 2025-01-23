const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const lex = @import("lexer.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// An abstract key-value pair.
const Form = struct { head: u64, body: u64 };

fn formPointer(index: u64, length: u64) u64 {
    const idx: u29 = @truncate(index);
    const len: u19 = @truncate(length);
    return val.createPrimitiveArray(idx, len);
}

pub const FormParser = struct {
    const Self = @This();
    allocator: Allocator,
    index: u32,
    lexer: lex.Lexer,
    forms: ArrayList(Form),

    pub fn init(allocator: Allocator, lexer: lex.Lexer) Self {
        return Self{
            .allocator = allocator,
            .index = 0,
            .lexer = lexer,
            .forms = ArrayList(Form).init(allocator),
        };
    }

    pub fn deinit(self: *FormParser) void {
        self.forms.deinit();
    }

    pub fn parse(self: *Self, prev_head: ?u64, end_token: u64) !u64 {
        var currentForm = ArrayList(Form).init(self.allocator);
        defer currentForm.deinit();
        var head: ?u64 = prev_head;
        var current: ?u64 = null;
        while (self.index < self.lexer.tokens.items.len) {
            const token = self.lexer.tokens.items[self.index];
            self.index += 1;
            _ = switch (token) {
                // Leading indentation or inline open brace.
                tok.SYMBOL_INDENT => {
                    // Begin a new sub-map. Recurse.
                    current = try self.parse(head, tok.SYMBOL_DEDENT);
                    head = null;
                },
                tok.SYMBOL_OPEN_BRACE => {
                    // Equivalent to indent, just less ambiguous for nested blocks.
                    current = try self.parse(head, tok.SYMBOL_DEDENT);
                    head = null;
                },
                tok.SYMBOL_NEWLINE, tok.SYMBOL_COMMA => {
                    // Begin new block.
                    // Or end of expression.
                    // End current form. Insert into map.
                    if (head != null and current != null) {
                        try currentForm.append(Form{ .head = head.?, .body = current.? });
                        head = null;
                        current = null;
                    } else {
                        print("Syntax error: Expected head and body.", .{});
                    }
                },
                tok.SYMBOL_COLON => {
                    // End key portion. Current buffer will now collect body.
                    head = current;
                    current = null;
                },
                tok.SYMBOL_EQUALS => {
                    // x = y = z
                    if (current != null) {
                        // No "= x" without a head.
                        // In a pure context, that's meaningless and can be dropped.

                        // This is equivalent of calling a sub-parse and appending it.
                        // TODO: Double-check the scoping rules here.
                        const remaining = try self.parse(head, tok.SYMBOL_NEWLINE);
                        head = null;
                        const subBody = Form{ .head = current.?, .body = remaining };
                        const idx = formPointer(self.forms.items.len, 1);
                        try self.forms.append(subBody);
                        try currentForm.append(Form{ .head = tok.SYMBOL_EQUALS, .body = idx });
                        current = idx;
                    } else {
                        print("Syntax error. Expected head before =.", .{});
                    }
                },
                else => {
                    if (token == end_token) {
                        // Ending token depending on the beginning token.
                        // tok.SYMBOL_DEDENT, tok.SYMBOL_CLOSE_BRACE
                        // End entire map. Insert and return.
                        break;
                    }
                    current = token;
                },
                // If ( => : { and recurse.
                // Otherwise - it's part of the current key / value.
            };
        }

        if (head != null and current != null) {
            try currentForm.append(Form{ .head = head.?, .body = current.? });
        } else {
            print("Syntax error. No complete form by end.", .{});
        }

        // End of current map with the end of the current {block} or end of stream.
        const index = self.forms.items.len;
        for (currentForm.items) |form| {
            try self.forms.append(form);
        }

        return formPointer(index, currentForm.items.len);
    }
};

const test_allocator = std.testing.allocator;
const arena_allocator = std.heap.ArenaAllocator;
const expect = std.testing.expect;

fn testFormEquals(form: Form, expected: Form) !void {
    try expect(form.head == expected.head);
    try expect(form.body == expected.body);
}

fn testParse(buffer: []const u8, expected: []const Form) !void {
    var lexer = lex.Lexer.init(buffer, test_allocator);
    defer lexer.deinit();
    _ = try lexer.lex(0, 0);
    var parser = FormParser.init(test_allocator, lexer);
    defer parser.deinit();
    const result = try parser.parse(null, tok.SYMBOL_STREAM_END);
    _ = result;

    for (parser.forms.items, 0..) |form, i| {
        print("\nForm:     ({x} {x})\n", .{ form.head, form.body });
        tok.print_token(form.head, buffer);
        tok.print_token(form.body, buffer);
        if (i < expected.len) {
            print("\nExpected: ({x} {x})\n", .{ expected[i].head, expected[i].body });
            try testFormEquals(form, expected[i]);
        } else {
            print("Unexpected.", .{});
        }
    }

    try expect(parser.forms.items.len == expected.len);
}
// a :
//  b : c
// a :
// { c : d } : {e : f}
test "FormParser.Test parse map" {
    const source = "a: b";
    var expected = [_]Form{
        Form{ .head = val.createObject(tok.T_IDENTIFIER, 0, 1), .body = val.createObject(tok.T_IDENTIFIER, 3, 1) },
    };

    try testParse(source, &expected);

    const test2 =
        \\a:
        \\  b
    ;
    var expected2 = [_]Form{
        Form{ .head = val.createObject(tok.T_IDENTIFIER, 0, 1), .body = val.createObject(tok.T_IDENTIFIER, 5, 1) },
    };
    try testParse(test2, &expected2);
}
