import { orderCellBody } from "./order"
import { syntaxError } from "./parser";

import * as core from "./core";

console.log("core in generator is")
console.log(core);
console.log(Object.keys(core));



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
        return "__aa_attr(" + left + ", '" + right + "' )"
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
    if(node.value) {
        for(var i = 0; i < node.value.length; i++){
            let val_start = findMinStart(node.value[i]);
            min = val_start < min ? val_start : min
        }
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
    if(node.value) {
        for(var i = 0; i < node.value.length; i++){
            let val_start = findMaxEnd(node.value[i]);
            max = val_start > max ? val_start : max
        }
    }    
    return max
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
    console.log("Parse guard")
    console.log(node);
    console.log(params);
    
    // TODO: Type support
    var name = "__" + code.genVariable();

    var paramsStr = params ? "(" + params.value + ")" : "()";
    let guardFn = paramsStr + " => " + astToJs(node, code, cell);

    code.add(`var ${name} = ${guardFn};`)
    // Add a text representation

    let guard_start = findMinStart(node);
    let guard_end = findMaxEnd(node);
    let guard_expr = cell.expr.slice(guard_start, guard_end);

    code.add(`${name}.toString = () => ${JSON.stringify(guard_expr)};`)

    return name
}


function objToJs(node, kv_list, code, cell, name) {
    if(!name) {
        name = code.genVariable();
    }

    let prefix = name ? "var " + name + " = " : "";
    let result = prefix + "new Obj();";

    var is_conditional = undefined;
    console.log("KV list: ")
    console.log(kv_list)

    // Array of key value tuples
    kv_list.forEach((kv) => {
        let [k, v] = kv
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
            // let valueFn = "(" + paramStr + ") => " + astToJs(v, code, cell)
            
            // code.add(`var ${value_name} = ${valueFn};\n`)

            code.add(`var ${value_name} = (${paramStr}) => {\n`)
            code.add("\n return " + astToJs(v, code, cell))
            code.add("\n};")

            let value_start = findMinStart(v);
            let value_end = findMaxEnd(v);
            let value_expr = cell.expr.slice(value_start, value_end)
            // code.add(`${value_name}.toString = () => "${value_expr}";\n`)
            code.add(`${value_name}.toString = () => ${JSON.stringify(value_expr)};\n`)

            value = value_name;
            
        } else {
            console.log("Map flat keys");
            console.log(k)
            console.log(v)
            console.log("---")
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
            return objToJs(node, [node.value], code, cell, name)
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
            return prefix + astToJs(node.left, code, cell) + ".get(" + astToJs(node.right, code, cell) + ")"
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
