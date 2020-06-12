import { genID, isObject, isFunction } from "../utils"


export class Obj {
    constructor(data) {
        // pseudokey -> value
        this._values = {};
        // pseudokey -> key
        this._keys = {};
        this.$aa_key = "@" + genID();
        this.data = data;
        this.__type = "Obj"
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
const OP_BINARY = 3;
const OP_COMBINED_FILTER = 4;

export class Stream {
    constructor(sources) {
        // Source: A generator for values. May be infinite
        this.sources = sources
        this.operations = []
        // TODO: Future optimization flags to maintain between ops
        this.sized = false;
        this.sorted = false;
        this.distinct = false;
        this.length = undefined;
        this.__type = "Stream"

        // Private cached computed data. Should not be copied over in clone
        this.__cached = []
        this.__cached_iter = undefined;
        // TODO: Optimization - build off of the computed state of the previous node
        // So it doesn't have to do all the operations on iter, just a subset.

        // TODO: Optimization: Store slices of data, so for large generated ranges
        // it will store a sliding window and never more than the window bounds.
    }

    elementAt(index) {
        // TODO: Support negative indexes
        // Get the element at a given index. 
        // Requires serializing the data up to that point into memory

        if(index < this.__cached.length) {
            return this.__cached[index]
        } else {
            if(this.sized && index >= this.length) {
                // Skip iteration if accessing out of bounds
                // TODO: Friendly error message
                throw Error("Index out of bounds")
            }
            if(!this.__cached_iter) {
                this.__cached_iter = this.iter()
            }
            while(index >= this.__cached.length) {
                let elem = this.__cached_iter.next();
                if(elem.done) {
                    // TODO: Friendly error message
                    throw Error("Index out of bounds")
                } else {
                    this.__cached.push(elem.value)
                }
            }
            // assert: cached length = index
            return this.__cached[index]
        }

    }

    get(index) {
        // Index can be one of these:
        // Single index - return single element at index
        // (Future) Single key - return single element by that primary key
        // (Future) List of keys - return list of elements where keys match.
        // (Future) List of indexes - return list of elements at indexes
        // List of boolean flags - return list where flag is true.
        // Return a stream
        
        if(index.__type === "Stream") {
            // Filter by flags index
            return this.addOperation({
                'type': OP_COMBINED_FILTER,
                'fn': function* () {
                    let it = index.iter();
                    while(true) {
                        let elem = it.next();
                        if(elem.done) {
                            break;
                        } else {
                            yield elem.value
                        }
                    }
                }
            })
        } else {
            return this.elementAt(index)
        }

    }

    where(expr) {
        
    }

    filter(fn) {
        // todo: flags
        return this.addOperation({'type': OP_FILTER, 'fn': fn})
    }

    map(fn) {
        // todo: flags
        return this.addOperation({'type': OP_MAP, 'fn': fn})
    }

    binaryOp(fn, right) {
        // todo: flags
        // TODO: Proper handling of binary ops between streams of different lengths
        return this.addOperation({'type': OP_BINARY, 'fn': fn, 'right': right})
    }

    concat(stream) {
        // Lazily combine two streams into one logical stream
        let s = this.clone();
        s.sources.push(stream)
        // Update flags
        if(s.sized && stream.sized) {
            s.length = s.length + stream.length
        } else {
            s.sized = false;
            s.length = undefined;
        }
        // We can't know anything about these when combined.
        s.sorted = false;
        s.distinct = false;
        return s
    }

    addOperation(operation) {
        let s = this.clone();
        s.operations.push(operation)
        return s
    }

    clone() {
        // TODO: Change clone mechanism to point to parent stream instead.
        let s = new Stream([...this.sources]);
        s.operations = [...this.operations]      // Clone
        s.sized = this.sized;
        s.sorted = this.sorted;
        s.distinct = this.distinct;
        s.length = this.length;
        return s
    }

    // TODO: Common variant of this which just takes stop
    // TODO: Omit step?
    static range(start, stop, step=1) {
        // assert: stop < start. TODO: Check
        // Returns a lazy generator for looping over that range
        // TODO: Optimization: Override get to compute elem at index directly
        let s = new Stream([function* () {
            for(var i = start; i < stop; i += step) {
                yield i
            }
        }])
        s.sized = true;
        s.length = Math.ceil((stop-start) / step)

        return s;
    }

    // TODO: These internal methods should not be exposed
    static array(arr) {
        // Wraps an array object in an iterator
        let s = new Stream([function* () {
            for(var i = 0; i < arr.length; i++) {
                yield arr[i]
            }
        }])
        s.__cached = arr
        s.sized = true;
        s.length = arr.length;
        return s;
    }

    * iter() {
        // Iterate over this stream
        let source_index = 0;
        // Assert - there's always atleast one source.
        let source_iter = this.sources[source_index++]()
        let data;
        // Internal stack to store state for any right-hand iterable
        let right_iters = [];
        while(true) {
            data = source_iter.next()
            if(data.done) {
                // Advance to the next iterator or end
                if(source_index < this.sources.length) {
                    // Note: Assert any concat elems are sub-streams.
                    source_iter = this.sources[source_index++].iter()
                    continue;
                } else {
                    break
                }
            }

            let value = data.value;
            let right_idx = 0;      // Index into the internal iterator state for any parallel loops
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
                } else if(op.type == OP_BINARY) {
                    // Retrieve this stateful op from the array
                    let right;
                    if(right_idx < right_iters.length) {
                        // We've seen this op before. Resume from existing iterator state
                        right = right_iters[right_idx++]
                    } else {
                        // Right index >= length. 
                        // Means it's the first time we're seeing this op. Add to array
                        right = op.right.iter()
                        right_iters.push(right)
                        right_idx++
                    }

                    let right_elem = right.next();
                    if(right_elem.done) {
                        // One of the iterators finished before the other
                        finished = false;
                        break;
                    } else {
                        value = op.fn(value, right_elem.value)
                    }
                } else if(op.type == OP_COMBINED_FILTER) {
                    let right;
                    if(right_idx < right_iters.length) {
                        right = right_iters[right_idx++]
                    } else {
                        // Note: op.fn here vs op.right above since this isn't really a binary op
                        // More of an op between two streams
                        right = op.fn();
                        right_iters.push(right);
                        right_idx++;
                    }
                    
                    let right_val = right.next()
                    if(right_val.done || !right_val.value) {
                        finished = false;
                        break;
                    }
                }
            }
            if(finished) {
                yield value;
            }
        }
    }

}

