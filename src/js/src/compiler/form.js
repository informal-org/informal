/*
Form is the shape of all things. It brings together parts and forms something of them.s
*/

export class MatchError extends Error {}

class Exists {
    constructor(a) {
        this.a = a
    }
    match() {
        return Exists.match(this.a)
    }
    static m(a) {
        // TODO: arrays, objects.
        if(a === undefined || a === ""){
            throw MatchError()
        }
        return a
    }
}

class Equals {
    
}

class Either {
    constructor(a, b) {
        this.a = a
        this.b = b
    }

    match() {
        return Either.match(this.a, this.b)
    }
    static m(a, b) {
        if(a) {
            return a
        } else if(b) {
            return b
        } else {
            throw MatchError()
        }
    }
}