export function traverseDown(cell, cb, ...args) {
    // General pattern of iteration used across most functions
    let paramReturns = cell.params.map((param) => {
        return cb(param, ...args)
    });

    let bodyReturns = cell.body.map((child) => {
        return cb(child, ...args)
    });

    return [paramReturns, bodyReturns]
}

export function traverseDownCell(cell, cb, ...args) {
    let paramReturns = cell.params.map((param) => {
        return cb(param, ...args)
    })
    let body = cell.orderCellBody();
    let bodyReturns = body.map((child) => {
        return cb(child, ...args)
    })
    return [paramReturns, bodyReturns]
}

export function traverseUp(cell, cb, ...args) {
    if(cell.parent) {
        return cb(cell.parent, ...args);
    }
    // Implicitly return undefined at root
}

export class QIter {
    constructor(queue) {
        this.queue = queue;
        this.it = this.queue.head;
    }

    next() {
        if(this.it) {
            let value = this.it.value;
            this.it = this.it.right;
            // return this.it ? this.it.value : undefined
            return value
        }
    }

    current() {
        return this.it.value
    }

    peek() {
        if(this.it && this.it.right) {
            return this.it.right.value
        }
    }

    hasNext() {
        return this.it && this.it.right ? true : false;
    }

    reset() {
        this.it = this.queue.head;
    }

    clone() {
        // Return a new iteration that can be moved independently
        let newIt = new QIter(this.queue)
        newIt.it = this.queue.head;
        return newIt;
    }

}

// Intersperse two arrays together. Example output of [a, b, c], [1, 2, 3]
// a, 1, b, 2, c, 3, b, 1, c, 2, a, 3, c, 1, a, 2, b, 3
export function* intersperseArr(arr, brr) {
    if(arr.length < brr.length) {
        return intersperseArr(brr, arr)
    } else {    // arr is >= than brr
        for(var offset = 0; offset < arr.length; offset++) {
            for(var index = 0; index < arr.length; index++) {
                yield arr[(index + offset) % arr.length];
                yield arr[(index) % brr.length];  // Keep b fixed, no offset.
            }
        }
    }
}

export function* interleave(streamA, streamB) {
    let aDone, bDone = false;
    let aVal, bVal;
    while(!aDone || !bDone) {
        if(!aDone) {
            aVal = streamA.next();
            aDone = aVal.done
            if(!aDone || aVal.value !== undefined) {
                yield aVal.value
            }
        }
        if(!bDone) {
            bVal = streamB.next()
            bDone = bVal.done
            if(!bDone || bVal.value !== undefined) {
                yield bVal.value
            }
        }
    }
}