import { QIter } from "../utils"
import { lex } from "./lexer"

/*
Implements a Pratt parser to construct the AST with precedence climbing.
References:
https://crockford.com/javascript/tdop/tdop.html
https://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing
http://effbot.org/zone/simple-top-down-parsing.htm

"What do we expect to see to the left of the token?"
*/

export const KEYWORD_TABLE = {}
export const TOKEN_LITERAL = "(literal)";               // 1, "str", true, null
export const TOKEN_IDENTIFIER = "(identifier)";         // x
export const TOKEN_OPERATOR = "(operator)";             // and, or, not, +
export const TOKEN_START_BLOCK = "(startblock)";        // Increase indentation level
export const TOKEN_CONTINUE_BLOCK = "(continueblock)";  // Same indentation level
export const TOKEN_END_BLOCK = "(endblock)";            // Decrease indentation level
export const TOKEN_WHERE = "(where)";       // a[]
export const TOKEN_ARRAY = "(array)";       // [1, 2, 3]
export const TOKEN_GROUPING = "(grouping)"
export const TOKEN_COND = "(if)";           // if x < 10:
export const TOKEN_ELSE = "(else)";
export const TOKEN_THEN = "(then)";
export const TOKEN_DEFAULT = "(default)";

class ParseIterator extends QIter {
    constructor(queue) {
        super(queue)
    }
    advance(expecting) {
        // Advance until you find the given token
        if(expecting && this.current() && this.current().operator.keyword !== expecting) {
            syntaxError("Expected token '" + expecting + "' not found. Found " + this.current().operator.keyword)
        }
        return this.hasNext() ? this.next() : new ASTNode(END_OP, null, TOKEN_OPERATOR, -1, -1)
    }
    currentKeyword() {
        return this.current().operator.keyword
    }
    currentBindingPower() {
        return this.current().operator.left_binding_power
    }
}

class Keyword {
    constructor(keyword_id, left_binding_power=0) {
        this.keyword = keyword_id
        this.left_binding_power = left_binding_power
        this.value = null
        KEYWORD_TABLE[keyword_id] = this
    }
    null_denotation(node, token_stream) { console.log("Null denotation not found for: " + this.keyword); }
    left_denotation(left, node, token_stream) { console.log("Left denotation not found: " + this.keyword); }
}

class Literal extends Keyword {
    constructor(keyword_id, value) {
        super(keyword_id, 0)
        this.value = value;
    }
    null_denotation(node, token_stream) {
        node.node_type = TOKEN_LITERAL
        return node;
    }
}

class Identifier extends Keyword {
    constructor(keyword_id) {
        super(keyword_id ,0)
    }
    null_denotation(node, tokenStream) {
        node.node_type = TOKEN_IDENTIFIER
        return node;
    }
}

class Prefix extends Keyword {
    constructor(keyword_id, left_binding_power, null_denotation=null) {
        super(keyword_id, left_binding_power)
        this.null_denotation = null_denotation ? null_denotation : Prefix.get_null_denotation()
    }
    static get_null_denotation(node_type="unary") {
        return (node, token_stream) => {
            node.left = expression(token_stream, 100);
            node.node_type = node_type
            return node;
        }
    }
}

class Infix extends Keyword {
    constructor(keyword_id, left_binding_power, left_denotation=null, node_type="binary") {
        super(keyword_id, left_binding_power)
        this.node_type = node_type
        this.left_denotation = left_denotation ? left_denotation : Infix.get_left_denotation(node_type, left_binding_power)
    }
    static get_left_denotation(node_type, left_binding_power) {
        return (left, node, token_stream) => {
            node.node_type = node_type
            node.left = left
            node.right = expression(token_stream, left_binding_power)
            return node
        }
    }
}

// Infix with right associativity, like =
class InfixRight extends Infix {
    constructor(keyword_id, left_binding_power, left_denotation=null, node_type="binary") {
        super(keyword_id, left_binding_power, left_denotation, node_type)
        if(!left_denotation) {
            // Note the left binding power is reduced for infix right
            this.left_denotation = Infix.get_left_denotation(node_type, left_binding_power - 1)
        }
    }
}

class Mixfix extends Keyword {
    constructor(keyword_id, left_binding_power, null_denotation, left_denotation) {
        super(keyword_id, left_binding_power)
        if(null_denotation) {
            this.null_denotation = null_denotation
        }

        if(left_denotation) {
            this.left_denotation = left_denotation
        }
    }
}


const ID_OP = new Identifier(TOKEN_IDENTIFIER);
const LITERAL_OP = new Literal(TOKEN_LITERAL)

