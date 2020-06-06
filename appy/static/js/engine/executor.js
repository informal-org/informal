import { Obj } from "./flex"
import { resolve } from "./namespace"

class CyclicRefError extends Error {
    constructor(message) {
        super(message);
    }
}

class ParseError extends Error {
    constructor(message) {
        super(message);
    }
}

var global = window || global;

global.Obj = Obj;
global.CyclicRefError = CyclicRefError;
global.ParseError = ParseError;

export function execJs(code) {
    // TODO: Sandboxed execution
    try {
        return Function(code)()
    } catch(err) {
        console.log("Evaluation error")
        console.log(err);
        return {}
    }
}



const BINARY_OPS = {
    "+": (a, b) => a + b,
    "-": (a, b) => a - b,
    "*": (a, b) => a * b,
    "/": (a, b) => a / b,
    "and": (a, b) => a && b,
    "or": (a, b) => a || b,
    "==": (a, b) => a === b,
    "<": (a, b) => a < b,
    "<=": (a, b) => a <= b,
    ">": (a, b) => a > b,
    ">=": (a, b) => a >= b,
}

const UNARY_OPS = {
    "-": (a) => -a,
    "not": (a) => !a
}


function interpretObj(node, kv_list, env, cell) {
    let obj = new Obj();
    kv_list.forEach((kv) => {
        let [k, v] = kv
        let key;
        let value;
        if(k.node_type == "(identifier)") {
            // It's a parameter. Wrap it in an object
            key = new Obj([k.value])
            // Functional KVs can't be evaluated immediately. Create a function instead
            
            // TODO: Tuple support for multiple parameters
            // Relies on implicit return in final expression
            // TODO: Return in the context of multiple lines.

            // TODO: Args?
            value = new Obj((args) => { interpretExpr(v, env, cell, args) })

        } else {
            // For flat keys, evaluate both key and value
            key = interpretExpr(k, env, cell)
            value = interpretExpr(v, env, cell)
        }
        
        if(name) {
            // TODO
            code += name + ".insert( (" + key + "),(" + value + "));"
        }
    })
    return obj
}


function localResolve(cell, identifier, args) {
    // First, check if it's a locally bound parameter
    if(identifier in args) {
        return args[identifier]
    }

    let resolved = resolve(cell, identifier);
    if(resolved) {
        // TODO: Assert it was evaluated before this
        return resolved.result
    } else {
        // TODO: Error
        return undefined
    }
}


function interpretExpr(node, env, cell, args={}) {
    if(!node || !node.node_type) { return undefined; }
    switch(node.node_type) {
        case "binary":
            let left = interpretExpr(node.left, env, cell, args)
            let right = interpretExpr(node.right, env, cell, args);
            return BINARY_OPS[node.operator.keyword](left, right)
        case "unary":
            return UNARY_OPS[node.operator.keyword](interpretExpr(node.left, env, cell, args))
        case "(literal)":
            return node.value
        case "(identifier)":
            return localResolve(node.value)
        case "maplist": {
            return interpretObj(node, node.value, env, cell, args)
        }
        case "map": {
            return interpretObj(node, [node.value], env, cell, args)
        }
        case "apply": {
            // Function application            
            // Left is verified to be an identifier
            let params = [];
            node.value.forEach((param) => {
                params.push(interpretExpr(param, env, cell, args))
            })
            let left = localResolve(cell, node.left.value, args)
            return left.call(params)
        }
        case "(array)": {
            let elems = [];
            node.value.forEach((elem) => {
                elems.push(interpretExpr(elem, env, cell, args))
            })
            return elems
        }
        default:
            console.log("Error: Could not translate ast node: ");
            console.log(node)
    }
}

function interpretCell(env, cell) {
    // TODO: Cyclic deps

    cell.result = interpretExpr(cell.parsed, env, cell)

    // TODO: Cell.body
}

export function interpret(env) {
    Object.values(env.cell_map).forEach((cell) => {
        console.log("interpret: " + cell);
        interpretCell(env, cell);
    })
}