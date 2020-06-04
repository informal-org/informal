import { genID, isObject, isFunction } from "../utils"


export class Obj {
    constructor(data) {
        // pseudokey -> value
        this._values = {};
        // pseudokey -> key
        this._keys = {};
        this.$aa_key = "@" + genID();
        this.data = data;
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
            // Use numeric keys as-is without any modification
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
        }
    }

    lookup(key, fallback=undefined) {
        let pseudokey = this.getPseudoKey(key);
        return pseudokey in this._values ? this._values[pseudokey] : fallback;
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
        console.log("Is match?")
        console.log(key);
        console.log(args);
        // Pattern match against the key, not the value
        // The value may be a function, but we're checking the key match
        if(Array.isArray(key)) {
            return key.length === args.length
        } else {    // Assert: is Obj otherwise
            if(Array.isArray(key.data)) {
                return key.data.length === args.length
            }
            if(args.length === 1) {
                // For object key match, assume single arg object.
                // Shallow check of object keys against obj keys
                let arg = args[0];
                // Compare keys array
                return JSON.stringify(arg.pseudokeys()) === JSON.stringify(key.pseudokeys())
            }
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
            return this.lookup(args[0])
        } else {
            // Linear search for a match with all non-standard keys
            let keys = Object.keys(this._keys);
            for(var i = 0; i < keys.length; i++) {
                let pseudokey = keys[i];
                let key = this._keys[pseudokey];

                if(this.isMatch(key, args)) {
                    let val = this._values[pseudokey];
                    return val.call(...args)
                }
            }
            console.log("No match found in call");
        }
    }
}

