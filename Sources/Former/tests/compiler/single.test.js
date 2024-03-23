import { parseExpr } from "@informal/compiler/parser.js"
var dedent = require('dedent-js');

test('test indentation blocks', () => {
    let result = parseExpr(dedent`
    f = (x, y):
        x + y
    f(2, 3)
    `);
    expect(result.toString()).toEqual("({ (: (if ((grouping) x y) ((grouping) (<= x y))) x) (: ((grouping) x y) y))")
})
