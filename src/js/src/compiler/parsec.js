/* 
    A simple, flexible parser-combinator based parsing approach.
*/

// function isString(obj) {
//     return typeof obj === 'string' || obj instanceof String
// }

function match(obj, value) {
    if(obj instanceof ParsecMatcher) {
        return obj.match(value)
    } else {
        throw new NoMatchError("No match error")
    }
}

function pick(currentMatch, newMatch) {
    if(currentMatch === undefined) {
        return newMatch;
    } else if(newMatch === undefined) {
        return currentMatch
    } else {
        // Shorter matches are more specific sub-sets of the longer matches.
        // Prefer shorter.
        return newMatch.priority() <= currentMatch.priority() ? newMatch : currentMatch;
    }
}

// function isMatcher(obj) {
//     return obj instanceof ParsecMatcher
// }

class NoMatchError extends Error {}

export class ParsecMatcher {
    constructor(){
    }
    match(value) {
        // For now, we define all matches as being prefix matches.
        // Something at the end checks if there is still remaining tokens.
        // Returns [result, rest] or throws an error.
        throw new NoMatchError("Not implemented")
    }
    priority() {
        return 0
    }
}

export class ParsecObj extends ParsecMatcher {
    constructor() {
        self.attributes = []
    }
    addAttr(attr) {
        this.attributes.push(attr);
    }
    match(value) {
    }
}

export class ParsecAttr extends ParsecMatcher {
    constructor(name=undefined, type=undefined) {
        // Raw literals = it's set as the type itself. without name.
        this.name = name
        this.type = type
    }
    match(value) {
        // Match on type for now.
        if(isString(this.type)) {
            if(value.startsWith(this.type)) {
                // TODO: What's the right result here? The string? Or an instance of this attr?
                return [this.type, this.value.slice(this.type.length)]
            }
        } else if(isMatcher(this.type)) {
            return this.type.match(value)
        } else {
            // We don't know how to treat this kind of type
            throw new NoMatchError(`Unknown type match ${this.type} for value ${value}`)
        }
    }
}

export class ListMatcher extends ParsecMatcher {
    constructor() {
        super()
        this.patterns = []
    }
    add(pattern) {
        this.patterns.push(pattern);
    }
}

// Choice
export class Any extends ListMatcher {
    constructor(){
        super();
    }
    match(input) {
        // Important - this should not just return the first match
        // That would bias it towards how we define the pattern rather than
        // what's specified in the input value.
        // Important - All Choices get the same input. Not chained.
        let selected = undefined;
        
        for(var i = 0; i < this.patterns.length; i++){
            let pattern = this.patterns[i];
            try {
                selected = pick(selected, match(pattern, input))
            } catch(e) {
                if (e instanceof NoMatchError) {
                    console.log("Skipping no match error")
                }
                else {
                    console.log(`Unknown error type: ${e}`)
                }
            }
        }
        if(selected === undefined) {
            throw new NoMatchError()
        }
        return selected;
    }
}

// Composition. Objects.
export class All extends ListMatcher {
    match(value){
        let matches = [];
        let rest = value;
        // If any of them fail, the entire result fails.
        this.patterns.forEach((pattern) => {
            let m = match(pattern, rest);
            matches.push(m[0])
            rest = m[1];
        });
        // These values are now the object binding.
        // TODO: Initialize and return
        return [matches, rest]
    }
}

export class Optional extends ParsecMatcher {
    constructor(pattern) {
        super()
        this.pattern = pattern
    }
    match(value) {
        if(this.pattern instanceof ParsecMatcher) {
            try {
                return this.pattern.match(value)
            } catch(e) {
                console.log(`Optional: Skipping error - ${e}`)
            }
        }
        // Return no match and same value without any errors
        return [undefined, value]
    }
}

// Prefix matching of a value
export class ValueType extends ParsecMatcher {
    constructor(pattern) {
        super()
        this.pattern = pattern
    }
}

export class StringType extends ValueType {
    match(input) {
        if(input.startsWith(this.pattern)) {
            return [this, input.slice(this.pattern.length)]
        }
        throw new NoMatchError()
    }

    priority() {
        // Prefer shorter
        return this.value.length
    }
}

export class NumericType extends ValueType {
    // TODO
}

// Name, Type -> Name, Type -> Value
export class Obj extends ParsecMatcher {

}

// Template of named, Type
export class Cls extends ParsecMatcher {

}