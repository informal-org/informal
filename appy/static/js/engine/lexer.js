import { Queue } from "../utils"
import { 
    LiteralNode, IdentifierNode, OperatorNode, 
    KEYWORD_TABLE, syntaxError,
    CONTINUE_BLOCK, START_BLOCK, END_BLOCK
} from "./parser"

const DELIMITERS = new Set(['(', ')', '[', ']', 
// '{', '}', 
'"', "'", 
'.', ',', ':', 
// ';', 
'+', '-', '*', '/', '%',
'<', '>', '=', '!',
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
        // Store number of spaces at each active indentation level
        this.block_levels = [];
        this.tokens = new Queue();
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

    currentBlock() {
        return this.block_levels.length > 0 ? this.block_levels[this.block_levels.length - 1] : 0
    }

    startBlock(level, char_start) {
        this.block_levels.push(level)
        this.tokens.push(new OperatorNode(START_BLOCK, char_start, this.index))
    }

    continueBlock(char_start) {
        this.tokens.push(new OperatorNode(CONTINUE_BLOCK, char_start, this.index))
    }

    endBlock(level, char_start) {
        // May end multiple blocks in one go
        while(level < this.currentBlock()) {
            this.block_levels.pop();
            this.tokens.push(new OperatorNode(END_BLOCK, char_start, this.index));
        }

        if(this.block_levels.length > 0 && level != this.currentBlock()) {
            syntaxError("Error: Indentation level doesn't match any previous code blocks.")
        }

        return this.currentBlock();
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
    let num_str = it.expr.slice(char_start, char_end)
    if(num_str === '.') {
        return OperatorNode(KEYWORD_TABLE['.'], char_start, char_end)
    } else {
        return LiteralNode(parseFloat(num_str), char_start, char_end);
    }
    
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
    let char_start = it.index + 1;
    let kw = it.lookahead(length);
    if(kw.length == length && kw in KEYWORD_TABLE) {
        it.next(length)
        return OperatorNode(KEYWORD_TABLE[kw], char_start, it.index)
    }
}

function parseWhitespace(it) {
    // Currently just skip whitespace.
    // TODO: /r/n on windows?
    let char_start = it.index;

    if(it.peek() == '\n' && it.tokens.length > 0) {
        it.next();
        let space_count = 0;
        
        // Count the number of leading spaces
        while(true) {
            if(it.peek() == ' ') {
                space_count += 1;
                it.next();
            } else if(it.peek() == '\t') {
                space_count += 4
                it.next();
            } else {
                break;
            }
        }

        // let indentation_level = Math.ceil(space_count / 4.0);
        let running_lvl = it.currentBlock();
        if(space_count > running_lvl) {
            // Start of a new block
            it.startBlock(space_count, char_start);
        } else if(space_count == running_lvl) {
            // Continuation of the existing block
            it.continueBlock(char_start)
        } else if(space_count < running_lvl) {
            // Rewind stack, closing valid blocks. 
            // Syntax error if it doesn't match a previous indentation level.
            it.endBlock(space_count, char_start);
        }

    } else {
        // Leading whitespace before any tokens or
        // Whitespace in the middle of a line is meaningless
        it.next();
    }
    
    return undefined
}

export function lex(expr) {
    // Index - shared mutable closure var
    let it = new LexIterator(expr);

    // Match against the starting value of each type of token
    while(it.hasNext()) {
        let ch = it.peek();
        let token;

        if(isWhitespace(ch)) {  // Some whitespace is meaningful when changing indentation level.
            // Indentation tokens are added directly if valid
            parseWhitespace(it);
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
            it.tokens.push(token)
        }
    }

    // End all active blocks
    it.endBlock(0, it.index)

    return it.tokens
}
