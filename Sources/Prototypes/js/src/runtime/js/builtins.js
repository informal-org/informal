import { Obj, KeySignature } from "./flex"
import { Stream } from "./Stream"
import { __aa_call } from "@appassembly/shared"

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


global.__aa_bool = (a) => {
    return !!a
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

global.__aa_uminus = (a) => {
    return -a
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
    if(left === undefined) {
        // TODO: Better errors
        throw Error("No attribute on undefined")
    }
    if('attr' in left) {
        return left.attr(right)
    }
    return left[right]
    
}

global.__aa_call = __aa_call

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

global.range = Stream.range


global.all = function(...args) {
    var it;
    if(args.length == 1) {          // It's a stream
        it = args[0].iter()
    } else {
        it = args.values()
    }

    let elem = it.next();
    while(!elem.done){
        if(!global.__aa_bool(elem.value)){
            return false
        }
        elem = it.next();
    }
    
    return true
}

global.any = function(...args) {
    var it;
    if(args.length == 1) {          // It's a stream
        it = args[0].iter()
    } else {
        it = args.values()
    }

    let elem = it.next();
    while(!elem.done){
        if(global.__aa_bool(elem.value)){
            return true
        }
        elem = it.next();
    }
    
    return false

}