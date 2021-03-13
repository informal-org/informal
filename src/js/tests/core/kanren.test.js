import { State } from "@informal/core/kanren.js"

test('Test unify', () => {
    let state = new State();
    let x, y;
    [state, [x, y]] = state.createVariables(["x", "y"])
    // Unify with self = same
    expect(state.unify(x, x)).toEqual(state)
    
    state = state.unify(x, y)
    state = state.unify(x, 5)
    expect(state.valueOf(x)).toEqual(5)
});