const val = @import("value.zig");
const std = @import("std");
const print = std.debug.print;


const Range = packed struct { length: u24, offset: u32 };
const KindData = packed struct { kind: u24, value: u32 };
const LiteralData = packed struct { kind: LiteralKind, value: u48 };

pub const LiteralKind = enum(u8) {
    boolean,
    string,
};

const Index = packed struct { offset: u24, index: u32 }; // Offset to previous newline in syntaxQueue and index of current newline in auxQueue.


pub const Token = packed struct(u64) { 
    flags: Flags,
    kind: Kind,
    data: Data,
    
    const Flags = packed struct(u2) {
        prev: bool = false,
        next: bool = false,
    };

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
        grp_close_sqbr,
        grp_open_sqbr,
        op_at,
        op_question,
        op_gt,
        op_assign_eq, // =
        op_lt,
        op_semicolon,
        op_colon_assoc, // :
        op_div,
        op_dot_attr, // .
        op_sub,
        sep_comma,
        op_add,
        op_mul,
        grp_close_paren,
        grp_open_paren,
        op_mod,

        // Alphabetical keywords and special-cases come last.

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

        sep_newline,
        sep_stream_end,

        identifier,
        literal,

        // All aux tokens go at the end.
        aux_comment=59,
        aux_whitespace=60,
        aux_newline=61,
        aux_indentation=62,
        aux_sep_stream_start=63
    };


    const Data = packed union {
        range: Range,
        index: Index,
        kind: KindData,
        literal: LiteralData,
    };

};



pub fn createToken(kind: Token.Kind) Token {
    return Token {
        .kind = kind,
    };
}

pub fn createNewLine(auxIndex: u32, prevOffset: u24) Token {
    return Token{ 
        .kind = Token.Kind.newline,
        .data = Token.Data{
            .index = Index{ .index = auxIndex, .offset = prevOffset }
        }
    };
}

pub fn stringLiteral(offset: u32, len: u24) Token {
    // return Token{ .tag = TokenTag.string_literal, .data = @as(u48, @bitCast(StringLiteralData{ .length = len, .offset = offset })) };
    return Token{ .kind = Token.Kind.literal, .data = Token.Data{ .range = Range{ .length = len, .offset = offset } } };
}

pub fn identifier(offset: u32, len: u16) Token {
    return Token{ .kind = Token.Kind.identifier, .data = Token.Data{ .range = Range{ .length = len, .offset = offset } } };
}

pub fn auxToken(kind: Token.Kind, offset: u32, len: u16) Token {
    // return Aux{ .tag = tag, .data = AuxData{ .range = Range{ .length = len, .offset = offset } } };
    return Token{ .kind = kind, .data = Token.Data{ .range = Range{ .length = len, .offset = offset } } };
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
pub const OP_DOT_ATTR = createToken(Token.Kind.op_dot_attr);

pub const GRP_OPEN_PAREN = createToken(Token.Kind.grp_open_paren);
pub const GRP_CLOSE_PAREN = createToken(Token.Kind.grp_close_paren);
pub const GRP_OPEN_SQBR = createToken(Token.Kind.grp_open_sqbr);
pub const GRP_CLOSE_SQBR = createToken(Token.Kind.grp_close_sqbr);
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
pub const SEP_STREAM_END = createToken(Token.Kind.sep_stream_end);


// pub fn print_token(token: Token) void {
//     switch (token.tag) {
//         TokenTag.token => {
//             print("Token {any}", .{token});
//         },
//         TokenTag.value => {
//             print("value", .{});
//         },
//         TokenTag.identifier => {
//             print("identifier", .{});
//         },
//         TokenTag.string_literal => {
//             print("string_literal", .{});
//         },
//         TokenTag.newline => {
//             print("newline", .{});
//         }
//     }
// }

// @bitSizeOf
const expect = std.testing.expect;

test "Test token sizes" {
    try expect(@bitSizeOf(Token) == 64);
    // try expect(@bitSizeOf(Aux) == 64);
    // try expect(@bitSizeOf(AuxOrToken) == 128);
}