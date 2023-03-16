use avs::constants::*;
use avs::runtime::RESERVED_SYMBOLS;
use avs::structs::Atom;
use avs::utils::truncate_symbol;
use avs::environment::Environment;
use avs::expression::Expression;
use super::structs::*;



fn get_op_precedence(symbol: u64) -> u8 {
    let index = symbol & PAYLOAD_MASK;
    if index < (RESERVED_SYMBOLS.len() as u64) {
        let symbol_value = RESERVED_SYMBOLS[index as usize];
        if let Some(prec) = symbol_value.precedence {
            return prec
        }
    }
    return 255
}

pub fn is_operator(symbol: u64) -> bool {
    // TODO: Verify. 16 or 30?
    return (symbol & PAYLOAD_MASK) <= 16;
}

pub fn is_dependency_symbol(symbol: u64) -> bool {
    // Check if a symbol is a valid dependency (i.e. not a built in operator/symbol)
    // One option - check for any symbols that are outside the built-in range.
    return (symbol & PAYLOAD_MASK) >= APP_SYMBOL_START
}

// TODO: There may be additional edge cases for handling inline function calls within the expression
// Current assumption is that all variable references are to a value.
pub fn apply_operator_precedence(expression: &mut Expression, infix: &mut Vec<Atom>) {
    // Parse the lexed infix input and construct a postfix version
    // Current implementation uses the shunting yard algorithm for operator precedence.
    let mut postfix: Vec<Atom> = Vec::with_capacity(infix.len());
    let mut operator_stack: Vec<u64> = Vec::with_capacity(infix.len());
    // The callee will generate used_by from this.
    let mut depends_on: Vec<u64> = Vec::new();

    for token in infix.drain(..) {
        match &token {
            Atom::SymbolValue(kw_addr) => {
                let kw = *kw_addr;
                if kw == SYMBOL_OPEN_PAREN.symbol {
                    operator_stack.push(kw)
                } else if kw == SYMBOL_COMMA.symbol {
                    // Denotes end of one sub-expression. i.e. min(1 * 2, 2 + 2). Flush.
                    while let Some(op) = operator_stack.last() {
                        if *op == SYMBOL_COMMA.symbol {
                            operator_stack.pop();
                        } else if *op == SYMBOL_OPEN_PAREN.symbol {
                            break;
                        } else {
                            postfix.push(Atom::SymbolValue(operator_stack.pop().unwrap()))
                        }
                    }
                } else if kw == SYMBOL_CLOSE_PAREN.symbol {
                    // Pop until you find the matching opening paren
                    let mut found = false;
                    while let Some(op) = operator_stack.pop() {
                        // Should always be true since the operator stack only contains keywords
                        if op == SYMBOL_OPEN_PAREN.symbol {
                                found = true;
                                break;
                        } else {
                            postfix.push(Atom::SymbolValue(op))
                        }
                    }
                    if found == false {
                        // return Err(PARSE_ERR_UNMATCHED_PARENS)
                        expression.set_result(PARSE_ERR_UNMATCHED_PARENS);
                        return;
                    }
                    
                    // Check for function call
                    if let Some(maybe_fn) = operator_stack.last() {
                        if !is_operator(*maybe_fn) {
                            // TODO: check if function
                            // TODO: Namespace/module support
                            postfix.push(Atom::SymbolValue(operator_stack.pop().unwrap()));
                            postfix.push(Atom::SymbolValue(SYMBOL_CALL_FN.symbol));
                        }
                    }
                } else {
                    // For all other operators, flush higher or equal level operators
                    // All operators are left associative in our system right now. (else, equals doesn't get pushed)
                    let my_precedence = get_op_precedence(kw);
                    // Is operator. Use precedence.
                    while operator_stack.len() > 0 {
                        let op_peek_last = operator_stack.last().unwrap();
                        // Skip any items that aren't really operators.
                        if *op_peek_last == SYMBOL_OPEN_PAREN.symbol {
                            break;
                        }


                        let other_precedence = get_op_precedence(*op_peek_last);
                        if other_precedence >= my_precedence {        // output any higher priority operators.
                            let stack_symbol = operator_stack.pop().unwrap();
                            // Dependency is managed at cell/pointer level. Treat built-in symbols as met.
                            if is_dependency_symbol(stack_symbol) {
                                depends_on.push(stack_symbol);
                            }
                            
                            // // TODO: This makes commas optional. Change to required but ignored.
                            // if stack_symbol == SYMBOL_COMMA {
                            //     continue
                            // }

                            postfix.push(Atom::SymbolValue(stack_symbol));
                        } else {
                            break;
                        }
                    }
                    // Flushed all operators with higher precedence. Add to op stack.
                    operator_stack.push(kw);
                }
            },
            Atom::NumericValue(_lit) => postfix.push(token),
            Atom::StringValue(_lit) => postfix.push(token),
            Atom::ObjectValue(_lit) => postfix.push(token),     // Should not happen
            Atom::HashMapValue(_lit) => postfix.push(token),     // Should not happen
            Atom::FunctionValue(_lit) => postfix.push(token)
        }
    }

    // Flush all remaining operators onto the postfix output. 
    // Reverse so we get items in the stack order.
    operator_stack.reverse();
    for op_kw in operator_stack.drain(..) {
        // All of them should be keywords
        if op_kw == SYMBOL_OPEN_PAREN.symbol {
            println!("Invalid paren in drain operator stack");
            expression.set_result(PARSE_ERR_UNMATCHED_PARENS);
            return;
        }

        postfix.push(Atom::SymbolValue(op_kw));
        // Don't push operators in
        if is_dependency_symbol(op_kw) {
            depends_on.push(op_kw);
        }
    }
    
    // Save result
    expression.parsed = postfix;
    expression.depends_on = depends_on;
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_basic() {
        // Verify straightforward conversion to postfix
        // 1 + 2
        let mut input: Vec<Atom> = vec![Atom::NumericValue(1.0), Atom::SymbolValue(SYMBOL_PLUS.symbol), Atom::NumericValue(2.0)];

        let output: Vec<Atom> = vec![Atom::NumericValue(1.0), Atom::NumericValue(2.0), Atom::SymbolValue(SYMBOL_PLUS.symbol)];
        let mut expr = Expression::new(APP_SYMBOL_START, "".to_string());
        apply_operator_precedence(&mut expr, &mut input);
        assert_eq!(expr.parsed, output);
    }

    #[test]
    fn test_parse_add_mult() {
        // Verify order of operands - multiply before addition
        // 1 * 2 + 3 = 1 2 * 3 +
        let mut input: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), 
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol), 
            Atom::NumericValue(3.0),
        ];
        let output: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), 
            Atom::NumericValue(3.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol),
        ];
        
        let mut expr = Expression::new(APP_SYMBOL_START, "".to_string());
        apply_operator_precedence(&mut expr, &mut input);
        assert_eq!(expr.parsed, output);


        // above test with order reversed. 1 + 2 * 3 = 1 2 3 * +
        let mut input2: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::SymbolValue(SYMBOL_PLUS.symbol), 
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), 
            Atom::NumericValue(3.0),
        ];

        let output2: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::NumericValue(2.0),
            Atom::NumericValue(3.0),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol),
            Atom::SymbolValue(SYMBOL_PLUS.symbol),
        ];

        let mut expr2 = Expression::new(APP_SYMBOL_START, "".to_string());
        apply_operator_precedence(&mut expr2, &mut input2);
        assert_eq!(expr2.parsed, output2);
    }

    #[test]
    fn test_parse_add_mult_paren() {
        // Verify order of operands - multiply before addition
        // 1 * (2 + 3) = 1 2 3 + *
        let mut input: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol), 
            Atom::SymbolValue(SYMBOL_OPEN_PAREN.symbol), 
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol), 
            Atom::NumericValue(3.0),
            Atom::SymbolValue(SYMBOL_CLOSE_PAREN.symbol)
        ];
        let output: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::NumericValue(2.0),
            Atom::NumericValue(3.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol)
        ];
        let mut expr = Expression::new(APP_SYMBOL_START, "".to_string());
        apply_operator_precedence(&mut expr, &mut input);
        assert_eq!(expr.parsed, output);

        // above test with order reversed. (1 + 2) * 3 = 1 2 + 3 *
        let mut input2: Vec<Atom> = vec![
            Atom::SymbolValue(SYMBOL_OPEN_PAREN.symbol),
            Atom::NumericValue(1.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol),
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_CLOSE_PAREN.symbol),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol),
            Atom::NumericValue(3.0),
        ];

        let output2: Vec<Atom> = vec![
            Atom::NumericValue(1.0), 
            Atom::NumericValue(2.0),
            Atom::SymbolValue(SYMBOL_PLUS.symbol),
            Atom::NumericValue(3.0),
            Atom::SymbolValue(SYMBOL_MULTIPLY.symbol),
        ];

        let mut expr2 = Expression::new(APP_SYMBOL_START, "".to_string());
        apply_operator_precedence(&mut expr2, &mut input2);
        assert_eq!(expr2.parsed, output2);
    }
}