import { genID, isObject, isFunction } from "../utils"


export class Obj {
    constructor(data) {
        this._values = {};
        this._keys = {};
        this._aakey = "@" + genID();
        this.data = data;
    }
    getPseudoKey(key) {
        // Convert a key of unknown type to a unique string identifier.
        if(isObject(key)) {
            // Generate and cache key for future use with this exact obj.
            if(key._aakey === undefined) {
                key._aakey = "@" + genID();
            }
            return key._aakey
        } else if (Number.isInteger(key)) {
            // Use numeric keys as-is without any modification
            return key
        } else {
            // For string-y keys, append a prefix to prevent collision with objs
            this._values["_" + key] = value
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

    call(obj) {
        // Call this object as a function with obj as args.
        console.log(this.data + " : " + isFunction(this.data))
        if(isFunction(this.data)) {
            console.log("Evaluating function")
            // TODO: Argument expansion
            let result = this.data(obj)
            console.log(result);
            return result;
        }
        else if(this.hasKey(obj)) {
            return this.lookup(obj)
        } else {
            // Linear search for a match with all non-standard keys
            let keys = Object.keys(this._keys);
            for(var i = 0; i < keys.length; i++) {
                let pseudokey = keys[i];
                let key = this._keys[pseudokey];

                // TODO: Key match check
                if(true) {
                    let val = this._values[pseudokey];
                    return val.call(obj)
                }
            }
        }
    }
}

