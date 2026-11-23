pub const Flags = packed struct(u8) {
    alt: bool = false,
    _reserved: u7 = 0,
};

pub const Data = packed union {
    // All u32+u16 variants share the same bit layout and can be read interchangeably.
    // Use the variant that matches the token's semantic context.

    raw: u48,

    // Identifiers: symbol table index + offset.
    // Lexer: offset = source length. Resolution: offset = signed i16 to declaration.
    ident: Ident,

    // Literal values (lit_number, lit_string).
    // Numbers: value = inline int or pool index, length = digit count (0 = pooled).
    // Strings: value = interned string index, length = string length.
    literal: Literal,

    // Function header (kw_fn in parsedQ).
    // body_length = tokens to skip past header (codegen skip-over).
    // body_offset = close_paren_idx + 1 - header_idx, so
    //               header_idx + body_offset is the first body token.
    fn_header: FnHeader,

    // Scope boundaries (grp_indent / grp_dedent).
    // grp_indent: index = end_index (patched at close). grp_dedent: index = start_index.
    scope: Scope,

    // Syntax queue newline cross-reference to aux queue.
    newline: Newline,

    // Aux token source positions (whitespace, newline, indentation).
    aux: Aux,

    irags: IrArgs,

    pub const Ident = packed struct(u48) {
        symbol_id: u16,
        prev_offset: u16,
        next_offset: u16,
    };

    pub const Literal = packed struct(u48) {
        value: u32,
        length: u16,
    };

    pub const FnHeader = packed struct(u48) {
        body_length: u32,
        body_offset: u16,
    };

    pub const Scope = packed struct(u48) {
        index: u32,
        scope_id: u16,
    };

    pub const Newline = packed struct(u48) {
        aux_index: u32,
        prev_offset: u16,
    };

    pub const Aux = packed struct(u48) {
        position: u32,
        length: u16,
    };

    pub const IrArgs = packed struct(u48) { left: u24, right: u24 };
};

pub const Token = packed struct(u64) {
    flags: Flags,
    kind: u8,
    data: Data,

    pub fn lex(kind: u8, value: u32, offset: u16) Token {
        return Token{ .flags = Flags{}, .kind = kind, .data = .{ .literal = .{ .value = value, .length = offset } } };
    }

    pub fn nextAlt(self: Token) Token {
        var flags = self.flags;
        flags.alt = true;
        return Token{ .flags = flags, .kind = self.kind, .data = self.data };
    }
};

pub fn token(kind: u8) Token {
    return Token.lex(kind, 0, 0);
}
