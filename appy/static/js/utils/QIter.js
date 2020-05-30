export class QIter {
    constructor(queue) {
        this.queue = queue;
        this.it = this.queue.head;
    }

    next() {
        if(this.it) {
            // let value = this.it.value;
            this.it = this.it.right;
            return this.it.value
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