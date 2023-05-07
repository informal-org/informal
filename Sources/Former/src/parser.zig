const std = @import("std");
const ast = @import("ast.zig");
const val = @import("value.zig");
const Allocator = std.mem.Allocator;

pub const Parser = struct {
    const Self = @This();
    buffer: []const u8,
    index: u32,
    allocator: Allocator,
    // The AST is stored is a postfix order - where all operands come before the operator.
    // This stack structure avoids the need for any explicit pointers for operators
    // and matches the dependency order we want to emit bytecode in and matches the order of evaluation.
    ast: std.MultiArrayList(ast.AstNode),
    strings: std.StringHashMap(usize),
    symbols: std.StringHashMap(u64),
    operators: std.ArrayList(ast.AstNode), // Shunting yard temporary operator stack
    // nesting: std.ArrayList(u16),
    // indentation_char: u8,

    pub fn init(buffer: []const u8, allocator: Allocator) Self {
        var tokens = std.MultiArrayList(ast.AstNode){}; // .init(allocator);
        var strings = std.StringHashMap(usize).init(allocator);
        var symbols = std.StringHashMap(u64).init(allocator);
        var operators = std.ArrayList(ast.AstNode).init(allocator);
        // symbols.put("and", val.KW_AND);

        return Self{ .buffer = buffer, .index = 0, .allocator = allocator, .ast = tokens, .strings = strings, .symbols = symbols, .operators = operators };
    }

    pub fn deinit(self: *Parser) void {
        self.ast.deinit(self.allocator);
        self.strings.deinit();
        self.symbols.deinit();
        self.operators.deinit();
    }

    fn gobble_digits(self: *Self) void {
        // Advance index until the first non-digit character.
        while (self.index < self.buffer.len) : (self.index += 1) {
            _ = switch (self.buffer[self.index]) {
                '0'...'9' => continue,
                else => break,
            };
        }
    }

    fn is_alpha(ch: u8) bool {
        var lch = ch | 0x20; // ascii-lowercase
        // TODO: Unicode-support if > UNICODE_START = 0x80;
        return 'a' <= lch and lch <= 'z' or ch == '_';
    }

    fn is_digit(ch: u8) bool {
        return '0' <= ch and ch <= '9';
    }

    fn is_alphanumeric(ch: u8) bool {
        return is_alpha(ch) or is_digit(ch);
    }

    // fn is_delimiter(ch: u8) bool {
    //     // No mathematical operators in MVL.
    //     return switch (ch) {
    //         '(', ')', '[', ']', '{', '}', '"', '\'', '.', ',', ':', ';', ' ', '\t', '\n' => true,
    //         else => false,
    //     };
    // }

    fn peek_starts_with(self: *Self, matchStr: []const u8) bool {
        // Peek if the next tokens start with the given match string.
        for (matchStr, 0..) |character, matchIndex| {
            var bufferI = self.index + matchIndex;
            if ((bufferI >= self.buffer.len) or (self.buffer[bufferI] != character)) {
                return false;
            }
        }
        return true;
    }

    fn peek(self: *Self) u8 {
        if (self.index + 1 >= self.buffer.len) {
            return 0;
        }
        return self.buffer[self.index + 1];
    }

    fn seek_till(self: *Self, ch: []const u8) ?u64 {
        while (self.index < self.buffer.len and self.buffer[self.index] != ch[0]) : (self.index += 1) {}
        return null;
    }

    fn skip(self: *Self) ?u64 {
        self.index += 1;
        return null;
    }

    // fn seek_till_delimiter(self: *Self) ?u64 {
    //     while (self.index < self.buffer.len and !is_delimiter(self.buffer[self.index])) : (self.index += 1) {}
    //     return null;
    // }

    fn lex_number(self: *Self) ast.AstNode {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        var start = self.index;
        self.index += 1; // First char is already recognized as a digit.
        self.gobble_digits();
        var value: u64 = std.fmt.parseInt(u32, self.buffer[start..self.index], 10) catch 0;

        return ast.AstNode{ .value = value, .loc = ast.Location{ .start = start, .end = self.index } };
    }

    fn lex_string(self: *Self) ast.AstNode {
        self.index += 1; // Omit beginning quote.
        var start = self.index;
        _ = self.seek_till("\"");
        var end = self.index - 1;
        // Expect but omit end quote.
        if (self.index < self.buffer.len and self.buffer[self.index] == '"') {
            self.index += 1;
        } else {
            // Raise error. Unterminated string. Skip for MVL.
        }
        // Use the value-field to explicitly store the end, or a ref to the
        // string in some table. The string contains both quotes.
        // return val.createStringPtr(start, end);

        const stringId = self.strings.getOrPutValue(self.buffer[start..end], self.strings.count());
        const stringRef = val.createReference(val.AST_STRING, stringId);
        return ast.AstNode{ .value = stringRef, .loc = ast.Location{ .start = start, .end = end } };
    }

    fn lex_identifier(self: *Self) ast.AstNode {
        // First char is known to not be a number or delimiter.
        var start = self.index;
        // Non digit or symbol start, so interpret as an identifier.
        while (self.index < self.buffer.len and is_alphanumeric(self.buffer[self.index])) : (self.index += 1) {}

        if (self.index - start > 255) {
            unreachable;
        }
        // This can be further optimized with a perfect-hash lookup for builtins.

        // Test off by one for symbol value (shouldn't contain delimiter)
        var identifier = self.buffer[start..self.index];
        var symbolId: ?u64 = self.symbols.get(identifier);
        if (symbolId == null) {
            symbolId = val.createReference(val.AST_IDENTIFIER, self.symbols.count());
            _ = self.symbols.getOrPutValue(identifier, symbolId.?) catch {};
        }

        return ast.AstNode{ .value = symbolId.?, .loc = ast.Location{ .start = start, .end = self.index } };
    }

    // fn lex_block(self: *Self) {

    // }

    fn lex_comment(self: *Self) ast.AstNode {
        // Comment - including the starting //.
        var start = self.index;
        self.index += 2;
        self.seek_till("\n");
        var end = self.index;
        var commentRef = val.createReference(val.AST_COMMENT, 0);
        return ast.AstNode{ .value = commentRef, .loc = ast.Location{ .start = start, .end = end } };
    }

    fn kw(self: *Self, keyword: u64, length: u8) ast.AstNode {
        var start = self.index;
        self.index += length;
        return ast.AstNode{ .value = keyword, .loc = ast.Location{ .start = start, .end = self.index } };
    }

    // The core lexer. We use a shunting-yard + state machine based approach since the desired AST form is Postfix.
    // Bottom-up parsing fits that perfectly vs top-down pratt style parsers.
    fn lex(self: *Self) !void {
        while (self.index < self.buffer.len) {
            var ch = self.buffer[self.index];

            if (is_alpha(ch)) {
                try self.ast.append(self.allocator, self.lex_identifier());
            } else if (is_digit(ch)) {
                try self.ast.append(self.allocator, self.lex_number());
            } else {
                var token: ?ast.AstNode = null;
                _ = switch (ch) {
                    ' ', '\t' => self.skip(),
                    // '\n' => self.lex_block(),
                    // '"' => self.lex_string(),
                    // '/' => {
                    //     if (self.peek() == '/') {
                    //         // TODO: Triple slash for doc comments.
                    //         self.lex_comment();
                    //     } else {
                    //         // Division
                    //         self.kw(val.KW_DIV, 1);
                    //     }
                    // },
                    '+' => {
                        token = self.kw(val.KW_ADD, 1);
                        // Precedence add
                    },
                    '-' => {
                        token = self.kw(val.KW_SUB, 1);
                    },
                    '*' => {
                        token = self.kw(val.KW_MUL, 1);
                    },
                    else => {
                        return error.InvalidToken;
                    },
                };
            }
        }
    }
};

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const print = std.debug.print;

pub fn testParser(buffer: []const u8, expected: []const u64) !void {
    print("\nTest Parser: {s}\n", .{buffer});
    defer print("\n--------------------------------\n", .{});

    var parser = Parser.init(buffer, test_allocator);
    defer parser.deinit();

    _ = try parser.lex();
    if (parser.ast.len != expected.len) {
        print("Expected {d} tokens, got {d}\n", .{ expected.len, parser.ast.len });
        for (parser.ast.items(.value)) |token| {
            print("{x}", .{token});
        }
    }

    try expect(parser.ast.len == expected.len);
    for (parser.ast.items(.value), 0..) |token, i| {
        try expect(token == expected[i]);
    }
}

test "Lex digits" {
    try testParser("123", &[_]u64{
        123,
    });
}
