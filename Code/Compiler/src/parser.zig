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

        // 2. fn_header placeholder (arg0=bodyLength, arg1=metadata - patched later)
        const headerIdx: u32 = @truncate(self.parsedQ.list.items.len);
        try self.emit(Token.lex(Kind.kw_fn, 0, 0));

        // 3. Parameters — track kinds for lazy detection
        assert(self.syntaxQ.pop().kind == Kind.grp_open_paren);
        try self.resolution.startScope(rs.Scope{ .start = headerIdx, .scopeType = .function });
        var paramCount: u16 = 0;
        var lazyParamDeclIdx: u32 = 0;
        var lazyCount: u16 = 0;
        var eagerCount: u16 = 0;
        while (self.syntaxQ.peek().kind != Kind.grp_close_paren) {
            if (self.syntaxQ.peek().kind == Kind.sep_comma) _ = self.syntaxQ.pop();
            const paramToken = self.syntaxQ.pop();
            const paramIdx: u32 = @truncate(self.parsedQ.list.items.len);
            const declParam = self.resolution.declare(paramIdx, paramToken);
            try self.emit(declParam);
            if (paramToken.kind == Kind.const_identifier) {
                lazyParamDeclIdx = paramIdx;
                lazyCount += 1;
            } else {
                eagerCount += 1;
            }
            paramCount += 1;
        }
        _ = self.syntaxQ.pop(); // close paren
        _ = self.syntaxQ.pop(); // op_colon_assoc

        // 4. Parse body — use Separator power to stop at newlines for single-line bodies.
        const bodyStart: u32 = @truncate(self.parsedQ.list.items.len);
        try self.parse(Power.Separator.val());

        // 5. Pop scope
        try self.resolution.endScope(@truncate(self.parsedQ.list.items.len));

        // 6. Lazy detection: exactly 1 eager + 1 lazy param → scan body for splice points
        //    Identify references to the lazy param by following arg1 offset to the declaration index.
        const isLazy = eagerCount == 1 and lazyCount == 1;
        if (isLazy) {
            const bodyEnd: u32 = @truncate(self.parsedQ.list.items.len);
            var spliceCount: u32 = 0;
            var i: u32 = bodyStart;
            while (i < bodyEnd) : (i += 1) {
                const bodyToken = self.parsedQ.list.items[i];
                if (!bodyToken.aux.declaration and
                    (bodyToken.kind == Kind.identifier or bodyToken.kind == Kind.const_identifier or bodyToken.kind == Kind.op_identifier))
                {
                    const refDeclIdx = rs.applyOffset(i16, i, bodyToken.data.value.arg1);
                    if (refDeclIdx == lazyParamDeclIdx) {
                        var patched = bodyToken;
                        patched.aux.splice = true;
                        self.parsedQ.list.items[i] = patched;
                        spliceCount += 1;
                    }
                }
            }
            assert(spliceCount == 1);
        }

        // 7. Patch fn_header: arg0=bodyLength, arg1=(lazyFlag << 15) | paramCount
        const bodyLength: u32 = @truncate(self.parsedQ.list.items.len - headerIdx - 1);
        const lazyFlag: u16 = if (isLazy) 1 else 0;
        const metadata: u16 = (lazyFlag << 15) | paramCount;
        self.parsedQ.list.items[headerIdx] = Token.lex(Kind.kw_fn, bodyLength, metadata);
    }

    fn opIdentifierInfix(self: *Self, token: Token) anyerror!void {
        const resolved = self.resolution.resolve(@truncate(self.parsedQ.list.items.len), token);
        const offset = resolved.data.value.arg1;

        // Check if this resolves to a function declaration.
        if (offset == rs.UNDECLARED_SENTINEL) {
            // Unresolved — fall back to binary op.
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }

        const declIndex = rs.applyOffset(i16, @truncate(self.parsedQ.list.items.len), offset);

        // Verify the declaration is followed by a kw_fn header.
        if (declIndex + 1 >= self.parsedQ.list.items.len or
            self.parsedQ.list.items[declIndex + 1].kind != Kind.kw_fn)
        {
            // Not a function — fall back to binary op.
            try self.parse(self.power(token) + 1);
            try self.emit(resolved);
            return;
        }

        const fnHeader = self.parsedQ.list.items[declIndex + 1];
        const bodyLength = fnHeader.data.value.arg0;
        const metadata = fnHeader.data.value.arg1;
        const isLazy = (metadata & 0x8000) != 0;
        const paramCount: u32 = metadata & 0xFF;
        assert(paramCount == 2);

        const param1 = self.parsedQ.list.items[declIndex + 2];
        const param2 = self.parsedQ.list.items[declIndex + 3];

        if (isLazy) {
            // Lazy expansion: one eager param bound to left operand, splice lazy param from syntaxQ.
            // Mask off fn_depth from upper 8 bits of declaration arg0 to recover symbolId.
            const eagerSymbolId = if (param1.kind == Kind.identifier) param1.data.value.arg0 & 0xFFFFFF else param2.data.value.arg0 & 0xFFFFFF;
            const savedDecl = self.resolution.declarations[eagerSymbolId];

            // Declare eager param with splice flag (binds to stack-top in codegen).
            var eagerDecl = self.resolution.declare(@truncate(self.parsedQ.list.items.len), Token.lex(Kind.identifier, eagerSymbolId, 0));
            eagerDecl.aux.splice = true;
            try self.emit(eagerDecl);

            // Walk body template.
            const bodyStart: u32 = declIndex + 2 + paramCount;
            const bodyEnd: u32 = declIndex + 1 + bodyLength;
            try self.walkBodyTemplate(bodyStart, bodyEnd, token);

            // Restore eager declaration.
            self.resolution.declarations[eagerSymbolId] = savedDecl;
        } else {
            // Eager expansion: bind both params, then walk body.
            // Mask off fn_depth from upper 8 bits of declaration arg0 to recover symbolId.
            const sym1 = param1.data.value.arg0 & 0xFFFFFF;
            const sym2 = param2.data.value.arg0 & 0xFFFFFF;
            const saved1 = self.resolution.declarations[sym1];
            const saved2 = self.resolution.declarations[sym2];

            // Bind first param to left operand.
            var decl1 = self.resolution.declare(@truncate(self.parsedQ.list.items.len), Token.lex(Kind.identifier, sym1, 0));
            decl1.aux.splice = true;
            try self.emit(decl1);

            // Parse right operand.
            try self.parse(self.power(token) + 1);

            // Bind second param to right operand.
            var decl2 = self.resolution.declare(@truncate(self.parsedQ.list.items.len), Token.lex(Kind.identifier, sym2, 0));
            decl2.aux.splice = true;
            try self.emit(decl2);

            // Walk body template.
            const bodyStart: u32 = declIndex + 2 + paramCount;
            const bodyEnd: u32 = declIndex + 1 + bodyLength;
            try self.walkBodyTemplate(bodyStart, bodyEnd, token);

            // Restore declarations.
            self.resolution.declarations[sym1] = saved1;
            self.resolution.declarations[sym2] = saved2;
        }
    }

    fn walkBodyTemplate(self: *Self, bodyStart: u32, bodyEnd: u32, opToken: Token) anyerror!void {
        var fixupStack: [4]u32 = undefined;
        var fixupDepth: u8 = 0;

        var i: u32 = bodyStart;
        while (i <= bodyEnd) : (i += 1) {
            // Re-index each iteration — emit() may reallocate parsedQ.
            const templateToken = self.parsedQ.list.items[i];

            if (templateToken.aux.splice) {
                // Splice: parse right operand from syntaxQ.
                try self.parse(self.power(opToken) + 1);
            } else if (templateToken.kind == Kind.identifier or templateToken.kind == Kind.const_identifier) {
                // Re-resolve against current scope.
                // Recover symbolId: declarations have fn_depth|symbolId in arg0, references have forward chain pointer.
                const symbolId = if (templateToken.aux.declaration)
                    templateToken.data.value.arg0 & 0xFFFFFF
                else blk: {
                    const declIdx = rs.applyOffset(i16, i, templateToken.data.value.arg1);
                    break :blk self.parsedQ.list.items[declIdx].data.value.arg0 & 0xFFFFFF;
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
