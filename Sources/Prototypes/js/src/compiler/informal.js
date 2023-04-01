const PRECEDENCE_ADD = 10;
const PRECEDENCE_MULTIPLY = 20;

class Type {
    match() {
        return true;
    }
}

class CompoundType extends Type {
    constructor(...options) {
        super();
        this.options = options;
        this.value = [];
        this.rest = "";
    }
}

class LiteralType extends Type {
    constructor(value) {
        super();
        this.value = value;
        this.rest = "";
    }

    match(input) {
        // console.log("Literal check ", input, " against ", this.value)
        if(this.value === input[0]) {
            console.log("Literal ", this.value);
            this.rest = input.slice(1);
            return input.slice(1);
        } else {
            return null;
        }
    }
}

class Intersection extends CompoundType {
    match(input) {
        // console.log("Intersection check ", input, " against ", this.options)
        for (const option of this.options) {
            if (!match(input, option)) {
                return null;
            }
        }
        console.log("Intersection ", this.options);
        return input.slice(1);
    }
}

class Choice extends CompoundType {
    match(input) {
        // console.log("Choice check ", input, " against ", this.options)
        for (const option of this.options) {
            const result = match(input, option);
            if (result) {
                console.log("Choice ", option);
                return result;
            }
        }
        return null;
    }
}

class Structure extends CompoundType {
    match(input) {
        // console.log("Structure check ", input, " against ", this.options)
        for (const option of this.options) {
            const result = match(input, option);
            if (!result) {
                return null;
            }
            input = result;
        }
        console.log("Structure ", this.options);
        return input;
    }
}

function match(input, type) {
    // console.log("input is ", input)
    // console.log("type is ", type)
    if(type instanceof Type) {
        return type.match(input);
    } else if(typeof type === "boolean") {
        return type ? input : null;
    } else if(typeof type === "function") {
        return match(input, type(input))
    } else {
        throw new Error("Unknown type: " + typeof type);
    }
}


/////////////////////////////////////////////////////////////

// function Intersection(...options) {
//     // The input matches against all of the options.
//     return function(input) {
//         console.log("Intersection check ", input, " against ", options);

//         for (const option of options) {
//             let result;
//             if(typeof option === "function") {
//                 result = option(input[0]);
//             } else {
//                 result = option;
//             }
//             if (!result) {
//                 return;
//             }
//         }
//         return input;
//     }
// }

// function Choice(...options) {
//     // The input matches against one of the options.
//     return function(input) {
//         console.log("Chocie check ", input, " against ", options);

//         for (const option of options) {
//             let result;
//             if(typeof option === "function") {
//                 result = option(input[0]);
//             } else {
//                 result = option;
//             }
//             if (result) {
//                 return result;
//             }
//         }
//     }
// }

// function Structure(...options) {
//     // The input matches against the option at each index.
//     return function(input) {
//         console.log("Struct check ", input, " against ", options);
//         for(let i = 0; i < options.length; i++) {
//             const option = options[i];
//             let result;
//             // check if option is a string
//             if (typeof option === "string") {
//                 result = input[i] === option;
//                 console.log(input[i], " vs ", option);
//             } else {
//                 result = option(input[i]);
//             }
//             if (!result) {
//                 return;
//             }
//         }
//     }
// }

function PrecedenceGTE(node_bp, context_bp) {
    return node_bp >= context_bp;
}

function PrecedenceGT(node_bp, context_bp) {
    return node_bp > context_bp;
}

function AddNode(binding_power) {
    return new Structure(
        new Intersection(PrecedenceGT(PRECEDENCE_ADD, binding_power), Expr(PRECEDENCE_ADD)),
        new LiteralType("+"),
        new Intersection(PrecedenceGTE(PRECEDENCE_ADD, binding_power), Expr(PRECEDENCE_ADD)),      
    )
}

function MultiplyNode(binding_power) {
    return new Structure(
        new Intersection(PrecedenceGT(PRECEDENCE_MULTIPLY, binding_power), Expr(PRECEDENCE_MULTIPLY)),
        new LiteralType("*"),
        new Intersection(PrecedenceGTE(PRECEDENCE_MULTIPLY, binding_power), Expr(PRECEDENCE_MULTIPLY)),
    )
}

class NumericLiteral extends Type {
    match(input) {
        if (input[0].match(/[0-9]/)) {
            console.log("NumericLiteral ", input[0]);
            return input.slice(1);
        } else {
            return null;
        }
    }
}

function Expr(binding_power) {
    return () => new Choice(AddNode(binding_power), MultiplyNode(binding_power), new NumericLiteral());
}

function parse(input) {
    const tokens = input.split(" ");
    const base = Expr(0);
    // console.log(base().match(tokens));
    console.log(    match(tokens, base)    );
}

parse("1 + 2 * 3");