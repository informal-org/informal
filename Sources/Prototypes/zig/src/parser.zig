const std = @import("std");
const val = @import("value.zig");
const tok = @import("token.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// An abstract key-value pair.
const Form = struct { head: u64, body: u64 };

pub const Parser = struct {
    const Self = @This();
    allocator: Allocator,
    index: u32,
    lexer: tok.Lexer,
    forms: ArrayList(Form),

    pub fn init(allocator: Allocator, lexer: tok.Lexer) Self {
        return Self{
            .allocator = allocator,
            .index = 0,
            .lexer = lexer,
            .forms = ArrayList(Form).init(allocator),
        };
    }

    pub fn parse(self: *Self, end_token: u64) u64 {
        const currentForm = ArrayList(Form);
        var head: ?u64 = null;
        var current: ?u64 = null;
        while (self.index < self.lexer.tokens.length) {
            const token = self.lexer.tokens[self.index];
            self.index += 1;
            _ = switch (token) {
                // Leading indentation or inline open brace.
                tok.SYMBOL_INDENT => {
                    // Begin a new sub-map. Recurse.
                    current = self.parse(tok.SYMBOL_DEDENT);
                },
                tok.SYMBOL_OPEN_BRACE => {
                    current = self.parse(tok.SYMBOL_DEDENT);
                },
                end_token => {
                    // tok.SYMBOL_DEDENT, tok.SYMBOL_CLOSE_BRACE
                    // End current form. Insert and return.
                    break;
                },
                tok.SYMBOL_NEWLINE, tok.SYMBOL_COMMA => {
                    // Begin new block.
                    // Or end of expression.
                    // End current form. Insert into map.
                    if (head != null and current != null) {
                        currentForm.append(Form{ .head = head, .body = current });
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
                else => {
                    current = token;
                },
                // If ( => : { and recurse.
                // Otherwise - it's part of the current key / value.
            };
        }

        if (head != null and current != null) {
            currentForm.append(Form{ .head = head, .body = current });
        } else {
            print("Syntax error. No complete form by end.", .{});
        }

        // End of current map with the end of the current {block} or end of stream.
        var index = self.forms.len;
        for (currentForm) |form| {
            self.forms.append(form);
        }

        return val.createPrimitiveArray(@truncate(u29, index), @truncate(u19, self.forms.len()));
    }
};

// a :
//  b : c
// a :
// { c : d } : {e : f}
