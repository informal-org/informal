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