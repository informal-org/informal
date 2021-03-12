export class Pattern {
    // Match function:
    // Return [match, restOfPattern] or false
}

class StrPattern {
    constructor(pattern) {
        this.pattern = pattern;
    }
    match(value) {      // partial match
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
    // Return first match
    match(value) {
        let pMatch;
        let hasMatch = this.patterns.some((p) => {
            return pMatch = p.match(value)
        });
        return hasMatch ? pMatch : false;
    }
}

class ListPattern {
    constructor(...args) {
        this.pattern = args;
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