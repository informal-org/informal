use super::error::{Result, ArevelError};
use super::lexer::{TokenType, KeywordType, TRUE_VALUE, FALSE_VALUE, NONE_VALUE};

// const UNARY_OPS: &[TokenType] = [TokenType::OpNot];
// This could be a set, but array is likely competetive given size. TODO benchmark.
// const BINARY_OPS: &[TokenType] = [
//     TokenType::OpOr, TokenType::OpAnd, 
//     TokenType::OpIs,
//     TokenType::OpNot,   // TODO: Precedence of 'Not' in 'x is not false'
//     TokenType::OpLt, TokenType::OpLte, TokenType::OpGt, TokenType::OpGte,
//     TokenType::OpPlus, TokenType::OpMinus, 
//     TokenType::OpMultiply, TokenType::OpDivide,

//     // Not real operations
//     TokenType::OpOpenParen, TokenType::OpCloseParen,
//     TokenType::Equals
// ];

// Higher numbers have higher precedence. 
// Indexes should match with TokenType enum values.
const BINARY_PRECEDENCE: &[u8] = &[
    1, 2,       // and/or
    5,          // is (==)
    6,          // not
    7, 7, 7, 7, // Comparison
    9, 9,       // Add/subtract
    10, 10,     // Multiply, divide
    11, 11,     // Parens
    0           // Equals
];

fn get_bin_op_precedence(keyword: KeywordType) -> u8 {
    let index = keyword as usize;
    return BINARY_PRECEDENCE[index];
}