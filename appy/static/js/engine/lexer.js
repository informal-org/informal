import { Queue } from "../utils"
import { LiteralNode, IdentifierNode, OperatorNode, KEYWORD_TABLE, syntaxError } from "./parser"

const DELIMITERS = new Set(['(', ')', '[', ']', 
// '{', '}', 
'"', "'", 
'.', ',', ':', 
// ';', 
'+', '-', '*', '/', '%',
' ', '\t', '\n']);

// TODO: Better error messages
const ERR_INVALID_FLOAT = "Invalid floating point number format.";
const ERR_UNTERM_STR = "Could not find the ending quotes for this String.";
const ERR_INVALID_NUMBER = "Invalid number";
const ERR_UNMATCHED_PARENS = "Unmatched parentheses";

class LexIterator {
    constructor(expr) {
        this.expr = expr;
        this.index = 0;
        this.indentation = 0;
    }
    peek() {
        return this.index < this.expr.length ? this.expr[this.index] : ""
    }
    lookahead(n) {
        let combined = ""
        for(var i = this.index; i < this.index + n; i++) {
            if(i < this.expr.length) {
                combined += this.expr[i]
            }
        }
        return combined
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

function parseNumber(it) {   
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
    let char_end = it.index;
    return LiteralNode(val, char_start, char_end);
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
    return LiteralNode(token, char_start, char_end)
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
    if(!(token in KEYWORD_TABLE)) {
        return IdentifierNode(token, char_start, char_end)
    }
    
}

function parseWhitespace(it) {
    // TODO: Convert indentation level into meaningful token
    // Currently just skip whitespace.
    it.next();
    return undefined
}

export function lex(expr) {
    // Index - shared mutable closure var
    let it = new LexIterator(expr);
    let tokens = new Queue();

    // Match against the starting value of each type of token
    while(it.hasNext()) {
        let ch = it.peek();
        let token;

        if(isWhitespace(ch)) {
            // Some whitespace is meaningful when changing indentation level.
            token = parseWhitespace(it);
        } else if(isDigit(ch) || ch == '.'){
            token = parseNumber(it, false)
        }
        // else if(ch == '-') {
        //     it.next();            // Gobble the '-'
        //     // Differentiate subtraction and unary minus
        //     // If prev token's a number, this is an operation. Else unary.
        //     if(tokens.length > 0 && isNumber(tokens.tail.value.value)) {
        //         token = new Token("-", TOKEN_OPERATOR, it.index, it.index)
        //     } else {
        //         token = parseNumber(it, true)
        //     }
        // } 
        else if (ch == '"' || ch == "'") {
            token = parseString(it)
        } else if (isDelimiter(ch)) {
            // Treat ch like a prefix and greedily consume the best operator match
            it.next();
            let ch_2 = ch + it.lookahead(2);    // Get operators like ...
            let ch_1 = ch + it.lookahead(1)     // Get operators like ++
            let ch_0 = ch;
            if(ch_2 in KEYWORD_TABLE) {
                token = OperatorNode(KEYWORD_TABLE[ch_2], it.index, it.index)
                it.next();
                it.next();
            } else if(ch_1 in KEYWORD_TABLE) {
                token = OperatorNode(KEYWORD_TABLE[ch_1], it.index, it.index)
                it.next();
            } else if(ch_0 in KEYWORD_TABLE) {
                token = OperatorNode(KEYWORD_TABLE[ch_0], it.index, it.index)
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
