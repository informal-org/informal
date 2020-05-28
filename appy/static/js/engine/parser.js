import { isNumber } from "../utils"
import { Node } from "../utils/Node"

const DELIMITERS = new Set(['(', ')', '[', ']', '{', '}', '"', "'", 
'.', ',', ':', ';', 
'+', '-', '*', '/', '%',
' ', '\t', '\n']);

// TODO: Better error messages
const ERR_INVALID_FLOAT = "Invalid floating point number format.";
const ERR_UNTERM_STR = "Could not find the ending quotes for this String.";
const ERR_INVALID_NUMBER = "Invalid number";
const ERR_UNMATCHED_PARENS = "Unmatched parentheses";

const BINARY_OPS = {
    ",": 1,
//    "=": 2,
    "or": 3,
    "and": 4,
    "not": 5,
    "==": 10,
    "!=": 10,
    "<": 15,
    ">": 15,
    "<=": 15,
    ">=": 15,
    "+": 20,
    "-": 20,
    "*": 21,
    "/": 21,
    "%": 21,
    ".": 25,
    "(": 30,
    ")": 30,
}


class Token {
    constructor(value, token_type, char_start, char_end) {
        this.value = value
        this.token_type = token_type
        this.char_start = char_start
        this.char_end = char_end
    }
}

class ASTNode extends Node {
    constructor(value, left, right, node_type) {
        super(value, left, right)
        this.node_type = node_type;
    }
}

export const TOKEN_LITERAL = 1;
export const TOKEN_DELIMITER = 2;
export const TOKEN_IDENTIFIER = 3;
export const TOKEN_OPERATOR = 4;

export const NODE_LITERAL = 1;      // 1, "hello"
export const NODE_IDENTIFIER = 2;   // x
export const NODE_MEMBER = 3;       // x.y
export const NODE_COMPOUND = 4;     // a, b
export const NODE_THIS = 5;         // this
export const NODE_CALL = 6;         // f(x)
export const NODE_UNARY = 7;        // not x
export const NODE_BINARY = 8;       // 1 + 2
export const NODE_LOGICAL = 9;      // a or b
export const NODE_CONDITIONAL = 10; //
export const NODE_ARR = 11;         // 


// Meaningful whitespace tokens.
export const START_GROUP = '(';  // Equivalent of (
export const END_GROUP = ')';    // Equivalent of )
export const SEPARATOR = ',';    // Equivalent of ,

export const BUILTIN_LITERALS = new Set(["true", "false", "none"])


class ExprIterator {
    constructor(expr) {
        this.expr = expr;
        this.index = 0;
        this.indentation = 0;
    }
    peek() {
        return this.index < this.expr.length ? this.expr[this.index] : ""
    }
    next() {
        return this.expr[this.index++]
    }
    hasNext() {
        return this.index < this.expr.length
    }
}

function isWhitespace(ch) {
    return ch === ' ' || ch === '\t' || ch === '\n'
}

function isDigit(ch) {
    return ch >= '0' && ch <= '9'
}

function isDelimiter(ch) {
    return DELIMITERS.has(ch)
}

function syntaxError(message, index) {
    let err = new Error(message);
    err.index = index;
    throw err
}

function gobbleDigits(it) {
    let token = "";
    while(it.hasNext()) {
        if(isDigit(it.peek())) {
            token += it.next()
        } else {
            break;
        }
    }
    return token;
}

function parseNumber(it, negative=false) {   
    let char_start = it.index;
    // Leading decimal digits
    let token = gobbleDigits(it);
   
    // (Optional) decimal
    if(it.peek() == '.') {
        token += it.next()

        // (Optional) decimal digits
        token += gobbleDigits(it)
    }

    // (Optional) Exponent
    let exponent = it.peek()
    if(exponent === 'e' || exponent == 'E') {
        token += it.next()

        // (Optional) sign
        let exp_sign = it.peek();
        if(exp_sign === '+' || exp_sign === '-') {
            token += it.next()
        }

        // (Required) exponent power
        let power = gobbleDigits(it);
        if(power === "") {
            syntaxError(ERR_INVALID_FLOAT, it.index)
        } else {
            token += power;
        }
    }

    // If a number wasn't found where expected, raise error
    if(token == "") {
        syntaxError(ERR_INVALID_NUMBER, it.index)
    }

    let val = parseFloat(token);
    if(negative) {
        val = -1.0 * val;
    }
    let char_end = it.index;
    return new Token(val, TOKEN_LITERAL, char_start, char_end);
}

function parseString(it) {
    let char_start = it.index;
    let token = "";
    // Find which quote variation it is. Omit quotes from the resulting string.
    let quote_start = it.next();
    let terminated = false;

    while(it.hasNext()) {
        let ch = it.next();
        if(ch == '\\') {
            // Backslash escape
            if(it.hasNext()) {
                let escapedChar = it.next();
                switch(escapedChar) {
                    case '\\':
                    case '\'':
                    case '\"':
                        token += escapedChar
                        break;
                    case 'n': token += '\n'; break;
                    case 'r': token += '\r'; break;
                    case 't': token += '\t'; break;
                    default: token += '\\'; token += escapedChar;
                }
            }
        } else if (ch == quote_start) {
            // Omit quotes from resulting string
            terminated = true;
            break;
        } else {
            token += ch;
        }
    }

    if(!terminated) {
        syntaxError(ERR_UNTERM_STR, it.index)
    }

    let char_end = it.index;
    return new Token(token, TOKEN_LITERAL, char_start, char_end)
}

