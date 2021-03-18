// Pseudokey -> value for plain values
// For relational multiple values redefined, store as Choice

import { enableMapSet } from "immer"
enableMapSet()
import produce from "immer"
import { isNumber, isSymbol } from "@informal/shared/type"

export class Obj {
    constructor(kv=undefined, id=undefined) {
        this._map = kv === undefined ? new Map() : kv;
        this._id = id === undefined ? Obj.MAX_ID++ : id;
        this._type = "Obj"
    }

    set(key, value) {
        return new Obj(produce(
            this._map, (map) => {
                if(map.has(key)) {
                    // Relational maps can contain multiple values for a single key
                    let oldVal = map.get(key);
                    value = oldVal instanceof Choice ? oldVal.addChoice(value) : new Choice(oldVal, value)
                }
                map.set(key, value)
            }
        ), this._id)
        // Should the derived object have the same ID or a different one?
        // We can check exact equality with ===, so use this for derived equality.
    }

    get(key) {
        // TODO: Fallback/default needed?
        return this._map.get(key)
    }

    resolve(key) {
        // Resolve a variable reference to its base value. Should be tail-call optimized
        return isSymbol(key) && this._map.has(key) ? this.resolve(this._map.get(key)) : key
    }

    // Symbols are used as namespaced variables.
    // Get(symbol) to get its value.
    symbolFor(name) {
        // Note - Symbol is primitive. Don't use "new"
        // return name in this._symbols ? this._symbols[name] : this._symbols[name] = Symbol(name)
        return Symbol.for("@" + this._id + "." + name)
    }

    has(key) {
        return this._map.has(key)
    }

    keys() {
        return this._map.keys()
    }

    // Unify symbol variables A and B in this given state.
    unify(a, b) {
        a = this.resolve(a);
        b = this.resolve(b);

        // Already unified
        // TODO: Stricter equality?
        if(a === b) {    return this     }
        else if(isSymbol(a)) {
            return this.set(a, b)
        } else if(isSymbol(b)) {
            return this.set(b, a)
        }

        return null     // Could not unify
    }

    // TODO: This should be checked in the bindings context.
    typecheck(type, value) {
        // For the minimal version, each value just has a single type
        if(typeof type == "object" && type.__type == "Obj") {
            return type.structuralMatch(value) !== null
        }
        // TODO: Type check for primitive types
        return false
    }

    // TODO: This should be an iterable. 
    structuralMatch(args) {
        // Match two objects by key and any type-constraints.
        var i = 0;
        let bindings = this;

        for([param, type] of this._map.entries()) {
            let arg = args[i]
            if(isSymbol(param) && this.typecheck(bindings.resolve(type), arg)) {
                // TODO: The type should give back the value if it matches.
                bindings = bindings.set(param, arg)
            } else if(param === arg) {
                bindings = bindings.set(param, arg)
            } else {
                return null;
            }
            i++;
        }
    }

    match(args) {
        for([signature, body] of this._map.entries()) {
            if(typeof signature == "object" && signature.__type == "Obj") {
                let bindings = signature.structuralMatch(args)
                if(bindings !== null) {
                    return [bindings, body]
                }
            }
        }
    }

    call(...args) {
        if(args.length == 1 && this._map.has(args[0])) {
            return this._map.get(args[0])
        }else {

        }
    }

    toString() {
        return "Obj{" + this._map.entries() + "}"
    }
}

Obj.MAX_ID = Obj.MAX_ID === undefined ? 0 : Obj.MAX_ID;

export class Value {
    constructor(value, types) {
        this.value = value      // Literal or expression
        this.types =  types     // Type array
    }
}

export class Invocation {
    constructor(fn, ...args) {
        this.fn = fn
        this.args = args
    }
}

export class Choice {
    constructor(...choices) {
        this.choices = choices
    }
    addChoice(option) {
        return new Choice(...this.choices, option)
    }
}



// export class Pattern {
//     // Match function:
//     // Return [match, restOfPattern] or false

