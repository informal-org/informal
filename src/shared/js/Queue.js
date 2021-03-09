import { Node } from './Node';
// Double-ended linked list queue
export class Queue {
    constructor() {
        this.head = null;
        this.tail = null;
        this.length = 0;
    }
    push(value) {
        // Append to end of queue
        let last = new Node(value, this.tail, null);
        let prev = this.tail;
        if (this.head === null) {
            this.head = last;
        }
        else {
            // if head != null, then prev != null
            prev.right = last;
        }
        this.tail = last;
        this.length += 1;
    }
    shift() {
        // Pop and return the first element
        if (this.length > 0) {
            let original_head = this.head;
            if (original_head.right) {
                // Shift head over to the next node if there is one.
                this.head = original_head.right;
                this.head.left = null;
            }
            else {
                // No elements in queue. head = tail = null.
                this.head = null;
                this.tail = null;
            }
            this.length -= 1;
            return original_head.value;
        }
    }
    asArray() {
        let arr = [];
        let it = this.head;
        while(it !== null) {
            arr.push(it.value)
            it = it.right
        }
        return arr;
    }
}
