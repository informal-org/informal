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
//   kw_fn / kw_lazy_fn     — declares the name in enclosing scope, opens a function scope for params,
//                            header token stores { body_length, body_offset }. Laziness is
//                            encoded by kind (kw_fn vs kw_lazy_fn). Functions are inlined at call
//                            sites (see inline-expansion-spec.md); bodies in parsedQ are templates
//                            and skipped by codegen.
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
const bitset = @import("bitset.zig");

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

    const ParserType = enum(u8) { none, literal, identifier, callExpr, unaryOp, binaryOp, binaryRightAssocOp, assignOp, colonAssocOp, separator, skipNewLine, groupParen, groupBracket, groupBrace, indentBlock, kwIf, kwElse, kwFn, opIdentifierInfix };

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
        grammar.grammar[@intFromEnum(Kind.const_identifier)] = TokenParser{ .prefix = .identifier, .infix = .opIdentifierInfix, .power = .Comparison };
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
        grammar.infix(Kind.op_identifier, .opIdentifierInfix, .Comparison);
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

        // Keywords
        grammar.prefix(Kind.kw_if, .kwIf, .None);
        grammar.prefix(Kind.kw_else, .kwElse, .None);
        grammar.prefix(Kind.kw_fn, .kwFn, .None);

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
        fns[@intFromEnum(ParserType.kwFn)] = kwFn;
        fns[@intFromEnum(ParserType.opIdentifierInfix)] = opIdentifierInfix;
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

    fn groupDelim(self: *Self, open_kind: Kind, close_kind: Kind) anyerror!void {
        try self.emit(Token.groupOpen(open_kind));
        var arg_counter: u16 = 0;
        if (self.syntaxQ.peek().kind != close_kind) {
            while (true) {
                try self.parse(Power.Separator.val());
                if (self.syntaxQ.peek().kind != Kind.sep_comma) break;
                _ = self.syntaxQ.pop();
                arg_counter += 1;
                try self.emit(Token.groupSep(arg_counter));
            }
        }
        assert(self.syntaxQ.pop().kind == close_kind);
        try self.emit(Token.groupClose(close_kind));
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

    fn kwFn(self: *Self, _: Token) anyerror!void {
        // 1. Function name - pop identifier, declare it
        const nameToken = self.syntaxQ.pop();
        const declName = self.resolution.declare(@truncate(self.parsedQ.list.items.len), nameToken);
        try self.emit(declName);

        // 2. fn_header placeholder — kind/body_length/body_offset patched later.
        const headerIdx: u32 = @truncate(self.parsedQ.list.items.len);
        try self.emit(Token.fnHeader(Kind.kw_fn, 0, 0));

        // 3. Parameters — track per-slot laziness via a bitset (slot i = 1 iff param i is lazy).
        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        try self.resolution.startScope(rs.Scope{ .start = headerIdx, .scopeType = .function });
        const openIdx: u32 = @truncate(self.parsedQ.list.items.len);
        try self.emit(Token.groupOpen(Kind.grp_open_paren));
        var arg_counter: u16 = 0;
        var lazyMask = bitset.BitSet64.initEmpty();
        if (self.syntaxQ.peek().kind != Kind.grp_close_paren) {
            while (true) {
                const paramToken = self.syntaxQ.pop();
                const paramIdx: u32 = @truncate(self.parsedQ.list.items.len);
                const declParam = self.resolution.declare(paramIdx, paramToken);
                try self.emit(declParam);
                if (paramToken.kind == Kind.const_identifier) {
                    assert(arg_counter < 64);
                    lazyMask.set(arg_counter);
                }
                const next = self.syntaxQ.peek();
                if (next.kind == Kind.sep_comma) {
                    _ = self.syntaxQ.pop();
                    arg_counter += 1;
                    try self.emit(Token.groupSep(arg_counter));
                } else break;
            }
        }
        _ = self.syntaxQ.pop(); // close paren
        try self.emit(Token.groupClose(Kind.grp_close_paren));
        // body_offset lands on the token immediately after the close paren.
        const body_offset: u16 = @truncate(self.parsedQ.list.items.len - headerIdx);
        _ = self.syntaxQ.pop(); // op_colon_assoc

        // 4. Parse body — use Separator power to stop at newlines for single-line bodies.
        try self.parse(Power.Separator.val());
        // TODO: Multi-line function-body support.

        // 5. Pop scope
        try self.resolution.endScope(@truncate(self.parsedQ.list.items.len));

        // 6. Validate each lazy param: exactly one body-use, reachable via next_offset.
        //    Rewrite that use's kind to ident_splice so the body walker dispatches by kind alone.
        //    Param i's decl is at openIdx + 1 + 2*i (open, decl0, sep, decl1, sep, decl2, ..., close).
        var it = lazyMask.iterator(.{});
        while (it.next()) |slot| {
            // TODO: This indexing won't work long term once we add in optional type declarations, default value expressions, etc.
            // Instead, use comma-chaining to walk the params.
            const declIdx: u32 = openIdx + 1 + 2 * @as(u32, @truncate(slot));
            const nextOff = self.parsedQ.list.items[declIdx].data.ident.next_offset;
            if (nextOff == 0) return error.LazyParamUnused;
            const spliceIdx = rs.applyOffset(i16, declIdx, nextOff);
            if (self.parsedQ.list.items[spliceIdx].data.ident.next_offset != 0)
                return error.LazyParamUsedMoreThanOnce;
            self.parsedQ.list.items[spliceIdx].kind = Kind.ident_splice;
        }

        // 7. Patch fn_header: kind (lazy vs eager), body_length, body_offset.
        const bodyLength: u32 = @truncate(self.parsedQ.list.items.len - headerIdx - 1);
        const headerKind: Kind = if (lazyMask.count() > 0) Kind.kw_lazy_fn else Kind.kw_fn;
        self.parsedQ.list.items[headerIdx] = Token.fnHeader(headerKind, bodyLength, body_offset);
    }

    fn opIdentifierInfix(self: *Self, token: Token) anyerror!void {
        const resolved = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), token);
        const offset = resolved.data.ident.prev_offset;

        // Check if this resolves to a kw_lazy_fn declaration. Pure-eager fns no longer inline (D6).
        if (offset == rs.UNDECLARED_SENTINEL) {
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }

        const declIndex = rs.applyOffset(i16, @truncate(self.parsedQ.list.items.len), offset);

        if (declIndex + 1 >= self.parsedQ.list.items.len) {
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }
        const headerKind = self.parsedQ.list.items[declIndex + 1].kind;
        if (headerKind != Kind.kw_lazy_fn) {
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }

        // Param list layout (2-param infix): [open, param1, sep, param2, close].
        const openIdx: u32 = declIndex + 2;
        assert(self.parsedQ.list.items[openIdx].kind == Kind.grp_open_paren);
        assert(self.parsedQ.list.items[openIdx + 4].kind == Kind.grp_close_paren);
        const param1 = self.parsedQ.list.items[openIdx + 1];
        const param2 = self.parsedQ.list.items[openIdx + 3];

        // Infix-inline requires slot 0 eager, slot 1 lazy. First-lazy would require retroactive
        // left-operand patching, which the design explicitly disallows. Fall back to binary op
        // on any other shape.
        var paramMask = bitset.BitSet64.initEmpty();
        if (param1.kind == Kind.const_identifier) paramMask.set(0);
        if (param2.kind == Kind.const_identifier) paramMask.set(1);
        if (paramMask.isSet(0) or !paramMask.isSet(1)) {
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }

        const fnHeader = self.parsedQ.list.items[declIndex + 1];
        const bodyLength = fnHeader.data.fn_header.body_length;
        const bodyOffset = fnHeader.data.fn_header.body_offset;

        // Lazy expansion: bind eager param 1 to the left operand (already emitted); splice
        // parses the right operand from syntaxQ when walkBodyTemplate hits the lazy param's use.
        const eagerSymbolId = param1.data.ident.symbol_id;
        const savedDecl = self.resolution.declarations[eagerSymbolId];

        // Synthesised eager-param binding: kind = ident_splice so codegen pops the register
        // (operand already on the stack) instead of allocating a fresh one.
        const eagerDecl = self.resolution.declare(@truncate(self.parsedQ.list.items.len), Token.lex(Kind.ident_splice, eagerSymbolId, 0));
        try self.emit(eagerDecl);

        const bodyStart: u32 = declIndex + 1 + bodyOffset;
        const bodyEnd: u32 = declIndex + 1 + bodyLength;
        try self.walkBodyTemplate(bodyStart, bodyEnd, token);

        self.resolution.declarations[eagerSymbolId] = savedDecl;
    }

    fn walkBodyTemplate(self: *Self, bodyStart: u32, bodyEnd: u32, opToken: Token) anyerror!void {
        var fixupStack: [4]u32 = undefined;
        var fixupDepth: u8 = 0;

        var i: u32 = bodyStart;
        while (i <= bodyEnd) : (i += 1) {
            // Re-index each iteration — emit() may reallocate parsedQ.
            const templateToken = self.parsedQ.list.items[i];

            if (templateToken.kind == Kind.ident_splice) {
                // Splice: parse right operand from syntaxQ.
                try self.parse(self.power(opToken) + 1);
            } else if (templateToken.kind == Kind.identifier or templateToken.kind == Kind.const_identifier) {
                // Re-resolve against current scope.
                // Recover symbolId: declarations have fn_depth|symbolId in arg0, references have forward chain pointer.
                const symbolId = if (templateToken.flags.declaration)
                    templateToken.data.ident.symbol_id
                else blk: {
                    const declIdx = rs.applyOffset(i16, i, templateToken.data.ident.prev_offset);
                    break :blk self.parsedQ.list.items[declIdx].data.ident.symbol_id;
                };
                const freshToken = Token.lex(templateToken.kind, symbolId, 0);
                const reResolved = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), freshToken);
                try self.emit(reResolved);
            } else if (templateToken.kind == Kind.grp_indent) {
                const emitIdx: u32 = @truncate(self.parsedQ.list.items.len);
                try self.emit(Token.lex(Kind.grp_indent, 0, self.resolution.scopeId));
                fixupStack[fixupDepth] = emitIdx;
                fixupDepth += 1;
            } else if (templateToken.kind == Kind.grp_dedent) {
                fixupDepth -= 1;
                const indentIdx = fixupStack[fixupDepth];
                const emitIdx: u32 = @truncate(self.parsedQ.list.items.len);
                try self.emit(Token.lex(Kind.grp_dedent, indentIdx, self.resolution.scopeId));
                self.parsedQ.list.items[indentIdx] = Token.lex(Kind.grp_indent, emitIdx, self.resolution.scopeId);
            } else {
                // Copy as-is (operators, kw_if, kw_else, op_colon_assoc, literals, etc.)
                try self.emit(templateToken);
            }
        }
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

test {
    _ = @import("test/test_parser.zig");
}
