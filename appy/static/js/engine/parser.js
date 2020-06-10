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
export const TOKEN_LITERAL = "(literal)";
export const TOKEN_IDENTIFIER = "(identifier)";
export const TOKEN_OPERATOR = "(operator)";
export const TOKEN_CONTINUE_BLOCK = "(continueblock)";
export const TOKEN_START_BLOCK = "(startblock)";
export const TOKEN_END_BLOCK = "(endblock)";
export const TOKEN_WHERE = "(where)";       // []
export const TOKEN_ARRAY = "(array)";

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
        if(null_denotation) {
            this.null_denotation = null_denotation
        }
    }
    static null_denotation(node, token_stream) {
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
        // console.log("Infix led for " + this.keyword_id);
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
        if(kw == TOKEN_IDENTIFIER || kw == TOKEN_LITERAL) { return this.value }
        let repr = "";
        if(this.value !== null) {
            this.value.forEach((val) => {
                repr += " " + val.toString();
            })
        }
        else {
            repr = `${this.left ? " " + this.left : ""}${this.right ? " " + this.right : ""}`
        }
        return `(${kw}${repr})`
    }
}

export const OperatorNode = ASTNode.OperatorNode;
export const IdentifierNode = ASTNode.IdentifierNode;
export const LiteralNode = ASTNode.LiteralNode;

const END_OP = new Keyword("(end)")

new Keyword(")")
new Keyword("]")
new Keyword(",")


export const CONTINUE_BLOCK = new Infix(TOKEN_CONTINUE_BLOCK, 10)  // \n
export const START_BLOCK = new Infix(TOKEN_START_BLOCK, 10)     // Tab +
export const END_BLOCK = new Keyword(TOKEN_END_BLOCK, 10)       // Tab -

new Literal("True", true)
new Literal("False", false)
new Literal("None", null)


new InfixRight("or", 30)
new InfixRight("and", 40)

new Infix("in", 60)

// Prefix: when used as Not
// Infix: "not in" TODO
new Mixfix("not", 60, Prefix.null_denotation)
new Infix("is", 60)     // TODO


new InfixRight("==", 40)
new InfixRight("<", 40)
new InfixRight(">", 40)
new InfixRight("<=", 40)
new InfixRight(">=", 40)

// Skip adding a node for unary plus.
new Infix("+", 50).null_denotation = (node, token_stream) => {
    return expression(token_stream, 100)
}
// Support unary minus
new Infix("-", 50).null_denotation = Prefix.null_denotation

new Infix("*", 60)
new Infix("/", 60)

// More binding power than multiplication, but less than unary minus (100)
new InfixRight("**", 70)


const SQ_BK = new Mixfix("[", 150);
// Defining an array
SQ_BK.null_denotation = (node, tokenStream) => {
    node.node_type = TOKEN_ARRAY
    node.value = [];

    if(tokenStream.currentKeyword() != "]"){ // []
        while(tokenStream.hasNext()) {
            node.value.push(expression(tokenStream, 10))
            if(tokenStream.currentKeyword() == ",") {
                tokenStream.next();
            } else {
                break;
            }
        }
    }

    tokenStream.advance("]")
    return node
}
// As indexing
SQ_BK.left_denotation = (left, node, tokenStream) => {
    node.left = left;       // Left could be identifier, array, string.
    node.node_type = TOKEN_WHERE;
    
    node.right = expression(tokenStream, 0)
    tokenStream.advance("]")
    return node;
}


function continuation(left, node, tokenStream) {
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


// TODO: Precedence level for this
new Infix(",", 10).left_denotation = continuation;

// Treat new lines as comma equivalents.
CONTINUE_BLOCK.left_denotation = continuation;

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



new Infix(":", 80).left_denotation = (left, node, tokenStream) => {
    node.node_type = "map"
    // Key, value. Store in a list which will be appended upon
    // node.value = [left, expression(tokenStream, 80)]
    node.value = [left, expression(tokenStream, 10)]
    return node
}


new Mixfix("(", 150, (node, tokenStream) => {
    // In Prefix mode ( indicates a parenthesized expression grouping

    node.value = [];
    while(tokenStream.hasNext()) {
        if(tokenStream.currentKeyword() == ")") {
            break
        }
        node.value.push(expression(tokenStream, 10))
        if(tokenStream.currentKeyword() == ",") {
            node.node_type = "(grouping)"
            tokenStream.next();
        } else {
            break;
        }
        
    }

    tokenStream.advance(")")

    if(node.node_type == "(grouping)") {
        return node
    } else {
        console.log(node.value.length == 0)
        return node.value[0]
    }
    
}, (left, node, tokenStream) => {
    // In infix mode, ( indicates a function call
    node.left = left;

    if(node.left.node_type != TOKEN_IDENTIFIER) {
        syntaxError("Error: Could not call " + node.left.operator.value + " as a function.")
    }

    node.node_type = "apply"
    node.value = [];

    if(tokenStream.currentKeyword() != ")") {   // f()
        while(tokenStream.hasNext()) {
            node.value.push(expression(tokenStream, 10))
            if(tokenStream.currentKeyword() == ",") {
                tokenStream.next();
            } else {
                break;
            }
        }
    }
    
    tokenStream.advance(")")
    return node
})

export function syntaxError(message, index) {
    let err = new Error(message);
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