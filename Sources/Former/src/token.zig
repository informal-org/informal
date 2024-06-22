const val = @import("value.zig");
const std = @import("std");
const print = std.debug.print;
const bitset = @import("bitset.zig");


pub const Token = packed struct(u64) { 
    alternate: bool = false,

    _reserved: u1 = 0,  // Reserved for future expansion of kind.
    kind: Kind, // 6,
    data: Data, // 56
    

    pub const Kind = enum(u6) {
        // The order here should match bitset lookups in the lexer.
        // Multi-character symbolic operators come first. >=, ==, etc.
        // In reverse ascii-order of first-character to avoid an extra subtract.
        op_gte, // >=
        op_dbl_eq, // ==
        op_lte, // <=
        op_div_eq, // /=
        op_minus_eq, // -=
        op_plus_eq, // +=
        op_mul_eq, // *=
        op_not_eq, // !=

        // All single-character operators come next, in reverse ascii-order.
        grp_close_brace,
        op_choice, // |
        grp_open_brace,
        op_pow, // ^
        grp_close_bracket,
        grp_open_bracket,
        // op_at,
        // op_question,
        op_gt,
        op_assign_eq, // =
        op_lt,
        // op_semicolon,
        op_colon_assoc, // :
        op_div,
        op_dot_member, // .
        op_sub,
        sep_comma,
        op_add,
        op_mul,
        grp_close_paren,
        grp_open_paren,
        op_mod,

        // Alphabetical keywords and special-cases come last in any order.

        op_unary_minus,

        op_and,
        op_or,
        op_not,

        op_in,
        op_is,
        op_as,
        // op_is_not,
        // op_not_in,

        grp_indent,
        grp_dedent,

        kw_if,
        kw_else,
        kw_else_if,
        kw_for,
        kw_def,

        sep_newline,

        identifier,
        lit_string,
        lit_bool,
        lit_number,
        lit_null,



        // All aux tokens go at the end - denoted by the AUX_KIND_START constant.
        // Used to detect what's aux.
        aux=57,
        aux_comment=58,
        aux_whitespace=59,
        aux_newline=60,
        aux_indentation=61,
        aux_stream_start=62,
        aux_stream_end=63
    };


    const Value = packed struct { value: u56 };
    const Range = packed struct { offset: u32, length: u24 };
    // Offset to previous newline in syntaxQueue and index of current newline in
    // auxQueue.
    const Index = packed struct { offset: u24, index: u32 };
    
    // 56 bits for data.
    const Data = packed union {
        range: Range,
        index: Index,
        value: Value,
    };
};

pub const TokenWriter = struct {
    token: Token,
    buffer: []const u8,

    pub fn format(wrapper: TokenWriter, comptime fmt: []const u8, 
    options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        const value = wrapper.token;
        const buffer = wrapper.buffer;
        const alt = if (value.alternate) "A" else "";

        switch (value.kind) {
            TK.lit_number, TK.lit_string, TK.identifier => {
                try std.fmt.format(writer, "{s} {any} {any} {s}",
                 .{ alt, value.kind, value.data.range, 
                 buffer[value.data.range.offset..value.data.range.offset + 
                 value.data.range.length]});
            },
            TK.aux, TK.aux_comment, TK.aux_whitespace, TK.aux_newline, 
            TK.aux_indentation, TK.aux_stream_start, 
            TK.aux_stream_end => {
                try std.fmt.format(writer, "{s} {any}", .{alt, 
                value.kind});
            },
            else => {
                try std.fmt.format(writer, "{s} {any}", .{alt, 
                value.kind});
            }
        }
    }
};


pub const AUX_KIND_START: u6 = @intFromEnum(Token.Kind.aux);


pub fn createToken(kind: Token.Kind) Token {
    return Token {
        .kind = kind,
        .data = Token.Data{ .value = Token.Value{ .value = 0 } }
    };
}

pub fn createNewLine(auxIndex: u32, prevOffset: u24) Token {
    return Token{ 
        .kind = Token.Kind.sep_newline,
        .data = Token.Data{
            .index = Token.Index{ .index = auxIndex, .offset = prevOffset }
        }
    };
}

