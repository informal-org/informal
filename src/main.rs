enum AbstractNode {
    Compound, 
    Identifier,
    MemberExpression,
    Literal, 
    ThisExpression,
    CallExpression,
    UnaryExpression,
    BinaryExpression,
    LogicalExpression,
    ConditionalExpression,
    ArrayExpression
}

enum LiteralValue {
    TrueVal, 
    FalseVal, 
    NoneVal
}

const PERIOD_CODE: char = '.';
const COMMA_CODE: char = ',';
const SQUOTE_CODE: char = '\'';
const DQUOTE_CODE: char = '"';
const OPAREN_CODE: char = '(';
const CPAREN_CODE: char = ')';
const OBRACK_CODE: char = '[';
const CBRACK_CODE: char = ']';
const QUMARK_CODE: char = '?';
const SEMCOL_CODE: char = ';';
const COLON_CODE: char = ':';

// These could both be sets, but honestly seems like array would be
// more performant here given how small it is. 
// Worth a micro-benchmark later. 
const UNARY_OPS: &[&str] = &["-", "NOT", "Not", "not"];

const BINARY_OPS: &[&str] =     &["^", "OR", "Or", "or", "AND", "And", "and", "IS", "Is", "is", "<", ">", "<=", ">=", "+", "-", "*", "/", "%", "MOD", "Mod", "mod"];
const BINARY_PRECEDENCE: &[i8] = &[1,   1,    1,     1,   2,      2,    2,     6,    6,      6,     7,   7,   7,  7,     9,    9,   10,  10,  10,    10,    10,   10 ];

// This should be updated any time a longer token is added.
const MAX_UNARY_LEN: i8 = 3;
const MAX_BINARY_LEN: i8 = 3;

// This may be tricky since the result is of a mixed value type
const LITERAL: &[&str] = &["TRUE", "True", "true", "FALSE", "False", "false", "NONE", "None", "none"];
const LITERAL_VAL: &[LiteralValue] = &[LiteralValue::TrueVal, LiteralValue::TrueVal, LiteralValue::TrueVal, LiteralValue::FalseVal, LiteralValue::FalseVal, LiteralValue::FalseVal, LiteralValue::NoneVal, LiteralValue::NoneVal, LiteralValue::NoneVal];

fn throw_error(message: &str, index: i32) {
    // TODO: Throw an actual error, ey?
    println!("{} at character {}", message, index);
}

// TODO: Create binary expression
fn is_decimal_digit(ch: char) -> bool {
    return ch >= '0' && ch <= '9';
}

fn is_identifier_start(ch: char) -> bool {
    return ch == '$' || ch == '_' || 
    (ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z');
    // Jsep also supports any non-ascii char that's not an operator
    // We'll exclude that since names are separate from IDs
}

fn is_identifier_part(ch: char) -> bool {
    // Any ascii character and can contain numbers within.
    return is_identifier_start(ch) || is_decimal_digit(ch);
}

fn gobble_spaces(expr: &Vec<char>, start: usize) -> usize {
    let mut index = start;
    let len = expr.len();
    while index < len && expr[index].is_whitespace() {
        index+=1;
    }
    return index;
}

fn gobble_token(expr: &Vec<char>, start: usize) -> (&str, usize) {
    let mut index = gobble_spaces(expr, start);
    let ch: char = expr[index];
    if is_decimal_digit(ch) || ch == PERIOD_CODE {
        return gobble_numeric_literal(expr, index);
    }
    return ("", start); // TODO
}

fn gobble_digits_helper(expr: &Vec<char>, start: usize) -> (Vec<char>, usize) {
    let mut index = start;
    let mut number: Vec<char> = vec![];
    let length = expr.len();
    if index >= length {
        return (number, length);
    }

    let mut ch = expr[index];
    while is_decimal_digit(ch) {
        number.push(ch);
        index+=1;
        if index >= length {
            return (number, length);
        }
        ch = expr[index];
    }

    return (number, index);
}

// Kind of a very special-case char at, because it will return
// Empty space if you go out of range. Which differs from jsep, which 
// can return empty string. Use carefully (i.e. only in comparison against other non space values)
fn char_at_helper(expr: &Vec<char>, index: usize) -> char {
    if index < expr.len() {
        return expr[index];
    }
    return ' ';
}

fn gobble_numeric_literal(expr: &Vec<char>, start: usize) -> (&str, usize) {
    let mut number: Vec<char> = vec![];
    let mut index = start;
    let length = expr.len();
    
    let (digit, i) = gobble_digits_helper(expr, index);
    number.extend(digit);
    index = i;
    let mut ch = char_at_helper(expr, index);

    if(ch == '.') {
        number.push(ch);
        index += 1;
        let (digit, i) = gobble_digits_helper(expr, index);
        number.extend(digit);
        index = i;
        ch = char_at_helper(expr, index);
    }

    if(ch == 'e' || ch == 'E') { // Exponent marker
        number.push(ch);
        index += 1;
        ch = char_at_helper(expr, index);
        if(ch == '+' || ch == '-') { // Exponent sign
            number.push(ch);
            index += 1;
        }
        // Exponent
        let (digit, i) = gobble_digits_helper(expr, index);
        number.extend(digit);
        index = i;
        if(!is_decimal_digit(char_at_helper(expr, index-1))){
            // TODO validate
            // throw_error( &["Expected exponent (", number.iter().collect(), char_at_helper(expr, index), ")"].concat(), index)
            let num: String = number.iter().collect();
            println!("Expected exponent ({}{}) at {}", num, char_at_helper(expr, index), index);
            // TODO - raise error in this case?
        }
    }


    return ("", start); // TODO
}

fn gobble_binary_op(expr: &Vec<char>, start: usize) -> (&str, usize) {
    let mut index = gobble_spaces(expr, start);


    // Return operator (or empty string) and continue index.
    return ("", start); // TODO
}

fn gobble_binary_expression(expr: &Vec<char>, start: usize) -> usize {
    return 0; // TODO
}

fn parse(expr: &str) {
    let mut index = 0;
    // Char-at isn't constant time due to utf, so do an upfront conversion
    let expr_vector: Vec<char> = expr.chars().collect();
    let index = gobble_spaces(&expr_vector, 0);
    println!("Result index {}", index)
}

fn main() {
    println!("hey");
    // parse("   1 + 2");
    // let pie: f64 = " 3.14E-2".parse().unwrap();
    // println!("{}", pie);


}
