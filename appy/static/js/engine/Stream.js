import { __aa_call } from "../utils"

const OP_FILTER = 1;
const OP_MAP = 2;
const OP_BINARY = 3;
const OP_COMBINED_FILTER = 4;
const OP_FOLD = 5;



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

        this.map = this.map.bind(this);
        this.filter = this.filter.bind(this);
        this.reduce = this.reduce.bind(this);
        this.max = this.max.bind(this);
        this.min = this.min.bind(this);
        this.fn_map = {
            'map': this.map,
            'filter': this.filter,
            'reduce': this.reduce,
            'max': this.max,
            'min': this.min
        }
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

    filter(fn) {
        // todo: flags
        return this.addOperation({'type': OP_FILTER, 'fn': fn})
    }

    map(fn) {
        // todo: flags
        return this.addOperation({'type': OP_MAP, 'fn': fn})
    }

    reduce(fn, init=undefined) {
        // Terminal operation. Apply the function and return the value.
        let result;
        let it = this.iter();
        let elem = it.next();
        if(init == undefined) {
            result = elem.value;
            elem = it.next();
        } else {
            result = init;
        }
        
        while(!elem.done) {
            result = __aa_call(fn, result, elem.value)
            elem = it.next();
        }
        return result
    }

    max(){          // Terminal operation
        return Math.max(...Array.from(this.iter()))
    }

    min(){          // Terminal operation
        return Math.min(...Array.from(this.iter()))
    }

    attr(fn_name) {
        if(fn_name == "length") {
            return this.length
        }
        return this.fn_map[fn_name]
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
                    if(!__aa_call(op.fn, value)) {
                        finished = false;
                        break;
                    }
                } else if(op.type == OP_MAP) {
                    value = __aa_call(op.fn, value);
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
                        value = __aa_call(op.fn, value, right_elem.value);
                    }
                } else if(op.type == OP_COMBINED_FILTER) {
                    let right;
                    if(right_idx < right_iters.length) {
                        right = right_iters[right_idx++]
                    } else {
                        // Note: op.fn here vs op.right above since this isn't really a binary op
                        // More of an op between two streams
                        right = __aa_call(op.fn);
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

    * first(n) {
        let it = this.iter();
        for(var i = 0; i < n; i++) {
            let val = it.next();
            if(val.done) {
                break
            }
            yield val.value
        }
        
    }

}
