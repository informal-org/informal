// = pattern matching
// : function definitions.
// () applications.

import { TOKEN_IDENTIFIER, TOKEN_LITERAL, TOKEN_APPLY, TOKEN_HEADER } from "./parser";

const { Map } = require('immutable');


export const builtins = Map({
    "__builtin_add": {
        value: (a, b) => a + b
    },
});

function assert(condition, message) {
    if(!condition) {
        throw new Error(message);
    }
}

export function interpret(root, env) {
    // : function definition.
    // node_type = apply = function call.
    // const tok = tokens[0];
    console.log("evaluating: " + root.node_type);
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
                let resolved = env.get(argNode.value)
                console.log("resolving " + argNode.value + " to " + resolved);
                args.push(resolved);
            }
        });

        console.log("func name = ", func_name.value);
        console.log("args = ", args);

        const fn = env.get(func_name.value);
        if(fn.value) {
            assert(fn, `Builtin Function ${func_name.value} not found in environment`);
            return fn.value(...args);
        } else {
            // Bind parameters
            let fn_env = fn.env;
            for(var i = 0; i < fn.args.length; i++) {
                console.log("setting " + fn.args[i] + " to " + args[i])
                fn_env = fn_env.set(fn.args[i], args[i]);
            }
            console.log("evaluating")
            console.log(fn.body);
            return interpret(fn.body, fn_env);
        }
        
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
    
            // TODO: support recursion.
            let fn_def = {
                args: args,
                body: body,
                env: env
            }
            env = env.set(fn_name, fn_def);
            fn_def.env = env;
            // value: (...args) => {
            //     console.log(`Evaluating ${fn_name} args = ${args}`);
            //     let result = interpret(body, env);
            //     console.log("result = ", result);
            //     return result;
            // }

            return fn_def;

        }


    }
}

