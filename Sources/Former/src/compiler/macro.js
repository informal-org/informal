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

function evaluate(env, op, output) {
    // kind == "do" block. Evaluate "this", then evaluate "then" with this's resulting environment.
    // kind = "apply" block. Unify parameters into an env. Merge it with the function's env. Evaluate the expression with that environment.

    if(left.kind === "parse") {
        // Call back into the parser if it was written in-language.

    } else if(left.kind === "apply") {
        // if built in function, call it. Else, call the defined function.
        // It doesn't actually evaluate it at this layer. It gives back what this should evaluate to.
        // Which can be interpreted or compiled.
        Object.entries(left.args).reverse().forEach((_index, arg) => {
            // Resolve the arg to it's value / whatever symbol it references.
            output.push(env.get(arg));
        })
        // Push count if we need variable arity.
        let fn = env.get(left.name);
        output.push(fn);

        return env;
    }
}

function getArity(obj) {
    if(typeof obj === "object") {
        return Object.keys(obj).length;
    }
    return -1
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


function assert(expr, message) {
    if(!expr) {
        throw new Error(message);
    }
}


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