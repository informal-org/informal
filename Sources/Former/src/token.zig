const val = @import("value.zig");
const std = @import("std");
const print = std.debug.print;

// Tags which are only relevant in the context of the lexer.
pub const TokenTag = enum(u3) {
    token, // Keywords, operator symbols, delimiters, etc.
    value, // Literal values, like true, false, null, etc.
    identifier, // Variable names
    string_literal,
    newline,
    // Third bit unused - reserved for future.
};

// Differentiate tokens that may appear in the auxillary queue without semantic meaning.
pub const AuxTag = enum(u3) {
    token, // Tokens with kind, value rather than offset length.
    comment,
    whitespace,
    newline
};

const DataOffsetLen = packed struct { length: u16, offset: u32 };
const DataKindValue = packed struct { kind: u16, value: u32 };

const TokenData = DataKindValue;
const IdentifierData = DataOffsetLen; // Byte offset, identifier length.
const StringLiteralData = DataOffsetLen;
const NewLineData = packed struct { prevOffset: u16, auxIndex: u32 }; // Offset to previous newline in syntaxQueue and index of current newline in auxQueue.

pub const Token = packed struct { switch_q: u1 = 0, _reserved_nan: u12 = val.QUIET_NAN_HEADER, tag: TokenTag, data: u48 };
pub const AuxToken = packed struct { switch_q: u1 = 1, _reserved_nan: u12 = val.QUIET_NAN_HEADER, tag: AuxTag, data: u48 };


// The order here should match bitset lookups in the lexer.
pub const TokenKind = enum {
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
    op_is_not,
    op_not_in,

    grp_indent,
    grp_dedent,

    kw_if,
    kw_else,
    kw_else_if,
    kw_for,

    sep_newline,
    sep_stream_end,
};

pub const AuxKind = enum {
    sep_stream_start,
    indentation,
    number, // References the raw number for col calculations, preserving details like leading zeroes.
};

pub fn createToken(kind: TokenKind) Token {
    return Token{ .tag = TokenTag.token, .data = @as(u48, @bitCast(TokenData{ .kind = @as(u16, @intFromEnum(kind)), .value = 0 })) };
}

pub fn createNewLine(auxIndex: u32, prevOffset: u16) Token {
    return Token{ .tag = TokenTag.newline, .data = @as(u48, @bitCast(NewLineData{ .auxIndex = auxIndex, .prevOffset = prevOffset })) };
}

pub fn stringLiteral(offset: u32, len: u16) Token {
    return Token{ .tag = TokenTag.string_literal, .data = @as(u48, @bitCast(StringLiteralData{ .length = len, .offset = offset })) };
}

pub fn identifier(offset: u32, len: u16) Token {
    return Token{ .tag = TokenTag.identifier, .data = @as(u48, @bitCast(IdentifierData{ .length = len, .offset = offset })) };
}

pub fn auxToken(tag: AuxTag, offset: u32, len: u16) AuxToken {
    return AuxToken{ .tag = tag, .data = @as(u48, @bitCast(DataOffsetLen{ .length = len, .offset = offset })) };
}

pub fn auxKindToken(kind: AuxKind, value: u32) AuxToken {
    return AuxToken{ .tag = AuxTag.token, .data = @as(u48, @bitCast(DataKindValue{ .kind = @as(u16, @intFromEnum(kind)), .value = value })) };
}

pub const OP_ADD = createToken(TokenKind.op_add);
pub const OP_SUB = createToken(TokenKind.op_sub);
pub const OP_MUL = createToken(TokenKind.op_mul);
pub const OP_DIV = createToken(TokenKind.op_div);
pub const OP_MOD = createToken(TokenKind.op_mod);
pub const OP_POW = createToken(TokenKind.op_pow);
pub const OP_AND = createToken(TokenKind.op_and);
pub const OP_OR = createToken(TokenKind.op_or);
pub const OP_NOT = createToken(TokenKind.op_not);
pub const OP_DBL_EQ = createToken(TokenKind.op_dbl_eq);
pub const OP_NE = createToken(TokenKind.op_ne);
pub const OP_LT = createToken(TokenKind.op_lt);
pub const OP_GT = createToken(TokenKind.op_gt);
pub const OP_LTE = createToken(TokenKind.op_lte);
pub const OP_GTE = createToken(TokenKind.op_gte);
pub const OP_ASSIGN_EQ = createToken(TokenKind.op_assign_eq);
pub const OP_IN = createToken(TokenKind.op_in);
pub const OP_IS = createToken(TokenKind.op_is);
pub const OP_IS_NOT = createToken(TokenKind.op_is_not);
pub const OP_NOT_IN = createToken(TokenKind.op_not_in);
pub const OP_COLON_ASSOC = createToken(TokenKind.op_colon_assoc);
pub const OP_DOT_ATTR = createToken(TokenKind.op_dot_attr);

pub const GRP_OPEN_PAREN = createToken(TokenKind.grp_open_paren);
pub const GRP_CLOSE_PAREN = createToken(TokenKind.grp_close_paren);
pub const GRP_OPEN_SQBR = createToken(TokenKind.grp_open_sqbr);
pub const GRP_CLOSE_SQBR = createToken(TokenKind.grp_close_sqbr);
pub const GRP_OPEN_BRACE = createToken(TokenKind.grp_open_brace);
pub const GRP_CLOSE_BRACE = createToken(TokenKind.grp_close_brace);
pub const GRP_INDENT = createToken(TokenKind.grp_indent);
pub const GRP_DEDENT = createToken(TokenKind.grp_dedent);

pub const KW_IF = createToken(TokenKind.kw_if);
pub const KW_ELSE = createToken(TokenKind.kw_else);
pub const KW_ELSE_IF = createToken(TokenKind.kw_else_if);
pub const KW_FOR = createToken(TokenKind.kw_for);

pub const SEP_COMMA = createToken(TokenKind.sep_comma);
pub const SEP_NEWLINE = createToken(TokenKind.sep_newline);
pub const SEP_STREAM_END = createToken(TokenKind.sep_stream_end);
