import { genID, isObject, isFunction } from "../utils"

export class Obj {
    /*
    A more generic object type which support object keys 
    rather than just string keys like JS objects.
    */

    constructor(kv=[]) {
        // pseudokey -> value
        this._values = {};
        // pseudokey -> original key object
        this._keys = {};
        this.$aa_key = "@" + genID();
        this.__type = "Obj"
        this._attrs = {};

        kv.forEach(([key, value]) => {
            this.insert(key, value);
        })
    }
    getPseudoKey(key) {
        // Convert a key of unknown type to a unique string identifier.
        if(isObject(key)) {
            // Generate and cache key for future use with this exact obj.
            if(key.$aa_key === undefined) {
                key.$aa_key = "@" + genID();
            }
            return key.$aa_key
        } else if (Number.isInteger(key)) {
            // Use numeric keys as-is without any modification so v8 stores as arrays.
            return key
        } else {
            // For string-y keys, append a prefix to prevent collision with objs
            // this._values["_" + key] = value
            return "_" + key
        }
    }

    insert(key, value) {
        let pseudokey = this.getPseudoKey(key)
        this._values[pseudokey] = value
        // If it's an object, save the original key as well for retrieval.
        // For other types, it can be computed
        if(isObject(key)) {
            this._keys[pseudokey] = key
            
            if(key.__type == "KeySig" && key.name) {
                if(key.name in this._attrs) {
                    this._attrs[key.name].push(pseudokey)
                } else {
                    this._attrs[key.name] = [pseudokey]
                }
            }
        }
    }

    // map[]
    lookup(key, fallback=undefined) {
        let pseudokey = this.getPseudoKey(key);
        return pseudokey in this._values ? this._values[pseudokey] : fallback;
    }

    // obj.attr
    attr(key) {
        // TODO: Handling multiple definitions
        if(key in this._attrs) {
            let matches = this._attrs[key];
            return this._values[matches[0]]
        }
    }

    hasKey(key) {
        let pseudokey = this.getPseudoKey(key)
        return pseudokey in this._values
    }

    getKey(pseudokey) {
        // Check if it's a numeric string. Still may not be an integer
        if (!isNaN(pseudokey)) {
            // Note: Floats would be handled in the string branch
            return parseInt(pseudokey)
        } else if (pseudokey.startsWith("_")) {
            // String key. Just remove prefix.
            return pseudokey.slice(1)
        } else if(pseudokey in this._keys) {
            return this._keys[pseudokey]
        }
    }

    pseudokeys() {
        // Return the value keys, which contain everything including the
        // inferred keys.
        return Object.keys(this._values)
    }

    isMatch(key, args) {
        // Pattern match against the key, not the value
        // The value may be a function, but we're checking the key match
        // if(Array.isArray(key)) {
        //     return key.length === args.length
        // } else {    // Assert: is Obj otherwise
        //     if(Array.isArray(key.data)) {
        //         return key.data.length === args.length
        //     }
        //     if(args.length === 1) {
        //         // For object key match, assume single arg object.
        //         // Shallow check of object keys against obj keys
        //         let arg = args[0];
        //         // Compare keys array
        //         return JSON.stringify(arg.pseudokeys()) === JSON.stringify(key.pseudokeys())
        //     }
        // }
        // return false
        if(typeof key == "object" && key.__type == "KeySig") {
            return key.isMatch(args)
        }
        return false
    }

    call(...args) {
        // Call this object as a function with obj as args.
        if(isFunction(this.data)) {
            // Spread args except on single params, which may be objects
            if(args.length == 0) {
                return this.data()
            } else if (args.length == 1) {
                return this.data(args[0])
            } else {
                return this.data(...args)
            }
        }
        else if(args.length === 1 && this.hasKey(args[0])) {
            // TODO: Named attribute lookup should be handled differently
            return this.lookup(args[0])
        } else {
            let val = this.findMatch(args);
            if(val) {
                return val(...args)
            }
            console.log("No match found in call");
        }
    }

    getAttr(attr) {
        if(this.hasKey(attr)) {
            return this.lookup(attr);
        } else {
            // Look through named args
            let pseudokeys = Object.keys(this._keys);
            for(var i = 0; i < pseudokeys.length; i++) {
                let pseudokey = pseudokeys[i];
                let key = this._keys[pseudokey];

                if(key.name != null && key.name === attr) {
                    return this._values[pseudokey]
                }
            }
        }
    }

