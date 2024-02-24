import { Stack } from "immutable";
const hamt = require('hamt');
import { 
    TOKEN_GROUPING,
    TOKEN_IDENTIFIER
} from "./parser"


const symbolTable = {};


function expectShift(tokenQueue) {
    if(tokenQueue.length == 0) {
        throw new Error("Unexpected end of input");
    }
    return tokenQueue.shift();
}

function evaluate() {
    // kind == "do" block. Evaluate "this", then evaluate "then" with this's resulting environment.
    // kind = "apply" block. Unify parameters into an env. Merge it with the function's env. Evaluate the expression with that environment.
}

function arity(obj) {
    if(typeof obj === "object") {
        return Object.keys(obj).length;
    }
    return -1
}

// function isPrefix(pattern) {
//     // Prefix functions depend on nothing to their left, and returns a process
//     // which takes the next expression and performs the prefix operation on it.
//     let key = pattern["key"];
//     let arity = arity(key);
//     return arity === 0;
// }

// function isInfix(pattern) {
//     // Infix function depends on their left argument, and returns a process
//     // which consumes the right argument and evaluates the whole expression, respecting precedence.
//     // Postfix functions are infix functions which depend on their left and return a value 
//     // without depending on what's to the right.
// }

// function isBlock(pattern) {
//     // if, for, etc. are blocks which have a header and a body.
//     // Arity of 2.
// }

export function matchExpand(tokenQueue) {
    let env = hamt.empty;
    let parsed = new Queue();
     // On enter new block, clone and push. On exit, pop and resume.
    let scopes = new Stack();

    while(tokenQueue.length > 0) {
        let left = tokenQueue.shift();
        if(left.node_type == TOKEN_IDENTIFIER) {
            let leftValue = env.get(left.value);
            let arity = -1;
            if(leftValue) {
                let key = pattern["key"];
                arity = arity(key);
                if(arity === 1) {
                    // Infix operator is not expected as the first token. 
                    throw Error("Unexpected infix operator " + left.value);
                }
            }

            if(arity === 0) {
                // Prefix function which returns a process to consume the next token, and return the evaluated op.

            } else if(arity === 2) {
                // Start of a block like if/for/fn etc.

            } else {
                // This one's not an operation, so expect the next token to be an operation or we quit.

            }

            

            if(isPrefix(leftValue)) {
                // If unary - evaluate it.
                // Always returns a process. Which, when evaluated will give a value or another process.
                call_macro(left, env);
            } else if(is_block_macro(left)) {
                // If block - start sub-process to parse block head till : and block body till group end.
                call_block()
            } else {
                // else - left = value. Check if next is operator. If so, it'll know what to do with this.
                let opToken = tokenQueue.shift();
                if(is_postfix_operator(opToken)) {
                    // Call it with left. It should return a complete result.
                    call_macro(opToken, left, env);
                }
                else if(is_binary_operator(opToken)) {
                    // Binary operators need the right-hand side to complete their processing. 
                    // It'll return a sub-process, which when given the right-hand side will
                    // either give back the result, or another sub-process.
                    // Keep calling it until you get a result.
                    // If result = 
                    call_macro(opToken, token, env)
                }
            }
            
            
            // let secondToken = expectShift(tokenQueue);
        } else if(token.node_type == TOKEN_LITERAL) {
            // If value, left = value.
            parsed.push(token);
        } else if(token.node_type == TOKEN_GROUPING) {
            // () [] {} "" '' (indentation) (commentblock) are all groupings.
            // Lookup end of comment. Collect until end.
            // If grouping takes one arg, give it the contents until end of group.
            // If it takes two args, give it head, contents. i.e. foo[bar]
            // For cases like foo.(bar) - the infix operator drives the behavior, not the grouping.
        } 
        // TODO: Comments.
        // else if(token.node_type == TOKEN_COMMENT) {

        // }

    }


}