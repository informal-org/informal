import {} from "@appassembly/runtime/builtins"


export function execJs(code) {
    // TODO: Sandboxed execution
    try {
        return Function(code)()
    } catch(err) {
        console.log("Evaluation error")
        console.log(err);
        console.log(code);
        return {}
    }
}

