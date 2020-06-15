import { CellEnv } from "./CellEnv";
import { totalOrderByDeps } from "./order"
import { astToJs } from "./generator"
import { parseExpr } from "./parser"

// Expected generated code. Note: Equality is whitespace sensitive.

test('generates linear code', () => {
    // When cells don't depend on each other, their order remains the same
    let env = new CellEnv();

    expect(astToJs(parseExpr("1 + 2"))).toEqual("__aa_add(1,2)");
});