//     match() {
//         // Objects of {fn: fn, args: [args]}
//         let choices = [];

//         while(choices.length > 0) {   // todo

//             let m = match();
//             if(m.next) {
//                 choices.push(m.next)
//             }

            

//         }




//     }
// }

// class StrPattern {
//     constructor(pattern) {
//         this.pattern = pattern;
//     }
//     // partial match. TODO: Separate functions for partial vs exact match?
//     match(value) {
//         if(value.startsWith(this.pattern)) {
//             return [str, value.slice(str.length)]
//         }
//     }
// }

// class ValuePattern {
//     constructor(pattern) {
//         this.pattern = pattern;
//     }
//     match(value) {
//         return this.pattern === value
//     }
// }

// class ChoicePattern {
//     constructor(...args) {
//         this.patterns = args;
//     }
//     * match(value) {
//         let pMatch;
//         for(var i = i; i < this.patterns.length; i++) {
//             let pMatch = this.patterns[i].match(value);
//             if(pMatch !== false) {
//                 yield pMatch
//             }
//         }
//     }

//     match(value, index) {
//         if(index < this.patterns.length) {
//             let next = index + 1 < this.patterns.length ? {
//                 fn: this.match,
//                 args: [value, index+1]
//             } : null;

//             return {
//                 result: this.patterns[index].match(value),
//                 next: next
//             }
//         }
//         return {}
//     }
// }

// class ListPattern {
//     constructor(...args) {
//         this.patterns = args;
//     }

//     match(value, partial) {
//         // let choices = [];
//         // This iteration is responsible for finding the single next element.
//         if(partial.length < this.patterns.length){
//             let fn = this.patterns[partial.length].match;
//             let args = [value]

//             do {
//                 let pMatch = fn(...args);
//                 // if(pMatch._next) {
//                     // If the current choice doesn't work, what result to try next.
//                     // pMatch._next["partial"] = partial.slice();     // clone
//                     // choices.push(pMatch._next);
//                 // }
    
//                 if(pMatch.result) {
//                     // Clone current state and add this as a result
//                     let newPartial = partial.slice().push(pMatch.result.match);
//                     let withThisChoice = this.match(pMatch.result.value, newPartial);
//                     if(withThisChoice) {
//                         return withThisChoice
//                     }
//                 }

//                 fn = pMatch.next.fn;
//                 args = pMatch.next.args
//             } while(fn !== null)
//         }

//         // for(var i = partial.length; i < this.patterns.length; i++) {
            
//         // }
//     }

//     match(value) {
//         let pMatch;
//         let hasMatch = this.patterns.every((p) => {
//             return pMatch = p.match(value)
//         });
//         // Todo: Return value for list patterns.
//         return hasMatch
//     }
// }

// class ObjPattern {
//     constructor(...args) {

//     }
//     match(value) {

//     }
// }

// export class RangePattern {
//     constructor(start, end=null) {
//         this.start = start;
//         this.end = end;
//     }

//     match(value) {
//         if(this.start !== null && value >= this.start) {
//             if(this.end !== null && value >= this.end) {
//                 return false
//             }
//             return true
//         }
//         return false
//     }
// }

// class NotPattern {
//     constructor(expr) {
//         this.expr = expr;
//     }
//     match(value) {
//         return this.expr.match(value) === false ? true : false;
//     }
// }

// export class PatternMap {

// }


// function Optional(token) {
//     return new ChoicePattern(token, "")
// }

// // For objects
// // name (optional) type (optional) value (optional)
// // <numeric id> - Literal
// // Keys ordered
// // Matching an object = matching all of the clauses.
// // Match should be defined using pattern matching.

// continuation = {
//     result: result,
//     fn: func,
//     args: []
// }

// check
// output
// solve
// choice - this is the critical step. 
// If you can re-order the choices, you can apply smart heuristics.
// first
// next(P, s)

// accept, reject callbacks.