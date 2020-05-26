import { genID, isObject } from "../utils"


export class Obj {
    constructor() {
        this._values = {};
        this._keys = {};
        this._aakey = "@" + genID();
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

    getKey(pseudokey) {
        if (Number.isInteger(pseudokey)) {
            return pseudokey
        } else if (pseudokey.startsWith("_")) {
            // String key. Just remove prefix.
            return pseudokey.slice(1)
        } else if(pseudokey in this._keys) {
            return this._keys[pseudokey]
        }
    }
}

