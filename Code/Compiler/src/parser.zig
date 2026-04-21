// Parser — see Docs/Specs/parser-spec.md for the full specification.
//
// Recursive Pratt (top-down operator precedence) parser. Single-pass, no backtracking,
// one-token lookahead. Consumes the lexer's syntaxQ and emits `parsedQ` in postfix order
// (operands before operators) — no heap AST, the flat queue feeds codegen directly.
// `parsedQ[0]` is always aux_stream_start and acts as the null sentinel for symbol resolution.
// A parallel `offsetQ` (u16 per token) records each parsed token's distance back to its syntaxQ origin.
//
// Dispatch uses two compile-time tables keyed by token Kind (first 64 kinds only; aux tokens are skipped):
//   tokenParsers[Kind] → { prefix: ParserType, infix: ParserType, power: Power }   (packed u24)
//   parseFns[ParserType] → handler fn
// The handler recurses via `parse(minBindingPower)` for sub-expressions. Binding powers run
// None(0) · Separator(10) · Assign(20) · Or(30) · And(40) · Equality(50) · Comparison(60)
// · Additive(70) · Multiplicative(80) · Exp(90) · Unary(100) · Member(110) · Call(120).
//
// Symbol resolution is interleaved: every identifier goes through resolution.resolve/declare,
// which writes a signed i16 offset (arg1) from each reference to its declaration.
// See resolution.zig / resolution-spec.md.
//
// Special shapes:
//   grp_indent / grp_dedent — emitted around blocks; start token's arg0 is patched with the block's end index.
//   kw_if / kw_else        — condition is emitted first (postfix), then branch bodies via colon_assoc.
//   kw_fn                  — declares the name in enclosing scope, opens a function scope for params,
//                            header token stores { body_length, body_offset }. Bodies are emitted
//                            verbatim after the param chain and skipped by codegen.
//
// Assumptions from the lexer: unary minus is pre-normalized to op_unary_minus; `call_identifier`
// guarantees the next token is grp_open_paren; indentation is already indent/dedent tokens.

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

const log = std.log.scoped(.parser);

