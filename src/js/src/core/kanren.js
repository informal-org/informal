class Variable {
    static maxVarId = 0;
    constructor(name) {
        this.id = Variable.maxVarId++;
        this.name = name
    }

    toString(){ return this.name }
}

// Set of Identity -> value
export class State {
    constructor(variables=[], values = {}) {
        this.variables = variables
        this.values = values
    }
    createVariables(names) {
        let newVars = names.map((name) => new Variable(name));

        return [new State(
            this.variables.concat(newVars),
            this.values
        ), newVars]
    }

    assignValues(newValues) {   // varID -> value map
        return new State(this.variables, Object.assign({}, this.values, newValues))
    }

    valueOf(v) {    // Optimization: Avoid recursion here. Use a while loop
        return v instanceof Variable && v.id in this.values ? this.valueOf(this.values[v.id]) : v
    }

    // Unify variables a and b in this given state.
    unify(a, b) {
        let aVal = this.valueOf(a)
        let bVal = this.valueOf(b)

        // State is already unified
        if(aVal == bVal) {
            return this
        }
        else if(aVal instanceof Variable) {
            return this.assignValues(Object.fromEntries([
                [aVal.id, bVal]
            ]))
        } else if(bVal instanceof Variable) {
            return this.assignValues(Object.fromEntries([
                [bVal.id, aVal]
            ]))
        }
        // Else - cannot unify

    }

    toString(){
        return "State(" + this.variables + ", " + this.values + ")"
    }
}

