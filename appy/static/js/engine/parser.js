const DELIMITERS = Set(['(', ')', '[', ']', '{', '}', '"', "'", 
'.', ',', ':', ';', 
'+', '-', '*', '/', '%',
' ', '\t', '\n']);

const ERR_INVALID_FLOAT = "Invalid floating point number format."
const ERR_UNTERM_STR = "Could not find the ending quotes for this String."

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
                syntaxError(ERR_INVALID_FLOAT, i)
            }
            token += power;
        } else {
            syntaxError(ERR_INVALID_FLOAT, i)
        }
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
        syntaxError(ERR_UNTERM_STR, i)
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
    return token;
}


// TODO: Better error messages
function parse(expr){
    // Index - shared mutable closure var
    let it = ExprIterator(expr);




}