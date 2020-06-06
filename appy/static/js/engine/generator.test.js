import { CellEnv } from "./CellEnv";
import { totalOrderByDeps } from "./order"
import { genJs, JS_PRE_CODE, JS_POST_CODE } from "./generator"
import { parseExpr } from "./parser"

// Tree where no cells depend on each other.
const TREE_LINEAR_MATH = {
    0: {
      id: 0,
      name: "root",
      depends_on: [], 
  
      body: [1, 2, 3],
      params: []
    },
    1: {
        id: 1,
        name: "a",
        expr: "1 + 1",
        depends_on: [],
        
        body: [],
        params: []
    },
    2: {
        id: 2,
        name: "b",
        depends_on: [1],
        expr: "a * 2",
  
        body: [],
        params: []
    },
    3: {
        id: 3,
        name: "",
        depends_on: [2],
        expr: "b",
  
        body: [],
        params: []
    }, 
}

// Expected generated code. Note: Equality is whitespace sensitive.
const LINEAR_EXPECTED = `var a = 1+1
ctx.set("1", a);
var b = a*2
ctx.set("2", b);
var __3 = b
ctx.set("3", __3);
`



test('generates linear code', () => {
    // When cells don't depend on each other, their order remains the same
    let env = new CellEnv();
    env.create(TREE_LINEAR_MATH, 0);

    Object.values(env.cell_map).forEach((cell) => {
        cell.parsed = parseExpr(cell.expr)
    })

    totalOrderByDeps(env)

    let cycles = env.cyclic_deps;
    let order = env.eval_order;
    
    // Expect all cells returned
    expect(order.length).toEqual(4);

    let code = genJs(env);
    let expected_code = JS_PRE_CODE + LINEAR_EXPECTED + JS_POST_CODE;
    expect(code).toEqual(expected_code);

});
