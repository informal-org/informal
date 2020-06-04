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
    try {
        return Function(code)()
    } catch(err) {
        console.log("Evaluation error")
        console.log(err);
        return {}
    }
}


function inspect() {
    
}

