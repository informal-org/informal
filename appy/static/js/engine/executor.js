
function execCode(code) {
    // TODO: Sandboxed execution
    return eval(code);
}


function inspect() {
    
}

export function evaluate(state) {
    console.log("Evaluating");
    console.log(state);
    
    // 0: {id: 0, output: "Hello 2", error: ""}
    let output = [];
    let cells = state.cellsReducer.byId;
    let parsed = parseAll(cells);

    let code = generateCode(parsed);
    let result = execCode(code);
    console.log("Final result");
    console.log(result);

    for(var cell_id in cells) {
        var element = cells[cell_id];
        output.push({
            id: element.id,
            value: result[element.id],
            error: ""
        });
    }
    // expr.body.forEach(element => {
    //     let code = generateCode(element);
    //     let result = execCode(code);

    //     output.push({
    //         id: element.id,
    //         output: result,
    //         error: ""
    //     });
    // });
    console.log(output);

    return {'results': output}
}
