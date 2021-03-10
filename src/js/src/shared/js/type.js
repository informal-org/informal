export function isObject(val) {
    var type = typeof val;
    return type === 'object' || type === 'function' && !!val;
}

export function isFunction(val) {
    return typeof val === "function"
}

export function isCallable(val) {
    let type = typeof val;
    return type === "function" || type === "object" && type.__type == "Obj"
}

export function isNumber(val) {
    return (typeof val === "number")
}