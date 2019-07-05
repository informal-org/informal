use super::error::{Result, ArevelError};
use super::lexer::*;

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
const KEYWORD_PRECEDENCE: &[u8] = &[
    1, 2,       // and/or
    5,          // is (==)
    6,          // not
    7, 7, 7, 7, // Comparison
    9, 9,       // Add/subtract
    10, 10,     // Multiply, divide
    11, 11,     // Parens
    0           // Equals
];

fn get_op_precedence(keyword: KeywordType) -> u8 {
    let index = keyword as usize;
    return KEYWORD_PRECEDENCE[index];
}


fn parse(tokens: Vec<TokenType>) { //  -> Result<Vec<TokenType>> 
    // Parse the lexed tokens and construct an AST representation
    // Current implementation uses the shunting yard algorithm for operator precedence.
    let mut output: Vec<&TokenType> = Vec::with_capacity(tokens.len());
    let mut operator_stack: Vec<&TokenType> = Vec::with_capacity(tokens.len());

    for token in tokens.iter() {
        match token {
            TokenType::Keyword(kw) => {
                match kw {
                    KeywordType::OpOpenParen => operator_stack.push(&TOKEN_OPEN_PAREN),
                    KeywordType::OpCloseParen => {
                        // Pop until you find the matching opening paren
                        let mut found = false;
                        while let Some(op) = operator_stack.pop() {
                            match op {
                                // &TOKEN_OPEN_PAREN => {
                                //     found = true;
                                // }
                                _ => {
                                    // output.push(op);
                                }
                            }
                        }
                        if found == false {
                            // return Err(ArevelError::UnmatchedParens)
                        }
                    },
                    _ => {
                        // While there's an operator on the operator stack with greater precedence. 
                        // All operators are left associative in our system right now.
                        // let op_iter = operator_stack.iter().peekable();
                        // while let Some(&op) = op_iter.peek() {

                        // }

                    }
                }

            },
            Literal => {
                // Add numbers to output
                output.push(&token);
            },
            Identifier => {
                output.push(&token);
            }

        }
    }
    // return Ok(output);
}
