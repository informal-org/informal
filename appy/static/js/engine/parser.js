import { Node, Queue, QIter, isNumber } from "../utils"

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

const UNARY_OPS = {
    "not": 5
}

const LITERALS = {
    "true": true,
    "false": false,
    "none": null
}

const BINARY_OPS = {
//    "=": 2,
    "or": 3,
    "and": 4,
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
}

const SYNTAX_TOKENS = {
    ",": 1, 
    '.': 25,
    "(": 30,
    ")": 30,
}

const KEYWORD_TABLE = {}


export const TOKEN_LITERAL = 1;
export const TOKEN_IDENTIFIER = 3;
export const TOKEN_OPERATOR = 4;    // syntax tokens like , ( and operators +


class Keyword {
    constructor(keyword_id, left_binding_power=0) {
        this.keyword = keyword_id
        this.left_binding_power = left_binding_power
        KEYWORD_TABLE[keyword_id] = this
    }
    // static getOrCreate(keyword_id, left_binding_power=0) {
    //     // getOrCreate a keyword, setting it to the max binding power
    //     // Binding power = power of element to bind to left element
    //     let keyword = KEYWORD_TABLE[keyword_id];
    //     if(keyword) {
    //         keyword.left_binding_power = Math.max(left_binding_power, keyword.left_binding_power)
    //     } else {
    //         // Dynamically construct a Keyword or an inherited instance
    //         keyword = new this.constructor(keyword_id, left_binding_power)
    //     }
    // }
    null_denotation(node, token_stream) { console.log("Null denotation not found"); }
    left_denotation(left, node, token_stream) { console.log("Left denotation not found"); }
}

class Constant extends Keyword {
    constructor(keyword_id, value) {
        super(keyword_id, 0)
        this.value = value
    }
    null_denotation(node, token_stream) {
        node.node_type = "literal"
        node.value = this.value
        return node;
    }
}

class Prefix extends Keyword {
    constructor(keyword_id, left_binding_power, null_denotation=null) {
        super(keyword_id, left_binding_power)
        if(null_denotation) {
            this.null_denotation = null_denotation
        }
    }
    null_denotation(node, token_stream) {
        node.left = expression(token_stream, 100);
        node.node_type = "unary"
        return node;
    }
}

class Infix extends Keyword {
    constructor(keyword_id, left_binding_power, left_denotation=null) {
        super(keyword_id, left_binding_power)
        if(left_denotation) {
            this.left_denotation = left_denotation
        }
    }
    left_denotation(left, node, token_stream) {
        node.node_type = "binary"
        node.left = left;
        node.right = expression(token_stream, this.left_binding_power)
        return node;
    }
}

// Infix with right associativity, like =
class InfixRight extends Infix {
    left_denotation(left, node, token_stream) {
        node.node_type = "binary"
        node.left = left;
        node.right = expression(token_stream, this.left_binding_power - 1)
        return node;
    }
}


function repeatString(count, str=" "){
    let s = "";
    while(count > 0) {
        s += str
        count--;
    }
    return s;
}


class ASTNode {
    constructor(operation, value, node_type, char_start, char_end) {
        this.operation = operation
        this.value = value
        this.node_type = node_type
        this.char_start = char_start
        this.char_end = char_end
        this.left = null;
        this.right = null;
    }
    static OperatorNode(operation, char_start, char_end) {
        return new ASTNode(operation, null, TOKEN_OPERATOR, char_start, char_end)
    }
    static IdentifierNode(value, char_start, char_end) {
        return new ASTNode(ID_OP, value, TOKEN_IDENTIFIER, char_start, char_end)
    }
    static LiteralNode(value, char_start, char_end) {
        return new ASTNode(ID_OP, value, TOKEN_LITERAL, char_start, char_end)
    }
    toString() {
        // pre-order
        let string = "";
        if(this.left){
            string += this.left.toString()
        }

        string += "\n"
        if(this.value != null) {
            string += this.value;
        } else {
            string += this.operation.keyword
        }
        string += "\n"
        
        if(this.right) {
            string += this.right.toString();
        }
        return string;
    }
}

