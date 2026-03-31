const tok = @import("token.zig");
const Kind = tok.Kind;
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const q = @import("queue.zig");
const parse_queue = @import("parse_queue.zig");
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
    index: u32,
    tokenParsers: [64]TokenParser = initGrammar(),

    parsedQ: *TokenQueue,
    // For each token in the parsedQ, indicates where to find it in the syntaxQ.
    offsetQ: *OffsetQueue,

    const Power = enum(u8) {
        None = 0,
        Separator = 10,
        Assign = 20,
        Or = 30,
        And = 40,
        Equality = 50,
        Comparison = 60,
        Additive = 70,
        Multiplicative = 80,
        Exp = 90,
        Unary = 100,
        Member = 110,
        Call = 120,

        pub fn val(self: Power) u8 {
            return @intFromEnum(self);
        }
    };

    const ParserType = enum(u8) { none, literal, identifier, callExpr, unaryOp, binaryOp, binaryRightAssocOp, assignOp, colonAssocOp, separator, skipNewLine, groupParen, groupBracket, groupBrace, indentBlock };

    const TokenParser = packed struct(u24) {
        // Compact pratt rule representations. Aviods storing function pointers directly, but requires an extra level of indirection.
        prefix: ParserType = .none, // What does this token mean at the start of an expression with nothing to its left? Null denotation.
        infix: ParserType = .none, // What does this token mean when it follows some expression? Left denotation.
        power: Power = .None, // Left binding power
    };

    pub fn init(
        buffer: []const u8,
        syntaxQ: *TokenQueue,
        auxQ: *TokenQueue,
        parsedQ: *TokenQueue,
        offsetQ: *OffsetQueue,
        allocator: Allocator,
        resolution: *rs.Resolution,
    ) Self {
        return Self{
            .buffer = buffer,
            .syntaxQ = syntaxQ,
            .auxQ = auxQ,
            .parsedQ = parsedQ,
            .offsetQ = offsetQ,
            .allocator = allocator,
            .index = 0,
            .resolution = resolution,
        };
    }

    pub fn deinit(self: *Self) void {
        // No opStack to free.
        _ = self;
    }

    fn define(self: *Self, kind: Kind, rule: TokenParser) void {
        self.tokenParsers[@intFromEnum(kind)] = rule;
    }

    fn initGrammar() [64]TokenParser {
        @setEvalBranchQuota(10000);
        assert(tok.AUX_KIND_START <= 64);

        const Grammar = struct {
            const Grammy = @This();
            grammar: [64]TokenParser,
            fn init() Grammy {
                return Grammy{ .grammar = [_]TokenParser{TokenParser{ .prefix = .none, .infix = .none, .power = .None }} ** 64 };
            }
            fn infix(self: *Grammy, kind: Kind, parserType: ParserType, lbp: Power) void {
                self.grammar[@intFromEnum(kind)] = TokenParser{ .infix = parserType, .power = lbp };
            }
            fn prefix(self: *Grammy, kind: Kind, parserType: ParserType, lbp: Power) void {
                self.grammar[@intFromEnum(kind)] = TokenParser{ .prefix = parserType, .power = lbp };
            }
        };
        var grammar = Grammar.init();

        grammar.prefix(Kind.lit_number, .literal, .None);
        grammar.prefix(Kind.lit_string, .literal, .None);
        grammar.prefix(Kind.lit_bool, .literal, .None);
        grammar.prefix(Kind.lit_null, .literal, .None);
        grammar.prefix(Kind.identifier, .identifier, .None);
        grammar.prefix(Kind.const_identifier, .identifier, .None);
        grammar.prefix(Kind.call_identifier, .callExpr, .None);

        // Unary ops (prefix only)
        grammar.prefix(Kind.op_not, .unaryOp, .Unary);
        grammar.prefix(Kind.op_unary_minus, .unaryOp, .Unary);
        grammar.infix(Kind.op_add, .binaryOp, .Additive);
        grammar.infix(Kind.op_sub, .binaryOp, .Additive);
        grammar.infix(Kind.op_mul, .binaryOp, .Multiplicative);
        grammar.infix(Kind.op_div, .binaryOp, .Multiplicative);
        grammar.infix(Kind.op_mod, .binaryOp, .Multiplicative);
        grammar.infix(Kind.op_pow, .binaryRightAssocOp, .Exp);

        // Comparison
        grammar.infix(Kind.op_lt, .binaryOp, .Comparison);
        grammar.infix(Kind.op_gt, .binaryOp, .Comparison);
        grammar.infix(Kind.op_lte, .binaryOp, .Comparison);
        grammar.infix(Kind.op_gte, .binaryOp, .Comparison);
        grammar.infix(Kind.op_dbl_eq, .binaryOp, .Equality);
        grammar.infix(Kind.op_not_eq, .binaryOp, .Equality);

        // Logical
        grammar.infix(Kind.op_and, .binaryOp, .And);
        grammar.infix(Kind.op_or, .binaryOp, .Or);

        // Other binary
        grammar.infix(Kind.op_choice, .binaryOp, .Or);
        grammar.infix(Kind.op_in, .binaryOp, .Comparison);
        grammar.infix(Kind.op_is, .binaryOp, .Comparison);
        grammar.infix(Kind.op_as, .binaryOp, .Comparison);
        grammar.infix(Kind.op_identifier, .binaryOp, .Comparison);
        grammar.infix(Kind.op_dot_member, .binaryOp, .Member);

        // Assignment
        grammar.infix(Kind.op_assign_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_plus_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_minus_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_mul_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_div_eq, .assignOp, .Assign);

        // Separators
        grammar.infix(Kind.sep_comma, .separator, .Separator);
        grammar.grammar[@intFromEnum(Kind.sep_newline)] = TokenParser{ .prefix = .skipNewLine, .infix = .separator, .power = .Separator };

        // Grouping
        grammar.prefix(Kind.grp_open_paren, .groupParen, .None);
        grammar.prefix(Kind.grp_open_bracket, .groupBracket, .None);
        grammar.prefix(Kind.grp_open_brace, .groupBrace, .None);
        grammar.prefix(Kind.grp_indent, .indentBlock, .None);
        // grammar.prefix(Kind.grp_dedent, .dedentBlock, .None);

        // TODO: Keywords like if, for, fn, etc.
        return grammar.grammar;
    }

    const ParseFn = *const fn (*Self, Token) anyerror!void;
    const parseFns = initParseFns();
    fn initParseFns() [64]ParseFn {
        var fns: [64]ParseFn = [_]ParseFn{literal} ** 64;
        fns[@intFromEnum(ParserType.literal)] = literal;
        fns[@intFromEnum(ParserType.identifier)] = identifier;
        fns[@intFromEnum(ParserType.callExpr)] = callExpr;
        fns[@intFromEnum(ParserType.unaryOp)] = unaryOp;
        fns[@intFromEnum(ParserType.skipNewLine)] = skipNewLine;
        fns[@intFromEnum(ParserType.groupParen)] = groupParen;
        fns[@intFromEnum(ParserType.groupBracket)] = groupBracket;
        fns[@intFromEnum(ParserType.groupBrace)] = groupBrace;
        fns[@intFromEnum(ParserType.indentBlock)] = indentBlock;
        fns[@intFromEnum(ParserType.binaryOp)] = binaryOp;
        fns[@intFromEnum(ParserType.binaryRightAssocOp)] = binaryRightAssocOp;
        fns[@intFromEnum(ParserType.assignOp)] = assignOp;
        fns[@intFromEnum(ParserType.colonAssocOp)] = colonAssocOp;
        fns[@intFromEnum(ParserType.separator)] = separator;
        return fns;
    }

    fn emit(self: *Self, token: Token) anyerror!void {
        try self.parsedQ.push(token);
        try self.offsetQ.push(@truncate(self.offsetQ.list.items.len - self.index)); // TODO: This is probably not the correct offset. Need to double-check.
    }

    fn currentBindingPower(self: *Self) u8 {
        const token = self.syntaxQ.peek();
        const kindVal = @intFromEnum(token.kind);
        if (kindVal >= self.tokenParsers.len) return Power.None.val();
        return self.tokenParsers[kindVal].power.val();
    }

    fn prefix(self: *Self, token: Token) anyerror!void {
        const tokenParser = self.tokenParsers[@intFromEnum(token.kind)];
        const parseFn = parseFns[@intFromEnum(tokenParser.prefix)];
        try parseFn(self, token);
    }

    fn infix(self: *Self, token: Token) anyerror!void {
        const tokenParser = self.tokenParsers[@intFromEnum(token.kind)];
        const parseFn = parseFns[@intFromEnum(tokenParser.infix)];
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
        try self.parse(Power.None.val());
        const closeParen = self.syntaxQ.peek();
        if (closeParen.kind == Kind.grp_close_paren) {
            _ = self.syntaxQ.pop();
        }
        try self.emit(token);
    }

    fn unaryOp(self: *Self, token: Token) anyerror!void {
        // TODO: Not really implemented.
        try self.parse(Power.Unary.val());
        try self.emit(token);
    }

    fn skipNewLine(self: *Self, _: Token) anyerror!void {
        try self.parse(Power.None.val());
    }

    fn groupParen(self: *Self, _: Token) anyerror!void {
        try self.parse(Power.None.val());
        // TODO: There needs to be additional handling for commas in an inner loop here probably.
        assert(self.syntaxQ.pop().kind == Kind.grp_close_paren);
    }

    fn groupBracket(self: *Self, _: Token) anyerror!void {
        try self.parse(Power.None.val());
        assert(self.syntaxQ.pop().kind == Kind.grp_close_bracket);
    }

    fn groupBrace(self: *Self, _: Token) anyerror!void {
        try self.parse(Power.None.val());
        assert(self.syntaxQ.pop().kind == Kind.grp_close_brace);
    }

    fn indentBlock(self: *Self, _: Token) anyerror!void {
        const scopeId = self.resolution.scopeId;
        const startIdx = self.parsedQ.list.items.len;
        try self.emit(Token.lex(Kind.grp_indent, 0, scopeId));
        try self.resolution.startScope(rs.Scope{ .start = @truncate(startIdx), .scopeType = .block });
        try self.parse(Power.None.val());
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

        try self.parse(Power.Assign.val());
        try self.emit(token);
    }

    fn colonAssocOp(self: *Self, token: Token) anyerror!void {
        try self.parse(Power.Separator.val());
        try self.emit(token);
    }

    fn separator(self: *Self, _: Token) anyerror!void {
        try self.parse(Power.Separator.val());
    }

    // Core of the parsing loop
    fn parse(self: *Self, minRightBindingPower: u8) !void {
        var current = self.syntaxQ.pop();
        if (current.kind == Kind.aux_stream_end) return;
        try self.prefix(current);

        while (minRightBindingPower < self.currentBindingPower()) {
            current = self.syntaxQ.pop();
            try self.infix(current);
        }
    }

    pub fn startParse(self: *Self) !void {
        log.debug("Starting Pratt Parser", .{});
        try self.parsedQ.push(tok.AUX_STREAM_START);
        try self.parse(Power.None.val());
        log.debug("Ending Pratt Parser", .{});
    }
};

