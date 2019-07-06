use super::error::{Result, ArevelError};
#[macro_use]
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


fn parse(tokens: &mut Vec<TokenType>) -> Result<Vec<TokenType>> {
    // Parse the lexed tokens and construct an AST representation
    // Current implementation uses the shunting yard algorithm for operator precedence.
    let mut output: Vec<TokenType> = Vec::with_capacity(tokens.len());
    let mut operator_stack: Vec<TokenType> = Vec::with_capacity(tokens.len());
    println!("Parsing");

    for token in tokens.drain(..) {
        match &token {
            TokenType::Keyword(kw) => {
                println!("Found top level keyword");
                match kw {
                    KeywordType::OpOpenParen => operator_stack.push(token),
                    KeywordType::OpCloseParen => {
                        // Pop until you find the matching opening paren
                        let mut found = false;
                        while let Some(op) = operator_stack.pop() {
                            // Sholud always be true since the operator stack only contains keywords
                            if let TokenType::Keyword(op_kw) = &op {
                                match op_kw {
                                    KeywordType::OpOpenParen => {
                                        found = true;
                                        break;
                                    }
                                    _ => {
                                        output.push(op);
                                    }
                                }
                            }
                        }
                        if found == false {
                            return Err(ArevelError::UnmatchedParens)
                        }
                    },
                    _ => {
                        // For all other operators, flush higher or equal level operators
                        // All operators are left associative in our system right now. (else, equals doesn't get pushed)
                        let my_precedence = get_op_precedence(*kw);
                        while operator_stack.len() > 0 {
                            let op_peek_last = operator_stack.get(operator_stack.len() - 1);
                            if let Some(TokenType::Keyword(op_kw)) = op_peek_last {
                                let other_precedence = get_op_precedence(*op_kw);
                                if other_precedence >= my_precedence {
                                    // Then it takes priority. Output.
                                    output.push(operator_stack.pop().unwrap());
                                } else {
                                    break;
                                }
                            }
                        }

                        println!("Adding to operator stack");
                        // Flushed all operators with higher precedence. Add to op stack.
                        operator_stack.push(token);
                    }
                }

            },
            TokenType::Literal(_lit) => {
                println!("Found top level literal");
                // Add numbers to output
                output.push(token);
            },
            TokenType::Identifier(_id) => {
                println!("Found top level id");
                output.push(token);
            }
        }
    }

    // Flush all remaining operators onto the output. 
    for token in operator_stack.drain(..) {
        println!("Token drain");
        // All of them should be keywords
        if let TokenType::Keyword(op_kw) = &token {
            match op_kw {
                KeywordType::OpOpenParen => {
                    return Err(ArevelError::UnmatchedParens)
                }
                _ => {}
            }
        }
        output.push(token);
    }

    return Ok(output);
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_basic() {
        let mut input: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TOKEN_PLUS, TokenType::Literal(LiteralValue::NumericValue(2.0))];
        let output: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TokenType::Literal(LiteralValue::NumericValue(2.0)), TOKEN_PLUS];
        assert_eq!(parse(&mut input).unwrap(), output);

        
    }
}