export class ASTNode {
    constructor(operator, value, node_type, char_start, char_end) {
        this.operator = operator
        this.value = value
        this.node_type = node_type
        this.char_start = char_start
        this.char_end = char_end
        this.left = null;
        this.right = null;
        this.data_type = undefined;
        
    }
    static OperatorNode(operator, char_start, char_end) {
        return new ASTNode(operator, operator.value, TOKEN_OPERATOR, char_start, char_end)
    }
    static IdentifierNode(value, char_start, char_end) {
        return new ASTNode(ID_OP, value, TOKEN_IDENTIFIER, char_start, char_end)
    }
    static LiteralNode(value, char_start, char_end) {
        return new ASTNode(LITERAL_OP, value, TOKEN_LITERAL, char_start, char_end)
    }

    // Convert to s-expression for debugging output
    toString() {
        let kw = this.operator.keyword;
        if(kw == TOKEN_IDENTIFIER || kw == TOKEN_LITERAL) { return this.value; }
        else if(kw === '(') { kw = '(grouping)' }

        let repr = `${this.left ? " " + this.left : ""}`;
        if(Array.isArray(this.value)) {
            this.value.forEach((val) => {
                repr += " " + val.toString();
            })
        }
        
        repr += `${this.right ? " " + this.right : ""}`
        
        return `(${kw}${repr})`
    }
}

export const OperatorNode = ASTNode.OperatorNode;
export const IdentifierNode = ASTNode.IdentifierNode;
export const LiteralNode = ASTNode.LiteralNode;

const END_OP = new Keyword("(end)")


new Literal("true", true)
new Literal("false", false)
new Literal("null", null)

new Keyword(")")
new Keyword("]")
new Keyword(",")

export const CONTINUE_BLOCK = new Infix(TOKEN_CONTINUE_BLOCK, 10)  // \n
export const START_BLOCK = new Infix(TOKEN_START_BLOCK, 10)     // Tab +
export const END_BLOCK = new Keyword(TOKEN_END_BLOCK, 10)       // Tab -

START_BLOCK.null_denotation = (node, tokenStream) => {
    node.node_type = "maplist"
    node.value = []

    // assert: Immediate endblock impossible?
    while(tokenStream.hasNext()) {
        let right = expression(tokenStream, 10);
        if(right.node_type == "map") {
            // Merge the map key value into this map list.
            node.value.push(right.value)
        } else {
            console.log("Found unexpected node type in block: " + right.node_type)
            node.value.push(right)
        }
        if(tokenStream.currentKeyword() == "(endblock)") {
            break;
        } else {
            console.log("Absorbing: " + tokenStream.currentKeyword())
            tokenStream.next();
        }
    }
    tokenStream.advance("(endblock)")

    return node;
}

// TODO: Test [(x): x + 1, ..]

function continuation_led(left, node, tokenStream) {
    let right = expression(tokenStream, 10)
    if(left.node_type == "maplist") {
        if(right.node_type != "map") {
            // TODO
            syntaxError("Expected map to the right of a map.")
        }
        // If it's a map, add it onto the list.
        left.value.push(right.value)
    }
    else if(left.node_type == 'map') {
        if(right.node_type != "map") {
            // TODO
            syntaxError("Expected map to the right of a map")
        }

        // Convert the single entity into a list structure
        left.node_type = "maplist"
        left.value = [left.value, right.value]
    } else {
        // TODO
        syntaxError("Unknown token to the left of , " + left)
    }

    return left
}

let COMMA = new Infix(",", 10);
COMMA.left_denotation = continuation_led;

// Treat new lines as comma equivalents. Later on, differentiate comma and ;
CONTINUE_BLOCK.left_denotation = continuation_led;


new Infix(":", 15).left_denotation = (left, node, tokenStream) => {
    node.node_type = "map"
    // Key, value. Store in a list which will be appended upon
    // node.value = [left, expression(tokenStream, 80)]
    node.value = [left, expression(tokenStream, 10)]
    return node
}


const COND = new Mixfix("if", 20, Prefix.get_null_denotation(TOKEN_COND), Infix.get_left_denotation(TOKEN_COND, 20));
COND.null_denotation = (node, token_stream) => {
    console.log("if null denotion");
    node.left = expression(token_stream, 15);
    console.log("Got left")
    console.log(node.left)
    node.node_type = "unary"
    return node;
}
const COND_THEN = new Mixfix("then", 20, Prefix.get_null_denotation(TOKEN_THEN), Infix.get_left_denotation(TOKEN_THEN, 20));
const COND_ELSE = new Mixfix("else", 20, Prefix.get_null_denotation(TOKEN_ELSE), Infix.get_left_denotation(TOKEN_ELSE, 20));
const COND_DEFAULT = new Mixfix("default", 20, Prefix.get_null_denotation(TOKEN_DEFAULT), Infix.get_left_denotation(TOKEN_DEFAULT, 20));


