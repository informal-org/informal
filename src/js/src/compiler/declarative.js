/*
Approach:
Declaratively define what each expression is composed of.
Write a general recursive-descent/pratt style parser which supports the left-recursive nature of this, with automatic precedence levels.
ex. 
The sub-choices denote that those elements are at the same precedence level.
Expr: Choice([number, Choice([mul, div]), Choice([add, sub])])
Equals: [
    left: Expr
    "="
    // This expresses that equals is right-associative, by prioritizing that association before the looser binding.    
    right: Choice(Equals, Expr)
]

Each of these things themselves represent the structure of the given result node.

Iterations:
- Write a date parser
- Write a floating point parser
- Write a simple math expression parser
- Extend it to the full language.
*/

function isString(value) {
    return typeof value === 'string' || value instanceof String
}

function parseString(target, input) {
    if(input.startsWith(target)) {
        return [target, input.substring(target.length)]
    } 
    return []
}


class Node {
    constructor(value) {
        this.value = value
    }
    static structure() {
        return []
    }

    static check(value) {
        return false
    }

    static match(pattern, input) {
        let result = [];
                
        if(pattern.prototype instanceof Node) {
            console.log(pattern)
            result = pattern.parse(input);
        } else if (pattern instanceof Node) {
            console.log("an actual instance of node")
            console.log(pattern)
            result = pattern.parse(input);
        } else if(isString(pattern)) {
            result = parseString(pattern, input)
        } else {
            console.log("Unknown node type")
        }

        return result

    }

    static parse(input) {
        let rest = input;
        let value = [];
        
        // Get structure instance from child class
        const structure = this.structure();

        if(structure.length > 0) {
            // Call each of the matchers
            let structureMatches = structure.every((element) => {
                let result = this.match(element, rest);

                if(result.length == 2) {
                    value.push(result[0]);
                    rest = result[1];
                    return true
                } else {
                    return false
                }

            });

            // If the entire structure doesn't match, then it's not valid
            if(!structureMatches) {
                return []
            }
        } else {
            // Character match
            if(input.length > 0 && this.check(input[0])) {
                value = input[0]
                rest = input.substring(1);
            } else {
                return []
            }
        }
        // Partial structure match at this point.
        // Check and convert it to node

        // Return [match, rest] where match is an instance of Node
        return [new this(value), rest]
    }

    toString() {
        return this.constructor.name + "(" + this.value + ")"
    }
}

class Digit extends Node {
    static check(ch) {
        return ch >= '0' && ch <= '9';
    }
}

class Alpha extends Node {
    static check(ch) {
        // Base version just supports ASCII
        return ch >= 'A' && ch <= 'z';
    }
}

class List extends Node {

}

class Choice extends Node {
    constructor(...options) {
        super(options)
        this.options = options
    }
    parse(input) {
        for(var i = 0; i < this.options.length; i++) {
            let option = this.options[i];
            let result = this.constructor.match(option, input)

            if(result.length == 2) {
                return result
            }
        }
        return []
    }
}

// TODO
class Optional extends Node {
    constructor(option) {
        super(option)
        this.option = option
    }

    static parse(input) {
        let result = this.match(this.option, input);
        if(result.length == 2) {
            return result
        }
        // Passthrough that makes it look like optional succeeded.
        return ["", input]
    }
}


class YMD extends Node {
    static structure() {
        return [Digit, Digit, Digit, Digit, "-", Digit, Digit, "-", Digit, Digit]
    }
}

class ExponentPart extends Node {
    static structure() {
        return [
            new Choice("e", "E"),
            // SIGN
            Digit       // List of digits - one or more.
        ]
    }
}


class FloatParser extends Node {
    static structure() {
        return [

        ]
    }
}

// YMD(Digit(2),Digit(0),Digit(2),Digit(1),-,Digit(0),Digit(9),-,Digit(0),Digit(1)),
console.log(YMD.parse("2021-09-01").toString())

console.log(ExponentPart.parse("e5").toString())
console.log(ExponentPart.parse("E5").toString())