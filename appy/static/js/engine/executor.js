import { Obj, Stream, KeySignature } from "./flex"
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

class RuntimeError extends Error {
    constructor(message) {
        super(message);
        this.name = "RuntimeError"
    }
}

var global = window || global;

global.Obj = Obj;
global.Stream = Stream;
global.CyclicRefError = CyclicRefError;
global.ParseError = ParseError;
global.RuntimeError = RuntimeError;
global.KeySignature = KeySignature;


// number (NaN), string, boolean, symbol, undefined, object (null), function
function __aa_typeof(val) {
    let t = typeof val;
    if(t == "object") {
        if(val.__type) {
            // Stream or Obj
            return val.__type
        }
    }
    return t
}

global.__aa_add_type_map = {
    "number": {
        "number": (a, b) => a + b,
        "string": (a, b) => "" + a + b,
        "Stream": (a, b) => b.map((x) => a + x)
    },
    "Stream": {
        "number": (a, b) => a.map((x) => x + b),
        "string": (a, b) => "" + a + b,
        // TODO: Recursive add call? __aa_add(x, y)
        "Stream": (a, b) => a.binaryOp(((x, y) => x + y), b)
    },
    "string": {
        "string": (a, b) => a + b,
        "number": (a, b) => a + b,
        // TODO: String + obj -> toString
    }
    // TODO: Stream + stream
}


// Comparison is only valid between objects of the same type


function genNumericOpMap(op, base) {
    return {
        "number": {
            "number": base,
            "Stream": (a, b) => b.map((x) => op(a,x))
        },
        "Stream": {
            "number": (a, b) => a.map((x) => base(x, b)),
            "Stream": (a, b) => a.binaryOp(op, b)
        },
    }
}


function genBooleanOpMap(op, base) {
    return {
        "boolean": {
            "boolean": base,
            "Stream": (a, b) => b.map((x) => op(a,x))
        },
        "Stream": {
            "boolean": (a, b) => a.map((x) => base(x, b)),
            "Stream": (a, b) => a.binaryOp(op, b)
        },
    }
}

// <, >=
function genComparisonOpMap(op, base) {
    return {
        "number": {
            "number": (a, b) => base(a, b),
            "Stream": (a, b) => b.map((x) => op(a,x))
        },
        "Stream": {
            "number": (a, b) => a.map((x) => op(x, b)),
            "string": (a, b) => a.map((x) => op(x, b)),
            "boolean": (a, b) => a.map((x) => op(x, b)),
            "Stream": (a, b) => a.binaryOp(((x, y) => op(x, y)), b),
        },
        "string": {
            "string": (a, b) => base(a, b),
            "Stream": (a, b) => b.map((x) => op(a, x))
        },
        "boolean": {
            "boolean": (a, b) => base(a, b),
            "Stream": (a, b) => a.map((x) => op(x, b))
        }
        // TODO: Object comparison
    }
}

global.get_behavior = (map, a_type, b_type) => {
    let a_map = map[a_type];
    if(a_map) {
        return a_map[b_type]
    }
    // Undefined
}

global.apply_type_map = (map, a, b, opname= " ") => {
    let a_type = __aa_typeof(a);
    let b_type = __aa_typeof(b);

    let behavior = get_behavior(map, a_type, b_type)
    if(behavior) {
        return behavior(a, b)
    }
    throw Error("Unsupported operation" + opname + "for " + a_type + " and " + b_type)
}


global.__aa_add = (a, b) => {
    return apply_type_map(__aa_add_type_map, a, b, " + ")
}

global.__aa_sub = (a, b) => {
    return apply_type_map(__aa_sub_type_map, a, b, " - ")
}

global.__aa_multiply = (a, b) => {
    return apply_type_map(__aa_multiply_type_map, a, b, " * ")
}

global.__aa_divide = (a, b) => {
    return apply_type_map(__aa_divide_type_map, a, b, " / ")
}

global.__aa_mod = (a, b) => {
    return apply_type_map(__aa_mod_type_map, a, b, " % ")
}

global.apply_boolean = (map, a, b, opname=" ") => {
    let a_type = __aa_typeof(a);
    let b_type = __aa_typeof(b);
    
    let a_val =a;
    let b_val = b;
    if(a_type != "Stream") {
        // Convert everything else to its boolean equivalent
        a_val = !!a
        a_type = "boolean"
    }
    if(b_type != "Stream") {
        b_val = !!b
        b_type = "boolean"
    }
    // TODO: Handling of empty array?
    let behavior = get_behavior(map, a_type, b_type)
    if(behavior) {
        return behavior(a, b)
    }
    // There should be no unhandled cases
}


global.__aa_and = (a, b) => {
    return apply_boolean(__aa_and_type_map, a, b, " and ")
}


global.__aa_or = (a, b) => {
    return apply_boolean(__aa_or_type_map, a, b, " or ")
}


