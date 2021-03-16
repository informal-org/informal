// Ported to JS from https://codon.com/hello-declarative-world#unification

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
        this.names = {}
        this.variables.forEach((v) => {
            this.names[v.name] = v
        })
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

    getByName(name) {
        return this.names[name]
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

export function* interleave(streamA, streamB) {
    let aDone, bDone = false;
    let aVal, bVal;

    while(!aDone || !bDone) {
        if(!aDone) {
            aVal = streamA.next();
            aDone = aVal.done
            if(!aDone || aVal.value !== undefined) {
                yield aVal.value
            }
        }
        if(!bDone) {
            bVal = streamB.next()
            bDone = bVal.done
            if(!bDone || bVal.value !== undefined) {
                yield bVal.value
            }
        }
    }
}

export class Goal {
    constructor(cb) {
        this.cb = cb
    }
    pursueIn(state) {
        return this.cb(state)
    }

    * pursueInStream(state) {
        return this.cb(state)
    }

    * pursueInEach(states) {
        // States are all of the valid states for the first state.
        // 
        let first = states.next();

        if(!first.done) {

            let firstStream = this.pursueIn(first.value)
            let remainingStreams = this.pursueInEach(states)
    
            let combined = interleave(firstStream, remainingStreams);
            let state;
            do {
                state = combined.next()
                if(!state.done || !state.value !== undefined) {   // hacky way to skip over missing returns
                    yield state.value
                }
            } while(!state.done)

        }

    }

    static equal(a, b) {
        let f = function*(state) {
            state = state.unify(a, b)
            if(state) {
                yield state
            }
        }

        return new Goal(f)
    }

    static withVariables(names, cb) {
        let f = function(state) {
            let variables;
            [state, variables] = state.createVariables(names);
            let goal = cb(...variables)
            return goal.pursueIn(state)
        }
        return new Goal(f)
    }

    static either(firstGoal, secondGoal) {
        let f = function(state) {
            let firstStream = firstGoal.pursueIn(state)
            let secondStream = secondGoal.pursueIn(state)
            return interleave(firstStream, secondStream)
        }

        return new Goal(f)
    }

    static both(firstGoal, secondGoal) {
        let f = function(state) {
            let states = firstGoal.pursueIn(state)
            return secondGoal.pursueInEach(states);
        }
        return new Goal(f)
    }
}