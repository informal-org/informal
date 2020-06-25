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

            if(this.isMatch(key, args)) {
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
    constructor(name="", type=null, params=[], guard=null) {
        this.name = name
        this.type = type
        // List of Abstract Identifiers
        this.params = params
        this.guard = guard      // Conditional function
        this.__type = "KeySig"
        this.$aa_key = "@" + genID();
    }

    isMatch(args) {
        // TODO: Named argument match in the future
        // TODO: Ommited arguments support?
        if(this.params.length != args.length) {
            return false;
        }

        // Pairwise match each parameter since lengths are equal
        for(var i = 0; i < this.params.length; i++) {
            let param = this.params[i];
            let arg = args[i];

            if(typeof param == "object" && param.__type == "KeySig") {
                if(param.type !== null) {
                    // TODO: Type check
                }
                if(param.guard !== null) {
                    // TODO: Generator support for param guards.
                    if(!param.guard(...args)) {
                        return false;
                    }
                }
            } else {
                // It's a raw value. Do pattern matching
                // TODO: type checking here?
                if(param !== arg) {
                    return false
                }
            }
        }

        // All of the parameters match, check guards.
        if(this.guard !== null) {
            if(!this.guard(...args)) {
                return false;
            }
        }


        return true;
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
