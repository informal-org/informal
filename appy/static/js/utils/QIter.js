export class QIter {
    constructor(queue) {
        this.queue = queue;
        this.it = this.queue.head;
    }

    next() {
        if(this.it) {
            this.it = this.it.right;
            return this.it.value
        }
    }

    lookahead(n) {
        let peek_it = it;
        for(var i = 0; i < n; i++) {
            if(peek_it) {
                peek_it = peek_it.right
            } else {
                // peek(n) doesn't exist then
                return
            }
        }
        if(peek_it) {
            return peek_it.value
        }
    }

    peek() {
        return this.lookahead(0)
    }

    reset() {
        this.it = this.queue.head;
    }
}