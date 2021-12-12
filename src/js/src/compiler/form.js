/*
Form is the shape of all things. It brings together parts and forms something of them.s
*/

export class MatchError extends Error {}

// Exists could be defined as
// Exists(input) => fn () => { ... }
// Exists() => fn(input) => { ... }
const Exists = () => {
    return (input) => {
        // TODO: arrays, objects.
        if(a === undefined || a === ""){
            throw MatchError()
        }
        return a
    }
}

const Equals = (value) => {
    return (input) => {
        if(input === value) {
            return input
        }
        throw MatchError()
    }
}

const Either = () => {
    return (a, b) => {
        if(Exists)
    }
}

const Variable {
    // Can be assigned a value
}

const Any {
    // Equivalent to . in Regex (not *). A single any character. 
}

const Choice {

}

// ... operator
const Many {

}

const Optional {

}

const Form {
    // Form takes input. Has shape.
}

const Forms {
    // Multiple pattern definitions to check
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