pub fn stringLiteral(offset: u32, len: u24) Token {
    return Token{ .kind = Token.Kind.lit_string, .data = Token.Data{ 
        .range = Token.Range{ .length = len, .offset = offset } } };
}

pub fn numberLiteral(offset: u32, len: u24) Token {
    return Token{ .kind = Token.Kind.lit_number, .data = Token.Data{
         .range = Token.Range{ .length = len, .offset = offset } } };
}

pub fn identifier(offset: u32, len: u24) Token {
    return Token{ .kind = Token.Kind.identifier, .data = Token.Data{ 
        .range = Token.Range{ .length = len, .offset = offset } } };
}

// auxToken -> rangeToken
pub fn range(kind: Token.Kind, offset: u32, len: u24) Token {
    return Token{ .kind = kind, .data = Token.Data{ .range = Token.Range{ 
        .length = len, .offset = offset } } };
}

pub fn nextAlt(token: Token) Token {
    return Token{ .alternate=true, .kind = token.kind, .data = token.data };
}

// pub fn auxKindToken(kind: Token.Kind, value: u32) Token {
//     // const aTok = AuxToken{ .tag = AuxTag.token, .data = @as(u48, @bitCast(DataKindValue{ .kind = @as(u16, @intFromEnum(kind)), .value = value })) };
//     // const aTok = Aux{ .tag = AuxTag.token, .data = AuxData{ .kind = kind, .value = value } };
//     // print("auxKindToken: {any}\n", .{aTok});
//     // return aTok;
//     return Token{ .kind = kind, .data = Token.Data{ .kind = KindData{ .kind = @as(u16, @intFromEnum(kind)), .value = value } } };
// }

// pub fn valFromToken(token: Token) u64 {
//     return @as(u64, @bitCast(token));
// }

// pub fn valFromAux(token: AuxToken) u64 {
//     return @as(u64, @bitCast(token));
// }


pub const OP_ADD = createToken(Token.Kind.op_add);
pub const OP_SUB = createToken(Token.Kind.op_sub);
pub const OP_MUL = createToken(Token.Kind.op_mul);
pub const OP_DIV = createToken(Token.Kind.op_div);
pub const OP_MOD = createToken(Token.Kind.op_mod);
pub const OP_POW = createToken(Token.Kind.op_pow);
pub const OP_AND = createToken(Token.Kind.op_and);
pub const OP_OR = createToken(Token.Kind.op_or);
pub const OP_NOT = createToken(Token.Kind.op_not);
pub const OP_DBL_EQ = createToken(Token.Kind.op_dbl_eq);
pub const OP_NE = createToken(Token.Kind.op_ne);
pub const OP_LT = createToken(Token.Kind.op_lt);
pub const OP_GT = createToken(Token.Kind.op_gt);
pub const OP_LTE = createToken(Token.Kind.op_lte);
pub const OP_GTE = createToken(Token.Kind.op_gte);
pub const OP_ASSIGN_EQ = createToken(Token.Kind.op_assign_eq);
pub const OP_IN = createToken(Token.Kind.op_in);
pub const OP_IS = createToken(Token.Kind.op_is);
pub const OP_IS_NOT = createToken(Token.Kind.op_is_not);
pub const OP_NOT_IN = createToken(Token.Kind.op_not_in);
pub const OP_COLON_ASSOC = createToken(Token.Kind.op_colon_assoc);
pub const OP_DOT_MEMBER = createToken(Token.Kind.op_dot_member);

pub const GRP_OPEN_PAREN = createToken(Token.Kind.grp_open_paren);
pub const GRP_CLOSE_PAREN = createToken(Token.Kind.grp_close_paren);
pub const grp_open_bracket = createToken(Token.Kind.grp_open_bracket);
pub const grp_close_bracket = createToken(Token.Kind.grp_close_bracket);
pub const GRP_OPEN_BRACE = createToken(Token.Kind.grp_open_brace);
pub const GRP_CLOSE_BRACE = createToken(Token.Kind.grp_close_brace);
pub const GRP_INDENT = createToken(Token.Kind.grp_indent);
pub const GRP_DEDENT = createToken(Token.Kind.grp_dedent);

