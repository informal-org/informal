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

    // Tail of the enclosing fn's iter chain, used to link lazy param body-refs.
    // 0 = no active fn body. Saved/restored around nested fn bodies.
    active_fn_iter_tail: u32 = 0,

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

    inline fn parsedLen(self: *Self) u32 {
        return @truncate(self.parsedQ.list.items.len);
    }

    fn isLazyFnAt(self: *Self, decl_idx: u32) bool {
        return decl_idx + 1 < self.parsedLen() and
            self.parsedQ.list.items[decl_idx + 1].kind == Kind.kw_lazy_fn;
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
        const is_lazy_param_use = if (token.kind == Kind.const_identifier)
            try self.handleLazyParamUse(token.data.ident.symbol_id)
        else
            false;
        var resolved = self.resolution.resolve(self.parsedLen(), token);
        if (is_lazy_param_use) resolved.kind = Kind.ident_splice;
        try self.emit(resolved);
    }

    /// If `sym_id` resolves to a lazy-fn param declaration, extend the enclosing fn's
    /// iter chain and validate single-use. Returns true iff this is a lazy-param use
    /// (caller should rewrite the emitted kind to ident_splice). Errors on double-use.
    fn handleLazyParamUse(self: *Self, sym_id: u16) !bool {
        const tail = self.resolution.declarations[sym_id];
        if (tail == rs.UNDECLARED_SENTINEL) return false;
        const tail_tok = self.parsedQ.list.items[tail];
        const decl_idx = if (tail_tok.flags.declaration)
            tail
        else
            rs.applyOffset(i16, tail, tail_tok.data.ident.prev_offset);
        const decl_tok = self.parsedQ.list.items[decl_idx];
        if (!decl_tok.flags.declaration or decl_tok.kind != Kind.const_identifier) return false;
        if (decl_idx == 0) return false;
        const prev_kind = self.parsedQ.list.items[decl_idx - 1].kind;
        // Lazy params are always preceded by a group separator (open paren or comma).
        if (prev_kind != Kind.grp_open_paren and prev_kind != Kind.sep_comma) return false;
        // Second use of the same lazy param — tail is the prior use, not the decl.
        if (!tail_tok.flags.declaration) return error.LazyParamUsedMoreThanOnce;

        const sep_idx: u32 = decl_idx - 1;
        const cur_tail = self.active_fn_iter_tail;
        assert(cur_tail != 0);
        self.parsedQ.list.items[cur_tail].data.group_link.iter_offset = rs.calcOffset(i16, sep_idx, cur_tail);
        self.active_fn_iter_tail = sep_idx;
        return true;
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
        const sym_id = token.data.ident.symbol_id;
        if (self.peekFnDecl(sym_id)) |decl_idx| {
            if (self.isLazyFnAt(decl_idx)) {
                return self.callExprInline(decl_idx);
            }
        }
        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        try self.groupDelim(Kind.grp_open_paren, Kind.grp_close_paren);
        try self.emit(token);
    }

    fn peekFnDecl(self: *Self, sym_id: u16) ?u32 {
        const tail = self.resolution.declarations[sym_id];
        if (tail == rs.UNDECLARED_SENTINEL) return null;
        const tailToken = self.parsedQ.list.items[tail];
        return if (tailToken.flags.declaration)
            tail
        else
            rs.applyOffset(i16, tail, tailToken.data.ident.prev_offset);
    }

    /// Skip one argument expression in syntaxQ, respecting balanced grouping.
    /// Stops before the next comma or close-paren at depth 0.
    fn skipArg(self: *Self) void {
        var depth: u32 = 0;
        while (true) {
            const t = self.syntaxQ.peek();
            if (depth == 0 and (t.kind == Kind.sep_comma or t.kind == Kind.grp_close_paren or t.kind == Kind.aux_stream_end)) break;
            _ = self.syntaxQ.pop();
            switch (t.kind) {
                Kind.grp_open_paren, Kind.grp_open_bracket, Kind.grp_open_brace => depth += 1,
                Kind.grp_close_paren, Kind.grp_close_bracket, Kind.grp_close_brace => depth -= 1,
                else => {},
            }
        }
    }

    fn callExprInline(self: *Self, decl_idx: u32) anyerror!void {
        const header_idx = decl_idx + 1;
        const fn_header = self.parsedQ.list.items[header_idx];
        const body_length = fn_header.data.fn_header.body_length;
        const body_offset = fn_header.data.fn_header.body_offset;
        const def_open_idx: u32 = decl_idx + 2;

        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        const args_start = self.syntaxQ.head;

        const scope_start = self.parsedLen();
        try self.resolution.startScope(rs.Scope{ .start = scope_start, .scopeType = .block });

        // Walk the def's positional chain. For each param, parse (eager) or skip (lazy)
        // the corresponding arg from syntaxQ.
        var cur_sep: u32 = def_open_idx;
        while (true) {
            const next_off: i16 = self.parsedQ.list.items[cur_sep].data.group_link.next_offset;
            if (next_off == 0) break;
            if (next_off > 1) {
                if (cur_sep != def_open_idx) assert(self.syntaxQ.pop().kind == Kind.sep_comma);
                const param_tok = self.parsedQ.list.items[cur_sep + 1];
                if (param_tok.kind == Kind.const_identifier) {
                    self.skipArg();
                } else {
                    try self.parse(Power.Separator.val());
                    const synth = self.resolution.declare(
                        self.parsedLen(),
                        Token.lex(Kind.ident_splice, param_tok.data.ident.symbol_id, 0),
                    );
                    try self.emit(synth);
                }
            }
            cur_sep = rs.applyOffset(i16, cur_sep, next_off);
        }

        assert(self.syntaxQ.pop().kind == Kind.grp_close_paren);
        const post_call = self.syntaxQ.head;

        // Body pass: each splice re-seeks args_start and re-advances to its slot,
        // since lazy body-refs may appear out of positional order.
        const body_start: u32 = header_idx + body_offset;
        const body_end: u32 = header_idx + body_length;
        try self.walkBodyBlock(body_start, body_end, def_open_idx, args_start);

        self.syntaxQ.head = post_call;
        try self.resolution.endScope(self.parsedLen());
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

    fn kwFn(self: *Self, _: Token) anyerror!void {
        // 1. Function name - pop identifier, declare it
        const nameToken = self.syntaxQ.pop();
        const declName = self.resolution.declare(self.parsedLen(), nameToken);
        try self.emit(declName);

        // 2. fn_header placeholder — kind/body_length/body_offset patched later.
        const headerIdx = self.parsedLen();
        try self.emit(Token.fnHeader(Kind.kw_fn, 0, 0));

        // 3. Parameters — emit with linked chain, collect eager-first iter chain.
        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        try self.resolution.startScope(rs.Scope{ .start = headerIdx, .scopeType = .function });
        const openIdx = self.parsedLen();
        try self.emit(Token.groupOpen(Kind.grp_open_paren));

        var prev_sep_idx: u32 = openIdx;
        var eager_head: u32 = 0;
        var iter_tail: u32 = 0;
        var has_lazy = false;

        if (self.syntaxQ.peek().kind != Kind.grp_close_paren) {
            while (true) {
                const paramToken = self.syntaxQ.pop();
                const declParam = self.resolution.declare(self.parsedLen(), paramToken);
                try self.emit(declParam);

                if (paramToken.kind == Kind.const_identifier) {
                    has_lazy = true;
                } else {
                    if (eager_head == 0) {
                        eager_head = prev_sep_idx;
                    } else {
                        self.parsedQ.list.items[iter_tail].data.group_link.iter_offset =
                            rs.calcOffset(i16, prev_sep_idx, iter_tail);
                    }
                    iter_tail = prev_sep_idx;
                }

                if (self.syntaxQ.peek().kind == Kind.sep_comma) {
                    _ = self.syntaxQ.pop();
                    prev_sep_idx = try self.emitChainedSep(prev_sep_idx, Token.groupSep());
                } else break;
            }
        }
        assert(self.syntaxQ.pop().kind == Kind.grp_close_paren);
        const closeIdx = try self.emitChainedSep(prev_sep_idx, Token.groupClose(Kind.grp_close_paren));

        // Overload open_paren's unused prev_offset to point at its matching close,
        // giving O(1) lookup (see opIdentifierInfix). Must be set after closeIdx is known.
        self.parsedQ.list.items[openIdx].data.group_link.prev_offset =
            rs.calcOffset(i16, closeIdx, openIdx);

        if (eager_head != 0) {
            self.parsedQ.list.items[closeIdx].data.group_link.iter_offset =
                rs.calcOffset(i16, eager_head, closeIdx);
        }

        const body_offset: u16 = @truncate(self.parsedLen() - headerIdx);
        assert(self.syntaxQ.pop().kind == Kind.op_colon_assoc);

        // 4. Parse body — save/restore iter_tail to support nested fn bodies.
        const prev_fn_iter_tail = self.active_fn_iter_tail;
        self.active_fn_iter_tail = if (eager_head != 0) iter_tail else closeIdx;
        try self.parse(Power.Separator.val());
        self.active_fn_iter_tail = prev_fn_iter_tail;

        try self.resolution.endScope(self.parsedLen());

        // 5. Patch fn_header: kind (lazy vs eager), body_length, body_offset.
        const bodyLength = self.parsedLen() - headerIdx - 1;
        const headerKind: Kind = if (has_lazy) Kind.kw_lazy_fn else Kind.kw_fn;
        self.parsedQ.list.items[headerIdx] = Token.fnHeader(headerKind, bodyLength, body_offset);
    }

    fn opIdentifierInfix(self: *Self, token: Token) anyerror!void {
        const is_lazy_param_use = try self.handleLazyParamUse(token.data.ident.symbol_id);
        var resolved = self.resolution.resolve(self.parsedLen(), token);
        if (is_lazy_param_use) {
            resolved.kind = Kind.ident_splice;
            return self.binaryOpResolved(token, resolved);
        }

        const offset = resolved.data.ident.prev_offset;
        const declIndex = if (offset != rs.UNDECLARED_SENTINEL)
            rs.applyOffset(i16, self.parsedLen(), offset)
        else
            return self.binaryOpResolved(token, resolved);

        if (!self.isLazyFnAt(declIndex))
            return self.binaryOpResolved(token, resolved);

        const openIdx: u32 = declIndex + 2;
        const open_tok = self.parsedQ.list.items[openIdx];
        assert(open_tok.kind == Kind.grp_open_paren);

        // open_paren's prev_offset is overloaded to point at its matching close (set in kwFn).
        // Walk the iter chain from the close paren; require exactly two entries.
        const close_idx = rs.applyOffset(i16, openIdx, open_tok.data.group_link.prev_offset);
        const close_iter_off: i16 = self.parsedQ.list.items[close_idx].data.group_link.iter_offset;
        if (close_iter_off == 0) return self.binaryOpResolved(token, resolved);
        const first_iter_sep = rs.applyOffset(i16, close_idx, close_iter_off);
        const first_iter_next: i16 = self.parsedQ.list.items[first_iter_sep].data.group_link.iter_offset;
        if (first_iter_next == 0) return self.binaryOpResolved(token, resolved);
        const second_iter_sep = rs.applyOffset(i16, first_iter_sep, first_iter_next);
        if (self.parsedQ.list.items[second_iter_sep].data.group_link.iter_offset != 0)
            return self.binaryOpResolved(token, resolved);

        const param1 = self.parsedQ.list.items[first_iter_sep + 1];
        const param2 = self.parsedQ.list.items[second_iter_sep + 1];
        if (param1.kind != Kind.identifier or param2.kind != Kind.const_identifier)
            return self.binaryOpResolved(token, resolved);

        const fnHeader = self.parsedQ.list.items[declIndex + 1];
        const bodyLength = fnHeader.data.fn_header.body_length;
        const bodyOffset = fnHeader.data.fn_header.body_offset;

        const scopeStart = self.parsedLen();
        try self.resolution.startScope(rs.Scope{ .start = scopeStart, .scopeType = .block });

        // Bind left operand (already on stack) to eager param via ident_splice.
        const eagerDecl = self.resolution.declare(self.parsedLen(), Token.lex(Kind.ident_splice, param1.data.ident.symbol_id, 0));
        try self.emit(eagerDecl);

        const bodyStart: u32 = declIndex + 1 + bodyOffset;
        const bodyEnd: u32 = declIndex + 1 + bodyLength;
        try self.walkBodyInfix(bodyStart, bodyEnd, self.power(token) + 1);

        try self.resolution.endScope(self.parsedLen());
    }

    fn binaryOpResolved(self: *Self, token: Token, resolved: Token) anyerror!void {
        try self.parse(self.power(token) + 1);
        try self.emit(resolved);
    }

    fn reResolveAndEmit(self: *Self, templateToken: Token, i: u32) anyerror!void {
        const symbolId = if (templateToken.flags.declaration)
            templateToken.data.ident.symbol_id
        else blk: {
            const declIdx = rs.applyOffset(i16, i, templateToken.data.ident.prev_offset);
            break :blk self.parsedQ.list.items[declIdx].data.ident.symbol_id;
        };
        const freshToken = Token.lex(templateToken.kind, symbolId, 0);
        const reResolved = self.resolution.resolve(self.parsedLen(), freshToken);
        try self.emit(reResolved);
    }

    fn emitTemplateIndent(self: *Self) anyerror!void {
        const scopeId = self.resolution.scopeId;
        const startIdx = self.parsedLen();
        try self.emit(Token.lex(Kind.grp_indent, 0, scopeId));
        try self.resolution.startScope(rs.Scope{ .start = startIdx, .scopeType = .block });
    }

    fn emitTemplateDedent(self: *Self) anyerror!void {
        const scope = self.resolution.scopeStack.items[self.resolution.scopeStack.items.len - 1];
        const indentToken = self.parsedQ.list.items[scope.start];
        try self.emit(Token.lex(Kind.grp_dedent, scope.start, indentToken.data.scope.scope_id));
        try self.resolution.endScope(self.parsedLen());
    }

    fn emitTemplateToken(self: *Self, t: Token, i: u32) anyerror!void {
        switch (t.kind) {
            Kind.identifier, Kind.const_identifier => try self.reResolveAndEmit(t, i),
            Kind.grp_indent => try self.emitTemplateIndent(),
            Kind.grp_dedent => try self.emitTemplateDedent(),
            else => try self.emit(t),
        }
    }

    fn walkBodyInfix(self: *Self, body_start: u32, body_end: u32, splice_power: u8) anyerror!void {
        var i: u32 = body_start;
        while (i <= body_end) : (i += 1) {
            const t = self.parsedQ.list.items[i];
            if (t.kind == Kind.ident_splice) {
                try self.parse(splice_power);
            } else {
                try self.emitTemplateToken(t, i);
            }
        }
    }

    fn walkBodyBlock(self: *Self, body_start: u32, body_end: u32, def_open_idx: u32, args_start: usize) anyerror!void {
        var i: u32 = body_start;
        while (i <= body_end) : (i += 1) {
            const t = self.parsedQ.list.items[i];
            if (t.kind == Kind.ident_splice) {
                const param_decl_idx = rs.applyOffset(i16, i, t.data.ident.prev_offset);
                // Walk the prev-chain back to open paren, counting hops = slot.
                var slot: u32 = 0;
                var s: u32 = param_decl_idx - 1;
                while (s != def_open_idx) : (slot += 1) {
                    const prev_off: i16 = self.parsedQ.list.items[s].data.group_link.prev_offset;
                    assert(prev_off < 0);
                    s = rs.applyOffset(i16, s, prev_off);
                }
                self.syntaxQ.head = args_start;
                var k: u32 = 0;
                while (k < slot) : (k += 1) {
                    self.skipArg();
                    assert(self.syntaxQ.pop().kind == Kind.sep_comma);
                }
                try self.parse(Power.Separator.val());
            } else {
                try self.emitTemplateToken(t, i);
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