global.__aa_sub_type_map = genNumericOpMap(global.__aa_sub, (a, b) => a - b);
global.__aa_multiply_type_map = genNumericOpMap(global.__aa_multiply, (a, b) => a * b);
global.__aa_divide_type_map = genNumericOpMap(global.__aa_divide, (a, b) => a / b);
global.__aa_mod_type_map = genNumericOpMap(global.__aa_mod, (a, b) => a % b);
global.__aa_and_type_map = genBooleanOpMap(global.__aa_and, (a, b) => a && b);
global.__aa_or_type_map = genBooleanOpMap(global.__aa_or, (a, b) => a || b);


global.__aa_lt = (a, b) => { return apply_type_map(__aa_lt_type_map, a, b, " < ")   }
global.__aa_gt = (a, b) => { return apply_type_map(__aa_gt_type_map, a, b, " > ")   }
global.__aa_lte = (a, b) => { return apply_type_map(__aa_lte_type_map, a, b, " <= ")   }
global.__aa_gte = (a, b) => { return apply_type_map(__aa_gte_type_map, a, b, " >= ")   }

global.__aa_eq = (a, b) => { 
    let a_type = __aa_typeof(a);
    let b_type = __aa_typeof(b);

    if(a_type == "Stream") {
        if(b_type == "Stream") {
            return a.binaryOp(((x, y) => x === y), b)
        } else {
            return a.map((x) => x == b)
        }
    }
    else if(b_type == "Stream") {
        // a_type != Stream
        return b.map((x) => a === x)
    }
    else if(a_type == b_type) {
        return a === b
    }
    else {
        // Strong typing. No coercion between types. Assuming all numeric types result as number
        // TODO: Separate isNaN operator since NaN != NaN
        return false
    }
}

global.__aa_neq = (a, b) => {
    return __aa_not(_aa_eq(a, b))
}

global.__aa_not = (a) => { 
    let a_type = __aa_typeof(a);
    if(a_type == "Stream") {
        return a.map((x) => __aa_not(x))
    } else {
        // Auto-cast to bool and not it
        return !a
    }
}



global.__aa_lt_type_map = genComparisonOpMap(global.__aa_lt, (a, b) => a < b)
global.__aa_gt_type_map = genComparisonOpMap(global.__aa_gt, (a, b) => a > b)
global.__aa_lte_type_map = genComparisonOpMap(global.__aa_lte, (a, b) => a <= b)
global.__aa_gte_type_map = genComparisonOpMap(global.__aa_gte, (a, b) => a >= b)
// TODO: Special case for eq
global.__aa_eq_type_map = genComparisonOpMap(global.__aa_eq, (a, b) => a === b)


global.__str_builtins = {
    "length": "length",
    "replace": "replace",
    "add": "concat",
    "slice": "slice",
    "uppercase": "toUpperCase",
    "lowercase": "toLowerCase",
    "starts_with": "startsWith",
    "ends_with": "endsWith",
}


global.__aa_attr = (left, right) => {
    if(typeof left == "string") {
        if(right == "split" || right == "chars") {
            // TODO: Wrap in stream
            if(right == "split") {
                return function(...args) {
                    return Stream.array(left.split(...args))
                }
            } else {
                return function() {
                    return Stream.array(Array.from(left))
                }
            }
        }

        var jsFunName = __str_builtins[right]
        if(typeof left[jsFunName] == "function") {
            // hello.toUpperCase
            return function(...args) {
                return left[jsFunName](...args)
            }
        } else {
            // "hello".length
            return left[jsFunName]
        }
    }
    if('attr' in left) {
        return left.attr(right)
    }
    return left[right]
    
}

global.__aa_call = (fn, ...args) => {
    if(typeof fn == "function") {
        return fn(...args)
    }
    else {
        // Note that spread syntax doesn't work with .call when it's a native function
        // ((...args) => "hello"["charAt"](...args)).call(2)
        return fn.call(...args)
    }
}

global.math = {
    "abs": Math.abs,
    "sqrt": Math.sqrt,
    "log": (a, b=undefined) => {
        if(b == undefined) {
            return Math.log(a)
        } else {
            return Math.log(a) / Math.log(b)
        }
    },
    "e": Math.E,
    "pi": Math.PI,

// TODO: Trig functions    
    "ceil": Math.ceil,
    "floor": Math.floor,
    "truncate": Math.trunc,
    "round": Math.round,
    "min": Math.min,
    "max": Math.max,
}

// TODO: Constants for min and max number

global.sum = function(stream) {
    let total = 0;
    let it = stream.iter();
    let elem =  it.next();
    while(!elem.done){
        total += elem.value
        elem = it.next();
    }
    return total
}

global.min = function(...args) {
    if(args.length == 1) {
        // Find min in a stream
        return Math.min(...args[0].iter())
    }else {
        return Math.min(...args)
    }
}
global.max = function(...args) {
    if(args.length == 1) {
        return Math.max(...args[0].iter())
    }else {
        return Math.max(...args)
    }
}


export function execJs(code) {
    // TODO: Sandboxed execution
    try {
        return Function(code)()
    } catch(err) {
        console.log("Evaluation error")
        console.log(err);
        console.log(code);
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