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
        code = `var ${variable_name} = ${cell.expr};\n`;
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

export function genJs(env) {
    var code = JS_PRE_CODE;

    // TODO: Support for nested structures
    code += cellToJs(env, env.root);

    code += JS_POST_CODE;
    return code;
}
