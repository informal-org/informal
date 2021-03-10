
export function __aa_call(fn, ...args) {
    if(typeof fn == "function") {
        return fn(...args)
    }
    else {
        // Note that spread syntax doesn't work with .call when it's a native function
        // ((...args) => "hello"["charAt"](...args)).call(2)
        return fn.call(...args)
    }
}