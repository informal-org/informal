import { Stack } from "immutable";
const hamt = require('hamt');
import { 
    TOKEN_GROUPING,
    TOKEN_IDENTIFIER
} from "./parser"



// Types of expressions:
// 1. Prefix. i.e. "not X". Depends on nothing to left. Consumes the next token and returns the result.
//      (): (right): result.
// 2. Infix. i.e "X and Y". Depends on left. 
// Infix function depends on their left argument, and returns a process
// which consumes the right argument and evaluates the whole expression, respecting precedence.
//     (left): (right): result.
//     (left, middle): (right): result.   // (left +) (middle) + (right). Determines which it binds more strongly to.
// 2.5 Postfix functions are infix functions which depend on their left and return a value 
// without depending on what's to the right.
// 3. Grouping. i.e. "(1 + 1)", "a[1]", indentation blocks, comments, strings, tuples, etc.
// Things in between a begin and end token. Comes in two variants.
// (contents): results - wraps some contents and returns a result.
// (head, contents): Expressions like foo[bar] or foo(bar). Operates on the head.
// 4. Block. i.e. "if(x): body" or "for(x in y): ...". Contains a grouping operator in head, and a closure or a map in the body.
// It determines if/when/how to evaluate the body. Closure forms a scope. 
// (head: (unbound, vars): head_expr, body: (vars): body_expr): result.


const syntax = {
    '[': [
        (contents) => {
            // array definition.
            return {
                "kind": "list",
                "contents": contents
            }
        },
        (head, contents) => {
            // array access. head = variable being accessed.
            return {
                "kind": "index",
                "head": head,
                "contents": contents,
            }
        }
    ],
    '\t': [
        (contents) => {
            // Indented blocks form a closure.
            return {
                "kind": "block",
                "contents": contents
            }
        }
    ],
    '(': [
        (contents) => {
            // Tuple
            return {
                "kind": "tuple",
                "contents": contents
            }
        },
        (head, contents) => {
            // Function application. foo(a, b)
            return {
                "kind": "apply",
                "head": head,
                "contents": contents
            }
        }
    ],
    ':': [
        (left) => {
            return (right) => {

            }
        },
        (left, middle) => {
            return (right) => {

            }
        }
    ]
};



function expectShift(tokenQueue) {
    if(tokenQueue.length == 0) {
        throw new Error("Unexpected end of input");
    }
    return tokenQueue.shift();
}


function isPrefix(token) {

}



function match(env, left, right) {
    // Left returns a process which takes the right argument.
    return 
}


// not : (right): __not(right)
// {
//     "kind": "parse",
//     "key": {
//         0: "right",
//     },
//     "value": {
//         "kind": "apply",
//         "name": "__not",    // Built-in / intrinsic function.
//         "args": {
//             0: "right"      // Evaluate each in given environment and pass to function.
//         }
//     }
// }




export function matchExpand(tokenQueue) {
    let env = hamt.empty;
    let parsed = new Queue();
    let output = new Queue();
     // On enter new block, clone and push. On exit, pop and resume.
    let scopes = new Stack();

    let left = undefined;
    while(tokenQueue.length > 0) {
        let current = tokenQueue.shift();
        if(current.node_type == TOKEN_IDENTIFIER) {
            let currentValue = env.get(current.value);
            let arity = -1;
            if(currentValue) {
                let key = pattern["key"];
                arity = getArity(key);
            }

            // Parse start of a fresh expression without anything unparsed to the left.
            if(left === undefined) {
                // Start of an expression.
                if(arity === 0) {
                    // Prefix functions depend on nothing to their left. They return a process which consumes the next argument.
                    left = currentValue;
                    assert(left.kind === "parse", "Expected a prefix parser");
                    assert(left.key[0] === "right", "Expected a prefix parser with a single argument 'right'");
                    let right = expectShift(tokenQueue);
                    // It should be some kind of value you can apply the operation on...
                    let envWithParams = env.set('right', right);
                    evaluate(envWithParams, left);
                }
                else if(arity === 1) {
                    // Infix operator is not expected as the first token. 
                    throw Error("Unexpected infix operator " + current.value);
                } else if(arity === 2) {
                    // Block
                }

            } else {
                // Expect it to be a continuation of the previous expression.
                if(arity === 0) {
                    // Prefix after an unused left is not expected.
                    throw Error("Unexpected prefix operator " + current.value);
                }
                else if(arity === 1) {
                    // Infix function depends on their left argument, and returns a process
                    // which consumes the right argument and evaluates the whole expression, respecting precedence.
                    // Postfix functions are infix functions which depend on their left and return a value 
                    // without depending on what's to the right.

                    // (1 +) 1
                    // Want to evaluate this with left. Check if we get back a value or a process by "kind".
                    // If process, then you repeat the process. If other kind of operation, do that operation, then save it to 
                    


                    // We've consumed left. Reset it.
                    left = undefined;
                }
                else if(arity === 2) {
                    // Block also do not consume whatever's to their left.
                    throw Error("Unexpected block " + current.value);
                }

            }
            
            
        } else if(token.node_type == TOKEN_LITERAL) {
            if(left === undefined) {
                parsed.push(token);
                left = token;
                // Expect the the next thing to be infix or grouping.
            } else {
                // There's an unconsumed left. A literal is not expected here.
                throw Error("Unexpected literal " + token.value);
            }
        } else if(token.node_type == TOKEN_GROUPING) {
            // () [] {} "" '' (indentation) (commentblock) are all groupings.
            // Lookup end of comment. Collect until end.
            // If grouping takes one arg, give it the contents until end of group.
            // If it takes two args, give it head, contents. i.e. foo[bar]
            // For cases like foo.(bar) - the infix operator drives the behavior, not the grouping.



        } 

    }

}