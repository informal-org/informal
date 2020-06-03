import { Obj } from "./flex"


class CyclicRefError extends Error {
    constructor(message) {
        super(message);
    }
}

class ParseError extends Error {
    constructor(message) {
        super(message);
    }
}

var global = window || global;

global.Obj = Obj;
global.CyclicRefError = CyclicRefError;
global.ParseError = ParseError;

export function execJs(code) {
    // TODO: Sandboxed execution
    return Function(code)()
}


function inspect() {
    
}