pub const KW_IF = createToken(Token.Kind.kw_if);
pub const KW_ELSE = createToken(Token.Kind.kw_else);
pub const KW_ELSE_IF = createToken(Token.Kind.kw_else_if);
pub const KW_FOR = createToken(Token.Kind.kw_for);

pub const SEP_COMMA = createToken(Token.Kind.sep_comma);
pub const SEP_NEWLINE = createToken(Token.Kind.sep_newline);
pub const AUX_STREAM_START = createToken(Token.Kind.aux_stream_start);
pub const AUX_STREAM_END = createToken(Token.Kind.aux_stream_end);


pub fn print_token_queue(queue: []Token, buffer: []const u8) void {
    for (queue) |token| {
        print("{any}\n", .{ TokenWriter{ .token = token, .buffer = buffer } });
    }
}


pub const Assoc = enum(u1) {
    left, right
};

pub const Arity = enum(u1) {
    unary, binary
};

pub const ParserMeta = packed struct(u6) {
    precedence: u4, 
    assoc: Assoc,
    arity: Arity,
};

const TK = Token.Kind;

pub const LITERALS = bitset.token_bitset(&[_]TK{ 
    TK.lit_string, TK.lit_number, TK.lit_bool, TK.lit_null});
pub const UNARY_OPS = bitset.token_bitset(&[_]TK{ 
    TK.op_not, TK.op_unary_minus});
pub const GROUP_START = bitset.token_bitset(&[_]TK{ 
    TK.grp_indent, TK.grp_open_paren, TK.grp_open_brace, TK.grp_open_bracket});
pub const IDENTIFIER = bitset.token_bitset(&[_]TK{ 
    TK.identifier});
pub const KEYWORD_START = bitset.token_bitset(&[_]TK{ 
    TK.kw_if, TK.kw_for, TK.kw_def});
pub const PAREN_START = bitset.token_bitset(&[_]TK{ 
    TK.grp_open_paren });
pub const BINARY_OPS = bitset.token_bitset(&[_]TK{ 
    TK.op_gte,
    TK.op_dbl_eq,
    TK.op_lte,
    TK.op_div_eq,
    TK.op_minus_eq,
    TK.op_plus_eq,
    TK.op_mul_eq,
    TK.op_not_eq,
    TK.op_choice,
    TK.op_pow,
    // op_at,
    // op_question,
    TK.op_gt,
    TK.op_assign_eq,   // TODO: This one's a special case
    TK.op_lt,
    TK.op_colon_assoc, // TODO: This one's a special case
    TK.op_div,
    TK.op_dot_member,
    TK.op_sub,
    TK.op_add,
    TK.op_mul,
    TK.op_mod,
    TK.op_and,
    TK.op_or,
    TK.op_in,
    TK.op_is,
    TK.op_as,
});
pub const SEPARATORS = bitset.token_bitset(&[_]TK{ 
    TK.sep_comma,
    TK.sep_newline
});

const PRECEDENCE_LEVELS = [_]bitset.BitSet64 {
    // Higher binding power -> lower
    // Grouping is handled separately.
    bitset.token_bitset(&[_]TK{ TK.op_dot_member }),

    // Unary ops.
    bitset.token_bitset(&[_]TK{ TK.op_unary_minus, TK.op_not }),

    bitset.token_bitset(&[_]TK{ TK.op_pow }),
    bitset.token_bitset(&[_]TK{ TK.op_mod, TK.op_div, TK.op_mul }),
    bitset.token_bitset(&[_]TK{ TK.op_add, TK.op_sub }),

    // Comparison operators
    bitset.token_bitset(&[_]TK{ TK.op_gte, TK.op_lte, TK.op_lt, TK.op_gt }),
    bitset.token_bitset(&[_]TK{ TK.op_dbl_eq, TK.op_not_eq }),

    // Logical operators
    bitset.token_bitset(&[_]TK{ TK.op_and }),
    bitset.token_bitset(&[_]TK{ TK.op_or }),

    // Assignment operators
    bitset.token_bitset(&[_]TK{ TK.op_assign_eq, TK.op_div_eq, 
    TK.op_minus_eq, TK.op_plus_eq, TK.op_mul_eq }),

    // Separators
    bitset.token_bitset(&[_]TK{ TK.sep_comma, TK.sep_newline }),
};

