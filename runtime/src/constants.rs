use super::structs::*;
use avs::constants::*;

/*
// Takes parsed tokens and generates wasm code from it.
*/
pub const AV_STD_ADD: &'static str  = "(call $__av_add)\n";
pub const AV_STD_SUB: &'static str  = "(call $__av_sub)\n";
pub const AV_STD_MUL: &'static str  = "(call $__av_mul)\n";
pub const AV_STD_DIV: &'static str  = "(call $__av_div)\n";

pub const AV_STD_AND: &'static str  = "(call $__av_and)\n";
pub const AV_STD_OR: &'static str   = "(call $__av_or)\n";
pub const AV_STD_NOT: &'static str   = "(call $__av_not)\n";

pub const AV_STD_LT: &'static str  = "(call $__av_lt)\n";
pub const AV_STD_LTE: &'static str   = "(call $__av_lte)\n";
pub const AV_STD_GT: &'static str   = "(call $__av_gt)\n";
pub const AV_STD_GTE: &'static str   = "(call $__av_gte)\n";

// alternatively. Do .nearest first
pub const WASM_F64_AS_I32: &'static str  = "(i32.trunc_s/f64)\n";
pub const WASM_I32_AS_F64: &'static str  = "(f64.convert_s/i32)\n";
pub const WASM_F64_AS_I64: &'static str = "(i64.reinterpret_f64)\n";



// Constants for basic literals
pub const TRUE_LIT: LiteralValue = LiteralValue::BooleanValue(SYMBOL_TRUE);
pub const FALSE_LIT: LiteralValue = LiteralValue::BooleanValue(SYMBOL_FALSE);
pub const NONE_LIT: LiteralValue = LiteralValue::NoneValue;

// Constants for each token type
pub const TOKEN_TRUE: TokenType = TokenType::Literal(TRUE_LIT);
pub const TOKEN_FALSE: TokenType = TokenType::Literal(FALSE_LIT);
pub const TOKEN_NONE: TokenType = TokenType::Literal(NONE_LIT);

pub const TOKEN_OR: TokenType = TokenType::Keyword(KeywordType::KwOr);
pub const TOKEN_AND: TokenType = TokenType::Keyword(KeywordType::KwAnd);
pub const TOKEN_IS: TokenType = TokenType::Keyword(KeywordType::KwIs);
pub const TOKEN_NOT: TokenType = TokenType::Keyword(KeywordType::KwNot);

pub const TOKEN_LT: TokenType = TokenType::Keyword(KeywordType::KwLt);
pub const TOKEN_LTE: TokenType = TokenType::Keyword(KeywordType::KwLte);
pub const TOKEN_GT: TokenType = TokenType::Keyword(KeywordType::KwGt);
pub const TOKEN_GTE: TokenType = TokenType::Keyword(KeywordType::KwGte);

pub const TOKEN_PLUS: TokenType = TokenType::Keyword(KeywordType::KwPlus);
pub const TOKEN_MINUS: TokenType = TokenType::Keyword(KeywordType::KwMinus);
pub const TOKEN_MULTIPLY: TokenType = TokenType::Keyword(KeywordType::KwMultiply);
pub const TOKEN_DIVIDE: TokenType = TokenType::Keyword(KeywordType::KwDivide);

pub const TOKEN_OPEN_PAREN: TokenType = TokenType::Keyword(KeywordType::KwOpenParen);
pub const TOKEN_CLOSE_PAREN: TokenType = TokenType::Keyword(KeywordType::KwCloseParen);
pub const TOKEN_EQUALS: TokenType = TokenType::Keyword(KeywordType::KwEquals);