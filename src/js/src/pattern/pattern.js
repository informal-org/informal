/* 
*/

class Atom {
    constructor(name) {
        // Name: String
        this.name = name
    }
}

class Parameters {
    constructor(params) {
        // Params: List of expressions
        this.params = params
    }
}

class Expression {
    constructor(declaration, types, value) {
        this.declaration = declaration
        this.types = types
        this.value = value
    }
}