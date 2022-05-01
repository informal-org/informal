

// Value = primitive value | Symbol | Expression
class Parameters {
    constructor(params) {
        // Params: List of Values
        this.params = params
    }
}

class Expression {
    constructor(declaration, types, value) {
        // fn add(a: Integer, b: Integer) : Integer = a + b
        // [         Declaration        ]   [Types]   [Values]
        // List of values
        this.declaration = declaration ? declaration : []
        this.types = types ? types : []
        this.value = value ? value : []
    }
}


// add(a: Integer, b: Integer): Integer = a + b

let TypeInteger = Symbol("Integer")

let addParams = Parameters(
    params=[
        Expression(
            declaration=[Symbol("a")],
            types=[TypeInteger]
        ),
        Expression(
            declaration=[Symbol("b")],
            types=[TypeInteger]
        )
    ]
)

let addCall = Expression(
    declaration=[],
    types=[],
    value=[Symbol("+"), Parameters(params=[
        1, 2
    ])]
)

let add = Expression(
    declaration=[Symbol("add"), addParams],
    types=[TypeInteger],
    value=[])


function declare(declaration, type) {
    // Declare a value
}

function check(type, value) {
    // Perform a type check. 
}

function match(declaration, valueExpr) {
    // Pattern match against the values, destructuring it.
    // Return back bindings or raises an exception.
}

function evaluate(valueExpr) {

}

function bind(declaration, value) {

}

function simpleParser(expr) {
    // Given a string expression, do some naiive parsing on it.
    let tokens = expr.split(/([ \(\)\{\}\[\]:=,;])/);
    

}