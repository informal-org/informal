import { Obj } from "../flex.js"

export class Environment {
    constructor(table, parent=null) {
        // Symbol Table
        this.table = table;
        this.parent = parent;
    }

    define(name, value) {
        return this.table.insert(name, value)
    }

    _find_env(name) {
        let env = this;
        while(env) {
            if(name in env.table) {
                return env
            }
            env = env.parent
        }
        return null
    }

    get(name) {
        let env = this._find_env(name)
        if(env !== null){
            return env.table[name]
        }
        throw Error(name + " not found")
    }

    is_defined(name) {
        return this._find_env(name) !== null
    }
}