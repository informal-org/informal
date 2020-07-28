import { orderCellBody } from "./order"
import { syntaxError } from "./parser";
import { findMinStart, findMaxEnd } from "../utils/ast"

import * as core from "./core";


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

    ".": (left, right) => {
        // Quote the right hand side attribute
        return "__aa_attr(" + left + ", '" + right + "' )"
    },    
}

// TODO: Vector support for unary minus
const UNARY_OPS = {
    "-": (left) => { return "-" + left },
    "not": (left) => { return "__aa_not(" + left + ")" }
}

function paramsToJs(node) {
    // TODO: Preserve normal values as-is for pattern matching
    if(node && node.value) {
        let params = node.value.map((p) => {
            return "new KeySignature('" + p + "')"
        })
        return params.join(" , ")
    } else {
        return ""
    }
}

function parseGuard(node, params, code, cell) {
    // TODO: Type support
    var name = "__" + code.genVariable();

    var paramsStr = params ? "(" + params.value + ")" : "()";
    let guardFn = paramsStr + " => " + astToJs(node, code, cell);

    code.add(`var ${name} = ${guardFn};`)
    
    // Add a text representation
    code.add(`${name}.toString = () => ${getNodeText(node, cell)};`)
    return name
}

function getNodeText(node, cell) {
    let node_start = findMinStart(node);
    let node_end = findMaxEnd(node);
    let node_expr = cell.expr.slice(node_start, node_end)
    return JSON.stringify(node_expr)
}

function objToJs(node, kv_list, code, cell, name) {
    if(!name) {
        name = code.genVariable();
    }
    let result = "var " + name + " = new Obj();";

    var is_conditional = undefined;

    // Array of key value tuples
    kv_list.forEach((kv_node) => {
        if(kv_node.node_type != "map") {
            syntaxError("Unexpected node found in map " + kv_node)
        }
        // TODO: Possibly convert from kv list format to left-right kv.
        let k = kv_node.value[0];
        let v = kv_node.value[1];
        
        let key;
        let value;
        if(k.node_type == "(identifier)") {
            // It's a column name
            key = `new KeySignature("${k.value}")`;
            // Functional KVs can't be evaluated immediately. Create a function instead
            
            // TODO: Tuple support for multiple parameters
            // Relies on implicit return in final expression
            // TODO: Return in the context of multiple lines.
            value = astToJs(v, code, cell) 

        } else if(k.node_type == "(grouping)" || k.node_type == "(if)") {

            let paramNode = k;
            let guard = null;
            if(k.node_type == "(if)") {
                if(k.right) {
                    // Guard clause
                    paramNode = k.left;
                    is_conditional = false;
                    guard = parseGuard(k.right, paramNode, code, cell);
                } else {
                    // Bare if clause
                    if(is_conditional === undefined) {
                        // Only if all clauses are conditionals, not mixed clauses.
                        is_conditional = true;
                    }
                    guard = parseGuard(k.left, null, code, cell);
                }
            }

            // TODO: Generator support for parameter guards
            let paramSignature = paramsToJs(paramNode)

            // It's a parameter. Wrap in an object
            // TODO: Type support
            // TODO: Function names
            key = "new KeySignature('', null, [" + paramSignature + "],(" + guard + "))"

            let value_name = "__" + code.genVariable();
            let paramStr = paramNode && paramNode.value ? paramNode.value : ""
            
            code.add(`
    var ${value_name} = (${paramStr}) => {
        return ${astToJs(v, code, cell)}
    };
    ${value_name}.toString = () => ${getNodeText(v, cell)};\n`)
            value = value_name;
            
        } else {
            // For flat keys, evaluate both key and value
            key = astToJs(k, code, cell)
            value = astToJs(v, code, cell)
        }
        
        result += name + ".insert( (" + key + "),(" + value + "));"
    });
    code.add(result)

    if(is_conditional === true) {
        code.add(name + " = __aa_call(" + name + ");")
    }
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
            return objToJs(node, [node], code, cell, name)
        }
        case "(grouping)": {
            // Top level groupings are expressions
            if(node.value.length == 1) {
                return "(" + astToJs(node.value[0], code, cell, name) + ")"
            } else {
                console.log("Unexpected parentheses")
                console.log(node);
                console.log(node.value);
            }
        }
        case "apply": {
            // Function application            
            // Left is verified to be an identifier
            let params = [];
            node.value.forEach((param) => {
                params.push(astToJs(param, code, cell))
            })
            let paramString = params ? ", " + params.join(",") : ""
            return prefix + "__aa_call(" + astToJs(node.left) + paramString + ")"
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
            let right = node.value[0]
            return prefix + astToJs(node.left, code, cell) + ".get(" + astToJs(right, code, cell) + ")"
        }
        case "(if)": {
            // guard = parseGuard(node.left, null, code, cell);
            // console.log("Guard: ");
            // console.log(guard);

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
    } else {

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

class CodeGenContext {
    constructor(env){
        this.code = JS_PRE_CODE;
        this.env = env;

        this.variable_count = 0;
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

    genVariable() {
        return "u_" + this.variable_count++
    }
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
