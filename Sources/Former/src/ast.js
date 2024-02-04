import {ID_OP, LITERAL_OP, TOKEN_OPERATOR, TOKEN_IDENTIFIER, TOKEN_LITERAL} from './parser.js';


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
        return new ASTNode(operator, operator.value ? operator.value : operator, TOKEN_OPERATOR, char_start, char_end)
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