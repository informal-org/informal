
export function isObject(val) {
    var type = typeof val;
    return type === 'object' || type === 'function' && !!val;
}