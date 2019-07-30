use super::structs::*;
use avs::constants::*;
use avs::structs::Atom;
use fnv::FnvHashMap;
use std::fmt;

/*
// Takes parsed tokens and generates wasm code from it.
// TODO: Convert these to a map lookup
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


// Constants for supported symbols within expressions.
// Uses the reserved space from 0-255 
// Note: Ensure no ID conflict with the symbols defined in avs
// The IDs represent index into the precedence array.
// TODO: Invert these?
pub const SYMBOL_OR: u64 = 0;
pub const SYMBOL_AND: u64 = 1;
pub const SYMBOL_IS: u64 = 2;
pub const SYMBOL_NOT: u64 = 3;

pub const SYMBOL_LT: u64 = 4;
pub const SYMBOL_LTE: u64 = 5;
pub const SYMBOL_GT: u64 = 6;
pub const SYMBOL_GTE: u64 = 7;

pub const SYMBOL_PLUS: u64 = 8;
pub const SYMBOL_MINUS: u64 = 9;
pub const SYMBOL_MULTIPLY: u64 = 10;
pub const SYMBOL_DIVIDE: u64 = 11;

pub const SYMBOL_OPEN_PAREN: u64 = 12;
pub const SYMBOL_CLOSE_PAREN: u64 = 13;
pub const SYMBOL_EQUALS: u64 = 14;

// TODO: Investigate whether having statically defined Atom constants for each symbol are worth it.

lazy_static! {

    // Used during printing
    pub static ref ID_SYMBOL_MAP: FnvHashMap<u64, &'static str> = {
        let mut m = FnvHashMap::with_capacity_and_hasher(25, Default::default());

        // Lowercase since they usually appear within sentences.
        m.insert(SYMBOL_OR, "or");
        m.insert(SYMBOL_AND, "and");
        m.insert(SYMBOL_IS, "is");
        m.insert(SYMBOL_NOT, "not");
        
        m.insert(SYMBOL_LT, "<");
        m.insert(SYMBOL_LTE, "<=");
        m.insert(SYMBOL_GT, ">");
        m.insert(SYMBOL_GTE, ">=");

        m.insert(SYMBOL_PLUS, "+");
        m.insert(SYMBOL_MINUS, "-");
        m.insert(SYMBOL_MULTIPLY, "*");
        m.insert(SYMBOL_DIVIDE, "/");

        m.insert(SYMBOL_OPEN_PAREN, "(");
        m.insert(SYMBOL_CLOSE_PAREN, ")");
        m.insert(SYMBOL_EQUALS, "=");

        // Additional keywords - Title case like nouns
        m.insert(SYMBOL_TRUE, "True");
        m.insert(SYMBOL_FALSE, "False");
        m.insert(SYMBOL_NONE, "None");

        m
    };


    // Used during lexing
    pub static ref SYMBOL_ID_MAP: FnvHashMap<&'static str, u64> = {
        // TODO: Sepcify different hasher
        let mut m = FnvHashMap::with_capacity_and_hasher(25, Default::default());
        // Inverting automatically via a function doesn't allow us to automatically uppercase
        // because of unknown size at compile time. So we do it the hard way.
        
        m.insert("OR", SYMBOL_OR);
        m.insert("AND", SYMBOL_AND);
        m.insert("IS", SYMBOL_IS);
        m.insert("NOT", SYMBOL_NOT);
        
        m.insert("<", SYMBOL_LT);
        m.insert("<=", SYMBOL_LTE);
        m.insert(">", SYMBOL_GT);
        m.insert(">=", SYMBOL_GTE);

        m.insert("+", SYMBOL_PLUS);
        m.insert("-", SYMBOL_MINUS);
        m.insert("*", SYMBOL_MULTIPLY);
        m.insert("/", SYMBOL_DIVIDE);

        m.insert("(", SYMBOL_OPEN_PAREN);
        m.insert(")", SYMBOL_CLOSE_PAREN);
        m.insert("=", SYMBOL_EQUALS);

        m.insert("TRUE", SYMBOL_TRUE);
        m.insert("FALSE", SYMBOL_FALSE);
        m.insert("NONE", SYMBOL_NONE);

        m
    };

}


// impl fmt::Debug for Atom {
//     fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
//         match self {
//             Atom::NumericValue(num) => {
//                 write!(f, "NumericValue({})", num)
//             },
//             Atom::StringValue(str_val) => {
//                 write!(f, "StringValue({})", str_val)
//             }
//             Atom::SymbolValue(symbol) => {
//                 write!(f, "SymbolValue({})", symbol)
//             }
//         }
//     }
// }