pub const Parser = struct {
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

    const ParserType = enum(u8) { none, literal, identifier, callExpr, unaryOp, binaryOp, binaryRightAssocOp, assignOp, colonAssocOp, separator, skipNewLine, groupParen, groupBracket, groupBrace, indentBlock, kwIf, kwElse };

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
            fn mixfix(self: *Grammy, kind: Kind, prefixType: ParserType, infixType: ParserType, lbp: Power) void {
                self.grammar[@intFromEnum(kind)] = TokenParser{ .prefix = prefixType, .infix = infixType, .power = lbp };
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
        grammar.infix(Kind.op_dot_member, .binaryOp, .Member);

        // Assignment
        grammar.infix(Kind.op_assign_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_plus_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_minus_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_mul_eq, .assignOp, .Assign);
        grammar.infix(Kind.op_div_eq, .assignOp, .Assign);

        // Separators
        grammar.infix(Kind.sep_comma, .separator, .Separator);
        grammar.mixfix(Kind.sep_newline, .skipNewLine, .separator, .Separator);

        // Grouping
        grammar.prefix(Kind.grp_open_paren, .groupParen, .None);
        grammar.prefix(Kind.grp_open_bracket, .groupBracket, .None);
        grammar.prefix(Kind.grp_open_brace, .groupBrace, .None);
        grammar.prefix(Kind.grp_indent, .indentBlock, .None);
        // grammar.prefix(Kind.grp_dedent, .dedentBlock, .None);

        // Keywords
        grammar.prefix(Kind.kw_if, .kwIf, .None);
        grammar.prefix(Kind.kw_else, .kwElse, .None);

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
        fns[@intFromEnum(ParserType.kwIf)] = kwIf;
        fns[@intFromEnum(ParserType.kwElse)] = kwElse;
        return fns;
    }

    fn emit(self: *Self, token: Token) anyerror!void {
        try self.parsedQ.push(token);
        try self.offsetQ.push(@truncate(self.offsetQ.list.items.len - self.index)); // TODO: This is probably not the correct offset. Need to double-check.
    }

    inline fn parsedLen(self: *Self) u32 {
        return @truncate(self.parsedQ.list.items.len);
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
        const resolved = self.resolution.resolve(self.parsedLen(), token);
        try self.emit(resolved);
    }

    fn emitChainedSep(self: *Self, prev_sep_idx: u32, sep_token: Token) !u32 {
        const cur_idx = self.parsedLen();
        var t = sep_token;
        t.data.group_link.prev_offset = rs.calcOffset(i16, prev_sep_idx, cur_idx);
        try self.emit(t);
        self.parsedQ.list.items[prev_sep_idx].data.group_link.next_offset = rs.calcOffset(i16, cur_idx, prev_sep_idx);
        return cur_idx;
    }

    fn groupDelim(self: *Self, open_kind: Kind, close_kind: Kind) anyerror!void {
        var prev_sep_idx = self.parsedLen();
        try self.emit(Token.groupOpen(open_kind));
        if (self.syntaxQ.peek().kind != close_kind) {
            while (true) {
                try self.parse(Power.Separator.val());
                if (self.syntaxQ.peek().kind != Kind.sep_comma) break;
                _ = self.syntaxQ.pop();
                prev_sep_idx = try self.emitChainedSep(prev_sep_idx, Token.groupSep());
            }
        }
        assert(self.syntaxQ.pop().kind == close_kind);
        _ = try self.emitChainedSep(prev_sep_idx, Token.groupClose(close_kind));
    }

    fn callExpr(self: *Self, token: Token) anyerror!void {
        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        try self.groupDelim(Kind.grp_open_paren, Kind.grp_close_paren);
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
        try self.groupDelim(Kind.grp_open_paren, Kind.grp_close_paren);
    }

    fn groupBracket(self: *Self, _: Token) anyerror!void {
        try self.groupDelim(Kind.grp_open_bracket, Kind.grp_close_bracket);
    }

    fn groupBrace(self: *Self, _: Token) anyerror!void {
        try self.groupDelim(Kind.grp_open_brace, Kind.grp_close_brace);
    }

    fn indentBlock(self: *Self, _: Token) anyerror!void {
        const scopeId = self.resolution.scopeId;
        const startIdx = self.parsedLen();
        try self.emit(Token.lex(Kind.grp_indent, 0, scopeId));
        try self.resolution.startScope(rs.Scope{ .start = startIdx, .scopeType = .block });
        try self.parse(Power.None.val());
        if (self.syntaxQ.peek().kind == Kind.grp_dedent) {
            _ = self.syntaxQ.pop();
        }
        try self.emit(Token.lex(Kind.grp_dedent, startIdx, scopeId));
        try self.resolution.endScope(self.parsedLen());
    }

    fn kwIf(self: *Self, token: Token) anyerror!void {
        // Parse condition expression
        try self.parse(Power.None.val());
        // Emit kw_if in postfix position
        try self.emit(token);
        // Consume and emit op_colon_assoc
        const colon = self.syntaxQ.pop();
        assert(colon.kind == Kind.op_colon_assoc);
        try self.emit(colon);
        // Parse then-branch (will hit grp_indent → indentBlock)
        try self.parse(Power.None.val());
        // Check for else
        if (self.syntaxQ.peek().kind == Kind.kw_else) {
            const elseToken = self.syntaxQ.pop();
            try self.emit(elseToken);
            const colon2 = self.syntaxQ.pop();
            assert(colon2.kind == Kind.op_colon_assoc);
            try self.emit(colon2);
            // Parse else-branch
            try self.parse(Power.None.val());
        }
    }

    fn kwElse(_: *Self, _: Token) anyerror!void {
        return error.UnexpectedElse;
    }

    fn binaryOp(self: *Self, token: Token) anyerror!void {
        try self.parse(self.power(token) + 1);
        try self.emit(token);
    }

    fn binaryRightAssocOp(self: *Self, token: Token) anyerror!void {
        try self.parse(self.power(token));
        try self.emit(token);
    }

    fn assignOp(self: *Self, token: Token) anyerror!void {
        // TODO: Brittle — assumes previous token is an identifier. Needs rework for destructuring.
        const ident = self.resolution.declare(self.parsedLen() - 1, self.parsedQ.list.getLast());
        self.parsedQ.list.items[self.parsedLen() - 1] = ident;

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

test {
    _ = @import("test/test_parser.zig");
}
