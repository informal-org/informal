// = pattern matching
// : function definitions.
// () applications.

import { TOKEN_IDENTIFIER, TOKEN_LITERAL, TOKEN_APPLY, TOKEN_HEADER } from "./parser";

const { Map } = require('immutable');
const env = {
    "__builtin_add": (a, b) => a + b,
}

function assert(condition, message) {
    if(!condition) {
        throw new Error(message);
    }
}

export function interpret(root) {
    // : function definition.
    // node_type = apply = function call.
    // const tok = tokens[0];
    const tok = root;
    if(tok.node_type == TOKEN_APPLY) {
        const func_name = tok.left;
        assert(func_name.node_type == TOKEN_IDENTIFIER, "Expected function name to be an identifier");
        const argsNodes = tok.value;
        let args = [];
        // TODO: Resolve identifiers.
        argsNodes.forEach((argNode) => {
            if(argNode.node_type === TOKEN_LITERAL) {
                args.push(argNode.value);
            } else {
                console.log("Unexpected arg type: ", argNode.node_type);
            }
        });

        console.log("func name = ", func_name.value);
        console.log("args = ", args);

        const fn = env[func_name.value];
        assert(fn, `Function ${func_name.value} not found in environment`);
        return fn(...args);
    } else if(tok.node_type == TOKEN_HEADER) {
        // ... : ...
        const head = tok.value[0];
        console.log("head")
        console.log(head);
        if(head.node_type == TOKEN_APPLY) {
            console.log("Function definition: ")
            const fn_name = head.left.value;
            // It's a function definition.
            const argsNodes = head.value;
            let args = [];
            // TODO: Resolve identifiers.
            argsNodes.forEach((argNode) => {
                if(argNode.node_type === TOKEN_IDENTIFIER) {
                    args.push(argNode.value);
                }
            });

            const body = tok.value[1];
            console.log("function " + fn_name + " args: (" + args + "): body {" + body + " }");


            
            
            
    

        }


    }
}

