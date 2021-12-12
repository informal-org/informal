/*
Form is the shape of all things. It brings together parts and forms something of them.
*/

export class MatchError extends Error {}

// Exists could be defined as
// Exists(input) => fn () => { ... }
// Exists() => fn(input) => { ... }

function check() {

}
function match() {

}
function generate() {

}

class Base {
    constructor() {
        this.structure = undefined;
    }
    check(){}
    match(){}
    generate(){}
}

class Empty extends Base {
    constructor() {
        this.structure = Or(Equals(undefined), Equals(""))
    }
}

class Exists extends Base {
    constructor() {
        this.structure = Not(Empty())
    }
}

class Equals {
    constructor(value) {
        this.value = value
        // No structure - this is a primitive.
    }
    check(input) {
        return this.value === this.input
    }
    match(input) {
        if(this.check(input)) {

        }
    }
}

// This should really be defined on Types/classes
// Not of Any = None. Not (None) = Any
// Not of String
class Not {
    constructor(value) {
        this.value = value
    }
}

class Or {
    constructor(a, b) {
        this.a = a
        this.b = b
    }
}

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
    // Universal set 
}

class None {

}

class Char {
    // Set of all characters. Matches any Character.
}

class Text {
    constructor() {
        this.structure = new Many(new Char())
    }
}

// String operations can be defined declaratively as well
// Starts with = Many(new Char())

const Choice {

}

// ... operator
class List {
    // An arbitrary list of elements.
    // More = 1 or more
    // Many = 0 or more instances of something?
    // Some conflicts with the Rust definition of the same word.
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