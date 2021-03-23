// Pseudokey -> value for plain values
// For relational multiple values redefined, store as Choice

import { enableMapSet } from "immer"
enableMapSet()
import produce from "immer"
import { isNumber, isSymbol } from "@informal/shared/type"

// AbstractForm is logical implication, indicated by = informally. Key => implies value
// An ordered directed graph representing the relation between a key and many values
export class AbstractForm {
    constructor(kv=undefined) {
        this._map = kv === undefined ? new Map() : kv;
    }

    _build(map) {
        return new AbstractForm(map)
    }

    set(key, value) {
        return this._build(produce(
            this._map, (map) => {
                if(map.has(key)) {
                    // Relational maps can contain multiple values for a single key
                    let oldVal = map.get(key);
                    value = oldVal instanceof Choice ? oldVal.addChoice(value) : new Choice(oldVal, value)
                }
                map.set(key, value)
            }
        ))
    }

    resolve(key) {
        // Resolve a variable reference to its base value. Should be tail-call optimized
        return isSymbol(key) && this._map.has(key) ? this.resolve(this._map.get(key)) : key
    }

    // Future: This may be namespaced. Get(symbol) to get its value.
    symbolFor(name) {
        return Symbol.for(name)     // Note - Symbol is primitive. Don't use "new"
    }
    
    keys() {
        return this._map.keys()
    }

    values() {
        return this._map.values()
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
        if(type instanceof AbstractForm) {
            return type.bind(value) !== null
        }
        // TODO: Type check for primitive types
        return false
    }

    // TODO: This should be an iterable. 
    // (a : Int, b: Int) bind (2: Int, 3: Int) = (a: 2, b: 2)
    bind(args) {
        // Structural match two objects by key and any type-constraints.
        var i = 0;
        let bindings = this;

        for([param, type] of this._map.entries()) {
            let arg = args[i]

            bindings = bindings.unify(type, arg)

            // if(isSymbol(param) && this.typecheck(bindings.resolve(type), arg)) {
            //     // TODO: The type should give back the value if it matches.
            //     bindings = bindings.set(param, arg)
            // } else if(param === arg) {
            //     bindings = bindings.set(param, arg)
            // } else {
            //     return null;
            // }
            i++;
        }
    }

    select(args) {
        // Select and bind the key pattern that matches the args
        for([signature, body] of this._map.entries()) {
            if(signature instanceof AbstractForm) {
                let bindings = signature.bind(args)
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
            let [bindings, body] = this.select(args)
            return body(...bindings.values().slice(1))
        }
    }

    toString() {
        return "Form {" + this._map.entries() + "}"
    }
}

// Form is implication (material implication), indicated by : informally. Key -> implies type
// Directed, unordered map. Transformation. Mapping.
class Form extends AbstractForm {
    _build(map) {
        return new Form(map)
    }
}

// Compound form glues forms together. ex. when having both a type (abstract) and value (form). 
// Ordered list (linked list/array). Positional.
class CompoundForm extends Form {
    _build(map) {
        return new CompoundForm(map)
    }
}