// , 10

// And binds slightly more than or.
new InfixRight("or", 24)
new InfixRight("and", 25)

// Ensure equality checks lower than comparison ops
new InfixRight("==", 30)
new InfixRight("!=", 30)


new InfixRight("<", 40)
new InfixRight(">", 40)
new InfixRight("<=", 40)
new InfixRight(">=", 40)


new Infix("in", 60)


// Prefix: when used as Not
// Infix: "not in" TODO
new Infix("is", 60)     // TODO


// Skip adding a node for unary plus.
new Infix("+", 80).null_denotation = (node, token_stream) => {
    return expression(token_stream, 100)
}
// Support unary minus
new Infix("-", 80).null_denotation = Prefix.get_null_denotation()

new Infix("*", 85)
new Infix("/", 85)
new Infix("%", 85)

// More binding power than multiplication, but less than unary minus (100)
new InfixRight("**", 88)

new Mixfix("not", 110, Prefix.get_null_denotation())  // was 60. Changed to 110



new Infix(".", 150)

const SQ_BK = new Mixfix("[", 150);
// Defining an array
SQ_BK.null_denotation = get_grouping_ned("]", TOKEN_ARRAY);
SQ_BK.left_denotation = get_grouping_led("]", TOKEN_WHERE);

// As indexing
// SQ_BK.left_denotation = (left, node, tokenStream) => {
//     node.left = left;       // Left could be identifier, array, string.
//     node.node_type = TOKEN_WHERE;
    
//     node.right = expression(tokenStream, 0)
//     tokenStream.advance("]")
//     return node;
// }

// Prefix mode - indicates a parenthesized expression group
function get_grouping_ned(end_group, node_type) {
    return (node, tokenStream) => {
        node.node_type = node_type
        node.value = [];

        while(tokenStream.hasNext()){
            if(tokenStream.currentKeyword() == end_group) { break }
            node.value.push(expression(tokenStream, 10));
            if(tokenStream.currentKeyword() == ",") {
                tokenStream.next();
            } else {
                break;
            }
        }

        tokenStream.advance(end_group);
        return node;
    }
}

function get_grouping_led(end_group, node_type) {
    let ned = get_grouping_ned(end_group, node_type);
    return (left, node, tokenStream) => {
        node.left = left;
        return ned(node, tokenStream);
    }
}



new Mixfix("(", 150, get_grouping_ned(")", TOKEN_GROUPING), 
get_grouping_led(")", "apply"));


// (left, node, tokenStream) => {
//     // In infix mode, ( indicates a function call
//     node.left = left;

//     // if(node.left.node_type != TOKEN_IDENTIFIER) {
//     //     console.log(node.left.node_type);
//     //     syntaxError("Error: Could not call " + node.left.operator.value + " as a function.")
//     // }

//     node.node_type = "apply"
//     node.value = [];

//     if(tokenStream.currentKeyword() != ")") {   // f()
//         while(tokenStream.hasNext()) {
//             node.value.push(expression(tokenStream, 10))
//             if(tokenStream.currentKeyword() == ",") {
//                 tokenStream.next();
//             } else {
//                 break;
//             }
//         }
//     }
    
//     tokenStream.advance(")")
//     return node
// })

class SyntaxError extends Error {
    constructor(message) {
        super(message)
        this.name = "SyntaxError"
    }
}

export function syntaxError(message, index) {
    let err = new SyntaxError(message);
    err.index = index;
    throw err
}

export function expression(tokenStream, right_binding_power) {
    let currentNode = tokenStream.next();
    let left = currentNode.operator.null_denotation(currentNode, tokenStream);

    while(right_binding_power < tokenStream.currentBindingPower()) {
        currentNode = tokenStream.next();
        left = currentNode.operator.left_denotation(left, currentNode, tokenStream);
    }

    return left
}

export function parseTokens(tokenQueue) {
    // Add an end element - prevents having to do an tokenStream.hasNext() check 
    // in the expr while loop condition
    tokenQueue.push(new ASTNode(END_OP, null, TOKEN_OPERATOR, -1, -1))
    let tokenStream = new ParseIterator(tokenQueue);
    let parsed = expression(tokenStream, 0)


    if(tokenStream.hasNext()) {
        // TODO
        syntaxError("Could not complete parsing. Unexpected token at: " + tokenStream.current().char_end)
    }

    return parsed
}


export function parseExpr(expr) {
    if(expr) {
        return parseTokens(lex(expr))
    }
}