import { evaluate } from "../../src"
var dedent = require('dedent-js');


test('Evaluate arithmetic scripts', () => {
    expect(evalScript("1 + 2 * 3 + 4 / 2 - 4")).toEqual(5);
})

test('Evaluate multi-line expression', () => {
    expect(evalScript(dedent`
    a = 1
    b = 2
    a + b
    `)).toEqual(3);
})

test('Eval array expressions', () => {
    const result = evalScript(dedent`
    a = [1, 2, 3]
    b = a + 2
    c = a * 2
    b + c
`);
    const resultArray = Array.from(result.iter());
    expect(resultArray).toEqual([5, 8, 11]); // [3, 4, 5] + [2, 4, 6]
})


test('Eval objects with attribute access', () => {
    const result = evalScript(dedent`
    a = { x: 1, y: 2 }
    a.x + a.y
`);
    expect(result).toEqual(3);
})

// Functions.
// Guard clauses
// Conditionals
// print function


function evalScript(expr) {
    // Should it be expr or body?
    let cellWrapper = {
        "root": {
            "id": "root",
            "name": "",
            "expr": expr,
            "depends_on": [],
            "body": [],
            "params": []
        }
    }
    let output = evaluate(cellWrapper, "root").results[0];
    console.log(output);
    if(output.error) {
        throw new Error(output.error)
    } else {
        return output.value
    }
}
