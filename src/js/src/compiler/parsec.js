/* 
    A simple, flexible parser-combinator based parsing approach.
*/

function isString(obj) {
    return typeof obj === 'string' || obj instanceof String
}

function isMatcher(obj) {
    return obj instanceof ParsecMatcher
}

class NoMatchError extends Error {}

class ParsecMatcher {
    match(value) {
        // For now, we define all matches as being prefix matches.
        // Something at the end checks if there is still remaining tokens.
        // Returns [result, rest] or throws an error.
        throw NoMatchError("Not implemented")
    }
}

class ParsecObj extends ParsecMatcher {
    constructor() {
        self.attributes = []
    }
    addAttr(attr) {
        this.attributes.push(attr);
    }
    match(value) {
        let matches = [];
        let rest = value;
        this.attributes.forEach((attr) => {
            let m = attr.match(rest);
            matches.push(m[0])
            rest = m[1];
        })
        // These values are now the object binding.
        // TODO: Initialize and return
        return [matches, rest]
    }
}

class ParsecAttr extends ParsecMatcher {
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
            throw NoMatchError(`Unknown type match ${this.type} for value ${value}`)
        }
    }
}


// TODO Choice
class Choice extends ParsecMatcher {
    match(value) {

    }
}