const test_allocator = std.testing.allocator;
const testutils = @import("testutils.zig");
const TK = Kind;

fn testPrattParse(buffer: []const u8, tokens: []const Token, max_symbols: u32, expected: []const Token) !void {
    var syntaxQ = TokenQueue.init(test_allocator);
    var auxQ = TokenQueue.init(test_allocator);
    var parsedQ = TokenQueue.init(test_allocator);
    var offsetQ = OffsetQueue.init(test_allocator);
    var resolution = try rs.Resolution.init(test_allocator, max_symbols, &parsedQ);
    defer syntaxQ.deinit();
    defer auxQ.deinit();
    defer parsedQ.deinit();
    defer offsetQ.deinit();
    defer resolution.deinit();

    try testutils.pushAll(&syntaxQ, tokens);
    var p = PrattParser.init(buffer, &syntaxQ, &auxQ, &parsedQ, &offsetQ, test_allocator, &resolution);
    defer p.deinit();
    try p.startParse();

    try testutils.testQueueEquals(buffer, &parsedQ, expected);
}

fn tok64(comptime bits: u64) Token {
    return @bitCast(bits);
}

test "basic add" {
    const buffer = "1+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1).nextAlt(),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023101),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "math op precedence" {
    const buffer = "1+2*3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001300),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "math op precedence reversed" {
    const buffer = "1*2+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001300),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "subtraction and division" {
    const buffer = "6-2/3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_sub),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_div),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000000e00),
        tok64(0x0000000000001000),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "chained adds" {
    const buffer = "1+2+3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "comparison operators" {
    const buffer = "1<2";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_lt),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000000c00),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "equality with arithmetic" {
    const buffer = "1+2==3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_dbl_eq),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0000000000000100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "logical and/or" {
    const buffer = "a and b or c";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_and),
        Token.lex(TK.identifier, 1, 1),
        tok.createToken(TK.op_or),
        Token.lex(TK.identifier, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b00),
        tok64(0x0000000000012b00),
        tok64(0x0000000000001700),
        tok64(0x0000000000022b00),
        tok64(0x0000000000001800),
    };
    try testPrattParse(buffer, tokens, 3, expected);
}

