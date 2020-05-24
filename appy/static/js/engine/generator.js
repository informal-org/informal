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
`;
export const JS_POST_CODE = `ctx.all();\n`;

function cellToJs(cell) {
    if(cell.expr) {
        // TODO: Variable name check
        var variable_name = cell.name ? cell.name : "__" + cell.id;
        let code = `var ${variable_name} = ${cell.expr};\n`;
        code += `ctx.set("${cell.id}", ${variable_name});\n`;
        return code;
    }
    return ""
}

export function genJs(env) {
    var code = JS_PRE_CODE;

    // TODO: Support for nested structures
    env.eval_order.forEach((cell) => {
        code += cellToJs(cell);
    })

    code += JS_POST_CODE;
    console.log(code);
    return code;
}
