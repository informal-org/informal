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

`;
// End wrapper function
export const JS_POST_CODE = `return ctx.all();\n`;

function mapToOp(op) {
    return (left, right) => {
        return "" + left + op + right
    }
}

const BINARY_OPS = {
    "and": mapToOp("&&"),
    "or": mapToOp("||"),
    "==": mapToOp("==="),
}

// Map operations that are 1:1 between JS and AA
const SHARED_OPS = ["+", "-", "*", "/", "<", ">", "<=", ">="];
SHARED_OPS.forEach((op) => {
    BINARY_OPS[op] = mapToOp(op)
})

const UNARY_OPS = {
    "-": (left) => { return "-" + left },
    "not": (left) => { return "!" + left }
}

function astToJs(env, node, name="") {
    // Convert a parsed abstract syntax tree into code
    let prefix = name ? "var " + name + " = " : "";
    if(!node || !node.node_type) { return undefined; }
    switch(node.node_type) {
        case "binary":
            let left = astToJs(env, node.left);
            let right = astToJs(env, node.right);
            return prefix + BINARY_OPS[node.operator.keyword](left, right)
        case "unary":
            console.log("Unary operation");
            console.log(node);
            return prefix + UNARY_OPS[node.operator.keyword](astToJs(env, node.left))
        case "(literal)":
            return prefix + JSON.stringify(node.value)
        case "(identifier)":
            return prefix + node.value
        case "maplist": {
            // let obj = new Obj();
            // let a = {"a": 1, "b": 2}
            // obj.insert(a, "A_VALUE")
            let code = prefix + "new Obj();";
            
            // Array of key value tuples
            node.value.forEach((kv) => {
                let [k, v] = kv
                let key = astToJs(env, k);
                let value = astToJs(env, v);
                code += name + ".insert( (" + key + "),(" + value + "));"
            });
            return code
        }
        case "map": {
            let val = {};
            let k = astToJs(env, node.value[0]);
            let v = astToJs(env, node.value[1]);
            val[k] = v;
            return prefix + JSON.stringify(val)
        }
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

    // TODO: Variable name check
    var variable_name = cell.name ? cell.name : "__" + cell.id;
    let expr = astToJs(env, cell.parsed, variable_name);
    if(expr) {
        code = expr;
        code += `\nctx.set("${cell.id}", ${variable_name});\n`;
    } else if(cell.expr) {  // If it has an expression, but it could not be parsed
        // TODO
        // code += `ctx.set("${cell.id}", new ParseError());\n`;
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