const OperatorNode = ASTNode.OperatorNode;
const IdentifierNode = ASTNode.IdentifierNode;
const LiteralNode = ASTNode.LiteralNode;

// 3 types of tokens
// Literals - some actual value - 1.0, "hello"
// Identifiers - a reference to some identity
// Keywords - some operation.
// Literals and identifiers form leafs while keywords form ast nodes.
// Regardless of type, they all must keep track of their context.

new Keyword(":")
new Keyword(")")
new Keyword("]")
new Keyword(",")

const ID_OP = new Keyword("")

new Constant("true", true)
new Constant("false", false)
new Constant("none", null)


new InfixRight("and", 30)       // TODO: Left or right associative?
new InfixRight("or", 30)
new InfixRight("==", 40)
new InfixRight("<=", 40)
new InfixRight(">", 40)
new InfixRight(">=", 40)

new Infix("+", 50)
new Infix("-", 50)

new Infix("*", 60)
new Infix("/", 60)


// TODO - Infix version
new Prefix("(", (node, token_stream) => {
    var e = expression(token_stream, 0);
    node.advance(")")
    return e;
})


export const NODE_LITERAL = 1;      // 1, "hello"
export const NODE_IDENTIFIER = 2;   // x
export const NODE_MEMBER = 3;       // x.y
export const NODE_COMPOUND = 4;     // a, b
export const NODE_THIS = 5;         // this
export const NODE_CALL = 6;         // f(x)
export const NODE_UNARY = 7;        // not x
export const NODE_BINARY = 8;       // 1 + 2
// export const NODE_LOGICAL = 9;      // a or b
// export const NODE_CONDITIONAL = 10; //
export const NODE_ARR = 11;         // 


export const START_GROUP = '(';  // Equivalent of (
export const END_GROUP = ')';    // Equivalent of )
export const SEPARATOR = ',';    // Equivalent of ,

export const BUILTIN_LITERALS = new Set(["true", "false", "none"])


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

class ParseIterator extends QIter {
    constructor(queue) {
        super(queue)
    }
    advance(token) {
        // Advance until you find the given token
        if(token && this.current() && this.current().operator.value != token) {
            syntaxError("Expected token '" + token + "' not found.")
        }
        return this.next()
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
    if(token in KEYWORD_TABLE) {
        return OperatorNode(KEYWORD_TABLE[token], char_start, char_end)
    } else {
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
            } else if(ch_1 in KEYWORD_TABLE) {
                token = OperatorNode(KEYWORD_TABLE[ch_1], it.index, it.index)
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

export function expression(tokenStream, right_binding_power) {
    let token = tokenStream.next();
    console.log("Token stream after: " + tokenStream)


    // console.log("Expression: Power " + token.operation.left_binding_power + " min(" + right_binding_power +")");
    // console.log(token);

    let left = token.operation.null_denotation(token, tokenStream);

    while(tokenStream.hasNext() && right_binding_power < token.operation.left_binding_power) {
        token = tokenStream.next();
        left = token.operation.left_denotation(left, token, tokenStream);
    }

    return left;
}

export function parse(tokenQueue) {
    let tokenStream = new ParseIterator(tokenQueue);
    return expression(tokenStream, 0)
}

 

// Expr starts with an identifier usually
// One of:
    // : - definition
    // []: Indexing/filtering
    // (optional) , next identifier : value

// definition
    // Literal
    // Binary expression (and, or, +, -, etc.)
    // Array literal []
    // new sub block

// Within a block
// <optional> identifier <optional> ( input , args = value ) <optional> [guard] :
    // Atleast one of the optional ones have to be present
// inline or new block of expressions (atleast one)



// https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
