export function traverseDown(cell, cb, ...args) {
    // General pattern of iteration used across most functions
    let paramReturns = cell.params.map((param) => {
        return cb(param, ...args)
    });

    let bodyReturns = cell.body.map((child) => {
        return cb(child, ...args)
    });

    return [paramReturns, bodyReturns]
}

export function traverseUp(cell, cb, ...args) {
    if(cell.parent) {
        return cb(cell.parent, ...args);
    }
    // Implicitly return undefined at root
}