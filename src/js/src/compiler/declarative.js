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

    static parse(input) {
        let rest = input;
        let value = [];
        
        // Get structure instance from child class
        const structure = this.structure();

        if(structure.length > 0) {
            // Call each of the matchers
            let structureMatches = structure.every((element) => {
                let result = [];
                
                if(element.prototype instanceof Node) {
                    result = element.parse(rest);
                } else if(isString(element)) {
                    result = parseString(element, rest)
                } else {
                    console.log("Unknown node type")
                    return false
                }

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

class YMD extends Node {
    static structure() {
        return [Digit, Digit, Digit, Digit, "-", Digit, Digit, "-", Digit, Digit]
    }
}



console.log(YMD.parse("2021-09-01").toString())