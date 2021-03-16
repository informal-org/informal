import { State, Goal, interleave } from "@informal/core/kanren.js"

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

test('Test equal goal', () => {
    let state = new State();
    let x, y, z;
    [state, [x, y, z]] = state.createVariables(["x", "y", "z"])

    let goal = Goal.equal(x, 5)
    let states = goal.pursueIn(state);

    let goalState = states.next().value;
    expect(goalState.valueOf(x)).toEqual(5);
});

test('Test goal with variables', () => {
    let goal = Goal.withVariables(["x"], (x) => Goal.equal(x, 5))
    let states = goal.pursueIn(new State());
    let state = states.next().value;
    expect(state.valueOf(state.getByName("x"))).toEqual(5);
})

test('Test stream interleave', () => {
    let letters = function*() {
        while(true){
            yield "A"
            yield "B"
            yield "C"
        }
    }

    let numbers = function*() {
        for(var i = 0; i < 5; i++) {
            yield i
        }
    }

    let combined = interleave(letters(), numbers());
    let combinedValues = [];
    for(var i = 0; i < 18; i++) {
        combinedValues.push(combined.next().value)
    }
    expect(combinedValues).toEqual(["A", 0, "B", 1, "C", 2,
        "A", 3, "B", 4, "C", "A",
        "B", "C", "A", "B", "C", "A",
    ]);
})

test('Test either goal', () => {
    let goal = Goal.withVariables(["x"], (x) => {
        return Goal.either(
            Goal.equal(x, 5),
            Goal.equal(x, 6),
        )
    });
    let states = goal.pursueIn(new State());
    let state = states.next().value;
    expect(state.valueOf(state.getByName("x"))).toEqual(5)
    state = states.next().value;
    expect(state.valueOf(state.getByName("x"))).toEqual(6)
})


test('Test both goal', () => {
    let goal = Goal.withVariables(["a", "b"], (a, b) => {
        return Goal.both(
            Goal.equal(a, 7),
            Goal.either(
                Goal.equal(b, 5),
                Goal.equal(b, 6)
            )
        )
    });
    let states = goal.pursueIn(new State());
    let state = states.next().value;
    expect(state.valueOf(state.getByName("a"))).toEqual(7)
    expect(state.valueOf(state.getByName("b"))).toEqual(5)
    state = states.next().value;
    expect(state.valueOf(state.getByName("a"))).toEqual(7)
    expect(state.valueOf(state.getByName("b"))).toEqual(6)
})

test('Test incompatible goals', () => {
    let goal = Goal.withVariables(["x"], (x) => {
        return Goal.both(
            Goal.equal(1, x),
            Goal.equal(x, 2)
        )
    })
    let states = goal.pursueIn(new State());
    let state = states.next()       // Yields undefined
    expect(state.value).toEqual(undefined)
    state = states.next()           // Function returns (nothing)
    expect(state.done).toEqual(true)
});