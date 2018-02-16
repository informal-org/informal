import { Value, Engine } from "./engine";

export class ValueError extends Error {
    message: string;
    values: Value[];

    constructor(message: string){
        super(message);
        this.name = "ValueError"
    }

    toString(){
        return this.message + "[" + this.values.length + "]"
    }
}

export class EngineError extends Error {
    message: string;
    engine: Engine;

    constructor(message: string){
        super(message);
        this.name = "EngineError"
    }

    toString() {
        return this.message + "@Engine[" + this.engine + "]"
    }
}
