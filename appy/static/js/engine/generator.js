import { orderCellBody } from "./order"
import { Obj } from "./flex";
import { syntaxError } from "./parser";

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
    ".": (left, right) => {
        return (left + ".lookup('" + right + "')")
    }
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

function objToJs(node, kv_list, env, name) {
    let prefix = name ? "var " + name + " = " : "";
    let code = prefix + "new Obj();";
            
    // Array of key value tuples
    kv_list.forEach((kv) => {
        let [k, v] = kv
        let key;
        let value;
        if(k.node_type == "(identifier)") {
            // It's a column name
            key = "'" + k.value + "'"
            // Functional KVs can't be evaluated immediately. Create a function instead
            
            // TODO: Tuple support for multiple parameters
            // Relies on implicit return in final expression
            // TODO: Return in the context of multiple lines.
            value = astToJs(v, env) 

        } else if(k.node_type == "(grouping)") {
            // It's a parameter. Wrap in an object
            // "a","b"
            key = "new Obj(['" + k.value.join("', '") + "'])"
            value = "new Obj((" + k.value + ") => " + astToJs(v, env) + ")"
        } else {
            // For flat keys, evaluate both key and value
            key = astToJs(k, env)
            value = astToJs(v, env)
        }
        
        if(name) {
            // TODO
            code += name + ".insert( (" + key + "),(" + value + "));"
        }
    });
    return code
}

function astToJs(node, env, name="") {
    // Convert a parsed abstract syntax tree into code
    let prefix = name ? "var " + name + " = " : "";
    if(!node || !node.node_type) { return undefined; }
    switch(node.node_type) {
        case "binary":
            let left = astToJs(node.left, env);
            let right = astToJs(node.right, env);
            // return prefix + "(" + BINARY_OPS[node.operator.keyword](left, right) + ")"
            return prefix + BINARY_OPS[node.operator.keyword](left, right)
        case "unary":
            return prefix + UNARY_OPS[node.operator.keyword](astToJs(node.left, env))
        case "(literal)":
            return prefix + JSON.stringify(node.value)
        case "(identifier)":
            return prefix + node.value
        case "maplist": {
            // let obj = new Obj();
            // let a = {"a": 1, "b": 2}
            // obj.insert(a, "A_VALUE")
            return objToJs(node, node.value, env, name)
        }
        case "map": {
            return objToJs(node, [node.value], env, name)
        }
        case "(grouping)": {
            // Top level groupings are expressions
            if(node.value.length == 1) {
                return "(" + astToJs(node.value[0], env, name) + ")"
            } else {
                // TODO
                syntaxError("Unexpected parentheses")
            }
        }
        case "apply": {
            // Function application            
            // Left is verified to be an identifier
            let params = [];
            node.value.forEach((param) => {
                params.push(astToJs(param, env))
            })
            return prefix + node.left.value + ".call(" + params.join(",") + ")"
        }
        case "(array)": {
            let elems = [];
            node.value.forEach((elem) => {
                elems.push(astToJs(elem, env))
            })
            return prefix + "Stream.array([" + elems.join(",") + "])"
        }
        case "(where)": {
            console.log("Where:")
            console.log(node)
            console.log(node.left)
            console.log(node.right)
            // if(node.right.node_type == "(literal)" || node.right.node_type == "(identifier)") {
            //     // arr[0] arr[index + 1]
            // }

            // TODO: Differentiate between indexing and filtering
            return prefix + astToJs(node.left, env) + ".get(" + astToJs(node.right, env) + ")"
        }
        default:
            console.log("Error: Could not translate ast node: ");
            console.log(node)
    }
    return "";
}


// Bottom up recursive code generation by local evaluation order.
// (see BURS - bottom up rewrite systems)
function cellToJs(env, cell) {
    let code = "";

    if(cell.error) {
        return ""
    }

    if(cell.cyclic_deps) {
        // If it contains cycles, then just report the error.
        code = `ctx.set("${cell.id}", new CyclicRefError());\n`
        return code;
    }

    // TODO: Variable name check
    var variable_name = cell.name ? cell.name : "__" + cell.id;
    let expr = astToJs(cell.parsed, env, variable_name);
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
