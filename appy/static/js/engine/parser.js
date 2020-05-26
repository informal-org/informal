import { isNumber } from "../utils"

const DELIMITERS = Set(['(', ')', '[', ']', '{', '}', '"', "'", 
'.', ',', ':', ';', 
'+', '-', '*', '/', '%',
' ', '\t', '\n']);


// TODO: Better error messages
const ERR_INVALID_FLOAT = "Invalid floating point number format."
const ERR_UNTERM_STR = "Could not find the ending quotes for this String."
const ERR_INVALID_NUMBER = "Invalid number"

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

const TOKEN_LITERAL = 1;
const TOKEN_START_GROUP = 2;
const TOKEN_END_GROUP = 3;
const TOKEN_IDENTIFIER = 4;
const TOKEN_OPERATOR = 5;


const BUILTIN_LITERALS = new Set(["true", "false", "none"])

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
        return this.expr[++this.index]
    }
    hasNext() {
        return this.index < this.expr.length
    }
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
    let token = "";
   
    // Leading decimal digits
    token = gobbleDigits(it);

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
        if(i < expr.length) {
            let power = gobbleDigits(it);
            if(power === "") {
                syntaxError(ERR_INVALID_FLOAT, it.index)
            }
            token += power;
        } else {
            syntaxError(ERR_INVALID_FLOAT, it.index)
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
    return val;
}

function parseString(it) {
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

    return token;
}

function parseIdentifier(it) {
    let token = "";
    while(it.hasNext()) {
        if(isDelimiter(it.peek())) {
            break;
        } else {
            token += it.next();
        }
    }
    // assert: token != "" since caller checks if is delimiter
    return token;
}

function parseWhitespace(it) {
    // TODO: Convert indentation level into meaningful token
    // Currently just skip whitespace.
    it.next();
    return undefined
}

function isWhitespace(ch) {
    return ch === ' ' || ch === '\t' || ch === '\n'
}

function lex(expr){
    // Index - shared mutable closure var
    let it = ExprIterator(expr);
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
            // Differentiate subtraction and unary minus
            // If prev token's a number, this is an operation. Else unary.
            if(tokens.length > 0 && isNumber(tokens[tokens.length -1])) {
                // if the previous character was a number, this is an operator
                token = parseNumber(it, true)
            } else {
                token = "-"
            }
        } else if (ch == '"' || ch == "'") {
            token = parseString(it)
        } else if (isDelimiter(ch)) {
            token = ch
        } else {
            token = parseIdentifier(it);
        }

        // Note: Token may be a parsed empty string or zero, but never ""
        if(token !== undefined) {
            tokens.push(token)
        }
    }

    return tokens
}

