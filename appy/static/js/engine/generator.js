import { orderCellBody } from "./order"

// TODO: Ensure error equality on CYCLIC_ERR throws error.
export const JS_PRE_CODE = `
function ctx_init() {
    var ctx = {};
    return {
        set: function(k, v) { ctx[k] = v; },
        get: function(k) { return ctx[k]; },
        all: function() { return ctx }
    };
};
var ctx = ctx_init();
class CyclicRefError extends Error {
    constructor(message) {
        super(message);
    }
}
`;
export const JS_POST_CODE = `ctx.all();\n`;

var BINARY_OPS = {
    "+": (left, right) => { return "" + left + " + " + right },
    "-": (left, right) => { return "" + left + " - " + right },
    "*": (left, right) => { return "" + left + " * " + right },
    "/": (left, right) => { return "" + left + " / " + right }
}

var UNARY_OPS = {
    "-": (left) => { return "-" + left }
}

function astToJs(env, node) {
    // Convert a parsed abstract syntax tree into code
    let code = "";
    switch(node.node_type) {
        case "binary":
            let left = astToJs(env, node.left);
            let right = astToJs(env, node.right);
            return BINARY_OPS[node.operator.keyword](left, right)
        case "unary":
            return UNARY_OPS[node.operator.keyword](astToJs(env, node.left))
        case "(literal)":
            return JSON.stringify(node.value)
        case "(identifier)":
            return "" + node.value
        default:
            console.log("Error: Could not translate ast node: ");
            console.log(node)
    }
    return code;
}


// Bottom up recursive code generation by local evaluation order.
// (see BURS - bottom up rewrite systems)
function cellToJs(env, cell) {
    let code = "";

    if(cell.cyclic_deps) {
        // If it contains cycles, then just report the error.
        code = `ctx.set("${cell.id}", new CyclicRefError());\n`
        return code;
    }

    if(cell.expr) {
        // TODO: Variable name check
        var variable_name = cell.name ? cell.name : "__" + cell.id;        
        let expr = astToJs(env, cell.parsed);
        code = `var ${variable_name} = ${expr};\n`;
        code += `ctx.set("${cell.id}", ${variable_name});\n`;
    }
    
    if(cell.body) {
        let body = orderCellBody(cell);
        body.forEach((child) => {
            code += cellToJs(env, child);
        })
    }
    return code
}

// export function genJs(env) {
//     var code = JS_PRE_CODE;

//     // TODO: Support for nested structures
//     code += cellToJs(env, env.root);

//     code += JS_POST_CODE;
//     return code;
// }



export function genJs(env) {
    var code = JS_PRE_CODE;

    // TODO: Support for nested structures
    if(env.root) {
        code += cellToJs(env, env.root);
    } else {
        Object.values(env.cell_map).forEach((cell) => {
            code += cellToJs(env, cell)
        })
    }

    code += JS_POST_CODE;
    return code;
}
