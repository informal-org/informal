use avs::constants::*;
use avs::structs::Atom;
use avs::utils::truncate_symbol;
use super::structs::*;


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
    // Symbols and everything else have a higher precedence so they're evaluated first
    return 16
}

pub fn is_operator(symbol: u64) -> bool {
    return (symbol & PAYLOAD_MASK) <= 16;
}

pub fn is_dependency_symbol(context: &Context, symbol: u64) -> bool {
    // Check if a symbol is a valid dependency (i.e. not a built in operator/symbol)
    // One option - check for any symbols that are outside the built-in range.
    return (symbol & PAYLOAD_MASK) >= APP_SYMBOL_START

    // Another - check against cell list
    // context.symbols_cell.is_some() && context.symbols_cell.as_ref().unwrap().contains_key(&op_kw)
}



// TODO: There may be additional edge cases for handling inline function calls within the expression
// Current assumption is that all variable references are to a value.
pub fn apply_operator_precedence(context: &Context, id: u64, cell_symbol: u64, infix: &mut Vec<Atom>) -> Expression {
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
                        return Expression::err(id, PARSE_ERR_UNMATCHED_PARENS)
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
                            if is_dependency_symbol(&context, stack_symbol) {
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
            return Expression::err(id, PARSE_ERR_UNMATCHED_PARENS)
        }

        postfix.push(Atom::SymbolValue(op_kw));
        // Don't push operators in
        if is_dependency_symbol(&context, op_kw) {
            depends_on.push(op_kw);
        }
    }
    let mut node = Expression::new(id);
    node.cell_symbol = cell_symbol;
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
        let mut context = Context::new(APP_SYMBOL_START);
        let mut input: Vec<Atom> = vec![Atom::NumericValue(1.0), Atom::SymbolValue(SYMBOL_PLUS.symbol), Atom::NumericValue(2.0)];
        let output: Vec<Atom> = vec![Atom::NumericValue(1.0), Atom::NumericValue(2.0), Atom::SymbolValue(SYMBOL_PLUS.symbol)];
        assert_eq!(apply_operator_precedence(&context, 0, context.next_symbol_id, &mut input).parsed, output);
    }

    #[test]
    fn test_parse_add_mult() {
        // Verify order of operands - multiply before addition
        // 1 * 2 + 3 = 1 2 * 3 +
        let mut context = Context::new(APP_SYMBOL_START);
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
        assert_eq!(apply_operator_precedence(&context, 0, context.next_symbol_id, &mut input).parsed, output);

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

        assert_eq!(apply_operator_precedence(&context, 0, context.next_symbol_id, &mut input2).parsed, output2);
    }

    #[test]
    fn test_parse_add_mult_paren() {
        // Verify order of operands - multiply before addition
        // 1 * (2 + 3) = 1 2 3 + *
        let mut context = Context::new(APP_SYMBOL_START);
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
        assert_eq!(apply_operator_precedence(&context, 0, context.next_symbol_id, &mut input).parsed, output);

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

        assert_eq!(apply_operator_precedence(&context, 0, context.next_symbol_id, &mut input2).parsed, output2);
    }
}