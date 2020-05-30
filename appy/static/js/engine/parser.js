import { QIter } from "../utils"

/*
Implements a Pratt parser to construct the AST with precedence climbing.
References:
https://crockford.com/javascript/tdop/tdop.html
https://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing

*/

export const KEYWORD_TABLE = {}

export const TOKEN_LITERAL = "token_literal";
export const TOKEN_IDENTIFIER = "token_identifier";
export const TOKEN_OPERATOR = "token_operator";

class Keyword {
    constructor(keyword_id, left_binding_power=0) {
        this.keyword = keyword_id
        this.left_binding_power = left_binding_power
        KEYWORD_TABLE[keyword_id] = this
    }
    null_denotation(node, token_stream) { console.log("Null denotation not found"); }
    left_denotation(left, node, token_stream) { console.log("Left denotation not found"); }
}

class Literal extends Keyword {
    constructor(keyword_id, value) {
        super(keyword_id, 0)
        this.value = value
    }
    null_denotation(node, token_stream) {
        console.log("Literal ned <" + this.value + ">");
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
        console.log("Infix led for " + this.keyword_id);
        node.node_type = "binary"
        node.left = left;
        node.right = expression(token_stream, this.left_binding_power)
        return node;
    }
}

// Infix with right associativity, like =
class InfixRight extends Infix {
    left_denotation(left, node, token_stream) {
        console.log("Infix right led for " + this.keyword_id);
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

export const OperatorNode = ASTNode.OperatorNode;
export const IdentifierNode = ASTNode.IdentifierNode;
export const LiteralNode = ASTNode.LiteralNode;

const ID_OP = new Keyword("(identifier)")

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

console.log(KEYWORD_TABLE);

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

export function expression(tokenStream, right_binding_power) {
    let current = tokenStream.current();
    // console.log("Token stream after: " + tokenStream)

    console.log("Expression: Power " + current.operation.left_binding_power + " min(" + right_binding_power +")");
    console.log(current);

    let token = tokenStream.next();
    let left = current.operation.null_denotation(current, tokenStream);
    console.log(token);

    console.log("token: " + token.operation.keyword + " Power " + token.operation.left_binding_power + " min(" + right_binding_power +")");


    while(tokenStream.hasNext() && right_binding_power < token.operation.left_binding_power) {
        current = token;
        token = tokenStream.next();
        left = current.operation.left_denotation(left, current, tokenStream);
        
        console.log("token: " + token.operation.keyword + " Power " + token.operation.left_binding_power + " min(" + right_binding_power +")");
    }

    return left;
}

export function parse(tokenQueue) {
    let tokenStream = new ParseIterator(tokenQueue);
    return expression(tokenStream, 0)
}
