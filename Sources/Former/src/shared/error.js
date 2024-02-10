export class SyntaxError extends Error {
    constructor(message) {
        super(message)
        this.name = "SyntaxError"
    }
}

export class RuntimeError extends Error {
    constructor(message) {
        super(message)
        this.name = "RuntimeError"
    }
}