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
            let val = this.findMatch(args);
            if(val) {
                return val.call(...args)
            }
            console.log("No match found in call");
        }
    }

    findMatch(args) {
        // Linear search for a match with all non-standard keys
        let keys = Object.keys(this._keys);
        for(var i = 0; i < keys.length; i++) {
            let pseudokey = keys[i];
            let key = this._keys[pseudokey];

            if(this.isMatch(key, args)) {
                let val = this._values[pseudokey];
                return val
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


const OP_FILTER = 1;
const OP_MAP = 2;

export class Stream {
    constructor(source) {
        // Source: A generator for values. May be infinite
        this.source = source
        this.operations = []
        // TODO: Future optimization flags to maintain between ops
        this.sized = false;
        this.sorted = false;
        this.distinct = false;
        this.length = undefined;
        // Store cached computed value
        this._computed = undefined;
    }

    filter(fn) {
        return this.addOperation({'type': OP_FILTER, 'fn': fn})
    }

    map(fn) {
        return this.addOperation({'type': OP_MAP, 'fn': fn})
    }

    addOperation(operation) {
        let s = this.clone();
        s.operations.push(operation)
        return s
    }

    clone() {
        let s = new Stream(this.source);
        s.operations = [...this.operations]      // Clone
        return s
    }

    // TODO: Common variant of this which just takes stop
    static range(start, stop, step=1) {
        // Returns a lazy generator for looping over that range
        return new Stream(function* () {
            for(var i = start; i < stop; i += step) {
                yield i
            }
        })
    }

    // TODO: These internal methods should not be exposed
    static array(arr) {
        // Wraps an array object in an iterator
        return new Stream(function* () {
            for(var i = 0; i < arr.length; i++) {
                yield arr[i]
            }
        })
    }

    * iter() {
        // Iterate over this stream
        let source_iter = this.source()
        let data;
        while(true) {
            data = source_iter.next()
            if(data.done) {
                break
            }
            
            let value = data.value;
            let finished = true;    // Remains true only if all operations complete successfully
            for(var op_index = 0; op_index < this.operations.length; op_index++) {
                let op = this.operations[op_index];
                if(op.type == OP_FILTER) {
                    if(!op.fn(value)) {
                        finished = false;
                        break;
                    }
                } else if(op.type == OP_MAP) {
                    value = op.fn(value);
                }
            }
            if(finished) {
                yield value;
            }
        }
    }

}