test "assignment" {
    const buffer = "x=1";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_assign_eq),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b02),
        tok64(0x0001000000023100),
        tok64(0x0000000000000b00),
    };
    try testPrattParse(buffer, tokens, 1, expected);
}

test "assignment with expression" {
    const buffer = "x=1+2";
    const tokens = &[_]Token{
        Token.lex(TK.identifier, 0, 1),
        tok.createToken(TK.op_assign_eq),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0000000000002b02),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001200),
        tok64(0x0000000000000b00),
    };
    try testPrattParse(buffer, tokens, 1, expected);
}

test "multiple expressions with newline" {
    const buffer = "1+2\n3+4";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.sep_newline),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 6, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001200),
        tok64(0x0001000000043100),
        tok64(0x0001000000063100),
        tok64(0x0000000000001200),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "comma separated" {
    const buffer = "1,2,3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.sep_comma),
        Token.lex(TK.lit_number, 4, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "single literal" {
    const buffer = "42";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 2),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0002000000003100),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "modulo" {
    const buffer = "7%3";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_mod),
        Token.lex(TK.lit_number, 2, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0000000000001400),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}

test "mixed precedence mul add sub" {
    const buffer = "1+2*3-4";
    const tokens = &[_]Token{
        Token.lex(TK.lit_number, 0, 1),
        tok.createToken(TK.op_add),
        Token.lex(TK.lit_number, 2, 1),
        tok.createToken(TK.op_mul),
        Token.lex(TK.lit_number, 4, 1),
        tok.createToken(TK.op_sub),
        Token.lex(TK.lit_number, 6, 1),
    };
    const expected = &[_]Token{
        tok64(0x0000000000003900),
        tok64(0x0001000000003100),
        tok64(0x0001000000023100),
        tok64(0x0001000000043100),
        tok64(0x0000000000001300),
        tok64(0x0000000000001200),
        tok64(0x0001000000063100),
        tok64(0x0000000000001000),
    };
    try testPrattParse(buffer, tokens, 0, expected);
}