    findMatch(args) {
        // Linear search for a match with all non-standard keys
        let pseudokeys = Object.keys(this._keys);
        for(var i = 0; i < pseudokeys.length; i++) {
            let pseudokey = pseudokeys[i];
            let key = this._keys[pseudokey];

            let matchBindings = this.isMatch(key, args)
            if(matchBindings !== false) {
                // todo: return values + bindings
                return this._values[pseudokey];
            }
        }
    }

    callInterpreted(args) {
        // Call this object as a function with obj as args.
        if(isFunction(this.data)) {
            // Spread args except on single params, which may be objects
            this.data(args)
        }
        else if(args.length === 1 && this.hasKey(args[0])) {
            return this.lookup(args[0])
        } else {
            let val = this.findMatch(args);
            if(val) {
                return val.callInterpreted(args)
            }
            console.log("No match found in call");
        }
    }
}

// A generic signature used as keys in objects.
// May denote an attribute, a guard, a param, a func or some combo of those.
export class KeySignature {
    // Params - made up of raw values, value patterns (i.e. destructuring) and "normal" typed parameters
    constructor(name="", type=null, params=[], guard=null, optional_index=1000, rest_param=false) {
        this.name = name
        this.type = type
        // List of Abstract Identifiers
        this.params = params
        this.guard = guard      // Conditional function

        // Index where optional args start. Atleast that many args are required
        this.optional_index = Math.min(optional_index, params.length)

        // Index in params where a ... appears. optional_index > many_index
        this.rest_param = rest_param
        
        this.__type = "KeySig"
        this.$aa_key = "@" + genID();
    }

    isMatch(args) {
        let raw_args = args;
        // Lower bound: Has at least the minimum number of arguments
        if(args.length < this.optional_index) {
            console.log("Args lower bound don't match")
            console.log(args.length)
            console.log(this.optional_index)
            return false;
        }

        let rest;
        // Args has an upper bound if it doesn't have a rest param
        if(this.rest_param) {
            // Then slice it into pieces at the boundary
            let primary_params = args.slice(0, this.params.length - 1)
            rest = args.slice(this.params.length - 1)
            args = primary_params
        } else if(args.length > this.params.length) {   // Else if fixed number of args, ensure upper bound
            console.log("Args upper bound don't match")
            return false
        }

        let upper_bound = Math.min(this.rest_param ? this.params.length - 1 : this.params.length, 
            args.length)

        let bindings = {}

        // Args is atleast as long as optional_args, may be longer than params
        for(var i = 0; i < upper_bound; i++) {
            let param = this.params[i];
            let arg = args[i];

            // TODO: Destructuring pattern support
            if(typeof param == "object" && (param.__type == "KeySig" || param.__type == "Param")) {
                let value_type = typeof arg;
                if(value_type === "object" && "__type" in value) {
                    value_type = value.__type
                }

                if(param.type !== null && param.type !== value_type) {
                    console.log("Arg parameter type doesn't match")
                    return false
                }

                if(param.guard) {
                    // TODO: Generator support for param guards.
                    if(!param.guard(...raw_args)) {
                        return false;
                    }
                }

                bindings[param.name] = arg
            } else {
                // It's a raw value. Do pattern matching
                // TODO: type checking here?
                if(param !== arg) {
                    return false
                }
            }
        }
        // Do a check for the rest param
        if(this.rest_param) {
            let param = this.params[this.params.length - 1];
            // Rest param can't be a value. It may have a type.
            if(typeof param == "object" && (param.__type == "KeySig" || param.__type == "Param")) {
                // todo - type check for rest array
                bindings[param.name] = rest
            }
        }

        // All of the parameters match, check guards.
        if(this.guard !== null) {
            if(!this.guard(...raw_args)) {
                return false;
            }
        }

        return bindings;
    }

    toString() {
        let signature = "";
        if(this.type) {
            signature += this.type + " "
        }
        if(this.name) {
            signature += this.name
        }
        if(this.params.length > 0) {
            signature += "(" + this.params.join(", ") + ")"
        }
        if(this.guard) {
            // todo
            // signature += " [" + this.guard + "]"

            signature += " if(" + this.guard + ")"
        }
        return signature
    }
}

// Signature
// return_type, name, guard, list of parameters/values (raw_value/param obj)
export class Param {
    // Params that are static values will be placed directly in list
    constructor(type, name, default_value=undefined) {
        this.type = type
        this.name = name
        this.default_value = default_value
        this.__type = "Param"
    }
}

