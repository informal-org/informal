const PRECEDENCE_ADD = 10;
const PRECEDENCE_MULTIPLY = 20;

// var treeify = require('treeify');

class Type {
    match() {
        return this;
    }
    repr() {
        return this.constructor.type;
    }
}

class CompoundType extends Type {
    constructor(...options) {
        super();
        this.options = options;
        this.value = [];
        this.rest = "";
    }

    repr() {
        return this.constructor.type + "()";
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
            return this;
        } else {
            return null;
        }
    }

    repr() {
        return "Literal("+  this.value + ")";
    }
}

class Intersection extends CompoundType {
    match(input) {
        const values = [];
        // console.log("Intersection check ", input, " against ", this.options)
        for (const option of this.options) {
            const result = match(input, option);
            if (!result) {
                return null;
            }
            values.push(result);
        }
        this.values = values;
        // console.log("Intersection ", this.options);
        this.rest = input.slice(1);
        return this
    }
    repr() {
        // return "Intersection("+  this.values.map((v) => v instanceof Type ? v.repr() : v) + ")";
        const lastVal = this.values[this.values.length - 1];
        return "Intersection(" + (lastVal instanceof Type ? lastVal.repr() : lastVal) + ")";
    }
}

class Choice extends CompoundType {
    match(input) {
        // console.log("Choice check ", input, " against ", this.options)
        for (const option of this.options) {
            const result = match(input, option);
            if (result) {
            //    console.log("Choice ", option);
                this.rest = input.slice(1);
                return result;
            }
        }
        return null;
    }
}

class Structure extends CompoundType {
    match(input) {
        this.rest = input;
        const values = [];
        // console.log("Structure check ", input, " against ", this.options)
        for (const option of this.options) {
            const result = match(this.rest, option);
            if (!result) {
                return null;
            }
            values.push(result);
            this.rest = result.rest;
        }
        this.values = values;
        console.log("Structure ", values);
        return this;
    }
    repr() {
        return "Structure{" + this.values.map((v) => v instanceof Type ? v.repr() : v).join("; ") + "}";
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

function PrecedenceGTE(node_bp, context_bp) {
    return node_bp >= context_bp;
}

function PrecedenceGT(node_bp, context_bp) {
    return node_bp > context_bp;
}

class DependentNode extends Type {
    constructor(binding_power) {
        super();
        this.binding_power = binding_power;
        this.rest = "";
        this.result = null;
    }

    match(input) {
        this.result = this.option.match(input);
        if(this.result) {
            this.rest = this.result.rest;
            return this;
        } else {
            return null;
        }
    }

    repr() {
        return this.constructor.name + " " + this.result.repr();
    }

}

class AddNode extends DependentNode {
    constructor(binding_power) {
        super(binding_power);
        this.option = new Structure(
            new Intersection(PrecedenceGT(PRECEDENCE_ADD, binding_power), new Expr(PRECEDENCE_ADD)),
            new LiteralType("+"),
            new Intersection(PrecedenceGTE(PRECEDENCE_ADD, binding_power), new Expr(PRECEDENCE_ADD) ),      
        )
    }
}

class MultiplyNode extends DependentNode {
    constructor(binding_power) {
        super(binding_power);
        this.option = new Structure(
            new Intersection(PrecedenceGT(PRECEDENCE_MULTIPLY, binding_power), new Expr(PRECEDENCE_MULTIPLY)),
            new LiteralType("*"),
            new Intersection(PrecedenceGTE(PRECEDENCE_MULTIPLY, binding_power), new Expr(PRECEDENCE_MULTIPLY)),
        )
    }
}

class Expr extends DependentNode {
    constructor(binding_power) {
        super(binding_power);
        this.result = null;
        this.option = () => new Choice(new AddNode(binding_power), new MultiplyNode(binding_power), new NumericLiteral());
    }

    match(input) {
        const result = match(input, this.option);
        if(result) {
            this.rest = result.rest;
            this.result = result;
            return this;
        } else {
            return null;
        }
    }

}

class NumericLiteral extends Type {
    match(input) {
        if (input[0].match(/[0-9]/)) {
            this.value = input[0];
            this.rest = input.slice(1);
            return this
        } else {
            return null;
        }
    }
    repr() {
        return "" + this.value;
    }
}

function parse(input) {
    const tokens = input.split(" ");
    const base = new Expr(0);
    // Recursive match. 
    // You can also define a greedy match function, which wraps it in a loop.
    // Which can be more efficient if you put the literal nodes first in the choice.
    const result = match(tokens, base);
    console.log(result.repr());
}

parse("1 + 2 * 3");