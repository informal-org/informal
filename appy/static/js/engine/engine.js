import { CellEnv } from "./CellEnv";
import { Cell } from "./Cell";
import { parseExpr } from "./parser"
import { genJs } from "./generator"
import { execJs, interpret } from "./executor"
import { defineNamespace } from "./namespace"

// Dict, Value -> value | null
export function resolveMember(node, context) {
    // cell4.name.blah
    // { "type": "MemberExpression", "computed": false, 
    // "object": { "type": "MemberExpression", "computed": false, 
        // "object": { "type": "Identifier", "name": "cell4" }, 
        // "property": { "type": "Identifier", "name": "name" } }, 
    // "property": { "type": "Identifier", "name": "blah" } } 
    // Object could be recursive for nested a.b.c style lookup.
    // let object = null;

    // let subnode = node;
    // while(node) {

    // }
    // let object = context.resolve(node.object.name);
    // if(object !== null){
    //     return object.resolve(node.property.name)
    // }
    // console.log(node);
    let object = null;
    if(node.object.type === "MemberExpression"){
        object = resolveMember(node.object, context);
    } else {
        // Assert is identifier
        object = context.resolve(node.object.name);
    }

    // console.log("object is");
    // console.log(object.name);

    if(object !== null){
        return object.resolve(node.property.name);
    }
    return null;
}

function isBoolean(value) {
    let lower = value.toLowerCase();
    return lower == "true" || lower == "false"
}

// Returns cell id
function resolve(state, name, scope) {
    var matches = state.byName[name];
    // TODO: Implement scope resolution
    if(matches !== undefined && matches.length > 0) {
        return matches[0]
    }
    return null
}


function runInterpreted(env) {
    defineNamespace(env.root)
    interpret(env)


    let output = [];


    env.root.body.forEach((cell) => {
        output.push({
            id: cell.id,
            value: cell.result,
            error: ""
        })
    })


    return output;
}

function runGenerated(env) {
    defineNamespace(env.root)
    let code = genJs(env);
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
            error: cell.error ? cell.error : cellResult.error
        })
    })

    return output;
}


export function evaluate(state) {
    let env = new CellEnv();
    env.raw_map = state.cellsReducer.byId;

    let root_id = state.cellsReducer.currentRoot;
    env.create(state.cellsReducer.byId, root_id)

    // let cells = [];
    // state.cellsReducer.allIds.forEach((cell_id) => {
    //     let raw_cell = env.getRawCell(cell_id);

    //     let cell = new Cell(raw_cell, undefined, env);
    //     cells.push(cell);

    //     // defineNamespace(cell)

    //     // TODO: Doesn't matter yet, since we haven't defined nested cells
    //     // [cell.params, cell.body] = traverseDown(raw_cell, env.createCell, cell);
    // })

    console.log("raw map");
    console.log(env.raw_map);
    env.parseAll(root_id);

    // let output = runInterpreted(env);
    let output = runGenerated(env);

    // ignore
    // expr.body.forEach(element => {
    //     let code = generateCode(element);
    //     let result = execCode(code);

    //     output.push({
    //         id: element.id,
    //         output: result,
    //         error: ""
    //     });
    // });

    return {'results': output}
}

