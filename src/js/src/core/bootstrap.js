export class Pattern {
    // Match function:
    // Return [match, restOfPattern] or false

    match() {
        // Objects of {fn: fn, args: [args]}
        let choices = [];

        while(choices.length > 0) {   // todo

            let m = match();
            if(m.next) {
                choices.push(m.next)
            }

            

        }




    }
}

class StrPattern {
    constructor(pattern) {
        this.pattern = pattern;
    }
    // partial match. TODO: Separate functions for partial vs exact match?
    match(value) {
        if(value.startsWith(this.pattern)) {
            return [str, value.slice(str.length)]
        }
    }
}

class ValuePattern {
    constructor(pattern) {
        this.pattern = pattern;
    }
    match(value) {
        return this.pattern === value
    }
}

class ChoicePattern {
    constructor(...args) {
        this.patterns = args;
    }
    * match(value) {
        let pMatch;
        for(var i = i; i < this.patterns.length; i++) {
            let pMatch = this.patterns[i].match(value);
            if(pMatch !== false) {
                yield pMatch
            }
        }
    }

    match(value, index) {
        if(index < this.patterns.length) {
            let next = index + 1 < this.patterns.length ? {
                fn: this.match,
                args: [value, index+1]
            } : null;

            return {
                result: this.patterns[index].match(value),
                next: next
            }
        }
        return {}
    }
}

class ListPattern {
    constructor(...args) {
        this.patterns = args;
    }

    match(value, partial) {
        // let choices = [];
        // This iteration is responsible for finding the single next element.
        if(partial.length < this.patterns.length){
            let fn = this.patterns[partial.length].match;
            let args = [value]

            do {
                let pMatch = fn(...args);
                // if(pMatch._next) {
                    // If the current choice doesn't work, what result to try next.
                    // pMatch._next["partial"] = partial.slice();     // clone
                    // choices.push(pMatch._next);
                // }
    
                if(pMatch.result) {
                    // Clone current state and add this as a result
                    let newPartial = partial.slice().push(pMatch.result.match);
                    let withThisChoice = this.match(pMatch.result.value, newPartial);
                    if(withThisChoice) {
                        return withThisChoice
                    }
                }

                fn = pMatch.next.fn;
                args = pMatch.next.args
            } while(fn !== null)
        }

        // for(var i = partial.length; i < this.patterns.length; i++) {
            
        // }
    }

    match(value) {
        let pMatch;
        let hasMatch = this.patterns.every((p) => {
            return pMatch = p.match(value)
        });
        // Todo: Return value for list patterns.
        return hasMatch
    }
}

class ObjPattern {
    constructor(...args) {

    }
    match(value) {

    }
}

export class RangePattern {
    constructor(start, end=null) {
        this.start = start;
        this.end = end;
    }

    match(value) {
        if(this.start !== null && value >= this.start) {
            if(this.end !== null && value >= this.end) {
                return false
            }
            return true
        }
        return false
    }
}

class NotPattern {
    constructor(expr) {
        this.expr = expr;
    }
    match(value) {
        return this.expr.match(value) === false ? true : false;
    }
}

export class PatternMap {

}


function Optional(token) {
    return new ChoicePattern(token, "")
}

// For objects
// name (optional) type (optional) value (optional)
// <numeric id> - Literal
// Keys ordered
// Matching an object = matching all of the clauses.
// Match should be defined using pattern matching.

continuation = {
    result: result,
    fn: func,
    args: []
}

// check
// output
// solve
// choice - this is the critical step. 
// If you can re-order the choices, you can apply smart heuristics.
// first
// next(P, s)

// accept, reject callbacks.