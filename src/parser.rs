use super::error::{Result, ArevelError};
use super::lexer::{TokenType, TRUE_VALUE, FALSE_VALUE, NONE_VALUE};

const UNARY_OPS: &[TokenType] = [TokenType::OpNot];

// This could be a set, but array is likely competetive given size. ToDo benchmark.
const BINARY_OPS: &[TokenType] = [
    TokenType::OpOr, TokenType::OpAnd, TokenType::OpIs,
    TokenType::OpLt, TokenType::OpGt, TokenType::OpLte, TokenType::OpGte,
    TokenType::OpPlus, TokenType::OpMinus, TokenType::OpMultiply, TokenType::OpDivide
];
const BINARY_PRECEDENCEL &[i8] = [
    1, 2, 6, 
    7, 7, 7, 7,
    9, 9, 10, 10
]

