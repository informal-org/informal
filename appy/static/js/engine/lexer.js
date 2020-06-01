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
    peek(n=0) {
        // assert: n is a positive number of indexes to peek. n = length when index + length < expr.length
        return this.index + n < this.expr.length ? this.expr[this.index + n] : ""
    }
    lookahead(n=1) {
        // Look ahead to the next n characters and return that slice
        return this.expr.slice(this.index, this.index + n)
    }
    next(n=1) {
        // assert: Caller ensures N + length won't pass expr.length
        this.index += n
        return this.expr[this.index - 1]
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
    let char_start = it.index, char_end = it.index;
    let dot_found = false, exp_found = false, sign_found = false;
    
    // Iterate over chars and stop when you find a char that doesn't belong in the number
    while(char_end < it.expr.length) {
        let ch = it.expr[char_end++];
        if(isDigit(ch)) {   continue;   }
        if(ch === '.' && !dot_found) {
            dot_found = true;
            continue;
        }
        if((ch === 'e' || ch === 'E') && !exp_found) {
            exp_found = true;
            continue
        }
        if((ch === '+' || ch === '-') && !sign_found) {    // Exponent power sign
            sign_found = true;
            continue
        }
        char_end--;
        break;
    }
    it.index = char_end;
    return LiteralNode(parseFloat(it.expr.slice(char_start, char_end)), char_start, char_end);
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

    return LiteralNode(token, char_start, it.index)
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

    // assert: token != "" since caller checks if is delimiter
    if(token in KEYWORD_TABLE) {
        return OperatorNode(KEYWORD_TABLE[token], char_start, it.index)
    } else {
        return IdentifierNode(token, char_start, it.index)
    }
}

function parseKeyword(it, length) {
    let char_start = it.length;
    let kw = it.lookahead(length);
    if(kw.length == length && kw in KEYWORD_TABLE) {
        it.next(length)
        return OperatorNode(KEYWORD_TABLE[kw], char_start, it.index)
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

        if(isWhitespace(ch)) {  // Some whitespace is meaningful when changing indentation level.
            token = parseWhitespace(it);
        } else if(isDigit(ch) || ch == '.') {   // + or - will be handled by parser as unary ops
            token = parseNumber(it, false)
        }
        else if (ch == '"' || ch == "'") {
            token = parseString(it)
        } else if (isDelimiter(ch)) {
            // Treat ch like a prefix and greedily consume the best operator match
            // assert: All delimiters are prefix of some keyword. Else, iter won't move
            token = parseKeyword(it, 3);
            token = token ? token : parseKeyword(it, 2)
            token = token ? token : parseKeyword(it, 1)
            if(!token) {
                it.next();
            }
        } else {
            token = parseSymbol(it);    // identifiers
        }

        // Note: Token may be a parsed empty string or zero, but never ""
        if(token !== undefined) {
            tokens.push(token)
        }
    }

    return tokens
}
