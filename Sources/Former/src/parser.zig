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

    pub fn init(buffer: []const u8, allocator: Allocator) Self {
        var tokens = std.MultiArrayList(u64).init(allocator);
        var strings = std.StringHashMap(usize).init(allocator);
        var symbols = std.StringHashMap(u64).init(allocator);
        // symbols.put("and", val.KW_AND);


        return Self{ .buffer = buffer, .index = 0, .allocator = allocator, .tokens = tokens, .strings = strings, .symbols = symbols };
    }


    pub fn deinit(self: *Parser) void {
        self.tokens.deinit();
        self.strings.deinit();
        self.symbols.deinit();
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

    fn is_delimiter(ch: u8) bool {
        // No mathematical operators in MVL.
        return switch (ch) {
            '(', ')', '[', ']', '{', '}', '"', '\'', '.', ',', ':', ';', ' ', '\t', '\n' => true,
            else => false,
        };
    }

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

    fn seek_till(self: *Self, ch: []const u8) ?u64 {
        while (self.index < self.buffer.len and self.buffer[self.index] != ch[0]) : (self.index += 1) {}
        return null;
    }

    fn seek_till_delimiter(self: *Self) ?u64 {
        while (self.index < self.buffer.len and !is_delimiter(self.buffer[self.index])) : (self.index += 1) {}
        return null;
    }

    fn lex_number(self: *Self) u64 {
        // MVL just needs int support for bootstrapping. Stage1+ should parse float.
        var start = self.index;
        self.index += 1; // First char is already recognized as a digit.
        self.gobble_digits();
        var value: u64 = std.fmt.parseInt(u32, self.buffer[start..self.index], 10) catch 0;

        return value;
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

        const stringId = self.strings.getOrPut(self.buffer[start..end], self.strings.len);
        const stringRef = val.createReference(val.AST_STRING, stringId);
        _ = stringRef;
        return ast.AstNode{ .value = stringId, .loc = ast.AstLoc{ .start = start, .end = end } };
    }

    fn lex_identifier(self: *Self) ast.AstNode {
        // First char is known to not be a number or delimiter.
        var start = self.index;
        // Non digit or symbol start, so interpret as an identifier.
        _ = self.seek_till_delimiter();
        if (self.index - start > 255) {
            unreachable;
        }
        // This can be further optimized with a perfect-hash lookup for builtins.

        // Test off by one for symbol value (shouldn't contain delimiter)
        const symbolRef = val.createReference(val.AST_IDENTIFIER, self.symbols.len);
        const symbolId = self.symbols.getOrPut(self.buffer[start..self.index], symbolRef);
        
        return ast.AstNode{ .value = symbolId, .loc = ast.AstLoc{ .start = start, .end = self.index } };
    }

    


};
