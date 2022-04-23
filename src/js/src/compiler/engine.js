import { execJs } from "./executor"
import { defineNamespace } from "./namespace"
import { compileJS } from "./compiler"
import { CellEnv } from "./CellEnv"

function runGenerated(env) {
    defineNamespace(env.root)
    let code = compileJS(env);
    // console.log(code);

    // 0: {id: 0, output: "Hello 2", error: ""}
    let result = execJs(code);
    let output = [];

    Object.values(env.cell_map).forEach((cell) => {
        var cellResult = result[cell.id];
        if(cellResult === undefined) {cellResult = {}}

        output.push({
            id: cell.id,
            value: cellResult.value,
            error: cell.error ? cell.error : cellResult.error,
        })
    })

    return output;
}


export function evaluate(byId, rootId) {
    let env = new CellEnv();
    env.create(byId, rootId);
    env.parseAll(rootId);
    let output = runGenerated(env);
    return {'results': output}
}