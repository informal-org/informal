const tok = @import("token.zig");
const Kind = tok.Kind;
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const q = @import("queue.zig");
const rs = @import("resolution.zig");

const Token = tok.Token;
pub const TokenQueue = q.Queue(Token, tok.AUX_STREAM_END);
pub const OffsetQueue = q.Queue(u16, 0);
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.pratt_parser);

pub const PrattParser = struct {
    const Self = @This();
    buffer: []const u8,
    syntaxQ: *TokenQueue,
    auxQ: *TokenQueue,
    resolution: *rs.Resolution,
    allocator: Allocator,

    tokenParsers: [64]TokenParser,

    const LeftBindingPower = enum(u8) {
        None = 0,
        Separator = 10,
        Assign = 20,
        Or = 30,
        And = 40,
        Equality = 50,
        Comparison = 60,
        Divisive = 70,
        Additive = 80,
        Exp = 90,
        Unary = 100,
        Member = 110,
        Call = 120,
    };

    const ParserType = enum { none, literal, identifier, callExpr, unaryOp, binaryOp, binaryRightAssocOp, assignOp, colonAssocOp, separator, skipNewLine, groupParen, groupBracket, groupBrace, indentBlock };

    const TokenParser = packed struct(u32) {
        // Compact pratt rule representations. Aviods storing function pointers directly, but requires an extra level of indirection.
        prefix: ParserType = .none, // What does this token mean at the start of an expression with nothing to its left? Null denotation.
        infix: ParserType = .none, // What does this token mean when it follows some expression? Left denotation.
        power: LeftBindingPower = .None, // Left binding power
    };

    fn define(self: *Self, kind: Kind, rule: TokenParser) void {
        self.tokenParsers[@intFromEnum(kind)] = rule;
    }

    fn initRules(self: *Self) void {
        assert(tok.AUX_KIND_START <= 64);
        for (0..64) |i| {
            self.rules[i] = TokenParser{};
        }

        self.define(Kind.lit_number, TokenParser{ .prefix = .literal });
        self.define(Kind.lit_string, TokenParser{ .prefix = .literal });
        self.define(Kind.lit_bool, TokenParser{ .prefix = .literal });
        self.define(Kind.lit_null, TokenParser{ .prefix = .literal });
        self.define(Kind.identifier, TokenParser{ .prefix = .identifier });
        self.define(Kind.const_identifier, TokenParser{ .prefix = .identifier });
        self.define(Kind.call_identifier, TokenParser{ .prefix = .callExpr });

        // Unary ops (prefix only)
        self.define(Kind.op_not, TokenParser{ .prefix = .unaryOp, .power = .Unary });
        self.define(Kind.op_unary_minus, TokenParser{ .prefix = .unaryOp, .power = .Unary });

        // Binary arithmetic
        self.define(Kind.op_add, TokenParser{ .infix = .binaryOp, .power = .Additive });
        self.define(Kind.op_sub, TokenParser{ .infix = .binaryOp, .power = .Additive });

        self.define(Kind.op_mul, TokenParser{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_div, TokenParser{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_mod, TokenParser{ .infix = .binaryOp, .power = .Divisive });
        self.define(Kind.op_pow, TokenParser{ .infix = .binaryRightAssocOp, .power = .Exp });

        // Comparison
        self.define(Kind.op_lt, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_gt, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_lte, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_gte, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_dbl_eq, TokenParser{ .infix = .binaryOp, .power = .Equality });
        self.define(Kind.op_not_eq, TokenParser{ .infix = .binaryOp, .power = .Equality });

        // Logical
        self.define(Kind.op_and, TokenParser{ .infix = .binaryOp, .power = .And });
        self.define(Kind.op_or, TokenParser{ .infix = .binaryOp, .power = .Or });

        // Assignment
        self.define(Kind.op_assign_eq, TokenParser{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_plus_eq, TokenParser{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_minus_eq, TokenParser{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_mul_eq, TokenParser{ .infix = .assignOp, .power = .Assign });
        self.define(Kind.op_div_eq, TokenParser{ .infix = .assignOp, .power = .Assign });

        // Other binary
        self.define(Kind.op_choice, TokenParser{ .infix = .binaryOp, .power = .Or });
        self.define(Kind.op_in, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_is, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_as, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_identifier, TokenParser{ .infix = .binaryOp, .power = .Comparison });
        self.define(Kind.op_dot_member, TokenParser{ .infix = .binaryOp, .power = .Member });

        // Separators
        self.define(Kind.sep_comma, TokenParser{ .infix = .separator, .power = .Separator });
        self.define(Kind.sep_newline, TokenParser{ .prefix = .skipNewLine, .infix = .separator, .power = .Separator });

        // Grouping
        self.define(Kind.grp_open_paren, TokenParser{ .prefix = .groupParen });
        self.define(Kind.grp_open_bracket, TokenParser{ .prefix = .groupBracket });
        self.define(Kind.grp_open_brace, TokenParser{ .prefix = .groupBrace });
        self.define(Kind.grp_indent, TokenParser{ .prefix = .indentBlock });
        self.define(Kind.grp_dedent, TokenParser{ .prefix = .dedentBlock });

        // TODO: Keywords like if, for, fn, etc.
    }

    const ParseFn = *const fn (*Self, Token) anyerror!void;
    const parseFns = [64]ParseFn;
    fn initParseFns(self: *Self) void {
        self.parseFns[ParserType.literal] = literal;
        self.parseFns[ParserType.identifier] = identifier;
        self.parseFns[ParserType.callExpr] = callExpr;
        self.parseFns[ParserType.unaryOp] = unaryOp;
        self.parseFns[ParserType.skipNewLine] = skipNewLine;
        self.parseFns[ParserType.groupParen] = groupParen;
        self.parseFns[ParserType.groupBracket] = groupBracket;
        self.parseFns[ParserType.groupBrace] = groupBrace;
        self.parseFns[ParserType.indentBlock] = indentBlock;
        self.parseFns[ParserType.binaryOp] = binaryOp;
        self.parseFns[ParserType.binaryRightAssocOp] = binaryRightAssocOp;
        self.parseFns[ParserType.assignOp] = assignOp;
        self.parseFns[ParserType.colonAssocOp] = colonAssocOp;
        self.parseFns[ParserType.separator] = separator;
    }

    fn emit(self: *Self, token: Token) anyerror!void {
        try self.parsedQ.push(token);
        try self.offsetQ.push(@truncate(self.offsetQ.list.items.len - self.index)); // TODO: This is probably not the correct offset. Need to double-check.
    }

    fn currentBindingPower(self: *Self) LeftBindingPower {
        const token = self.syntaxQ.peek();
        const rule = self.rules[@intFromEnum(token.kind)];
        return rule.power;
    }

    fn prefix(self: *Self, token: Token) anyerror!void {
        const tokenParser = self.tokenParsers[@intFromEnum(token.kind)];
        const parseFn = self.parseFns[@intFromEnum(tokenParser.prefix)];
        try parseFn(self, token);
    }

    fn infix(self: *Self, token: Token) anyerror!void {
        const tokenParser = self.tokenParsers[@intFromEnum(token.kind)];
        const parseFn = self.parseFns[@intFromEnum(tokenParser.infix)];
        try parseFn(self, token);
    }

    fn power(self: *Self, token: Token) u8 {
        return @intFromEnum(self.tokenParsers[@intFromEnum(token.kind)].power);
    }

    fn literal(self: *Self, token: Token) anyerror!void {
        try self.emit(token);
    }

    fn identifier(self: *Self, token: Token) anyerror!void {
        const resolved = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), token);
        try self.emit(resolved);
    }

    fn callExpr(self: *Self, token: Token) anyerror!void {
        const openParen = self.syntaxQ.pop();
        // TODO: Do we need to be handling the parentheses here?
        std.debug.assert(openParen.kind == Kind.grp_open_paren);
        try self.parse(.None);
        const closeParen = self.syntaxQ.peek();
        if (closeParen.kind == Kind.grp_close_paren) {
            _ = self.syntaxQ.pop();
        }
        try self.emit(token);
    }

    fn unaryOp(self: *Self, token: Token) anyerror!void {
        // TODO: Not really implemented.
        try self.parse(.Unary);
        try self.emit(token);
    }

    fn skipNewLine(self: *Self, _: Token) anyerror!void {
        try self.parse(.None);
    }

    fn groupParen(self: *Self, _: Token) anyerror!void {
        try self.parse(.None);
        // TODO: There needs to be additional handling for commas in an inner loop here probably.
        assert(self.syntaxQ.pop() == Kind.grp_close_paren);
    }

    fn groupBracket(self: *Self, _: Token) anyerror!void {
        try self.parse(.None);
        assert(self.syntaxQ.pop() == Kind.grp_close_bracket);
    }

    fn groupBrace(self: *Self, _: Token) anyerror!void {
        try self.parse(.None);
        assert(self.syntaxQ.pop() == Kind.grp_close_brace);
    }

    fn indentBlock(self: *Self, _: Token) anyerror!void {
        const scopeId = self.resolution.scopeId;
        const startIdx = self.parsedQ.list.items.len;
        try self.emit(Token.lex(Kind.grp_indent, 0, scopeId));
        try self.resolution.startScope(rs.Scope{ .start = @truncate(startIdx), .scopeType = .block });
        try self.parse(.None);
        const dedentToken = self.syntaxQ.peek();
        if (dedentToken.kind == Kind.grp_dedent) {
            _ = self.syntaxQ.pop();
        }
        try self.emit(Token.lex(Kind.grp_dedent, @truncate(startIdx), scopeId));
        try self.resolution.endScope(@truncate(self.parsedQ.list.items.len));
    }

    fn binaryOp(self: *Self, token: Token) anyerror!void {
        try self.parse(self.power(token) + 1);
        try self.emit(token);
    }

    fn binaryRightAssocOp(self: *Self, token: Token) anyerror!void {
        try self.parse(self.power(token));
        try self.emit(token);
    }

    // Infix operations

    fn assignOp(self: *Self, token: Token) anyerror!void {
        // Assume - the token to the left was the identifier.
        // When we add destructuring in the future, this will need to change.
        // TODO: This is fairly brittle since the previous val may not be an identifier or it might be a more complex definition.
        // Replace the previous token with the declared version.
        const ident = self.resolution.declare(@truncate(self.parsedQ.list.items.len - 1), self.parsedQ.list.getLast());
        self.parsedQ.list.items[self.parsedQ.list.items.len - 1] = ident;

        try self.parse(.Assign);
        try self.emit(token);
    }

    fn colonAssocOp(self: *Self, token: Token) anyerror!void {
        try self.parse(.Separator);
        try self.emit(token);
    }

    fn separator(self: *Self, _: Token) anyerror!void {
        try self.parse(.Separator);
    }

    // Core of the parsing loop
    fn parse(self: *Self, minRightBindingPower: u8) !void {
        var current = self.syntaxQ.pop();
        try self.prefix(current);

        while (minRightBindingPower < self.currentBindingPower()) {
            current = self.syntaxQ.pop();
            try self.infix(current);
        }
    }

    fn start(self: *Self) !void {
        log.debug("Starting Pratt Parser", .{});
        self.parsedQ.push(tok.AUX_STREAM_START);
        try self.parse(.None);
        log.debug("Ending Pratt Parser", .{});
    }
};