// The following operators are right associative. Everything else is left-associative.
// a = b = c is equivalent to a = (b = c). 
const RIGHT_ASSOC = bitset.token_bitset(&[_]TK{ TK.op_not,
 TK.op_pow, TK.op_colon_assoc, TK.op_assign_eq, TK.op_div_eq, 
 TK.op_minus_eq, TK.op_plus_eq, TK.op_mul_eq });


// Given the current operarator, indicates which other operators to flush from the operator stack
// Allows us to handle precedence and associativity in a single lookup
// Doesn't require additional precedence lookups per operator on the stack.
// Compile-time constant.

pub const TBL_PRECEDENCE_FLUSH = initPrecedenceTable();

fn initPrecedenceTable() [64]bitset.BitSet64 {
    @setEvalBranchQuota(10000);
    var flushTbl: [64]bitset.BitSet64 = undefined;
    const flushNothing = bitset.BitSet64.initEmpty();
    for(0..64) |i| {
        flushTbl[i] = flushNothing;
    }

    // We only want to construct the precedence table for the tokens which have
    // precedence. Everything else should be handled by separate state-machine
    // logic and should be unreachable.
    for(PRECEDENCE_LEVELS) |level| {
        for(0..64) |i| {        // TODO
            // Assumption: Each op only shows up in one precedence level.
            if (level.isSet(i)) {
                flushTbl[i] = getFlushBitset(@enumFromInt(i));
            }
        }
    }
    return flushTbl;
}

fn getFlushBitset(kind: TK) bitset.BitSet64 {
    // For each token, you flush all tokens with higher precedence, since those
    // operations must be done before this lower-precedence op. Also flush if
    // precedence is equal and left-associative, to respect left-to-right
    // precedence.
    var bs: bitset.BitSet64 = bitset.BitSet64.initEmpty();
    const tokenKind: u6 = @intFromEnum(kind);
    for (PRECEDENCE_LEVELS) |level| {
        if (!level.isSet(tokenKind)) {
            bs = bs.unionWith(level);
        } else {
            // Flush equal precedence if left-associative.
            if(!RIGHT_ASSOC.isSet(tokenKind)) {
                bs = bs.unionWith(level);
            }
            break;
        }
    }
    return bs;
}


// @bitSizeOf
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "Test token sizes" {
    try expect(@bitSizeOf(Token) == 64);
    // try expect(@bitSizeOf(Aux) == 64);
    // try expect(@bitSizeOf(AuxOrToken) == 128);
}

test "Test precedence table" {
    const dotFlush = TBL_PRECEDENCE_FLUSH[
        @intFromEnum(TK.op_dot_member)];
    // print("\nDot: {b}\n", .{dotFlush.mask});
    // try expect(dotFlush.isSet(@intFromEnum(TK.op_dot_member)));
    // Nothing else is higher precedence.
    try expectEqual(1, dotFlush.count());

    const divFlush = TBL_PRECEDENCE_FLUSH[
        @intFromEnum(TK.op_div)];
    // print("Div: {b}\n", .{divFlush.mask});
    try expectEqual(7, divFlush.count());   // 7 higher/equal precedence operators.
    // When you see a div, flush all of these operators (but not lower precedence ones like add, sub, etc.)
    const divFlushExpected = bitset.token_bitset(
        &[_]TK{ TK.op_mod, TK.op_div, TK.op_mul, TK.op_pow, 
        TK.op_unary_minus, TK.op_not, TK.op_dot_member }
    );
    try expectEqual(divFlushExpected.mask, divFlush.mask);

    // Test right-associative. Should not flush itself.
    const powFlush = TBL_PRECEDENCE_FLUSH[
        @intFromEnum(TK.op_pow)];
    // print("Pow: {b}\n", .{powFlush.mask});
    try expectEqual(3, powFlush.count());
    const powFlushExpected = bitset.token_bitset(
        &[_]TK{ TK.op_dot_member, TK.op_unary_minus, TK.op_not }
    );
    try expectEqual(powFlushExpected.mask, powFlush.mask);

    // print("Comma: {b}\n", .{TBL_PRECEDENCE_FLUSH[@intFromEnum(TK.sep_comma)].mask});
}