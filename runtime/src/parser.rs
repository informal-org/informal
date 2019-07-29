use super::Result;
use avs::constants::*;
use avs::structs::Atom;
use avs::utils::truncate_symbol;
use super::structs::*;
use super::constants::*;


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


fn get_op_precedence(symbol: u64) -> u8 {
    let index = truncate_symbol(symbol) as usize;
    if index < KEYWORD_PRECEDENCE.len() {
        return KEYWORD_PRECEDENCE[index];
    }
    // TODO: Rearrange precedence to not use 0 then.
    return 0
}

// TODO: There may be additional edge cases for handling inline function calls within the expression
// Current assumption is that all variable references are to a value.
pub fn apply_operator_precedence(id: u64, infix: &mut Vec<Atom>) -> ASTNode {
    // Parse the lexed infix input and construct a postfix version
    // Current implementation uses the shunting yard algorithm for operator precedence.
    let mut postfix: Vec<Atom> = Vec::with_capacity(infix.len());
    let mut operator_stack: Vec<u64> = Vec::with_capacity(infix.len());
    // The callee will generate used_by from this.
    let mut depends_on: Vec<u64> = Vec::new();

    for token in infix.drain(..) {
        match &token {
            Atom::SymbolValue(kw) => {
                match *kw {
                    SYMBOL_OPEN_PAREN => operator_stack.push(*kw),
                    SYMBOL_CLOSE_PAREN => {
                        // Pop until you find the matching opening paren
                        let mut found = false;
                        while let Some(op) = operator_stack.pop() {
                            // Sholud always be true since the operator stack only contains keywords
                            match op {
                                SYMBOL_OPEN_PAREN => {
                                    found = true;
                                    break;
                                }
                                _ => postfix.push(Atom::SymbolValue(op))
                            }
                        }
                        if found == false {
                            // return Err(PARSE_ERR_UNMATCHED_PARENS)
                            return ASTNode::err(id, PARSE_ERR_UNMATCHED_PARENS)
                        }
                    },
                    _ => {
                        // For all other operators, flush higher or equal level operators
                        // All operators are left associative in our system right now. (else, equals doesn't get pushed)
                        let my_precedence = get_op_precedence(*kw);
                        while operator_stack.len() > 0 {
                            let op_peek_last = operator_stack.last().unwrap();
                            // Skip any items that aren't really operators.
                            if *op_peek_last == SYMBOL_OPEN_PAREN {
                                break;
                            }

                            let other_precedence = get_op_precedence(*op_peek_last);
                            if other_precedence >= my_precedence {        // output any higher priority operators.
                                postfix.push(Atom::SymbolValue(operator_stack.pop().unwrap()));
                            } else {
                                break;
                            }
                        }
                        // Flushed all operators with higher precedence. Add to op stack.
                        operator_stack.push(*kw);
                    }
                }
            },
            Atom::NumericValue(_lit) => postfix.push(token),
            Atom::StringValue(_lit) => postfix.push(token),
            // TODO
            // TokenType::Identifier(_id) => {
            //     depends_on.push(*_id);
            //     postfix.push(token)
            // }
        }
    }

    // Flush all remaining operators onto the postfix output. 
    // Reverse so we get items in the stack order.
    operator_stack.reverse();
    for op_kw in operator_stack.drain(..) {
        // All of them should be keywords
        match op_kw {
            SYMBOL_OPEN_PAREN => {
                println!("Invalid paren in drain operator stack");
                // return Err(PARSE_ERR_UNMATCHED_PARENS)
                return ASTNode::err(id, PARSE_ERR_UNMATCHED_PARENS)
            }
            _ => {}
        }
        postfix.push(Atom::SymbolValue(op_kw));
    }
    let mut node = ASTNode::new(id);
    node.parsed = postfix;
    node.depends_on = depends_on;
    return node;
}


#[cfg(test)]
mod tests {
    use super::*;
    use crate::constants::*;

    #[test]
    fn test_parse_basic() {
        // Verify straightforward conversion to postfix
        // 1 + 2
        let mut input: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TOKEN_PLUS, TokenType::Literal(LiteralValue::NumericValue(2.0))];
        let output: Vec<TokenType> = vec![TokenType::Literal(LiteralValue::NumericValue(1.0)), TokenType::Literal(LiteralValue::NumericValue(2.0)), TOKEN_PLUS];
        assert_eq!(apply_operator_precedence(0, &mut input).parsed, output);
    }

    #[test]
    fn test_parse_add_mult() {
        // Verify order of operands - multiply before addition
        // 1 * 2 + 3 = 1 2 * 3 +
        let mut input: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];
        let output: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_PLUS,
        ];
        assert_eq!(apply_operator_precedence(0, &mut input).parsed, output);

        // above test with order reversed. 1 + 2 * 3 = 1 2 3 * +
        let mut input2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_MULTIPLY, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];

        let output2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_MULTIPLY,
            TOKEN_PLUS,
        ];

        assert_eq!(apply_operator_precedence(0, &mut input2).parsed, output2);
    }

    #[test]
    fn test_parse_add_mult_paren() {
        // Verify order of operands - multiply before addition
        // 1 * (2 + 3) = 1 2 3 + *
        let mut input: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TOKEN_MULTIPLY, 
            TOKEN_OPEN_PAREN, 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS, 
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_CLOSE_PAREN 
        ];
        let output: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_PLUS,
            TOKEN_MULTIPLY
        ];
        assert_eq!(apply_operator_precedence(0, &mut input).parsed, output);

        // above test with order reversed. (1 + 2) * 3 = 1 2 + 3 *
        let mut input2: Vec<TokenType> = vec![
            TOKEN_OPEN_PAREN,
            TokenType::Literal(LiteralValue::NumericValue(1.0)),
            TOKEN_PLUS,
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_CLOSE_PAREN,
            TOKEN_MULTIPLY,
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
        ];

        let output2: Vec<TokenType> = vec![
            TokenType::Literal(LiteralValue::NumericValue(1.0)), 
            TokenType::Literal(LiteralValue::NumericValue(2.0)),
            TOKEN_PLUS,
            TokenType::Literal(LiteralValue::NumericValue(3.0)),
            TOKEN_MULTIPLY,
        ];

        assert_eq!(apply_operator_precedence(0, &mut input2).parsed, output2);
    }
}