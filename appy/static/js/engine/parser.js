import { QIter } from "../utils"

/*
Implements a Pratt parser to construct the AST with precedence climbing.
References:
https://crockford.com/javascript/tdop/tdop.html
https://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing
http://effbot.org/zone/simple-top-down-parsing.htm

*/

export const KEYWORD_TABLE = {}

export const TOKEN_LITERAL = "token_literal";
export const TOKEN_IDENTIFIER = "token_identifier";
export const TOKEN_OPERATOR = "token_operator";

class ParseIterator extends QIter {
    constructor(queue) {
        super(queue)
    }
    advance(expecting) {
        // Advance until you find the given token
        if(expecting && this.current() && this.current().operator.value != expecting) {
            syntaxError("Expected token '" + expecting + "' not found.")
        }
        let next = this.next();
        if(this.hasNext()) {
            return this.next()
        } else {
            return new ASTNode(END_OP, null, TOKEN_OPERATOR, -1, -1)
        }
    }
}

class Keyword {
    constructor(keyword_id, left_binding_power=0) {
        this.keyword = keyword_id
        this.left_binding_power = left_binding_power
        KEYWORD_TABLE[keyword_id] = this
    }
    null_denotation(node, token_stream) { console.log("Null denotation not found for: " + this.keyword); }
    left_denotation(left, node, token_stream) { console.log("Left denotation not found: " + this.keyword); }
}

class Literal extends Keyword {
    constructor(keyword_id, value) {
        super(keyword_id, 0)
        this.value = value
    }
    null_denotation(node, token_stream) {
        // console.log("Literal ned <" + this.value + ">");
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
        console.log("Infix right led for " + this.keyword);
        node.node_type = "binary"
        node.left = left;
        node.right = expression(token_stream, this.left_binding_power - 1)
        return node;
    }
}

export class ASTNode {
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
        return new ASTNode(new Literal("(literal)", value), value, TOKEN_LITERAL, char_start, char_end)
    }

    toString() {
        let kw_name = this.operation.keyword;
        if(this.operation.keyword == "(name)" || this.operation.keyword == "(literal)") {
            return this.value
        }

        let string = "(";
        string += kw_name + ' '

        if(this.left){
            string += this.left.toString() +  ' '
        }
        
        if(this.right) {
            string += this.right.toString()
        }
        string += ')'
        return string;
    }
}

export const OperatorNode = ASTNode.OperatorNode;
export const IdentifierNode = ASTNode.IdentifierNode;
export const LiteralNode = ASTNode.LiteralNode;

const ID_OP = new Keyword("(identifier)")
const END_OP = new Keyword("(end)")

new Keyword(":")
new Keyword(")")
new Keyword("]")
new Keyword(",")

new Literal("true", true)
new Literal("false", false)
new Literal("none", null)


new InfixRight("and", 30)       // TODO: Left or right associative?
new InfixRight("or", 30)
new InfixRight("==", 40)
new InfixRight("<=", 40)
new InfixRight(">", 40)
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

// TODO: Unary minus
// Exponentiation. ** less binding power than unary minus.

// TODO - Infix version
new Prefix("(", (node, token_stream) => {
    var e = expression(token_stream, 0);
    node.advance(")")
    return e;
})

export function expression(tokenStream, right_binding_power) {
    let currentNode = tokenStream.next();
    let left = currentNode.operation.null_denotation(currentNode, tokenStream);

    while(right_binding_power < tokenStream.current().operation.left_binding_power) {
        currentNode = tokenStream.next();
        left = currentNode.operation.left_denotation(left, currentNode, tokenStream);
    }

    return left;
}

export function parse(tokenQueue) {
    // Add an end element - prevents having to do an tokenStream.hasNext() check 
    // in the expr while loop condition
    tokenQueue.push(new ASTNode(END_OP, null, TOKEN_OPERATOR, -1, -1))
    let tokenStream = new ParseIterator(tokenQueue);
    return expression(tokenStream, 0)
}
