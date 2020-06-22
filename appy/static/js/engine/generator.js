import { orderCellBody } from "./order"
import { syntaxError } from "./parser";
import {genID} from "../utils"

// TODO: Ensure error equality on CYCLIC_ERR throws error.
export const JS_PRE_CODE = `
function ctx_init() {
    var ctx = {};
    return {
        set: function(k, v) { ctx[k] = {value: v}; },
        setError: function(k, v) { ctx[k] = {error: v}; },
        get: function(k) { return ctx[k].value; },
        getError: function(k) { return ctx[k].error; },
        all: function() { return ctx }
    };
};
var ctx = ctx_init();
`;
// End wrapper function
export const JS_POST_CODE = `return ctx.all();\n`;

function mapToFn(fn) {
    return (left, right) => {
        return fn + "(" + left + "," + right + ")"
    }
}

const BINARY_OPS = {
    "and": mapToFn("__aa_and"),
    "or": mapToFn("__aa_or"),    

    ".": (left, right) => {
        return (left + ".lookup('" + right + "')")
    },

    
    "+": mapToFn("__aa_add"),
    "-": mapToFn("__aa_sub"),
    "*": mapToFn("__aa_multiply"),
    "/": mapToFn("__aa_divide"),
    "%": mapToFn("__aa_mod"),

    "<": mapToFn("__aa_lt"),
    ">": mapToFn("__aa_gt"),
    "<=": mapToFn("__aa_lte"),
    ">=": mapToFn("__aa_gte"),

    "==": mapToFn("__aa_eq"),
    "!=": mapToFn("__aa_neq"),
}

// TODO: Vector support for unary minus
const UNARY_OPS = {
    "-": (left) => { return "-" + left },
    "not": (left) => { return "__aa_not(" + left + ")" }
}

class CodeGenContext {
    constructor(env){
        this.code = JS_PRE_CODE;
        this.env = env;
    }
    add(newCode) {
        this.code += newCode
    }
    finalize() {
        this.code += JS_POST_CODE;
    }
    getCode() {
        return this.code
    }
}


function findMinStart(node) {
    let min = node.char_start;
    if(node.left) {
        let left_start = findMinStart(node.left)
        min = left_start < min ? left_start : min
    }
    if(node.right) {
        let right_start = findMinStart(node.right);
        min = right_start < min ? right_start : min
    }
    return min
}


function findMaxEnd(node) {
    let max = node.char_end;
    if(node.left) {
        let left_end = findMaxEnd(node.left)
        max = left_end > max ? left_end : max
    }
    if(node.right) {
        let right_end = findMaxEnd(node.right);
        max = right_end > max ? right_end : max
    }
    return max
}

function paramsToJs(node) {
    // TODO: Preserve normal values as-is for pattern matching
    let params = node.value.map((p) => {
        return "new KeySignature('" + p + "')"
    })
    return params.join(" , ")
}

function parseGuard(node, params, code, cell) {
    // TODO: Type support
    var name = "__" + genID();
    let guardFn = "(" + params.value + ") => " + astToJs(node, code, cell);
    code.add(`var ${name} = ${guardFn};`)
    // Add a text representation

    let guard_start = findMinStart(node);
    let guard_end = findMaxEnd(node);
    let guard_expr = cell.expr.slice(guard_start, guard_end);

    code.add(`${name}.toString = () => "${guard_expr}";`)

    return name
}


function objToJs(node, kv_list, code, cell, name) {
    if(!name) {
        name = genID();
    }

    let prefix = name ? "var " + name + " = " : "";
    let result = prefix + "new Obj();";

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
            value = astToJs(v, code, cell) 

        } else if(k.node_type == "(grouping)" || k.node_type == "(where)") {

            let paramNode = k;
            let guard = null;
            if(k.node_type == "(where)") {
                paramNode = k.left;
                guard = parseGuard(k.right, paramNode, code, cell);
            }

            // TODO: Generator support for parameter guards
            let paramString = paramsToJs(paramNode)

            // It's a parameter. Wrap in an object
            // TODO: Type support
            key = "new KeySignature('', null, [" + paramString + "],(" + guard + "))"

            value = "(" + paramNode.value + ") => " + astToJs(v, code, cell)

            
        } else {
            // For flat keys, evaluate both key and value
            key = astToJs(k, code, cell)
            value = astToJs(v, code, cell)
        }
        
        result += name + ".insert( (" + key + "),(" + value + "));"
    });
    code.add(result)
    return name
}

export function astToJs(node, code, cell, name="") {
    // Convert a parsed abstract syntax tree into code
    let prefix = name ? "var " + name + " = " : "";
    if(!node || !node.node_type) { return undefined; }
    switch(node.node_type) {
        case "binary":
            let left = astToJs(node.left, code, cell);
            let right = astToJs(node.right, code, cell);
            // return prefix + "(" + BINARY_OPS[node.operator.keyword](left, right) + ")"
            return prefix + BINARY_OPS[node.operator.keyword](left, right)
        case "unary":
            return prefix + UNARY_OPS[node.operator.keyword](astToJs(node.left, code, cell))
        case "(literal)":
            return prefix + JSON.stringify(node.value)
        case "(identifier)":
            return prefix + node.value
        case "maplist": {
            // let obj = new Obj();
            // let a = {"a": 1, "b": 2}
            // obj.insert(a, "A_VALUE")
            return objToJs(node, node.value, code, cell, name)
        }
        case "map": {
            return objToJs(node, [node.value], code, cell, name)
        }
        case "(grouping)": {
            // Top level groupings are expressions
            if(node.value.length == 1) {
                return "(" + astToJs(node.value[0], code, cell, name) + ")"
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
                params.push(astToJs(param, code, cell))
            })
            return prefix + node.left.value + ".call(" + params.join(",") + ")"
        }
        case "(array)": {
            let elems = [];
            node.value.forEach((elem) => {
                elems.push(astToJs(elem, code, cell))
            })
            return prefix + "Stream.array([" + elems.join(",") + "])"
        }
        case "(where)": {
            // if(node.right.node_type == "(literal)" || node.right.node_type == "(identifier)") {
            //     // arr[0] arr[index + 1]
            // }

            // TODO: Differentiate between indexing and filtering
            return prefix + astToJs(node.left, code, cell) + ".get(" + astToJs(node.right, code, cell) + ")"
        }
        default:
            console.log("Error: Could not translate ast node: ");
            console.log(node)
    }
    return "";
}

function cellToJs(code, cell) {
    if(cell.error) {
        return
    }

    if(cell.cyclic_deps) {
        // If it contains cycles, then just report the error.
        code.add(`ctx.set("${cell.id}", new CyclicRefError());\n`)
        return code;
    }

    // TODO: Variable name check
    var variable_name = cell.name ? cell.name : "__" + cell.id;
    code.add("\ntry { \n");
    let expr = astToJs(cell.parsed, code, cell, variable_name);

    if(expr) {
        code.add(expr)
        code.add(`\nctx.set("${cell.id}", ${variable_name});\n`)
    }
    code.add(`} catch(err) { console.log(err); ctx.setError("${cell.id}", err.message); }\n`)


    
    if(cell.body) {
        let body = orderCellBody(cell);
        body.forEach((child) => {
            cellToJs(code, child)
        })
    }
    return code
}

export function genJs(env) {
    var code = new CodeGenContext(env);

    if(env.root) {
        cellToJs(code, env.root);
    } else {
        Object.values(env.cell_map).forEach((cell) => {
            cellToJs(code, cell)
        })
    }

    code.finalize();
    return code.getCode();
}
