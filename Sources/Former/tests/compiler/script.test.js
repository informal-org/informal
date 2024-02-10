import { evaluate } from "../../src"
var dedent = require('dedent-js');


// test('Evaluate arithmetic scripts', () => {
//     expect(evalScript("1 + 2 * 3 + 4 / 2 - 4")).toEqual(5);
// })

test('Evaluate multi-line expression', () => {
    expect(evalScript(dedent`
    a = 1
    b = 2
    a + b
`)).toEqual(3);

    // expect(evalScript("():\na = 1\nb = 2\na + b")).toEqual(3);
})



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