function parseSymbol(it) {
    let char_start = it.index;
    let token = "";
    
    while(it.hasNext()) {
        if(isDelimiter(it.peek())) {
            break;
        } else {
            token += it.next();
        }
    }

    let char_end = it.index;
    // assert: token != "" since caller checks if is delimiter
    if(token in BINARY_OPS) {
        return new Token(token, TOKEN_OPERATOR, char_start, char_end)
    } else if(token in BUILTIN_LITERALS) {
        return new Token(token, TOKEN_LITERAL, char_start, char_end)
    } else {
        return new Token(token, TOKEN_IDENTIFIER, char_start, char_end)
    }
    
}

function parseWhitespace(it) {
    // TODO: Convert indentation level into meaningful token
    // Currently just skip whitespace.
    it.next();
    return undefined
}

export function lex(expr){
    // Index - shared mutable closure var
    let it = new ExprIterator(expr);
    let tokens = [];

    // Match against the starting value of each type of token
    while(it.hasNext()) {
        let ch = it.peek();
        var token;

        if(isWhitespace(ch)) {
            // Some whitespace is meaningful when changing indentation level.
            token = parseWhitespace(it);
        } else if(isDigit(ch) || ch == '.'){
            token = parseNumber(it, false)
        } else if(ch == '-') {
            it.next();            // Gobble the '-'
            // Differentiate subtraction and unary minus
            // If prev token's a number, this is an operation. Else unary.
            if(tokens.length > 0 && isNumber(tokens[tokens.length - 1].value)) {
                token = new Token("-", TOKEN_OPERATOR, it.index, it.index)
            } else {
                token = parseNumber(it, true)
            }
        } else if (ch == '"' || ch == "'") {
            token = parseString(it)
        } else if (isDelimiter(ch)) {
            it.next();
            if(ch in BINARY_OPS) {
                token = new Token(ch, TOKEN_OPERATOR, it.index, it.index)
            } else {
                token = new Token(ch, TOKEN_DELIMITER, it.index, it.index)
            }
            
        } else {
            // keywords, operations and identifiers
            token = parseSymbol(it);
        }

        // Note: Token may be a parsed empty string or zero, but never ""
        if(token !== undefined) {
            tokens.push(token)
        }
    }

    return tokens
}

function getOperatorPrecedence(token) {
    return token in BINARY_OPS ? BINARY_OPS[token] : 255
}

export function applyOperatorPrecedence(tokens) {
    // Convert an infix expression to a prefix expression
    // Implemented using shunting yard for operator precedence
    let postfix = [];
    let operator_stack = [];
    let depends_on = [];
    // keep track of which grouping construct
    let grouping_stack = [];

    tokens.forEach((ti) => {
        let [token, type] = ti;
        if(type == TOKEN_LITERAL) {
            postfix.push(token)
        } else {
            if(token == START_GROUP) {
                operator_stack.push(token);
            } else if(token == SEPARATOR) {
                // Denotes end of one sub-expression. Flush
                // i.e. min(1 * 2, 2 + 2). a: 1, b: 2
                while(operator_stack.length > 0) {
                    let op = operator_stack[operator_stack.length - 1];
                    if(op == SEPARATOR) {
                        operator_stack.pop();
                    } else if(op == START_GROUP) {
                        break;
                    } else {
                        postfix.push(operator_stack.pop())
                    }
                }
            } else if(token == END_GROUP) {
                console.log("end param")
                // Pop until you find the matching opening parens
                let found = false;
                while(operator_stack.length > 0) {
                    let op = operator_stack.pop();
                    if(op == START_GROUP) {
                        found = true;
                        break;
                    } else {
                        postfix.push(op)
                    }
                }
                if(!found) {
                    // TODO: Line number?
                    syntaxError(ERR_UNMATCHED_PARENS, -1)
                }

                // TODO: Check for function call
            } else {
                let token_precedence = getOperatorPrecedence(token);
                while(operator_stack.length > 0) {
                    let op = operator_stack[operator_stack.length - 1];

                    if(op == START_GROUP) {
                        break;
                    }

                    let op_precedence = getOperatorPrecedence(op);
                    // Output higher-precedence operators
                    if(op_precedence >= token_precedence) {
                        op = operator_stack.pop();  // Same val as before

                        // todo: dependency check

                        postfix.push(op);
                    } else {
                        break;
                    }
                }

                // At this point, all operators with higher precedence have been flushed.
                operator_stack.push(token);
            }
        }
    })


    // Flush all remaining operators onto the postfix output
    // Reverse so we get items in the stack order.
    operator_stack.reverse()
    operator_stack.forEach((op) => {
        if(op == START_GROUP) {
            syntaxError(ERR_UNMATCHED_PARENS)
        }
        postfix.push(op)
        // TODO: dependency check
    })

    return postfix
}

export function parse(tokenQueue) {
    let tokenStack = tokenQueue;
    tokenStack.reverse();

    let [token, token_type] = tokens.pop();
    if(token_type == TOKEN_LITERAL) {
        leftNode = Node(LITERAL_NODE)

    }
}